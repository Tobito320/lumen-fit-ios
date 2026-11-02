// Quelle: Lovea Health/Tracker/TrackerModell.swift
import Foundation
import Observation

/// Verbindung zum iSo-Tech-Tracker (H59MAX). Hält die Tage, die der Tracker geliefert hat (`BandTage`, im Speicher), und schreibt sie als Ops
/// `fit.band.tag` in den Raum des Profils (`BandSenke`): `GesundheitsStand` nimmt je Tag das Maximum aus Health und Band. Der Tracker schreibt
/// absichtlich nichts in Apple Health, sonst zählt Health dieselben Schritte doppelt.
///
/// Wann abgefragt wird: bei jeder Verbindung (auch wenn iOS die App dafür im Hintergrund weckt), beim Start, beim Öffnen der App und danach im
/// Abstand des Modus (`TrackerModus.abfrageAbstand`, ohne Modus alle zehn Minuten), solange die Verbindung steht. Der Tracker selbst sendet nach
/// dem Trennen erst wieder, wenn man ihn antippt; öfter als er will geht es nicht.
///
/// Modus (`TrackerModus`, Sparen oder Viele Daten): der Nutzer wählt; `modusWaehlen` schreibt die Einstellungen des Modus in einem Rutsch an
/// den Tracker (`aendern(alle:)`, danach Zurücklesen) und merkt sich, bis sie angekommen sind (`modusOffen`). Jede Einstellung wird je
/// Verbindung höchstens einmal versucht. Ohne gewählten Modus schreibt Lumen Fit nichts.
///
/// Jede Abfrage liest zuletzt den Pulsverlauf von heute (nur lesen): daraus folgt, ob das Band am Arm ist.
///
/// Verlauf von Stress und HRV (`Halbstundenreihe`, Gadgetbridge, am Gerät ungeprüft): am Ende einer Abfrage, nur wenn die jeweilige
/// Dauermessung am Tracker an ist. Das Ergebnis landet in `reihen`.
///
/// Schlaf vom Armband (`TrackerSchlaf`): Steht Dienst 2 am Band, geht höchstens alle 30 Minuten (und nach einer fertigen Runde) eine
/// Lese-Anfrage raus. Die Rohantwort geht erst ins Fehlersuche-Log (`bandLog`), dann wird sie ausgewertet; plausible Nächte landen als Op
/// `fit.band.schlaf` im Raum (Quelle "Armband" in der Quellenwahl des Moduls schlaf). Nichts davon ändert das Band.
///
/// Einstellungen ändern (`aendern`): schreiben, danach vom Tracker zurücklesen. Angezeigt wird immer, was der Tracker meldet, nie, was
/// Lumen Fit geschickt hat; weicht es ab, steht ein Hinweis da.
///
/// Gegenüber Lovea: kein Singleton (`BandDienstImpl` legt eine Instanz an, erst wenn `bandAktiv` an ist), keine Wecker-, Server- und
/// HealthModell-Anbindung, Einstellungen in `UserDefaults` unter `fit.band.*`.
@MainActor
@Observable
final class TrackerModell {
    enum Zustand: Equatable {
        case getrennt, sucht, nichtGefunden, wartet, verbunden
        case bluetoothAus, nichtErlaubt, nichtVerfuegbar
        case fehler(String)
    }

    /// Wie viele Tage zurück eine volle Abfrage geht (heute = 1), und wie viele die kurze.
    static let tageVoll = 7
    static let tageKurz = 2
    /// Eine volle Abfrage, wenn die letzte so lange her ist.
    private static let vollNach: TimeInterval = 12 * 3600
    /// So lange ohne Antwort, dann gilt die Frage als beantwortet und die nächste geht raus.
    private static let ruhe: Duration = .seconds(3)
    private static let nameSchluessel = "fit.band.name"
    private static let pauseSchluessel = "fit.band.pause"
    /// Nur-App-Optionen (UserDefaults, kein Raum): Schritte des Bands zählen und die Warnung vor leerem Akku (merkt sich, ob schon gewarnt wurde).
    nonisolated static let schritteSchluessel = "fit.band.schritte"
    private static let akkuGewarntSchluessel = "fit.band.akkugewarnt"
    /// Wann zuletzt die Schlaf-Anfrage ging (Sekunden seit 1970) und der Hex der letzten Antwort (nur Neues kommt ins Log).
    private static let schlafVersuchSchluessel = "fit.band.schlaf.versuch"
    /// `true`, solange die letzte Anfrage keinen gültigen Rahmen gebracht hat: dann gilt der kurze Abstand `TrackerSchlaf.wiederholung`.
    private static let schlafOhneAntwortSchluessel = "fit.band.schlaf.ohneantwort"
    /// So lange auf die ganze Antwort warten, dann gilt sie als abgebrochen (halb angekommen: das Log hat die Rohbytes).
    private static let schlafWarten: Duration = .seconds(15)
    /// So lange auf das Ergebnis einer einzelnen Pulsmessung warten.
    private static let pulsMessenWarten: Duration = .seconds(45)
    /// So viele Zeilen hält das Fehlersuche-Log.
    private static let bandLogMaximum = 60

    /// Eine einzelne Pulsmessung auf Knopfdruck (`pulsMessen`).
    enum PulsMessung: Equatable {
        case aus
        case misst(seit: Date)
        case fertig(wert: Int, um: Date)
        case fehler(String)
    }

