// Quelle: Lovea Health/Ernaehrung/LebensmittelDetail.swift (NutriScoreAbzeichen)
import XCTest
@testable import LumenFit

final class EssenNutriScoreTests: XCTestCase {
    func testNurAbisEZaehlt() {
        XCTAssertEqual(EssenNutriScoreLogik.note("a"), "a")
        XCTAssertEqual(EssenNutriScoreLogik.note(" E "), "e")
        XCTAssertNil(EssenNutriScoreLogik.note("unknown"))
        XCTAssertNil(EssenNutriScoreLogik.note("not-applicable"))
        XCTAssertNil(EssenNutriScoreLogik.note(""))
        XCTAssertNil(EssenNutriScoreLogik.note(nil))
        XCTAssertNil(EssenNutriScoreLogik.note("ab"))
    }

    func testIndexUndBeschreibung() {
        XCTAssertEqual(EssenNutriScoreLogik.index("a"), 0)
        XCTAssertEqual(EssenNutriScoreLogik.index("e"), 4)
        XCTAssertNil(EssenNutriScoreLogik.index("z"))
        for s in EssenNutriScoreLogik.stufen { XCTAssertTrue(EssenNutriScoreLogik.beschreibung(s).contains(s.uppercased())) }
    }
}
