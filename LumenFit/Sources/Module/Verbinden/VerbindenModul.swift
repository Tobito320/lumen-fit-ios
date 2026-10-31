import Foundation

/// Modulstart von verbinden (Lovea-Brücke, Mitteilungen, Band, Freundeskarten). `start` läuft synchron in `ModulStart.starteAlle`, ist idempotent und
/// legt nichts an, was Strom oder Rechte braucht: ohne die Schalter `loveaVerbunden` und `bandAktiv` bleibt alles still (kein Bluetooth, keine Datei).
enum VerbindenModul {
    @MainActor static func start(_ umgebung: AppUmgebung) {
        guard VerbindenDienste.geteilt == nil else { return }
        VerbindenDienste.geteilt = VerbindenDienste(umgebung)
    }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte), aber nur mit der Fixture-Datei `Verbinden/verbunden.json`; sonst bleibt alles unsichtbar.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        #if DEBUG
        guard let fixtures = StartArgumente.lies().fixtures,
              FileManager.default.fileExists(atPath: fixtures.appendingPathComponent("Verbinden/verbunden.json").path),
              let daten = umgebung.daten,
              let partner = (try? Data(contentsOf: fixtures.appendingPathComponent("Verbinden/partner-ansichten.json")))
                  ?? (try? Data(contentsOf: fixtures.appendingPathComponent("Verbinden/partner-beispiel.json"))),
              let datei = try? LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: partner) else { return }
        daten.einstellungen.aendere { $0.loveaVerbunden = true }
        daten.verbindung.freigaben = [.schritte, .gym, .schlaf]
        VerbindenDemo.partner = .verbunden(datei)
        let woche = Datum.wochenstart(Datum.text(umgebung.uhr()))
        let jetzt = umgebung.uhr()
        daten.verbindung.freunde = [
            FreundKarte(id: "demo-a-\(woche)", name: "Beispiel Freund A", woche: woche, schritte: 61_400, gymTage: 4, schlafSchnittMinuten: 440, erstellt: jetzt, respekt: true),
            FreundKarte(id: "demo-b-\(woche)", name: "Beispiel Freund B", woche: woche, schritte: 38_900, gymTage: 2, schlafSchnittMinuten: 410, erstellt: jetzt, respekt: false)
        ]
        #endif
    }
}

/// Nur für die Demo: der Partner-Stand aus der Fixture, weil die Demo-Umgebung `KeinePartnerBruecke` nutzt und `VerbindungStore.partner` nur lesbar ist
/// (Wunsch ans Grundgerüst: die Demo soll die Brücke aus den Fixtures nehmen). Außerhalb der Demo immer `nil`.
@MainActor
enum VerbindenDemo {
    static var partner: PartnerStand?
}

/// Verdrahtet die Teile des Moduls mit den Ereignissen der App: Datei für Lovea schreiben, Partner-Mitteilungen, Band, Wünsche. Es gibt eine Instanz
/// (`geteilt`). Sie liest nur Stores und Dateien, nie Health (der Abruf läuft auch bei gesperrtem Gerät).
@MainActor
final class VerbindenDienste {
    static var geteilt: VerbindenDienste?

    private let umgebung: AppUmgebung
    let bruecke: LoveaBrueckeDienst
    let band: BandDienstImpl
    let kopfhoerer = KopfhoererDienst()
    private var regeln: [ProfilID: PartnerEreignisRegeln] = [:]
    private var wuensche: BandWunschSchlange?
    /// Die Weck-Wünsche von Lumen Alarm (zweite Brücke) und der eine Wartetakt bis zum nächsten künftigen Wunsch.
    private var alarmWuensche: BandWunschSchlange?
    private var alarmTakt: Task<Void, Never>?
    private let schlafe: @Sendable (TimeInterval) async -> Void
    private var beobachter: [DarwinBeobachter] = []
    private var strom: Task<Void, Never>?
    private var bandWarAn = false
    private var loveaWarAn = false
    private var alarmWarAn = true