    private(set) var zustand: Zustand = .getrennt
    private(set) var gekoppelt = false
    private(set) var name: String?
    private(set) var akku: TrackerProtokoll.Akku?
    /// Wann der Tracker den Akku zuletzt gemeldet hat (nur im Speicher). Die Seite nennt das Alter, wenn es nicht frisch ist:
    /// nach einem Verbindungsabbruch bleibt der letzte Wert stehen und darf nicht wie der heutige aussehen.
    private(set) var akkuGelesen: Date?
    private(set) var pulsEinstellung: TrackerProtokoll.PulsEinstellung?
    private(set) var messungen: [TrackerProtokoll.Dauermessung: Bool] = [:]
    private(set) var aenderungsHinweis: String?
    /// Der gewählte Modus (`nil`: nie gewählt) und ob er noch nicht am Tracker angekommen ist.
    private(set) var modus: TrackerModus?
    private(set) var modusOffen = false
    private(set) var bandTage = BandTage()
    private(set) var abfrageLaeuft = false
    /// Laden aus dem Verlauf geschlossen, nicht aus dem Ladebit des Trackers (`TrackerLaden`).
    private(set) var ladenVermutet = false
    /// Jüngster Puls laut Pulsverlauf von heute und wann der Verlauf zuletzt vollständig kam (`TrackerArm`).
    private(set) var letzterPuls: PulsVerlauf.Puls?
    private(set) var pulsGelesen: Date?
    /// Rohe Pakete der letzten Abfragen als Hex (ohne Schritte und Pulswerte), für die Fehlersuche auf der Seite.
    private(set) var rohLog: [String] = []
    /// Für die Verlauf-Karten (`TrackerVerlaufAbschnitt`): Pulswerte von heute, Akku-Verlauf der letzten Tage und ein Zähler, der sich
    /// ändert, wenn eine neue Nacht vom Armband ankam (`bandSchlaf` selbst ist nicht beobachtbar).
    private(set) var reihen = BandReihen()
    private(set) var akkuVerlauf = TrackerAkkuVerlauf()
    private(set) var schlafStand = 0
    private(set) var pulsMessung: PulsMessung = .aus

    /// Warum ein Band-Ereignis es nicht in die Oberfläche schafft, steht in `bandLog` (Fehlersuche, nur im Speicher).
    private(set) var bandLog: [String] = []
    /// Auf welchem Weg die letzte Verbindung entstand (`BandVerbindungsweg`), nur im Speicher: die Rohdaten-Seite zeigt es als eigene Zeile, auch wenn die
    /// Log-Zeile längst aus den letzten `bandLogMaximum` gerutscht ist. Nach jedem App-Start wieder da (kein Merken in `UserDefaults`).
    private(set) var verbindungsWeg: String?
    @ObservationIgnored private var fremdesPaketGemeldet = false
    /// Ab hier hört das Modell auf Ereignisse des Funks; `funkFabrik` legt den Funk erst bei `verbinden` an (kein Bluetooth-Objekt davor).
    @ObservationIgnored private let funkFabrik: (@escaping @Sendable (TrackerEreignis) -> Void) -> any BandFunk
    @ObservationIgnored private let senke: BandSenke
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let uhr: Uhr
    /// Am Ende jeder Runde (frische Zahlen vom Band): Ziel-Puls im Training. Setzt `BandDienstImpl`.
    @ObservationIgnored var beiRundenende: (@MainActor () -> Void)?
    /// Der Akku ist unter die Grenze gefallen (einmal je Entladung, `TrackerAkkuWarnung`): der Dienst schickt die Mitteilung, wenn der Nutzer sie will.
    @ObservationIgnored var beiAkkuWarnung: (@MainActor (Int) -> Void)?
    private var funk: (any BandFunk)?
    /// Der Nutzer hat "Trennen" getippt: dann nicht von selbst wieder verbinden, auch nicht nach einem Neustart.
    private var pausiert = false
    private var offeneAnfragen: [Data] = []
    @ObservationIgnored private var pulsPuffer: PulsVerlauf?
    @ObservationIgnored private var akkuVorher: (prozent: Int, zeit: Date)?
    /// Stress und HRV, die in dieser Abfrage noch zu lesen sind, und die Antwort, die gerade eintrifft.
    @ObservationIgnored private var verlaufWartet: [TrackerProtokoll.Dauermessung] = []
    @ObservationIgnored private var verlaufPuffer: (art: TrackerProtokoll.Dauermessung, reihe: Halbstundenreihe)?
    /// Wann Stress und HRV zuletzt gelesen wurden (nur im Speicher: nach Start, Verbindung und Öffnen der Seite gleich wieder).
    @ObservationIgnored private var verlaufGelesen: [TrackerProtokoll.Dauermessung: Date] = [:]
    /// Schlaf vom Armband: die plausiblen Nächte (auf dem iPhone gespeichert), ob Dienst 2 bereit ist, die laufende Antwort
    /// (`nil` = keine Anfrage offen) und eine Marke, mit der ein Warte-Timer erkennt, dass er überholt ist.
    @ObservationIgnored private var bandSchlaf = BandSchlaf()
    @ObservationIgnored private var schlafBereit = false
    @ObservationIgnored private var schlafSammler: TrackerSchlaf.Sammler?
    @ObservationIgnored private var schlafNr = 0
    private var anfrageNr = 0
    private var planNr = 0
    private var schrittAntwort = false
    /// Die laufende Abfrage ist nur die Schritte-Frage von heute (`schritteLesen`): kein Planen der nächsten Runde, kein Rundenende.
    private var nurSchritte = false
    /// Die Einstellungen, deren Zurücklesen gerade läuft; `abschliessen` prüft sie gegen das, was der Tracker meldet.
    private var erwartet: [TrackerProtokoll.Aenderung] = []
    /// Die Einstellungen des Modus, die in dieser Verbindung schon versucht wurden (`TrackerModus.offene`).
    @ObservationIgnored private var modusVersucht: [TrackerProtokoll.Aenderung] = []
    /// Die Uhr des Bands wurde in dieser Verbindung schon gestellt (`TrackerProtokoll.zeitSetzenAnfrage`), und ihre Antwort steht noch aus.
    @ObservationIgnored private var zeitVersucht = false
    @ObservationIgnored private var zeitAntwortOffen = false
    /// Die Tage, die der Raum noch nicht kennt: ein neuer Stand der Zeilen setzt es, `bandMelden` schreibt die Ops.
    private var ungemeldet = true

