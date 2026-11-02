import Foundation
import Observation

/// Wohin das Band-Modell seine Daten schreibt: die Ops `fit.band.tag` und `fit.band.schlaf` des aktiven Profils. `bisher` liefert je Tag die zuletzt geschriebene Op
/// (`nil`: es gibt kein Profil, dann bleibt alles ungemeldet und kommt beim nächsten Mal).
struct BandSenke {
    var bisher: @MainActor () -> [String: BandTagOp]?
    var tag: @MainActor (BandTagOp) -> Void
    var schlaf: @MainActor (BandSchlafOp) -> Void
    /// Je Tag die zuletzt geschriebene Schlaf-Op (`nil`: unbekannt, dann wird geschrieben). Die Nächte im Speicher des Modells sind nach einem Neustart
    /// leer; ohne diesen Blick in den Raum schriebe jeder Start dieselben Nächte noch einmal.
    var bisherSchlaf: @MainActor () -> [String: BandSchlafOp]? = { nil }

    /// Schreibt in den Raum des aktiven Profils; `raum` wird bei jedem Aufruf neu gefragt (Profilwechsel).
    static func raum(_ raum: @escaping @MainActor () -> LokalerRaum?) -> BandSenke {
        BandSenke(
            bisher: {
                guard let r = raum() else { return nil }
                var tage: [String: BandTagOp] = [:]
                for op in r.ops(arten: ["fit.band.tag"]) { if let t = op.daten(BandTagOp.self) { tage[t.tag] = t } }
                return tage
            },
            tag: { raum()?.senden("fit.band.tag", $0) },
            schlaf: { raum()?.senden("fit.band.schlaf", $0) },
            bisherSchlaf: { SchlafEigeneQuellen.bandOps(raum()).reduce(into: [String: BandSchlafOp]()) { $0[$1.tag] = $1 } })
    }
}

/// Der Band-Dienst von Lumen Fit (`AppUmgebung.band`, Idee 85, 87, 88). Ohne `bandAktiv` entsteht nichts: kein `TrackerModell`, kein Funk, kein
/// `CBCentralManager`, keine Bluetooth-Frage. Mit dem Schalter hält der Dienst die Verbindung, meldet Status und Akku an Lovea
/// (`band-status.json`) und führt Vibrationen aus (`vibriere`, Wünsche aus `BandWunschSchlange`).
@MainActor
@Observable
final class BandDienstImpl: BandDienst {
    /// Das Modell gibt es erst, wenn der Schalter an ist (`starte`); die Ansichten lesen es für Status, Verlauf und Einstellungen.
    private(set) var modell: TrackerModell?

    @ObservationIgnored private let aktiv: @MainActor () -> Bool
    @ObservationIgnored private let fabrik: @MainActor () -> TrackerModell
    @ObservationIgnored private let bruecke: any PartnerAustausch
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let uhr: Uhr
    @ObservationIgnored private let sende: (String) -> Void
    @ObservationIgnored private let training: @MainActor () -> Bool
    /// Die zweite Brücke, zu Lumen Alarm (`<Lumen-Fit-Gruppe>/LumenAlarm/`): bekommt denselben `band-status.json`, solange "Lumen Alarm darf das Band wecken" an ist.
    @ObservationIgnored private let alarmBruecke: any PartnerAustausch
    @ObservationIgnored private let alarmAn: @MainActor () -> Bool
    @ObservationIgnored private var puls: BandPuls?
    @ObservationIgnored private var letzterStatus: BandStatusDatei?
    @ObservationIgnored private var alarmStatusGeschrieben = false
    /// Nach jeder fertigen Runde (das Band ist verbunden und hat geantwortet): wartende Wünsche von Lovea ausführen. Setzt `VerbindenDienste`.
    @ObservationIgnored var beiVerbunden: (@MainActor () -> Void)?
    /// Das Pausen-Ende im Training (das Gym ruft es über `vibriere(.pauseEnde)`, auch ohne Band): hier hängt die Ansage über Kopfhörer (`KopfhoererDienst`). Setzt `VerbindenDienste`.
    @ObservationIgnored var beiPauseEnde: (@MainActor () -> Void)?
    /// Der Akku des Bands ist niedrig (`TrackerAkkuWarnung`): zeigt die Mitteilung, wenn der Schalter an ist. Setzt `VerbindenDienste`.
    @ObservationIgnored var beiAkkuWarnung: (@MainActor (Int) -> Void)?

