import XCTest
@testable import LumenFit

/// Hilfen der Widgets-Tests (Grundgerüst-Hilfen bleiben unverändert).
enum WidgetsTestUmgebung {
    /// Eine Vorschau-Umgebung in einem Temp-Ordner, auf Wunsch mit einem angelegten Profil. Ordner und Uhr gehören dem Aufrufer.
    @MainActor
    static func neu(ordner: URL, uhr: TestUhr = TestUhr(), profil: Bool = true) throws -> AppUmgebung {
        let umgebung = AppUmgebung(ordner: ordner, schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                                   leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(),
                                   uhr: uhr.uhr, passwortRunden: 1_000)
        if profil { _ = try umgebung.profil.anlegen(name: "Beispiel", passwort: "abcd") }
        return umgebung
    }
}

/// Zählt Aufrufe aus Rückrufen auf dem Hauptakteur (ein Verweistyp, damit der Rückruf nichts Veränderliches einfangen muss).
@MainActor
final class WidgetsTestZaehler {
    private(set) var wert = 0
    func erhoehe() { wert += 1 }
}

/// Fängt die Verzögerungen der Drossel ab, damit der Test sie von Hand auslöst.
@MainActor
final class WidgetsTestVerzoegerung {
    private(set) var wartezeiten: [TimeInterval] = []
    private var aktionen: [@MainActor () -> Void] = []

    func merke(_ sekunden: TimeInterval, _ aktion: @escaping @MainActor () -> Void) {
        wartezeiten.append(sekunden)
        aktionen.append(aktion)
    }

    /// Führt alle gemerkten Aufgaben aus, in der Reihenfolge, in der sie geplant wurden.
    func fuehreAlleAus() {
        let jetzt = aktionen
        aktionen = []
        for aktion in jetzt { aktion() }
    }

    func fuehreAus(_ index: Int) { aktionen[index]() }
}

/// Fake-Steuerung des Trainings: zählt, was die Intents aufrufen.
@MainActor
final class WidgetsTestSteuerung: TrainingSteuerung {
    private(set) var satzFertigAufrufe = 0
    private(set) var gestartet: [String?] = []

    func starte(planTag: String?) { gestartet.append(planTag) }
    func satzFertig() { satzFertigAufrufe += 1 }
    func pauseAendern(sekunden: Int) {}
    func beende() {}
}

/// Fake des Spotlight-Index: merkt sich, was je Bereich ersetzt wurde.
@MainActor
final class WidgetsTestSenke: SpotlightSenke {
    private(set) var aufrufe: [(bereich: SpotlightBereich, eintraege: [SpotlightEintrag])] = []

    func ersetze(_ bereich: SpotlightBereich, durch eintraege: [SpotlightEintrag]) { aufrufe.append((bereich, eintraege)) }

    func ersetzt(_ bereich: SpotlightBereich) -> [[SpotlightEintrag]] { aufrufe.filter { $0.bereich == bereich }.map(\.eintraege) }
}

/// Fake-Fabrik der Live Activity (ein Akteur: Sendable ohne Sperre). Zeichnet jeden Aufruf auf.
actor WidgetsTestFabrik: LiveAktivitaetFabrik {
    enum Aufruf: Equatable { case starte(TrainingLiveStand), aktualisiere(TrainingLiveStand), beende }

    private(set) var aufrufe: [Aufruf] = []
    private var lebt: Bool
    private var startErlaubt: Bool

    init(lebtSchon: Bool = false, startErlaubt: Bool = true) {
        lebt = lebtSchon
        self.startErlaubt = startErlaubt
    }

    func setzeStartErlaubt(_ erlaubt: Bool) { startErlaubt = erlaubt }

    func laeuft() async -> Bool { lebt }

    func starte(_ stand: TrainingLiveStand) async -> Bool {
        aufrufe.append(.starte(stand))
        guard startErlaubt else { return false }
        lebt = true
        return true
    }

    func aktualisiere(_ stand: TrainingLiveStand) async { aufrufe.append(.aktualisiere(stand)) }

    func beende() async {
        aufrufe.append(.beende)
        lebt = false
    }
}
