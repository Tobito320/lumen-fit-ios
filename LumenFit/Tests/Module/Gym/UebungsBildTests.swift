import XCTest
@testable import LumenFit

/// Das Übungsbild: Symbol-Rückfall nach Körperteil, nie ein leeres Feld.
final class UebungsBildTests: XCTestCase {
    func testSymbolJeKoerperteil() {
        XCTAssertEqual(UebungsSymbol.name(koerper: "Cardio"), "figure.run")
        XCTAssertEqual(UebungsSymbol.name(koerper: "Beine"), "figure.strengthtraining.functional")
        XCTAssertEqual(UebungsSymbol.name(koerper: "Bauch"), "figure.core.training")
        XCTAssertEqual(UebungsSymbol.name(koerper: "Unbekannt"), "figure.strengthtraining.traditional")
        XCTAssertEqual(UebungsSymbol.name(koerper: nil), "figure.strengthtraining.traditional")
    }

    func testBeschreibungOhneBild() {
        let u = Uebung(id: "lv-x", name: "Face Pull", en: "face pull", muskel: "Schultern", koerper: "Schultern", geraet: "Kabelzug", neben: [])
        XCTAssertEqual(UebungsSymbol.beschreibung(u), "Face Pull, Schultern, Kabelzug")
    }
}
