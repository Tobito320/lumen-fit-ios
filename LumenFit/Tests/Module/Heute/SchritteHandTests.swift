import XCTest
@testable import LumenFit

final class SchritteHandTests: XCTestCase {
    private func op(_ tag: String, _ anzahl: Int) -> Op {
        Op.neu(SchritteHandLogik.art, SchritteHandD(tag: tag, anzahl: anzahl), von: .testA, zeit: Date())
    }

    func testAnzahlNimmtNurZiffernUndPrueftObergrenze() {
        XCTAssertEqual(SchritteHandLogik.anzahl("12.500"), 12_500)
        XCTAssertEqual(SchritteHandLogik.anzahl(" 8000 "), 8_000)
        XCTAssertNil(SchritteHandLogik.anzahl(""))
        XCTAssertNil(SchritteHandLogik.anzahl("abc"))
        XCTAssertNil(SchritteHandLogik.anzahl("100001"))
        XCTAssertEqual(SchritteHandLogik.anzahl("100000"), 100_000)
    }

    func testLetzteOpJeTagGilt() {
        let t = SchritteHandLogik.tage(ops: [op("2026-10-29", 3_000), op("2026-10-30", 500), op("2026-10-29", 4_200)])
        XCTAssertEqual(t, ["2026-10-29": 4_200, "2026-10-30": 500])
    }

    func testKaputteOpWirdUebersprungen() {
        let kaputt = Op(id: "x", art: SchritteHandLogik.art, von: .testA, zeit: Date(), d: Data("{}".utf8))
        XCTAssertTrue(SchritteHandLogik.tage(ops: [kaputt]).isEmpty)
    }

    func testZusammenNimmtDenGroesserenWertUndBehaeltMeter() {
        let band = ["2026-10-29": BandTagOp(tag: "2026-10-29", schritte: 9_000, meter: 6_000), "2026-10-28": BandTagOp(tag: "2026-10-28", schritte: 2_000, meter: 1_400)]
        let z = Dictionary(uniqueKeysWithValues: SchritteHandLogik.zusammen(band: band, hand: ["2026-10-29": 4_000, "2026-10-28": 5_000, "2026-10-27": 700]).map { ($0.tag, $0) })
        XCTAssertEqual(z["2026-10-29"]?.schritte, 9_000)
        XCTAssertEqual(z["2026-10-29"]?.meter, 6_000)
        XCTAssertEqual(z["2026-10-28"]?.schritte, 5_000)
        XCTAssertEqual(z["2026-10-28"]?.meter, 1_400)
        XCTAssertEqual(z["2026-10-27"]?.schritte, 700)
        XCTAssertEqual(z.count, 3)
    }
}
