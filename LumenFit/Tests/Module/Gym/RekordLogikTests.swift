import XCTest
@testable import LumenFit

/// Idee 24: Rekord sofort nach dem Satz (Gewicht, Wiederholungen, 1RM nach Epley, Satzvolumen gegen die Historie).
final class RekordLogikTests: XCTestCase {
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func satz(_ wdh: Int, _ kg: Double?, typ: String? = nil) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ)
        s.ok = true
        return s
    }

    /// Letzte Woche: ein Satz mit 60 kg × 10 (Volumen 600, 1RM 80).
    private var historie: [UebungTag] { [UebungTag(id: "alt", datum: t0 - 7 * 86400, saetze: [satz(10, 60)])] }

    func testEpleyUndEinsRepIstDasGewicht() {
        XCTAssertEqual(RekordLogik.e1rm(satz(10, 60)), 80) // 60 × (1 + 10/30)
        XCTAssertEqual(RekordLogik.e1rm(satz(1, 100)), 100)
        XCTAssertNil(RekordLogik.e1rm(satz(10, nil)))
        XCTAssertNil(RekordLogik.e1rm(satz(0, 60)))
        XCTAssertEqual(RekordLogik.volumen(satz(8, 62.5)), 500)
        XCTAssertNil(RekordLogik.volumen(satz(8, 0)))
    }

    func testSchwereresGewichtIstEinGewichtsrekord() {
        // 62,5 × 8: schwerer, aber weniger Wiederholungen, 1RM 79,2 und Volumen 500 liegen darunter.
        XCTAssertEqual(RekordLogik.beimSatz(satz(8, 62.5), davor: [], gegen: historie), [.gewicht])
    }

    func testMehrWiederholungenBrechenWiederholungen1RMUndVolumen() {
        // 60 × 12: 1RM 84 und Volumen 720 über 80 und 600, Gewicht gleich.
        XCTAssertEqual(RekordLogik.beimSatz(satz(12, 60), davor: [], gegen: historie), [.wiederholungen, .e1rm, .satzVolumen])
    }

    func testDasErsteMalUndAufwaermsaetzeSindKeinRekord() {
        XCTAssertEqual(RekordLogik.beimSatz(satz(8, 100), davor: [], gegen: []), [])
        XCTAssertEqual(RekordLogik.beimSatz(satz(8, 200, typ: "w"), davor: [], gegen: historie), [])
    }

    func testGleicherWertZweimalMeldetNurEinmal() {
        // Heute schon 65 × 5 gemacht: derselbe Satz noch einmal bricht nichts, ein schwererer schon.
        let davor = [satz(5, 65)]
        XCTAssertEqual(RekordLogik.beimSatz(satz(5, 65), davor: davor, gegen: historie), [])
        XCTAssertEqual(RekordLogik.beimSatz(satz(5, 67.5), davor: davor, gegen: historie), [.gewicht])
        // Und der erste 65er hätte gemeldet: schwerer als 60.
        XCTAssertEqual(RekordLogik.beimSatz(satz(5, 65), davor: [], gegen: historie), [.gewicht])
    }

    func testSchwereresGewichtMitGutenWiederholungenBrichtAuchDas1RM() {
        // 70 × 8: Gewicht über 60, 1RM 88,7 über 80; Wiederholungen (8 < 10) und Volumen (560 < 600) nicht.
        XCTAssertEqual(RekordLogik.beimSatz(satz(8, 70), davor: [], gegen: historie), [.gewicht, .e1rm])
    }

    func testSitzungsvolumenHatKeinenLiveRekord() {
        XCTAssertFalse(RekordLogik.liveArten.contains(.sitzungsVolumen))
        XCTAssertEqual(RekordLogik.wert([satz(10, 50), satz(8, 50)], .sitzungsVolumen), 900)
    }

    func testToastMitLumiStolzEinmalProSatz() throws {
        let t = try XCTUnwrap(RekordLogik.toast(uebung: "Bankdrücken", arten: [.gewicht], satz: satz(8, 62.5)))
        XCTAssertEqual(t.titel, "Neuer Rekord: Gewicht")
        XCTAssertEqual(t.zeile, "Bankdrücken, 62,5 kg × 8")
        XCTAssertEqual(t.stimmung, .stolz)
        XCTAssertEqual(RekordLogik.toast(uebung: "Bankdrücken", arten: [.gewicht, .e1rm], satz: satz(8, 62.5))?.titel, "Neue Rekorde: Gewicht, 1RM")
        XCTAssertNil(RekordLogik.toast(uebung: "Bankdrücken", arten: [], satz: satz(8, 62.5)))
    }

    func testTexte() {
        XCTAssertEqual(RekordLogik.text(12, art: .wiederholungen), "12 Wdh")
        XCTAssertEqual(RekordLogik.text(62.5), "62,5 kg")
        XCTAssertEqual(RekordLogik.text(nil), "–")
        XCTAssertEqual(RekordLogik.wert([satz(8, nil), satz(12, nil)], .wiederholungen), 12)
    }
}