    /// `startAbruf: false` lässt die erste Runde aus (Tests rufen `abruf()` selbst und warten darauf). `schlafe`: der Wartetakt der Weck-Wünsche (Tests geben einen eigenen).
    init(_ umgebung: AppUmgebung, startAbruf: Bool = true,
         schlafe: @escaping @Sendable (TimeInterval) async -> Void = { _ = try? await Task.sleep(for: .seconds($0)) }) {
        self.umgebung = umgebung
        self.schlafe = schlafe
        bruecke = LoveaBrueckeDienst(bruecke: umgebung.bruecke,
                                     quellen: .init(daten: { [weak umgebung] in umgebung?.daten }, gesundheit: umgebung.gesundheit,
                                                    profilName: { [weak umgebung] in umgebung?.profil.aktiv?.name }),
                                     uhr: umgebung.uhr)
        bruecke.hochladen = { [weak umgebung] in VerbindungenLogik.hochladen(umgebung?.konto.verbindungen.antwort) }
        let uhr = umgebung.uhr
        band = BandDienstImpl(aktiv: { [weak umgebung] in umgebung?.daten?.einstellungen.werte.bandAktiv ?? false },
                              bruecke: umgebung.bruecke, uhr: uhr,
                              training: { [weak umgebung] in umgebung?.daten?.training.laufende() != nil },
                              alarmBruecke: umgebung.alarmBruecke,
                              alarmAn: { [weak umgebung] in umgebung?.daten?.einstellungen.werte.alarmWeckt ?? false },
                              modell: { [weak umgebung] in
                                  TrackerModell(funk: { TrackerFunk(melden: $0) }, senke: .raum { umgebung?.daten?.raum }, uhr: uhr)
                              })
        umgebung.band = band
        umgebung.konto.beiVerbindungenGeaendert = { [weak self] in self?.verbindungenGeaendert() }
        band.beiVerbunden = { [weak self] in self?.wuenscheAusfuehren(); self?.alarmWuenscheAusfuehren() }
        band.beiPauseEnde = { [weak self] in self?.kopfhoerer.pauseEnde() }
        band.beiAkkuWarnung = { [weak umgebung] prozent in
            let inhalt = BandAkkuWarnung.text(prozent: prozent)
            Task { await umgebung?.mitteiler.zeige(id: BandAkkuWarnung.kennung, titel: inhalt.titel, text: inhalt.text, route: nil) }
        }
        umgebung.beiAbruf { [weak self] in await self?.abruf() }
        let ereignisse = umgebung.ereignisse.strom()
        strom = Task { @MainActor [weak self] in
            for await ereignis in ereignisse { await self?.behandle(ereignis) }
        }
        beobachter = [
            DarwinBeobachter(name: DarwinKanal.partner) { [weak self] in Task { await self?.abruf() } },
            DarwinBeobachter(name: DarwinKanal.bandWunsch) { [weak self] in self?.wuenscheAusfuehren() },
            DarwinBeobachter(name: DarwinKanal.alarmWunsch) { [weak self] in self?.alarmWuenscheAusfuehren() }
        ]
        bandWarAn = umgebung.daten?.einstellungen.werte.bandAktiv ?? false
        loveaWarAn = umgebung.daten?.einstellungen.werte.loveaVerbunden ?? false
        alarmWarAn = umgebung.daten?.einstellungen.werte.alarmWeckt ?? true
        if startAbruf { Task { await abruf() } }
    }

    // MARK: Abruf

    /// Eine Runde: Partner-Stand lesen, Mitteilungen, Band fortsetzen, Wünsche, Datei für Lovea. Läuft bei Start, Vordergrund, Hintergrund-Abruf und Darwin-Anstoß.
    func abruf() async {
        guard let daten = umgebung.daten else { return }
        let jetzt = umgebung.uhr()
        let werte = daten.einstellungen.werte
        daten.verbindung.aktualisiere(jetzt: jetzt)
        spiegleFreigaben(daten)
        if werte.loveaVerbunden {
            await regelnFuer(daten).verarbeite(daten.verbindung.partner, einstellungen: werte, jetzt: jetzt)
        }
        bruecke.schreibe()   // Datei für Lovea (mit Schalter) und Stand für den Server (nur mit aktiver Verbindung)
        bandStandardAnwenden(daten)
        if daten.einstellungen.werte.bandAktiv {
            band.starte()
            wuenscheAusfuehren()
            alarmWuenscheAusfuehren()
            band.statusSchreiben()
        }
    }

    /// Die Lovea-Datei zeigt nur, was die Lovea-Verbindung auf dem Server zeigt. Nach dem Entfernen oder der Pause ist sie leer. Ohne Stand vom Server bleibt alles beim Alten.
    private func spiegleFreigaben(_ daten: DatenSatz) {
        guard umgebung.konto.verbindungen.antwort != nil else { return }
        let neu = VerbindungenLogik.freigaben(fuer: umgebung.konto.verbindungen.lovea)
        if daten.verbindung.freigaben != neu { daten.verbindung.freigaben = neu }
    }

    /// Der Server stellt das Band für dieses Konto von selbst an (`bandStandard`), aber nur, solange es nie bewusst ausgeschaltet wurde.
    private func bandStandardAnwenden(_ daten: DatenSatz) {
        let werte = daten.einstellungen.werte
        guard umgebung.konto.config.bandStandard, !werte.bandAktiv, !werte.bandBewusstAus else { return }
        daten.einstellungen.aendere { $0.bandAktiv = true }
    }

    /// Der Stand der Verbindungen hat sich geändert (neu geholt, Einstellung, Entfernen): Partner-Stand lesen, Datei und Server-Stand nachziehen.
    private func verbindungenGeaendert() {
        Task { await abruf() }
    }

    private func regelnFuer(_ daten: DatenSatz) -> PartnerEreignisRegeln {
        if let r = regeln[daten.profil] { return r }
        let neu = PartnerEreignisRegeln(mitteiler: umgebung.mitteiler, ordner: daten.ordner)
        neu.beiNeuem = { [weak self] ereignis in self?.band.partnerEreignis(ereignis) }
        regeln[daten.profil] = neu
        return neu
    }