    init(funk: @escaping (@escaping @Sendable (TrackerEreignis) -> Void) -> any BandFunk, senke: BandSenke,
         defaults: UserDefaults = .standard, uhr: @escaping Uhr = { Date() }) {
        funkFabrik = funk
        self.senke = senke
        self.defaults = defaults
        self.uhr = uhr
        gekoppelt = TrackerFunk.gemerkteKennung(defaults) != nil
        name = defaults.string(forKey: Self.nameSchluessel)
        modus = defaults.string(forKey: TrackerModus.schluessel).flatMap(TrackerModus.init(rawValue:))
        modusOffen = defaults.bool(forKey: TrackerModus.offenSchluessel)
        pausiert = defaults.bool(forKey: Self.pauseSchluessel)
        reihen = BandReihen.laden(defaults)
        akkuVerlauf = TrackerAkkuVerlauf.laden(defaults)
    }

    // MARK: Aktionen

    /// App-Start (auch im Hintergrund), Vordergrund und Öffnen der Seite: wieder verbinden, wenn gekoppelt
    /// und nicht absichtlich getrennt. Die Bluetooth-Abfrage kommt so erst, wenn Nutzer "Tracker suchen" getippt hat.
    func fortsetzen() {
        verlaufGelesen = [:] // wer die App oder die Seite öffnet, bekommt frische Werte
        guard gekoppelt, !pausiert else { return }
        bandMelden()
        if funk == nil {
            verbinden()
        } else if zustand == .verbunden {
            if uhr().timeIntervalSince(bandTage.stand ?? .distantPast) > 120 { abfragen() }
            modusAnwenden() // ein Modus, der noch nicht am Tracker ist, geht jetzt raus (läuft schon eine Abfrage, passiert nichts)
        } else {
            funk?.starten()
        }
    }

    func verbinden() {
        pausiert = false
        defaults.set(false, forKey: Self.pauseSchluessel)
        if funk == nil {
            funk = funkFabrik { [weak self] ereignis in
                Task { @MainActor in self?.verarbeiten(ereignis) }
            }
        }
        funk?.starten()
    }

    func trennen() {
        pausiert = true
        defaults.set(true, forKey: Self.pauseSchluessel)
        abbrechen()
        funk?.trennen(vergessen: false)
    }

    func vergessen() {
        pausiert = true
        defaults.set(true, forKey: Self.pauseSchluessel)
        abbrechen()
        funk?.trennen(vergessen: true)
        gekoppelt = false
        name = nil
        akku = nil
        akkuGelesen = nil
        bandSchlaf = BandSchlaf()
        schlafStand += 1
        reihen = BandReihen()
        BandReihen.loeschen(defaults)
        pulsMessung = .aus
        akkuVerlauf = TrackerAkkuVerlauf()
        TrackerAkkuVerlauf.loeschen(defaults)
        defaults.removeObject(forKey: Self.schlafVersuchSchluessel)
        defaults.removeObject(forKey: Self.schlafOhneAntwortSchluessel)
        akkuVorher = nil
        ladenVermutet = false
        letzterPuls = nil
        pulsGelesen = nil
        pulsPuffer = nil
        rohLog = []
        pulsEinstellung = nil
        messungen = [:]
        aenderungsHinweis = nil
        modusVersucht = []
        modusOffen = modus != nil // ein neues Band bekommt den gewählten Modus
        defaults.set(modusOffen, forKey: TrackerModus.offenSchluessel)
        bandTage = BandTage()
        defaults.removeObject(forKey: Self.nameSchluessel)
    }

    /// Fragt Akku, Puls-Einstellung und die Schritte der letzten Tage der Reihe nach ab (jede Antwort
    /// löst die nächste Frage aus, bei Schweigen nach `ruhe` die nächste von selbst).
    func abfragen() {
        guard zustand == .verbunden, !abfrageLaeuft else { return }
        abfrageLaeuft = true
        schrittAntwort = false
        let voll = uhr().timeIntervalSince(bandTage.stand ?? .distantPast) > Self.vollNach
        let tage = voll ? Self.tageVoll : Self.tageKurz
        let pulsTag = TrackerProtokoll.tagSekunden(uhr())
        pulsPuffer = PulsVerlauf(tag: pulsTag)
        // Der Pulsverlauf kommt zuletzt: schweigt der Tracker dazu, kostet es nur die Ruhezeit.
        offeneAnfragen = [TrackerProtokoll.pulsEinstellungAnfrage]
            + TrackerProtokoll.Dauermessung.allCases.map(TrackerProtokoll.einstellungAnfrage)
            + (0..<tage).map { TrackerProtokoll.schritteAnfrage(tagVersatz: $0) }
            + [TrackerProtokoll.pulsVerlaufAnfrage(tag: pulsTag)]
        let jetzt = uhr()
        let kandidaten: [TrackerProtokoll.Dauermessung] = [.stress, .hrv]
        verlaufWartet = kandidaten.filter { TrackerVerlauf.verlaufFaellig(letzte: verlaufGelesen[$0], jetzt: jetzt) }
        verlaufPuffer = nil
        guard !zeitVersucht else { senden(TrackerProtokoll.akkuAnfrage); return }
        // Erste Runde dieser Verbindung: erst die Uhr stellen, dann Akku und der Rest; der Schlaf folgt erst am Rundenende. Schweigt das Band, kostet es nur die Ruhezeit.
        zeitVersucht = true
        zeitAntwortOffen = true
        let uhrPaket = TrackerProtokoll.zeitSetzenAnfrage(jetzt)
        bandLogSchreiben(art: "zeit", text: "gesendet \(Self.hex(uhrPaket))", nurWennNeu: false)
        offeneAnfragen.insert(TrackerProtokoll.akkuAnfrage, at: 0)
        senden(uhrPaket)
    }

