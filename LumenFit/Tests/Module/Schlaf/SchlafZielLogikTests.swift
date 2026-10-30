import XCTest
@testable import LumenFit

final class SchlafZielLogikTests: XCTestCase {
    func testExtraNurAnGewaehltenTagen() {
        // 2026-10-30 ist ein Freitag (5), 2026-10-31 ein Samstag (6)
        let extra = SchlafZielExtra(extraMinuten: 30, extraTage: SchlafZielLogik.umgeschaltet(0, wochentag: 5))
        XCTAssertEqual(SchlafZielLogik.ziel(basis: 480, extra: extra, tag: "2026-10-30"), 510)
        XCTAssertEqual(SchlafZielLogik.ziel(basis: 480, extra: extra, tag: "2026-10-31"), 480)
    }

    func testUmschaltenIstUmkehrbar() {
        let an = SchlafZielLogik.umgeschaltet(0, wochentag: 1)
        XCTAssertEqual(an, 1)
        XCTAssertEqual(SchlafZielLogik.umgeschaltet(an, wochentag: 1), 0)
        XCTAssertEqual(SchlafZielLogik.umgeschaltet(0, wochentag: 7), 64)
    }

    func testGeklemmt() {
        let e = SchlafZielLogik.geklemmt(SchlafZielExtra(extraMinuten: 500, extraTage: 0b11111111))
        XCTAssertEqual(e.extraMinuten, SchlafZielLogik.extraGrenze)
        XCTAssertEqual(e.extraTage, 0b1111111)
        XCTAssertEqual(SchlafZielLogik.geklemmt(SchlafZielExtra(extraMinuten: -500, extraTage: 0)).extraMinuten, -SchlafZielLogik.extraGrenze)
    }

    func testExtraText() {
        XCTAssertEqual(SchlafZielLogik.extraText(0), "±0 min")
        XCTAssertEqual(SchlafZielLogik.extraText(30), "+30 min")
        XCTAssertEqual(SchlafZielLogik.extraText(-15), "-15 min")
    }
}

final class SchlafLeistungTests: XCTestCase {
    private func punkt(_ id: String, _ stunden: Double, _ leistung: Double) -> SchlafPunkt { SchlafPunkt(id: id, stunden: stunden, leistung: leistung) }

    func testKernzeileZuWenigPunkte() {
        XCTAssertEqual(SchlafLeistung.kernzeile([punkt("a", 5, 80), punkt("b", 8, 95)]), "2 Einheiten mit Schlafdaten")
    }

    func testKernzeileLangeNaechteBesser() {
        let p = [punkt("a", 5, 80), punkt("b", 5.5, 80), punkt("c", 8, 95), punkt("d", 7.5, 95)]
        XCTAssertEqual(SchlafLeistung.kernzeile(p), "Nach langen Nächten im Schnitt 15 Prozentpunkte mehr Leistung")
    }

    func testKernzeileKeinUnterschied() {
        let p = [punkt("a", 5, 90), punkt("b", 5.5, 90), punkt("c", 8, 91), punkt("d", 7.5, 91)]
        XCTAssertEqual(SchlafLeistung.kernzeile(p), "Kein Unterschied zwischen kurzen und langen Nächten")
    }

    func testKernzeileKurzeNaechteBesser() {
        let p = [punkt("a", 5, 95), punkt("b", 5.5, 95), punkt("c", 8, 80), punkt("d", 7.5, 80)]
        XCTAssertEqual(SchlafLeistung.kernzeile(p), "Nach kurzen Nächten im Schnitt 15 Prozentpunkte mehr Leistung")
    }

    func testOhneSessionsKeinePunkte() {
        XCTAssertTrue(SchlafLeistung.punkte([], schlafMinuten: ["2026-10-30": 480]).isEmpty)
    }
}
