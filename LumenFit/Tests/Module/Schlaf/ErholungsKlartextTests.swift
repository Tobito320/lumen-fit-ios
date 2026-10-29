import XCTest
@testable import LumenFit

final class ErholungsKlartextTests: XCTestCase {
    private func bereich(_ art: VitalArt, mittel: Double, streuung: Double, aktuell: Double) -> PersoenlicherBereich {
        PersoenlicherBereich(art: art, mittel: mittel, streuung: streuung, anzahl: 30, aktuell: aktuell, aktuellTag: "2026-09-23")
    }

    func testHrvUeberDemSchnittIstBereit() {
        let e = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 5, aktuell: 61.6), ruhepuls: nil, letzteNachtMinuten: 450, ziel: 480)
        XCTAssertEqual(e.stufe, .bereit)
        XCTAssertEqual(e.satz, "Deine HRV liegt 12 Prozent über deinem Schnitt, du bist bereit.")
    }

    func testHrvDeutlichDarunterIstSchonen() {
        let e = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 4, aktuell: 49.5), ruhepuls: nil, letzteNachtMinuten: nil, ziel: 480)
        XCTAssertEqual(e.stufe, .schonen)
        XCTAssertEqual(e.satz, "Deine HRV liegt 10 Prozent unter deinem Schnitt. Heute lieber locker.")
        XCTAssertEqual(e.stufe.lumi, .muede)
    }

    func testHrvDarunterAberImBereichIstNormal() {
        let e = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 10, aktuell: 50.6), ruhepuls: nil, letzteNachtMinuten: nil, ziel: 480)
        XCTAssertEqual(e.stufe, .normal)
        XCTAssertEqual(e.satz, "Deine HRV liegt 8 Prozent unter deinem Schnitt, aber noch in deinem Bereich. Hör auf dein Gefühl.")
        XCTAssertEqual(e.stufe.lumi, .bereit)
    }

    func testHrvNahAmSchnittIstNormal() {
        let e = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 5, aktuell: 56), ruhepuls: nil, letzteNachtMinuten: nil, ziel: 480)
        XCTAssertEqual(e.stufe, .normal)
        XCTAssertEqual(e.satz, "Deine HRV liegt nah an deinem Schnitt. Ein ganz normaler Tag.")
    }

    func testHohesRuhepulsNimmtBereitZurueck() {
        let e = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 5, aktuell: 61.6), ruhepuls: bereich(.ruhepuls, mittel: 54, streuung: 2, aktuell: 58),
                                          letzteNachtMinuten: nil, ziel: 480)
        XCTAssertEqual(e.stufe, .normal)
        XCTAssertEqual(e.satz, "Deine HRV liegt 12 Prozent über deinem Schnitt, du bist bereit. Dein Ruhepuls ist höher als sonst.")
    }

    func testRuhepulsAllein() {
        let e = ErholungsKlartext.bewerte(hrv: nil, ruhepuls: bereich(.ruhepuls, mittel: 54, streuung: 2, aktuell: 58), letzteNachtMinuten: nil, ziel: 480)
        XCTAssertEqual(e.stufe, .normal)
        XCTAssertEqual(e.satz, "Dein Ruhepuls liegt 7 Prozent über deinem Schnitt. Geh den Tag etwas ruhiger an.")
        let normal = ErholungsKlartext.bewerte(hrv: nil, ruhepuls: bereich(.ruhepuls, mittel: 54, streuung: 2, aktuell: 54), letzteNachtMinuten: nil, ziel: 480)
        XCTAssertEqual(normal.stufe, .offen, "ein normaler Ruhepuls allein sagt nichts")
    }

    func testKurzeNachtNimmtBereitZurueckUndSchontNichtMehr() {
        let bereit = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 5, aktuell: 61.6), ruhepuls: nil, letzteNachtMinuten: 300, ziel: 480)
        XCTAssertEqual(bereit.stufe, .normal)
        XCTAssertEqual(bereit.satz, "Deine HRV liegt 12 Prozent über deinem Schnitt, du bist bereit. Die Nacht war kurz.")
        let schonen = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 4, aktuell: 49.5), ruhepuls: nil, letzteNachtMinuten: 300, ziel: 480)
        XCTAssertEqual(schonen.stufe, .schonen, "schlechter wird es durch die Nacht nicht")
    }

    func testNurDieNachtGegenDasZiel() {
        XCTAssertEqual(ErholungsKlartext.bewerte(hrv: nil, ruhepuls: nil, letzteNachtMinuten: 300, ziel: 480).stufe, .schonen)
        XCTAssertEqual(ErholungsKlartext.bewerte(hrv: nil, ruhepuls: nil, letzteNachtMinuten: 300, ziel: 480).satz, "Die Nacht war kurz. Geh den Tag ruhig an.")
        let gut = ErholungsKlartext.bewerte(hrv: nil, ruhepuls: nil, letzteNachtMinuten: 480, ziel: 480)
        XCTAssertEqual(gut.stufe, .bereit)
        XCTAssertEqual(gut.satz, "Du hast dein Schlafziel erreicht.")
        let mittel = ErholungsKlartext.bewerte(hrv: nil, ruhepuls: nil, letzteNachtMinuten: 420, ziel: 480)
        XCTAssertEqual(mittel.stufe, .normal)
    }

    func testOhneAlleWerteBleibtOffenUndErfindetNichts() {
        let e = ErholungsKlartext.bewerte(hrv: nil, ruhepuls: nil, letzteNachtMinuten: nil, ziel: 480)
        XCTAssertEqual(e.stufe, .offen)
        XCTAssertEqual(e.satz, "Für eine Einschätzung fehlen noch Werte. Eine Apple Watch liefert HRV und Ruhepuls.")
    }

    func testCoachFrageTraegtDenSatz() {
        let e = ErholungsKlartext.bewerte(hrv: bereich(.hrv, mittel: 55, streuung: 5, aktuell: 61.6), ruhepuls: nil, letzteNachtMinuten: nil, ziel: 480)
        XCTAssertTrue(e.coachFrage.contains(e.satz))
        XCTAssertTrue(e.coachFrage.hasPrefix("Erkläre mir bitte in einfachen Worten meine Erholung heute."))
    }

    func testStufenSindGeordnet() {
        XCTAssertLessThan(ErholungsKlartext.Stufe.bereit, .normal)
        XCTAssertLessThan(ErholungsKlartext.Stufe.normal, .schonen)
    }
}
