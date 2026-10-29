import XCTest
@testable import LumenFit

/// Schreibt nichts nach Health, merkt sich nur die Trainings (Test-Fake des Moduls gym).
// @unchecked Sendable: Zugriff nur unter dem NSLock.
final class GymFakeHealthSchreiber: HealthSchreiber, @unchecked Sendable {
    private let schloss = NSLock()
    private var _trainings: [GymSession] = []

    var trainings: [GymSession] { schloss.withLock { _trainings } }

    func speichere(training: GymSession) async -> Bool {
        schloss.withLock { _trainings.append(training) }
        return true
    }

    func speichere(gewichtKg: Double, am datum: Date) async -> Bool { false }
}

/// Ein Pulsgeber ohne Gerät: liefert feste Werte und merkt sich, wie beendet wurde.
@MainActor final class GymFakePuls: GymPulsQuelle {
    var puls: Int? = 120
    var schnitt: Int? = 118
    var kcal: Int? = 240
    private(set) var gestartet = 0
    private(set) var beendet: [Bool] = []
    /// Ob die "Sitzung" das Training selbst nach Health geschrieben hat.
    var schreibtSelbst = false

    func starten() { gestartet += 1 }
    func leeren() {}
    func verwaisteBeenden() {}
    func beenden(speichern: Bool) async -> Bool {
        beendet.append(speichern)
        return speichern && schreibtSelbst
    }
}

/// Eine Umgebung mit Profil, Test-Uhr und Fakes für Live-Anzeige, Band und Health.
@MainActor
struct GymTestAufbau {
    let umgebung: AppUmgebung
    let uhr: TestUhr
    let live = FakeLiveAnzeige()
    let band = FakeBandDienst()
    let schreiber = GymFakeHealthSchreiber()
    let puls = GymFakePuls()
    let sitzung: GymSitzung

    var daten: DatenSatz { guard let d = umgebung.daten else { preconditionFailure("kein Profil") }; return d }

    init(ordner: URL, healthSchreiben: Bool = false) throws {
        let uhr = TestUhr()
        let schreiber = self.schreiber
        let u = AppUmgebung(ordner: ordner, schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: LeererHealthLeser(), healthSchreiber: schreiber, bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "demo")
        u.liveAnzeige = live
        u.band = band
        u.daten?.einstellungen.aendere { $0.healthSchreiben = healthSchreiben }
        self.uhr = uhr
        self.umgebung = u
        self.sitzung = GymSitzung(umgebung: u, puls: puls)
        u.trainingSteuerung = sitzung
    }

    /// Ein Plantag "push" mit zwei Übungen (je drei Sätze 8 × 60 kg), die erste mit 90 s Pause.
    nonisolated static func plan(supersatz: Bool = false) -> TrainingsPlan {
        func satz(_ kg: Double) -> PlanSatz { PlanSatz(wdh: 8, kg: kg, failure: false) }
        let a = PlanUebung(id: "a", uebung: "EIeI8Vf", name: nil, saetze: [satz(60), satz(60), satz(60)], minuten: nil, pause: 90, supersatz: supersatz ? true : nil)
        let b = PlanUebung(id: "b", uebung: "903mzG8", name: nil, saetze: [satz(20), satz(20)], minuten: nil)
        return TrainingsPlan(tage: [TrainingsTag(id: "push", name: "Push", wochentage: [3], uebungen: [a, b])])
    }

    /// Ein früheres, beendetes Training mit einem Satz `kg` × `wdh` an Übung "a" (Bankdrücken).
    func fruehereEinheit(kg: Double, wdh: Int, tageZurueck: Double = 7) {
        let start = uhr.lesen - tageZurueck * 86400
        var satz = PlanSatz(wdh: wdh, kg: kg, failure: false)
        satz.ok = true
        let id = "frueher-\(Int(tageZurueck))"
        let von = daten.profil
        for (art, d, zeit) in [
            ("gym.checkin", GymD(session: id, tag: "push", start: start), start),
            ("gym.uebung", GymD(session: id, plan: "a", uebung: "EIeI8Vf", status: "satz", saetze: [satz]), start + 600),
            ("gym.checkout", GymD(session: id, ende: start + 3600), start + 3600),
        ] {
            daten.raum.einreihen(TestDaten.op(art, d, von: von, zeit: zeit))
        }
    }
}
