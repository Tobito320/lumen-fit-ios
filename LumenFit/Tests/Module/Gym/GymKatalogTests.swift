import XCTest
@testable import LumenFit

/// Idee 26: 1.333 Übungen auf Deutsch. Der Auszug aus Loveas Katalog (Fixture) steht im Katalog der App, die Suche findet ihn,
/// und die Bilder kommen aus `UebungsMedien` (Cache) oder fallen auf ein Symbol zurück.
final class GymKatalogTests: XCTestCase {
    private func auszug() throws -> [Uebung] {
        try JSONDecoder().decode([Uebung].self, from: FixtureOrt.daten("Gym", "lovea-uebungen-auszug.json"))
    }

    func testFixtureIstDerKatalogFormUndImKatalogDerApp() throws {
        let liste = try auszug()
        XCTAssertEqual(liste.count, 3)
        let katalog = UebungsKatalog.laden(Bundle(for: BundleAnker.self))
        for u in liste {
            XCTAssertEqual(katalog.first { $0.id == u.id }, u, "\(u.name) steht unverändert im Katalog")
        }
    }

    func testSucheFindetDenAuszugMitDeutschenUndEnglischenBegriffen() throws {
        let liste = try auszug()
        XCTAssertEqual(UebungsKatalog.suchen("Sit-up", in: liste).first?.id, "2gPfomN")
        XCTAssertEqual(UebungsKatalog.suchen("Ab Wheel", in: liste).first?.id, "NAgVB3t")
        XCTAssertEqual(UebungsKatalog.suchen("rollout langhantel", in: liste).first?.id, "xnInPfE")
        XCTAssertEqual(Set(UebungsKatalog.suchen("Bauch", in: liste).map(\.id)), ["2gPfomN", "xnInPfE", "NAgVB3t"], "Muskel zählt als Suchwort")
        XCTAssertTrue(UebungsKatalog.suchen("Klimmzug", in: liste).isEmpty)
    }

    func testMedienGibtEsNurFuerKatalogUebungenNichtFuerEigene() {
        XCTAssertTrue(UebungsKatalog.hatVideo("2gPfomN"))
        XCTAssertFalse(UebungsKatalog.hatVideo("lv-face-pull"), "eigene Einträge haben kein Bild: die Ansicht zeigt ein Symbol")
    }

    func testKatalogHatMehrAlsDreizehnhundertUebungenMitDeutschenNamen() {
        let katalog = UebungsKatalog.laden(Bundle(for: BundleAnker.self))
        XCTAssertGreaterThanOrEqual(katalog.count, 1300)
        XCTAssertFalse(katalog.contains { $0.name.isEmpty || $0.muskel.isEmpty || $0.geraet.isEmpty })
    }
}