    /// Fragt nur die Schritte von heute ab (für den Aufsteh-Wecker, alle 30 Sekunden im Weckfenster). Läuft schon eine Abfrage, passiert nichts:
    /// sie liest die Schritte ohnehin. Plant die nächste volle Runde nicht neu.
    func schritteLesen() {
        guard zustand == .verbunden, !abfrageLaeuft else { return }
        abfrageLaeuft = true
        nurSchritte = true
        schrittAntwort = false
        offeneAnfragen = []
        verlaufWartet = []
        senden(TrackerProtokoll.schritteHeuteAnfrage)
    }

    /// Nur bei stehender Verbindung und ohne laufende Abfrage; die Tracker-Seite sperrt sonst ihre Schalter.
    var einstellbar: Bool { zustand == .verbunden && !abfrageLaeuft }

    /// Schreibt eine Einstellung und liest sie danach zurück (die Antwort kommt über `antwortVerarbeiten`,
    /// bei Schweigen geht das Zurücklesen nach `ruhe` von selbst raus).
    func aendern(_ aenderung: TrackerProtokoll.Aenderung) {
        aendern(alle: [aenderung])
    }

    /// Mehrere Einstellungen in einer Runde: erst alle Schreibpakete, dann das Zurücklesen jeder Einstellung. `abschliessen` prüft alle.
    func aendern(alle aenderungen: [TrackerProtokoll.Aenderung]) {
        guard einstellbar, let erste = aenderungen.first else { return }
        abfrageLaeuft = true
        schrittAntwort = false
        erwartet = aenderungen
        aenderungsHinweis = nil
        verlaufWartet = []
        verlaufPuffer = nil
        let weitereSchreibpakete: [Data] = aenderungen.dropFirst().map(\.schreiben)
        let leseanfragen: [Data] = aenderungen.map(\.lesen)
        offeneAnfragen = weitereSchreibpakete + leseanfragen
        senden(erste.schreiben)
    }

    /// Nutzer wählt einen Modus: merken und, sobald der Tracker verbunden und frei ist, an den Tracker schreiben.
    func modusWaehlen(_ neu: TrackerModus) {
        modus = neu
        modusOffen = true
        modusVersucht = []
        defaults.set(neu.rawValue, forKey: TrackerModus.schluessel)
        defaults.set(true, forKey: TrackerModus.offenSchluessel)
        if zustand == .verbunden { naechsteAbfragePlanen() } // der neue Abstand gilt ab jetzt, auch wenn am Tracker nichts zu ändern ist
        modusAnwenden()
    }

    /// Schreibt, was vom Modus am Tracker noch fehlt. Kommt nach jeder fertigen Runde wieder hierher: nach dem Zurücklesen ist klar, was
    /// angekommen ist. Ist nichts mehr zu schreiben (angekommen oder schon versucht), gilt der Modus als abgeschlossen.
    private func modusAnwenden() {
        guard modusOffen, let modus, einstellbar else { return }
        let offene = modus.offene(puls: pulsEinstellung, messungen: messungen, versucht: modusVersucht)
        guard !offene.isEmpty else {
            modusOffen = false
            defaults.set(false, forKey: TrackerModus.offenSchluessel)
            return
        }
        modusVersucht += offene
        aendern(alle: offene)
    }

    /// Was am Tracker vom gewählten Modus abweicht (leer ohne Modus).
    var modusAbweichungen: [TrackerProtokoll.Aenderung] {
        modus?.abweichungen(puls: pulsEinstellung, messungen: messungen) ?? []
    }

    /// Sekunden zwischen zwei Abfragen: der Abstand des Modus, ohne Modus wie bisher.
    var abfrageAbstand: TimeInterval { modus?.abfrageAbstand ?? TrackerModus.standardAbstand }

    /// Lässt den Tracker vibrieren, damit man ihn findet. Keine Antwort, kein Zurücklesen.
    func finden() {
        guard zustand == .verbunden else { return }
        funk?.senden(TrackerProtokoll.findenAnfrage)
    }

    /// Startet eine einzelne Pulsmessung am Tracker; das Ergebnis kommt als Antwort und steht in `pulsMessung`. Der Sensor läuft dafür bis zu
    /// 45 Sekunden. Gadgetbridge schickt nur diesen einen Befehl und kein Stopp-Paket; ein Stopp-Befehl ist im Protokoll nicht belegt.
    func pulsMessen() {
        guard zustand == .verbunden else { return }
        if case .misst = pulsMessung { return }
        let start = uhr()
        pulsMessung = .misst(seit: start)
        funk?.senden(TrackerProtokoll.pulsMessenAnfrage)
        Task { [weak self] in
            try? await Task.sleep(for: Self.pulsMessenWarten)
            guard let self, case .misst(let seit) = self.pulsMessung, seit == start else { return }
            self.pulsMessung = .fehler("Keine Messung erhalten. Sitzt der Tracker eng am Arm?")
        }
    }

    /// Die Nacht vom Armband für den Tag des Aufwachens; `nil` ohne plausible Nacht (`schlafStand`).
    func schlafNacht(_ tag: String) -> TrackerSchlaf.Nacht? { bandSchlaf.naechte[tag] }

    /// Die jüngste plausible Nacht vom Armband für die Verlauf-Karte; ändert sich mit `schlafStand`.
    var letzteBandNacht: TrackerSchlaf.Nacht? {
        _ = schlafStand
        return bandSchlaf.naechte.values.max { $0.tag < $1.tag }
    }

