// Quelle: Lovea Health/Ernaehrung/ErnaehrungPortionen.swift (Portionsbeispiel)
import XCTest
@testable import LumenFit

final class EssenPortionsBeispieleTests: XCTestCase {
    func testZehnBeispieleMitEindeutigenNamen() {
        let alle = EssenPortionsBeispiel.alle
        XCTAssertEqual(alle.count, 10)
        XCTAssertEqual(Set(alle.map(\.name)).count, alle.count)
    }

    func testWerteSindPlausibel() {
        for p in EssenPortionsBeispiel.alle {
            XCTAssertGreaterThan(p.gramm, 0, p.name)
            XCTAssertGreaterThan(p.kcal, 0, p.name)
            XCTAssertFalse(p.hand.isEmpty, p.name)
            XCTAssertFalse(p.symbol.isEmpty, p.name)
            // Gemüse hat unter 1 kcal je Gramm, Öl rund 9: nichts liegt über 9,5 kcal je Gramm.
            XCTAssertLessThan(Double(p.kcal) / p.gramm, 9.5, p.name)
        }
    }
}