    init(aktiv: @escaping @MainActor () -> Bool, bruecke: any PartnerAustausch, defaults: UserDefaults = .standard, uhr: @escaping Uhr = { Date() },
         sende: @escaping (String) -> Void = DarwinKanal.sende, training: @escaping @MainActor () -> Bool = { false },
         alarmBruecke: any PartnerAustausch = KeinePartnerBruecke(), alarmAn: @escaping @MainActor () -> Bool = { false },
         modell: @escaping @MainActor () -> TrackerModell) {
        self.aktiv = aktiv
        self.bruecke = bruecke
        self.defaults = defaults
        self.uhr = uhr
        self.sende = sende
        self.training = training
        self.alarmBruecke = alarmBruecke
        self.alarmAn = alarmAn
        fabrik = modell
    }

    /// Ist der Schalter an? Erst dann legt der Dienst das Modell an.
    var an: Bool { aktiv() }

    /// Legt bei eingeschaltetem Schalter das Modell an und setzt die Verbindung fort (App-Start, Vordergrund, Schalter eben umgelegt).
    func starte() {
        guard aktiv() else { return }
        let m = modell ?? anlegen()
        m.fortsetzen()
    }

    private func anlegen() -> TrackerModell {
        let m = fabrik()
        modell = m
        let d = defaults
        let geber = BandPuls(finden: { [weak m] in m?.finden() }, verbunden: { [weak m] in m?.zustand == .verbunden },
                             umfeld: { [weak m] jetzt in
                                 BandPuls.umfeld(jetzt, defaults: d, bandAmArm: m?.armZustand.bandAmArm, akku: m?.akku?.prozent, akkuGelesen: m?.akkuGelesen)
                             }, defaults: d)
        puls = geber
        m.beiAkkuWarnung = { [weak self] prozent in
            guard let self, BandAkkuWarnung.an(self.defaults) else { return }
            self.beiAkkuWarnung?(prozent)
        }
        m.beiRundenende = { [weak self, weak m] in
            guard let self, let m else { return }
            self.puls?.rundeEnde(training: self.training(), puls: m.letzterPuls?.wert, zeit: m.letzterPuls?.zeit, heute: m.heute, stand: m.bandTage.stand)
            self.statusSchreiben()
            self.beiVerbunden?()
        }
        return m
    }

    /// Schalter aus: Verbindung beenden. Das Modell bleibt (Verlauf), bis die App neu startet; ein neues Einschalten verbindet wieder.
    func ausschalten() {
        modell?.trennen()
        statusSchreiben(erzwingen: true)
    }

    /// Das letzte Profil ist gelöscht: Band trennen und vergessen, alle Spuren in `UserDefaults` weg.
    func vergessen() {
        modell?.vergessen()
        BandReste.loesche(defaults)
    }

    // MARK: BandDienst

    func status() async -> BandStatus {
        guard aktiv(), let m = modell else { return BandStatus(verbunden: false, akkuProzent: nil, name: nil) }
        return BandStatus(verbunden: m.zustand == .verbunden, akkuProzent: m.akku?.prozent, name: m.name)
    }

    func verbinde() async {
        guard aktiv() else { return }
        (modell ?? anlegen()).verbinden()
    }

    func trenne() async { modell?.trennen() }

    /// Vibriert nur mit Schalter und verbundenem Band, nach den Regeln der Quelle (Schalter, Ruhezeit, Mindestpause). Das Pausen-Ende kommt vom Gym.
    func vibriere(_ muster: BandMuster) async {
        if muster == .pauseEnde { beiPauseEnde?() }
        guard aktiv() else { return }
        _ = puls?.muster(muster, jetzt: uhr())
    }

