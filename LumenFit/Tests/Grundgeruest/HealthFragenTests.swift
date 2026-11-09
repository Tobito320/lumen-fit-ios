import XCTest
@testable import LumenFit

/// Leserechte fragt der Gesundheitsstand erst, wenn die Person Health erlaubt hat (Onboarding, Health-Zugriff), nie still beim Start.
@MainActor
final class HealthFragenTests: XCTestCase {
    // @unchecked Sendable: nur im Test, der Zähler wird nacheinander auf dem Hauptakteur gelesen.
    private final class ZaehlLeser: HealthLeser, @unchecked Sendable {
        var gefragt = 0
        func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff { gefragt += 1; return .angefragt }
        func tagesWerte(von: String, bis: String) async -> [TagesWerte] { [TagesWerte(tag: bis, schritte: 100)] }
        func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] { [] }
        func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] { [] }
        func gewichte(von: String, bis: String) async -> [GewichtsMesswert] { [] }
        func workouts(von: String, bis: String) async -> [HealthWorkout] { [] }
        func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) {}
    }

    @MainActor private final class Schalter { var an = false }

    func testOhneErlaubnisWirdGelesenAberNichtGefragt() async {
        let leser = ZaehlLeser()
        let uhr = TestUhr()
        let erlaubt = Schalter()
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr, darfFragen: { erlaubt.an })
        await stand.aktualisiere()
        XCTAssertEqual(leser.gefragt, 0, "beim Start kein Health-Blatt")
        XCTAssertEqual(stand.tage[Datum.text(uhr.lesen)]?.schritte, 100, "gelesen wird, was schon erlaubt ist")
        erlaubt.an = true
        await stand.aktualisiere()
        XCTAssertEqual(leser.gefragt, 1, "nach dem Ja der Person wird einmal gefragt")
        await stand.aktualisiere()
        XCTAssertEqual(leser.gefragt, 1, "danach nicht noch einmal")
    }
}
