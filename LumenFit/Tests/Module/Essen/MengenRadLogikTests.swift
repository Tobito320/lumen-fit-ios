// Quelle: Lovea Tests/MengenRadLogikTests.swift
import XCTest
@testable import LumenFit

final class MengenRadLogikTests: XCTestCase {
    func testZusammensetzen() {
        XCTAssertEqual(MengenRad.zahl(ganz: 721, bruch: 7), 721.875)   // 7 = Index von 7/8
        XCTAssertEqual(MengenRad.zahl(ganz: 1, bruch: 0), 1)
    }

    func testZerlegen() {
        XCTAssertEqual(MengenRad.zerlegen(721.875).ganz, 721)
        XCTAssertEqual(MengenRad.brueche[MengenRad.zerlegen(721.875).bruch].text, "⅞")
        XCTAssertEqual(MengenRad.brueche[MengenRad.zerlegen(0.3).bruch].text, "⅓")
        XCTAssertEqual(MengenRad.zerlegen(500).ganz, 500)
        XCTAssertEqual(MengenRad.zerlegen(99999).ganz, MengenRad.maxGanz)
    }

    func testFeldText() {
        XCTAssertEqual(MengenRad.feldText(721.875), "721,875")
        XCTAssertEqual(MengenRad.feldText(500), "500")
        XCTAssertEqual(MengenRad.feldText(0.5), "0,5")
    }

    func testEingabe() {
        XCTAssertEqual(ErnaehrungLogik.eingabe("0,5"), 0.5)
        XCTAssertEqual(ErnaehrungLogik.eingabe("1.5"), 1.5)
        XCTAssertEqual(ErnaehrungLogik.eingabe("500"), 500)
        XCTAssertNil(ErnaehrungLogik.eingabe(""))
        XCTAssertNil(ErnaehrungLogik.eingabe("abc"))
        XCTAssertEqual(ErnaehrungLogik.eingabe("99999"), 99999)
    }

    func testRadZahlLaesstPassendeMengeUnberuehrt() {
        // 150,3 rundet am Rad auf 150 und 1/4: steht das Rad schon so, bleibt der getippte Wert stehen.
        let z = MengenRad.zerlegen(150.3)
        XCTAssertNil(MengenRad.radZahl(ganz: z.ganz, bruch: z.bruch, aktuell: 150.3))
        XCTAssertNil(MengenRad.radZahl(ganz: 100, bruch: 0, aktuell: 100))
    }

    func testRadZahlMeldetDrehung() {
        XCTAssertEqual(MengenRad.radZahl(ganz: 120, bruch: 0, aktuell: 100), 120)
        XCTAssertEqual(MengenRad.radZahl(ganz: 100, bruch: 4, aktuell: 100), 100.5)
        XCTAssertEqual(MengenRad.radZahl(ganz: 3, bruch: 99, aktuell: 1), 3.875, "ein Bruch-Index außerhalb klemmt am Rand")
    }
}