    /// Ein Ereignis des Partners (`PartnerEreignisRegeln`): vibriert nach der Quelle "Partner", wenn sie an ist.
    func partnerEreignis(_ ereignis: PartnerEreignis) {
        guard aktiv() else { return }
        _ = puls?.ausloesen(.partner, jetzt: uhr())
    }

    /// Führt einen Wunsch aus; vom `BandWunschSchlange` aufgerufen.
    func wunschAusfuehren(_ wunsch: BandWunsch) -> BandWunschSchlange.Ergebnis {
        guard aktiv(), let m = modell, let geber = puls else { return .spaeter }
        guard m.zustand == .verbunden else { return .spaeter }
        if BandWunschSchlange.istWecker(wunsch) { return geber.wecker(wunsch.muster, jetzt: uhr()) ? .ausgefuehrt : .spaeter }
        return geber.muster(wunsch.muster, jetzt: uhr()) == nil ? .ausgefuehrt : .verworfen
    }

    // MARK: Status für Lovea

    /// Wann das Band zuletzt verbunden war (Sekunden seit 1970), für `zuletztGesehen` in `band-status.json`.
    nonisolated static let zuletztGesehenSchluessel = "fit.band.zuletztGesehen"

    /// Bluetooth am iPhone: aus, wenn es abgeschaltet ist; unbekannt (nil), wenn die Erlaubnis fehlt oder es nicht verfügbar ist.
    static func bluetoothAn(_ zustand: TrackerModell.Zustand) -> Bool? {
        switch zustand {
        case .bluetoothAus: false
        case .nichtErlaubt, .nichtVerfuegbar: nil
        default: true
        }
    }

    // MARK: Schritte des Bands für den Aufsteh-Wecker

    /// Fragt nur die Schritte von heute ab (`TrackerModell.schritteLesen`); false, wenn das Band nicht bereit ist.
    @discardableResult
    func schritteLesen() -> Bool {
        guard aktiv(), let m = modell, m.zustand == .verbunden else { return false }
        m.schritteLesen()
        return true
    }

    /// Die Tagessumme der Schritte des Bands und wann sie gelesen wurde; nil ohne frische Antwort.
    func schritteStand() -> (summe: Int, zeit: Date)? {
        guard let m = modell, let zeit = m.bandTage.stand else { return nil }
        return (m.heute?.schritte ?? 0, zeit)
    }

    /// Schreibt `band-status.json` (verbunden, Akku, Name), wenn sich etwas geändert hat, und sendet die Darwin-Benachrichtigung.
    func statusSchreiben(erzwingen: Bool = false) {
        guard aktiv() || erzwingen, let m = modell else { return }
        let jetzt = uhr()
        let verbunden = aktiv() && m.zustand == .verbunden
        if verbunden { defaults.set(jetzt.timeIntervalSince1970, forKey: Self.zuletztGesehenSchluessel) }
        let gesehen = (defaults.object(forKey: Self.zuletztGesehenSchluessel) as? Double).map(Date.init(timeIntervalSince1970:))
        let datei = BandStatusDatei(version: LoveaVertrag.version, geschrieben: jetzt, verbunden: verbunden,
                                    akkuProzent: m.akku?.prozent, name: m.name, bluetoothAn: Self.bluetoothAn(m.zustand), laedt: m.akku?.laedt,
                                    zuletztGesehen: gesehen, staerke: nil, schritteHeute: m.heute?.schritte)
        let alarm = alarmAn()
        // Der Alarm-Schalter eben angelegt: die Datei fehlt dort noch, auch wenn sich am Band nichts geändert hat.
        let alarmNeu = alarm && !alarmStatusGeschrieben
        if !erzwingen, !alarmNeu, let alt = letzterStatus, alt.verbunden == datei.verbunden, alt.akkuProzent == datei.akkuProzent, alt.name == datei.name,
           alt.bluetoothAn == datei.bluetoothAn, alt.laedt == datei.laedt, datei.geschrieben.timeIntervalSince(alt.geschrieben) < 3600 { return }
        letzterStatus = datei
        bruecke.schreibe(status: datei)
        if alarm { alarmBruecke.schreibe(status: datei) }
        alarmStatusGeschrieben = alarm
        sende(DarwinKanal.bandStatus)
    }
}
