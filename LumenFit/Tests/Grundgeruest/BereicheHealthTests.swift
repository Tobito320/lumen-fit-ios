import XCTest
@testable import LumenFit

/// Health fragt und beobachtet nur, was gewählt ist.
@MainActor
final class BereicheHealthTests: XCTestCase {
    /// Merkt, nach welchen Typen gefragt und welche beobachtet wurden.
    private final class Aufzeichner: HealthLeser, @unchecked Sendable {
        private let schloss = NSLock()
        private var _gefragt: [Set<HealthTyp>] = []
        private var _beobachtet: [Set<HealthTyp>] = []
        private var _naechteAbfragen = 0
        var gefragt: [Set<HealthTyp>] { schloss.withLock { _gefragt } }
        var beobachtet: [Set<HealthTyp>] { schloss.withLock { _beobachtet } }
        var naechteAbfragen: Int { schloss.withLock { _naechteAbfragen } }
        func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff { schloss.withLock { _gefragt.append(typen) }; return .angefragt }
        func tagesWerte(von: String, bis: String) async -> [TagesWerte] { [] }
        func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] { schloss.withLock { _naechteAbfragen += 1 }; return [] }
        func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] { [] }
        func gewichte(von: String, bis: String) async -> [GewichtsMesswert] { [] }
        func workouts(von: String, bis: String) async -> [HealthWorkout] { [] }
        func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) { schloss.withLock { _beobachtet.append(typen) } }
    }

    /// Einstellungen mit den genannten Bereichen aus (der Rest bleibt an).
    private func aus(_ bereiche: AppBereich...) -> Einstellungen {
        var e = Einstellungen()
        for b in bereiche { e.setze(b, an: false) }
        return e
    }

    private func umgebung(leser: any HealthLeser = FakeHealthLeser()) throws -> AppUmgebung {
        AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                    leser: leser, healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: TestUhr().uhr, passwortRunden: 1_000)
    }


    // MARK: Health

    func testHealthTypenOhneSchlafUndOhneGym() {
        let ohneSchlaf = aus(.schlaf).healthTypen
        XCTAssertFalse(ohneSchlaf.contains(.schlaf) || ohneSchlaf.contains(.sauerstoff) || ohneSchlaf.contains(.atmung) || ohneSchlaf.contains(.temperatur))
        XCTAssertTrue(ohneSchlaf.contains(.training) && ohneSchlaf.contains(.schritte) && ohneSchlaf.contains(.gewicht))
        let ohneGym = aus(.gym).healthTypen
        XCTAssertFalse(ohneGym.contains(.training))
        XCTAssertTrue(ohneGym.contains(.schlaf))
        XCTAssertEqual(Einstellungen().healthTypen, Set(HealthTyp.allCases), "alles an = wie bisher")
    }

    func testGesundheitFragtNurGewaehlteTypenUndLiestKeineNaechteOhneSchlaf() async {
        let leser = Aufzeichner()
        var e = aus(.schlaf)
        let stand = GesundheitsStand(leser: leser, uhr: { Date() }, typen: { e.healthTypen })
        await stand.aktualisiere()
        XCTAssertEqual(leser.gefragt.count, 1)
        XCTAssertFalse(leser.gefragt[0].contains(.schlaf))
        XCTAssertEqual(leser.naechteAbfragen, 0)

        await stand.aktualisiere()
        XCTAssertEqual(leser.gefragt.count, 1, "nichts Neues: keine zweite Frage")

        e.setze(.schlaf, an: true)
        await stand.aktualisiere()
        XCTAssertEqual(leser.gefragt.count, 2, "Einschalten fragt die fehlenden Rechte")
        XCTAssertTrue(leser.gefragt[1].contains(.schlaf))
        XCTAssertEqual(leser.naechteAbfragen, 1)
    }

    func testBeobachtetWerdenNurGewaehlteTypenUndNachtraeglichNurDieNeuen() throws {
        let leser = Aufzeichner()
        let u = try umgebung(leser: leser)
        u.beobachteHealth()
        XCTAssertTrue(leser.beobachtet.isEmpty, "ohne Profil ist nichts gewählt")
        try u.profil.anlegen(name: "Test", passwort: "abcd")
        u.daten?.einstellungen.aendere { $0.setze(.schlaf, an: false) }
        u.beobachteHealth()
        XCTAssertEqual(leser.beobachtet, [[.schritte, .training]])
        u.daten?.einstellungen.aendere { $0.setze(.schlaf, an: true) }
        u.beobachteHealth()
        XCTAssertEqual(leser.beobachtet.last, [.schlaf])
        u.beobachteHealth()
        XCTAssertEqual(leser.beobachtet.count, 2, "nie doppelt")
    }
}
