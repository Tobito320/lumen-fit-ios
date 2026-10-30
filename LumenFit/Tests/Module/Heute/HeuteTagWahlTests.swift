import XCTest
@testable import LumenFit

/// Reine Tagwahl-Logik: Grenzen, Schritte, Wischen, Wochenstart, Titel. Heute ist Mittwoch, 23.09.2026.
final class HeuteTagWahlTests: XCTestCase {
    private let heute = "2026-09-23"

    func testDieZukunftIstGesperrt() {
        XCTAssertEqual(HeuteTagWahl.begrenze("2026-09-24", heute: heute), heute)
        XCTAssertEqual(HeuteTagWahl.begrenze("2030-01-01", heute: heute), heute)
        XCTAssertEqual(HeuteTagWahl.schritt(heute, tage: 1, heute: heute), heute)
        XCTAssertEqual(HeuteTagWahl.schritt(heute, tage: 7, heute: heute), heute)
        XCTAssertFalse(HeuteTagWahl.kannVor(heute, heute: heute))
        XCTAssertTrue(HeuteTagWahl.kannVor("2026-09-22", heute: heute))
    }

    func testDieVergangenheitReichtEinJahrZurueck() {
        let alt = HeuteTagWahl.aeltester(heute: heute)
        XCTAssertEqual(alt, "2025-09-23")
        XCTAssertEqual(HeuteTagWahl.begrenze("2020-01-01", heute: heute), alt)
        XCTAssertEqual(HeuteTagWahl.schritt(alt, tage: -1, heute: heute), alt)
        XCTAssertFalse(HeuteTagWahl.kannZurueck(alt, heute: heute))
        XCTAssertTrue(HeuteTagWahl.kannZurueck(Datum.addTage(alt, 1), heute: heute))
        XCTAssertEqual(HeuteTagWahl.begrenze("2026-01-15", heute: heute), "2026-01-15", "was dazwischen liegt, bleibt")
    }

    func testSchrittUeberMonatsUndJahresgrenze() {
        XCTAssertEqual(HeuteTagWahl.schritt("2026-09-01", tage: -1, heute: heute), "2026-08-31")
        XCTAssertEqual(HeuteTagWahl.schritt("2026-01-01", tage: -1, heute: heute), "2025-12-31")
        XCTAssertEqual(HeuteTagWahl.schritt("2026-09-20", tage: 2, heute: heute), "2026-09-22")
        XCTAssertEqual(HeuteTagWahl.schritt("2026-09-20", tage: -7, heute: heute), "2026-09-13")
    }

    func testRichtungBestimmtWoherDerInhaltGleitet() {
        XCTAssertEqual(HeuteTagWahl.richtung(von: "2026-09-20", nach: "2026-09-21"), 1)
        XCTAssertEqual(HeuteTagWahl.richtung(von: "2026-09-21", nach: "2026-09-20"), -1)
        XCTAssertEqual(HeuteTagWahl.richtung(von: heute, nach: heute), 0)
    }

    func testWischenNurWaagerechtUndLang() {
        XCTAssertEqual(HeuteTagWahl.wischSchritt(breite: -120, hoehe: 10), 1, "nach links: nächster Tag")
        XCTAssertEqual(HeuteTagWahl.wischSchritt(breite: 120, hoehe: -10), -1, "nach rechts: Tag davor")
        XCTAssertNil(HeuteTagWahl.wischSchritt(breite: -40, hoehe: 0), "zu kurz")
        XCTAssertNil(HeuteTagWahl.wischSchritt(breite: -120, hoehe: 100), "schräg ist Scrollen")
        XCTAssertNil(HeuteTagWahl.wischSchritt(breite: 10, hoehe: 200), "senkrecht ist Scrollen")
        XCTAssertEqual(HeuteTagWahl.wischSchritt(breite: -60, hoehe: 0), 1, "genau an der Schwelle zählt")
    }

    func testWochenstartIstDerMontag() {
        XCTAssertEqual(HeuteTagWahl.wochenstart("2026-09-23"), "2026-09-21")
        XCTAssertEqual(HeuteTagWahl.wochenstart("2026-09-21"), "2026-09-21")
        XCTAssertEqual(HeuteTagWahl.wochenstart("2026-09-27"), "2026-09-21", "Sonntag gehört zur Woche davor")
        XCTAssertEqual(HeuteTagWahl.wochenstart("2026-09-28"), "2026-09-28")
    }

    func testTitelHeuteGesternUndDatum() {
        XCTAssertEqual(HeuteTagWahl.titel(heute, heute: heute), "Heute")
        XCTAssertEqual(HeuteTagWahl.titel("2026-09-22", heute: heute), "Gestern")
        let alt = HeuteTagWahl.titel("2026-09-21", heute: heute)
        XCTAssertTrue(alt.contains("Montag") && alt.contains("21"), alt)
        XCTAssertNotNil(HeuteTagWahl.untertitel(heute, heute: heute))
        XCTAssertNotNil(HeuteTagWahl.untertitel("2026-09-22", heute: heute))
        XCTAssertNil(HeuteTagWahl.untertitel("2026-09-21", heute: heute), "das Datum steht schon im Titel")
    }
}