    // MARK: Anzeige

    var statusText: String {
        switch zustand {
        case .getrennt: return gekoppelt ? "Getrennt" : "Nicht verbunden"
        case .sucht: return "Sucht den Tracker"
        case .nichtGefunden: return "Nicht gefunden"
        case .wartet: return "Wartet auf den Tracker"
        case .verbunden: return abfrageLaeuft ? "Verbunden, liest" : "Verbunden"
        case .bluetoothAus: return "Bluetooth ist aus"
        case .nichtErlaubt: return "Bluetooth nicht erlaubt"
        case .nichtVerfuegbar: return "Bluetooth nicht verfügbar"
        case .fehler(let text): return text
        }
    }

    /// Der Tag heute laut Tracker; `nil`, solange er für heute nichts geliefert hat.
    var heute: BandTag? { bandTage.tage[Datum.text(uhr())] }

    /// Die Tage, die in die Schritte eingehen: leer, wenn der Nutzer die Band-Schritte ausgeschaltet hat (dann zählt nur Health).
    var schritteTage: [String: BandTag] {
        let zaehlen = defaults.object(forKey: Self.schritteSchluessel) as? Bool ?? true
        return zaehlen ? bandTage.tage : [:]
    }

    /// Am Arm, abgelegt oder unbekannt, aus dem Pulsverlauf (`TrackerArm`).
    var armZustand: TrackerArm.Zustand {
        TrackerArm.zustand(pulsAn: pulsEinstellung?.an == true, intervallMinuten: pulsEinstellung?.intervallMinuten ?? 0,
                           letzterPuls: letzterPuls?.zeit, gelesen: pulsGelesen,
                           tagesanfang: Calendar.current.startOfDay(for: pulsGelesen ?? uhr()), jetzt: uhr())
    }

    /// Lumen Fit verbindet von selbst wieder; aus, wenn Nutzer getrennt hat (`trennen`).
    var automatischVerbinden: Bool { !pausiert }

    // MARK: Ereignisse

    private func verarbeiten(_ ereignis: TrackerEreignis) {
        switch ereignis {
        case .bluetooth(let status):
            switch status {
            case .an: break
            case .aus: zustand = .bluetoothAus
            case .nichtErlaubt: zustand = .nichtErlaubt
            case .nichtVerfuegbar: zustand = .nichtVerfuegbar
            }
        case .sucht: zustand = .sucht
        case .nichtGefunden: zustand = .nichtGefunden
        case .verbindet: zustand = .wartet
        case .verbunden(let geraetename):
            zustand = .verbunden
            gekoppelt = true
            modusVersucht = [] // neue Verbindung, neue Versuche
            zeitVersucht = false // und die Uhr des Bands wird wieder gestellt
            verlaufGelesen = [:]
            if let geraetename {
                name = geraetename
                defaults.set(geraetename, forKey: Self.nameSchluessel)
            }
            abfragen()
        case .getrennt:
            abbrechen()
            zustand = pausiert ? .getrennt : .wartet
        case .fehler(let text):
            abbrechen()
            zustand = .fehler(text)
        case .daten(let daten):
            antwortVerarbeiten(daten)
        case .bandLog(let art, let text):
            if art == "weg" {
                // Je App-Start die erste Zeile, danach nur bei anderem Weg; über `UserDefaults` fehlte sie nach jedem Neustart auf der Seite.
                guard verbindungsWeg != text else { break }
                verbindungsWeg = text
                bandLogSchreiben(art: art, text: text, nurWennNeu: false)
            } else {
                bandLogSchreiben(art: art, text: text, nurWennNeu: art == "dienste")
            }
        case .schlafBereit:
            schlafBereit = true
            schlafLesenFallsFaellig()
        case .schlafDaten(let daten):
            schlafAntwort(daten)
        }
    }

    private func antwortVerarbeiten(_ daten: Data) {
        rohProtokollieren(daten)
        let antwort = TrackerProtokoll.lesen(daten)
        switch antwort {
        case .akku(let wert):
            let jetzt = uhr()
            let urteil = TrackerLaden.urteil(prozent: wert.prozent, byteLaedt: wert.laedt, vorher: akkuVorher, jetzt: jetzt,
                                             abgelegt: armZustand == .abgelegt)
            akkuVorher = (wert.prozent, jetzt)
            ladenVermutet = urteil == .vermutlich
            let ergebnis = TrackerProtokoll.Akku(prozent: wert.prozent, laedt: urteil != .nein)
            akku = ergebnis
            akkuGelesen = jetzt
            akkuVerlauf.aufnehmen(zeit: jetzt, prozent: wert.prozent, laedt: urteil != .nein)
            akkuVerlauf.speichern(defaults)
            akkuPruefen(wert) // nur das belegte Ladebit: eine Vermutung darf die Warnung nicht zurücksetzen
            naechsteAnfrage()
        case .pulsEinstellung(let wert):
            pulsEinstellung = wert
            naechsteAnfrage()
        case .dauermessung(let art, let an):
            messungen[art] = an
            naechsteAnfrage()
        case .quittung:
            naechsteAnfrage()
        case .zeitQuittung:
            guard zeitAntwortOffen else { break } // nicht von Lumen Fit angefragt: die Runde nicht weiterschieben
            zeitAntwortOffen = false
            bandLogSchreiben(art: "zeit", text: "Antwort \(Self.hex(daten))", nurWennNeu: false)
            naechsteAnfrage()
        case .schritteKopf:
            schrittAntwort = true
        case .schritte(let zeile):
            schrittAntwort = true
            let vorher = bandTage.tage[zeile.tag]
            bandTage.aufnehmen(zeile)
            // Nur Neues ist ungemeldet: dieselbe Zeile noch einmal startet kein neues Schreiben der Ops.
            if bandTage.tage[zeile.tag] != vorher { ungemeldet = true }
            if zeile.letzte { naechsteAnfrage() }
        case .schritteEnde:
            schrittAntwort = true
            naechsteAnfrage()
        case .pulsKopf, .pulsStart, .pulsWerte, .pulsEnde:
            pulsAufnehmen(antwort)
        case .verlauf(let art, let paket):
            verlaufAufnehmen(art, paket)
        case .pulsMessung(let fehler, let wert):
            pulsMessungAufnehmen(fehler: fehler, wert: wert)
        case .unbekannt, nil:
            break
        }
    }

