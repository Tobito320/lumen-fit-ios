import XCTest
@testable import LumenFit

final class DatumTests: XCTestCase {
    func testTextUndDatumSindUmkehrbar() {
        for tag in ["2026-01-01", "2026-03-29", "2026-09-23", "2026-10-25", "2026-12-31", "2028-02-29"] {
            XCTAssertEqual(Datum.text(Datum.datum(tag)), tag)
        }
    }

    func testTagGiltInBerlinAuchWennUTCNochGesternIst() {
        // 23.09.2026 00:30 Berlin (Sommerzeit, UTC+2) ist am 22.09. um 22:30 UTC.
        let mitternachtPlus = Datum.datum("2026-09-23").addingTimeInterval(30 * 60)
        XCTAssertEqual(Datum.text(mitternachtPlus), "2026-09-23")
        XCTAssertEqual(Datum.uhrzeit(mitternachtPlus), "00:30")
    }

    func testWochentagUndMontagDerWocheMitMontagAlsErstemTag() {
        XCTAssertEqual(Datum.wochentag("2026-09-21"), 1, "Montag")
        XCTAssertEqual(Datum.wochentag("2026-09-23"), 3, "Mittwoch")
        XCTAssertEqual(Datum.wochentag("2026-09-27"), 7, "Sonntag")
        XCTAssertEqual(Datum.montagDerWoche("2026-09-23"), "2026-09-21")
        XCTAssertEqual(Datum.montagDerWoche("2026-09-27"), "2026-09-21")
        XCTAssertEqual(Datum.montagDerWoche("2026-09-21"), "2026-09-21")
        XCTAssertEqual(Datum.wochenstart("2026-09-27"), Datum.montagDerWoche("2026-09-27"))
    }

    func testTageAddierenUeberMonatJahrUndSchalttag() {
        XCTAssertEqual(Datum.addTage("2026-09-30", 1), "2026-10-01")
        XCTAssertEqual(Datum.addTage("2026-12-31", 1), "2027-01-01")
        XCTAssertEqual(Datum.addTage("2028-02-28", 1), "2028-02-29")
        XCTAssertEqual(Datum.addTage("2026-01-01", -1), "2025-12-31")
        XCTAssertEqual(Datum.addTage("2026-09-23", 0), "2026-09-23")
    }

    func testTageZwischenUeberDieZeitumstellung() {
        XCTAssertEqual(Datum.tageZwischen("2026-03-28", "2026-03-30"), 2, "Umstellung auf Sommerzeit")
        XCTAssertEqual(Datum.tageZwischen("2026-10-24", "2026-10-26"), 2, "Umstellung auf Winterzeit (25.10.)")
        XCTAssertEqual(Datum.tageZwischen("2026-09-23", "2026-09-23"), 0)
        XCTAssertEqual(Datum.tageZwischen("2026-09-23", "2026-09-20"), -3)
    }

    func testUhrzeitenUndMinuten() {
        XCTAssertEqual(Datum.uhrzeit(minuten: 605), "10:05")
        XCTAssertEqual(Datum.uhrzeit(minuten: 0), "00:00")
        XCTAssertEqual(Datum.uhrzeit("23:30", plus: 120), "23:59", "ein Termin endet am selben Tag")
        XCTAssertEqual(Datum.uhrzeit("07:45", plus: 30), "08:15")
        XCTAssertEqual(Datum.minuten("07:45"), 465)
        XCTAssertNil(Datum.minuten("kaputt"))
        XCTAssertNil(Datum.minuten(nil))
    }

    func testAnzeigeNenntWochentagUndMonat() {
        let text = Datum.anzeige("2026-09-23")
        XCTAssertTrue(text.contains("Mittwoch"), text)
        XCTAssertTrue(text.contains("September"), text)
        XCTAssertTrue(text.contains("23"), text)
    }

    func testKaputterTagStuerztNichtAb() {
        XCTAssertEqual(Datum.datum("kaputt"), Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Datum.datum(""), Date(timeIntervalSince1970: 0))
        XCTAssertEqual(Datum.datum("2026-09"), Date(timeIntervalSince1970: 0))
    }
}
