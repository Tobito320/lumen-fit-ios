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

    func testZusammenHandZaehltNurOhneHealthSchritte() {
        // Besitzer 10.11.2026: Schritte nur aus Apple Health; vorher galt je Tag das Maximum aus Band, Hand und Health.
        let health = ["2026-10-29": TagesWerte(tag: "2026-10-29", schritte: 4_000, distanzMeter: 3_000),
                      "2026-10-28": TagesWerte(tag: "2026-10-28", schritte: 0, etagen: 2)]
        let z = SchritteHandLogik.zusammen(health: health, hand: ["2026-10-29": 6_000, "2026-10-28": 5_000, "2026-10-27": 3_000, "2026-10-26": 0])
        XCTAssertEqual(z["2026-10-29"]?.schritte, 4_000, "Health 4000 und Hand 6000: Health gilt")
        XCTAssertEqual(z["2026-10-29"]?.distanzMeter, 3_000, "Strecke nur aus Health")
        XCTAssertEqual(z["2026-10-28"]?.schritte, 5_000, "Health ohne Schritte: Hand gilt")
        XCTAssertEqual(z["2026-10-28"]?.etagen, 2, "die übrigen Health-Werte bleiben")
        XCTAssertEqual(z["2026-10-27"]?.schritte, 3_000, "kein Health-Tag: Hand gilt")
        XCTAssertNil(z["2026-10-26"], "Hand 0 legt keinen Tag an")
        XCTAssertEqual(z.count, 3)
    }
}