    /// Sammelt den Pulsverlauf; ist er vollständig und vom richtigen Tag, gilt er als gelesen und die nächste Frage geht raus.
    private func pulsAufnehmen(_ antwort: TrackerProtokoll.Antwort?) {
        guard let antwort, var puffer = pulsPuffer else { return }
        let fertig = puffer.aufnehmen(antwort)
        pulsPuffer = fertig ? nil : puffer
        guard fertig else { return }
        if puffer.gueltig {
            let jetzt = uhr()
            letzterPuls = puffer.letzter(tagesanfang: Calendar.current.startOfDay(for: jetzt), bis: jetzt)
            pulsGelesen = jetzt
            var heutige = reihen.fuer(Datum.text(jetzt)) // Stress und HRV von heute bleiben stehen
            heutige.puls = puffer.punkte(tagesanfang: Calendar.current.startOfDay(for: jetzt), bis: jetzt)
            reihen = heutige
        }
        naechsteAnfrage()
    }

    /// Sammelt eine Antwort auf den Stress- oder HRV-Verlauf. Pakete ohne offene Anfrage von Lumen Fit werden ignoriert. Was ankommt, gilt sofort
    /// (Karte und Speicher); ist die Antwort vollständig, geht die nächste Frage raus und die Rohwerte einmal ins versteckte Log.
    private func verlaufAufnehmen(_ art: TrackerProtokoll.Dauermessung, _ paket: TrackerProtokoll.VerlaufPaket) {
        guard var puffer = verlaufPuffer, puffer.art == art else { return }
        let fertig = puffer.reihe.aufnehmen(paket)
        verlaufPuffer = fertig ? nil : puffer
        let jetzt = uhr()
        let bereich: ClosedRange<Int> = art == .stress ? 1...100 : 1...250
        let punkte = puffer.reihe.punkte(bereich: bereich, tagesanfang: Calendar.current.startOfDay(for: jetzt), bis: jetzt)
        if !punkte.isEmpty {
            var heutige = reihen.fuer(Datum.text(jetzt))
            if art == .stress { heutige.stress = punkte } else { heutige.hrv = punkte }
            reihen = heutige
        }
        guard fertig else { return }
        if !punkte.isEmpty {
            bandLogSchreiben(art: art == .stress ? "stress-verlauf" : "hrv-verlauf", text: puffer.reihe.hex, nurWennNeu: true)
        }
        naechsteAnfrage()
    }

    private func pulsMessungAufnehmen(fehler: Int, wert: Int) {
        guard case .misst = pulsMessung else { return } // nicht von Lumen Fit angefragt
        switch fehler {
        case 0 where wert > 0: pulsMessung = .fertig(wert: wert, um: uhr())
        case 0, 2: break // das Band misst noch (Fehler 2: vorübergehend ohne Wert)
        case 1: pulsMessung = .fehler("Der Tracker sitzt nicht richtig am Arm.")
        default: pulsMessung = .fehler("Der Tracker meldet Fehler \(fehler).")
        }
    }

    /// Stress und HRV des Tages werden nur gelesen, wenn die Dauermessung am Tracker an ist (sonst gibt es nichts zu holen). Aufruf, wenn die
    /// Fragen einer Abfrage durch sind: `messungen` ist da frisch gelesen.
    private func verlaufVormerken() {
        while !verlaufWartet.isEmpty {
            let art = verlaufWartet.removeFirst()
            guard messungen[art] == true else { continue }
            verlaufGelesen[art] = uhr()
            verlaufPuffer = (art, Halbstundenreihe())
            offeneAnfragen = [art == .stress ? TrackerProtokoll.stressVerlaufAnfrage : TrackerProtokoll.hrvVerlaufAnfrage(tageZurueck: 0)]
            return
        }
    }

    private static func hex(_ daten: Data) -> String { daten.map { String(format: "%02x", $0) }.joined(separator: " ") }

    /// Das Ladebit und die Einstellungen sind unbelegt: Lumen Fit zeigt die rohen 16 Byte, nicht nur Byte 1 und 2.
    private func rohProtokollieren(_ daten: Data) {
        let art = daten.first
        if art == TrackerProtokoll.Befehl.schritte.rawValue { return }
        if art == TrackerProtokoll.Befehl.stressVerlauf.rawValue || art == TrackerProtokoll.Befehl.hrvVerlauf.rawValue { return }
        if art == TrackerProtokoll.Befehl.pulsVerlauf.rawValue, daten.count > 1, daten[daten.startIndex + 1] > 1 { return }
        let hex = Self.hex(daten)
        rohLog.append("\(uhr().formatted(date: .omitted, time: .standard))  \(hex)")
        if rohLog.count > 40 { rohLog.removeFirst(rohLog.count - 40) }
    }

    // MARK: Schlaf vom Armband (W-033)