    /// Wünsche aus `band-wuensche.json` ausführen: nur mit Lovea-Schalter und Band-Schalter.
    func wuenscheAusfuehren() {
        guard let werte = umgebung.daten?.einstellungen.werte, werte.loveaVerbunden, werte.bandAktiv else { return }
        if wuensche == nil {
            wuensche = BandWunschSchlange(bruecke: umgebung.bruecke, uhr: umgebung.uhr) { [weak self] in
                self?.band.wunschAusfuehren($0) ?? .spaeter
            }
        }
        wuensche?.verarbeite()
    }

    /// Weck-Wünsche von Lumen Alarm (`<Lumen-Fit-Gruppe>/LumenAlarm/band-wuensche.json`) ausführen: nur mit Band-Schalter und "Lumen Alarm darf das Band wecken",
    /// ohne den Lovea-Schalter. Wünsche mit künftiger `zeit` bleiben liegen; ein Wartetakt ruft diese Funktion zur Zeit des nächsten Wunsches noch einmal auf
    /// (läuft nur, solange iOS die App am Leben hält: ein Prozess, der Lumen Fit zur Weckzeit weckt, gibt es nicht).
    func alarmWuenscheAusfuehren() {
        alarmTakt?.cancel()
        alarmTakt = nil
        guard let werte = umgebung.daten?.einstellungen.werte, werte.bandAktiv, werte.alarmWeckt else { return }
        if alarmWuensche == nil {
            alarmWuensche = BandWunschSchlange(bruecke: umgebung.alarmBruecke, uhr: umgebung.uhr, schluessel: BandWunschSchlange.alarmSchluessel,
                                               merkMaximal: BandWunschSchlange.alarmMerkMaximal, zusammenfassen: true) { [weak self] in
                self?.band.wunschAusfuehren($0) ?? .spaeter
            }
        }
        guard let schlange = alarmWuensche else { return }
        schlange.verarbeite()
        guard let zeit = schlange.naechsteZeit() else { return }
        let warte = max(0, zeit.timeIntervalSince(umgebung.uhr()))
        let schlafe = self.schlafe
        alarmTakt = Task { @MainActor [weak self] in
            await schlafe(warte)
            guard !Task.isCancelled else { return }
            self?.alarmWuenscheAusfuehren()
        }
    }

    // MARK: Ereignisse

    private func behandle(_ ereignis: Ereignis) async {
        switch ereignis {
        case .trainingGestartet, .trainingBeendet, .satzFertig:
            if case .satzFertig(_, true) = ereignis { kopfhoerer.rekord() }
            bruecke.ereignis(ereignis)
            bruecke.schreibe()
        case .mahlzeitGespeichert, .habitGeaendert:
            bruecke.schreibe()
        case .einstellungenGeaendert:
            await einstellungenGeaendert()
        case .profilGewechselt:
            await einstellungenGeaendert(immer: true)
        case .profilGeloescht:
            // Letztes Profil weg: Band vergessen, die eigenen Dateien in Loveas Gruppe löschen (nichts schreiben, nichts abrufen).
            band.vergessen()
            umgebung.bruecke.loescheEigeneDateien()
            umgebung.konto.verbindungen.vergiss()
            regeln = [:]
            wuensche = nil
            alarmTakt?.cancel()
            alarmTakt = nil
            alarmWuensche = nil
            umgebung.alarmBruecke.loescheEigeneDateien()
            bandWarAn = false
            loveaWarAn = false
            alarmWarAn = true
        case .vordergrund:
            await abruf()
            await umgebung.gesundheit.aktualisiere()
            bruecke.schreibe()
        case .gewichtGespeichert, .meilensteinErreicht, .partnerAktualisiert, .healthAktualisiert, .speichernFehlgeschlagen:
            break
        }
    }

    /// Schalter umgelegt: Lovea an/aus (Stand neu lesen), Band an/aus (starten, trennen und Lovea den Status melden).
    /// `immer`: auch ohne umgelegten Schalter einen Abruf machen (Profilwechsel: das neue Profil hat eigene Schalter, ein Band des alten wird getrennt).
    private func einstellungenGeaendert(immer: Bool = false) async {
        guard let werte = umgebung.daten?.einstellungen.werte else { return }
        if immer || werte.loveaVerbunden != loveaWarAn || werte.bandAktiv != bandWarAn || werte.alarmWeckt != alarmWarAn {
            let bandAus = bandWarAn && !werte.bandAktiv
            loveaWarAn = werte.loveaVerbunden
            bandWarAn = werte.bandAktiv
            alarmWarAn = werte.alarmWeckt
            if !werte.alarmWeckt { alarmTakt?.cancel(); alarmTakt = nil }
            if bandAus { band.ausschalten() }
            await abruf()
        } else if werte.loveaVerbunden {
            bruecke.schreibe()
        }
    }
}
