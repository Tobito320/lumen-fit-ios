import XCTest
@testable import LumenFit

/// Idee 25: Scheiben pro Seite (Stange 20 kg, Scheiben 25 bis 1,25).
final class ScheibenRechnerTests: XCTestCase {
    func testEinfacheGewichte() {
        XCTAssertEqual(ScheibenRechner.berechne(kg: 80).proSeite, [25, 5]) // (80 - 20) / 2 = 30 = 25 + 5
        XCTAssertEqual(ScheibenRechner.berechne(kg: 60).proSeite, [20]) // 20 pro Seite
        XCTAssertEqual(ScheibenRechner.berechne(kg: 100).proSeite, [25, 15]) // 40 = 25 + 15
        XCTAssertEqual(ScheibenRechner.berechne(kg: 140).proSeite, [25, 25, 10]) // 60 = 25 + 25 + 10
    }

    func testNurDieStange() {
        let e = ScheibenRechner.berechne(kg: 20)
        XCTAssertEqual(e.proSeite, [])
        XCTAssertEqual(e.erreicht, 20)
        XCTAssertFalse(e.unterStange)
        XCTAssertEqual(ScheibenRechner.text(e), "ohne Scheiben")
    }

    func testUnterDerStange() {
        let e = ScheibenRechner.berechne(kg: 15)
        XCTAssertTrue(e.unterStange)
        XCTAssertEqual(e.proSeite, [])
        XCTAssertEqual(e.erreicht, 20)
    }

    func testKleineScheibenUndRest() {
        XCTAssertEqual(ScheibenRechner.berechne(kg: 62.5).proSeite, [20, 1.25]) // 21,25 pro Seite
        XCTAssertEqual(ScheibenRechner.berechne(kg: 62.5).rest, 0)
        // 61 kg: 20,5 pro Seite, mit 1,25 als kleinster Scheibe gehen 20 + ... = 20 (Rest 0,5 je Seite, 1 kg insgesamt).
        let e = ScheibenRechner.berechne(kg: 61)
        XCTAssertEqual(e.proSeite, [20])
        XCTAssertEqual(e.erreicht, 60)
        XCTAssertEqual(e.rest, 1)
    }

    func testEigeneStangeUndScheibenvorrat() {
        XCTAssertEqual(ScheibenRechner.berechne(kg: 35, stange: 15).proSeite, [10]) // 10 pro Seite
        let e = ScheibenRechner.berechne(kg: 100, verfuegbar: [10, 5]) // 40 pro Seite: 4 × 10
        XCTAssertEqual(e.proSeite, [10, 10, 10, 10])
    }

    func testText() {
        XCTAssertEqual(ScheibenRechner.text(ScheibenRechner.berechne(kg: 140)), "2 × 25, 10")
        XCTAssertEqual(ScheibenRechner.text(ScheibenRechner.berechne(kg: 62.5)), "20, 1,25")
    }
}