    /// Schickt die Schlaf-Anfrage, wenn Dienst 2 bereit ist, keine Abfrage läuft und `TrackerSchlaf.faellig` es erlaubt. Kommt am
    /// Ende jeder Abfragerunde und wenn Dienst 2 bereit wird: keine eigene Schleife, kein Timer außer dem Warten auf die Antwort.
    private func schlafLesenFallsFaellig() {
        guard schlafBereit, schlafSammler == nil, !abfrageLaeuft, zustand == .verbunden else { return }
        let jetzt = uhr()
        let letzte = (defaults.object(forKey: Self.schlafVersuchSchluessel) as? Double).map(Date.init(timeIntervalSince1970:))
        let ohneAntwort = defaults.bool(forKey: Self.schlafOhneAntwortSchluessel)
        guard TrackerSchlaf.faellig(letzte: letzte, naechte: bandSchlaf.naechte, heute: Datum.text(jetzt), jetzt: jetzt, ohneAntwort: ohneAntwort) else { return }
        defaults.set(jetzt.timeIntervalSince1970, forKey: Self.schlafVersuchSchluessel)
        defaults.set(true, forKey: Self.schlafOhneAntwortSchluessel)
        schlafSammler = TrackerSchlaf.Sammler()
        schlafNr += 1
        let nr = schlafNr
        funk?.schlafAnfragen()
        Task { [weak self] in
            try? await Task.sleep(for: Self.schlafWarten)
            guard let self, nr == self.schlafNr, let sammler = self.schlafSammler else { return }
            self.schlafSammler = nil
            self.bandLogSchreiben(art: "schlaf-roh", text: "keine fertige Antwort nach \(Self.schlafWarten.components.seconds) s, \(sammler.bytes.count) Byte: \(sammler.hex)", nurWennNeu: false)
        }
    }

    /// Ein Paket der Antwort: zusammensetzen, bei fertigem Rahmen auswerten. Pakete ohne offene Anfrage sind nicht von Lumen Fit
    /// angefragt und werden ignoriert.
    private func schlafAntwort(_ daten: Data) {
        guard var sammler = schlafSammler else {
            // Nur zur Fehlersuche, einmal je App-Start. Kein Beleg für eine zweite App: dieselbe Lage entsteht, wenn die eigene Antwort nach den 15 s oder einem "ungültig" eintrifft.
            if !fremdesPaketGemeldet {
                fremdesPaketGemeldet = true
                bandLogSchreiben(art: "ohne-anfrage", text: "Dienst-2-Paket ohne offene eigene Anfrage (\(daten.count) Byte), ignoriert: \(Self.hex(daten.prefix(8)))", nurWennNeu: false)
            }
            return
        }
        let stand = sammler.aufnehmen(daten)
        switch stand {
        case .wartet:
            schlafSammler = sammler
        case .ungueltig(let grund):
            schlafSammler = nil
            schlafNr += 1
            bandLogSchreiben(art: "schlaf-roh", text: "ungültig (\(grund)): \(sammler.hex)", nurWennNeu: true)
        case .fertig(let nutzdaten):
            schlafSammler = nil
            schlafNr += 1
            defaults.set(false, forKey: Self.schlafOhneAntwortSchluessel)
            schlafAuswerten(roh: sammler.hex, nutzdaten: nutzdaten)
        }
    }

    /// Die Rohantwort kommt vor der Auswertung ins Log (nur wenn sie anders ist als die letzte). Danach: plausible Nächte
    /// speichern und, wenn sich etwas geändert hat, die Schlaf-Rechnung der App anstoßen.
    private func schlafAuswerten(roh: String, nutzdaten: [UInt8]) {
        let jetzt = uhr()
        let neueAntwort = bandLogSchreiben(art: "schlaf-roh", text: roh, nurWennNeu: true)
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten, heute: Datum.text(jetzt), jetzt: jetzt)
        if neueAntwort {
            let uebernommen = ergebnis.naechte.map { "\($0.tag) \(Datum.uhrzeit($0.von))-\(Datum.uhrzeit($0.bis)) \($0.minuten) min, \($0.phasen.count) Phasen" }
            let text = "übernommen: \(uebernommen.isEmpty ? "keine" : uebernommen.joined(separator: "; ")); verworfen: \(ergebnis.verworfen.isEmpty ? "keine" : ergebnis.verworfen.joined(separator: "; "))"
            bandLogSchreiben(art: "schlaf-auswertung", text: text, nurWennNeu: false)
        }
        guard bandSchlaf.aufnehmen(ergebnis.naechte) else { return }
        bandSchlaf.kuerzen(heute: Datum.text(jetzt))
        schlafStand += 1
        // Nur was der Raum noch nicht hat: die Nächte im Speicher sind nach einem Neustart leer, die Ops stehen aber schon da.
        for op in TrackerSchlaf.neueOps(ergebnis.naechte, bisher: senke.bisherSchlaf()) { senke.schlaf(op) }
    }

    /// Eine Zeile ins Fehlersuche-Log (nur im Speicher, die letzten `bandLogMaximum`). `nurWennNeu`: gleicher Text wie beim letzten Mal derselben
    /// Art wird nicht noch einmal geschrieben. Liefert, ob geschrieben wurde.
    @discardableResult
    private func bandLogSchreiben(art: String, text: String, nurWennNeu: Bool) -> Bool {
        let merkSchluessel = "fit.band.bandlog.letzte.\(art)"
        if nurWennNeu {
            guard defaults.string(forKey: merkSchluessel) != text else { return false }
            defaults.set(text, forKey: merkSchluessel)
        }
        bandLog.append("\(uhr().formatted(date: .omitted, time: .standard))  \(art): \(text)")
        if bandLog.count > Self.bandLogMaximum { bandLog.removeFirst(bandLog.count - Self.bandLogMaximum) }
        return true
    }

    /// Merkt, ob der Akku niedrig ist (`akkuNiedrig`): einmal je Entladung, erst nach dem Laden oder Erholen wieder. Eine Warnung ist ein Status in der
    /// App; die Mitteilung kommt nur mit dem Schalter "Warnen bei niedrigem Akku" (`BandAkkuWarnung`). Keine eigene Abfrage: es zählt nur, was die Abfragen ohnehin lesen.
    private func akkuPruefen(_ wert: TrackerProtokoll.Akku) {
        let gewarnt = defaults.bool(forKey: Self.akkuGewarntSchluessel)
        switch TrackerAkkuWarnung.schritt(prozent: wert.prozent, laedt: wert.laedt, gewarnt: gewarnt) {
        case .warnen:
            defaults.set(true, forKey: Self.akkuGewarntSchluessel)
            beiAkkuWarnung?(wert.prozent)
        case .vergessen: defaults.set(false, forKey: Self.akkuGewarntSchluessel)
        case .nichts: break
        }
    }

    /// Der Akku ist niedrig (15 Prozent oder weniger) und lädt nicht: das Band-Blatt und die Verbinden-Seite zeigen die Warnung.
    var akkuNiedrig: Bool {
        guard let akku else { return false }
        return TrackerAkkuWarnung.niedrig(prozent: akku.prozent, laedt: akku.laedt)
    }

    // MARK: Abfrage-Ablauf

    private func senden(_ daten: Data) {
        anfrageNr += 1
        let nr = anfrageNr
        funk?.senden(daten)
        Task { [weak self] in
            try? await Task.sleep(for: Self.ruhe)
            guard let self, nr == self.anfrageNr else { return }
            if self.zeitAntwortOffen {
                self.zeitAntwortOffen = false
                self.bandLogSchreiben(art: "zeit", text: "keine Antwort nach \(Self.ruhe.components.seconds) s", nurWennNeu: false)
            }
            self.naechsteAnfrage()
        }
    }

    private func naechsteAnfrage() {
        guard abfrageLaeuft else { return }
        if offeneAnfragen.isEmpty { verlaufVormerken() }
        guard !offeneAnfragen.isEmpty else { abschliessen(); return }
        senden(offeneAnfragen.removeFirst())
    }

    private func abschliessen() {
        anfrageNr += 1
        abfrageLaeuft = false
        if nurSchritte {
            nurSchritte = false
            if schrittAntwort { bandTage.stand = uhr() }
            bandTage.kuerzen(heute: Datum.text(uhr()))
            bandMelden()
            return
        }
        // Ohne eine einzige Schritt-Antwort ist nichts gelesen worden: dann bleibt der Stand alt.
        if schrittAntwort { bandTage.stand = uhr() }
        if !erwartet.isEmpty {
            let bestaetigt: Bool = erwartet.allSatisfy { stimmt($0) }
            aenderungsHinweis = bestaetigt ? nil : "Der Tracker hat die Änderung nicht bestätigt. Angezeigt ist, was er meldet."
            erwartet = []
        }
        bandTage.kuerzen(heute: Datum.text(uhr()))
        reihen.speichern(defaults)
        bandMelden()
        schlafLesenFallsFaellig()
        beiRundenende?() // Ziel-Puls im Training
        naechsteAbfragePlanen()
        modusAnwenden() // nach dem Planen: eine Umstellung beginnt eine neue Runde und plant danach neu
    }

    /// Bricht eine laufende Abfrage ab (Verbindung weg, getrennt, vergessen). Was schon gelesen ist, bleibt.
    private func abbrechen() {
        anfrageNr += 1
        planNr += 1
        abfrageLaeuft = false
        nurSchritte = false
        offeneAnfragen = []
        pulsPuffer = nil
        verlaufWartet = []
        verlaufPuffer = nil
        zeitAntwortOffen = false
        reihen.speichern(defaults)
        if case .misst = pulsMessung { pulsMessung = .aus } // die Verbindung riss: kein Ergebnis mehr
        schlafBereit = false // kommt mit der nächsten Verbindung neu (`TrackerFunk` meldet `.schlafBereit`)
        schlafSammler = nil
        schlafNr += 1
        if !erwartet.isEmpty {
            aenderungsHinweis = "Verbindung abgebrochen, die Änderung ist nicht bestätigt."
            erwartet = []
        }
        bandMelden()
    }

    private func naechsteAbfragePlanen() {
        planNr += 1
        let nr = planNr
        let warten: Duration = .seconds(abfrageAbstand)
        Task { [weak self] in
            try? await Task.sleep(for: warten)
            guard let self, nr == self.planNr, self.zustand == .verbunden else { return }
            self.abfragen()
        }
    }

    /// Hat der Tracker die Änderung übernommen? Beim Ausschalten zählt nur "aus", der Abstand bleibt ihm überlassen.
    private func stimmt(_ aenderung: TrackerProtokoll.Aenderung) -> Bool {
        switch aenderung {
        case .puls(let an, let minuten):
            guard let puls = pulsEinstellung, puls.an == an else { return false }
            return !an || puls.intervallMinuten == minuten
        case .messung(let art, let an):
            return messungen[art] == an
        }
    }

    /// Neue Tracker-Zahlen als Ops `fit.band.tag` in den Raum schreiben (nur Tage, die gewachsen sind). Ohne Profil (Start im Hintergrund, bevor es
    /// bekannt ist) passiert nichts; `fortsetzen()` holt es beim nächsten Öffnen nach.
    private func bandMelden() {
        guard ungemeldet, !bandTage.tage.isEmpty else { return }
        let bisher = senke.bisher()
        guard let bisher else { return }
        ungemeldet = false
        for op in schritteTageFuerOps().ops(bisher: bisher) { senke.tag(op) }
    }

    /// Nur die Tage, die in die Schritte eingehen sollen (Schalter "Band-Schritte zählen").
    private func schritteTageFuerOps() -> BandTage {
        var tage = bandTage
        tage.tage = schritteTage
        return tage
    }
}
