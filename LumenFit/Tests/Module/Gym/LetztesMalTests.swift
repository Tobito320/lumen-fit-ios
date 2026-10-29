import XCTest
@testable import LumenFit

/// Idee 21: "Letztes Mal" je Satz und Plus/Minus statt Tippen.
final class LetztesMalTests: XCTestCase {
    private func satz(_ wdh: Int, _ kg: Double?, typ: String? = nil) -> PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ) }

    /// Beim letzten Mal: ein Aufwärmsatz und zwei Arbeitssätze.
    private var vorher: [PlanSatz] { [satz(10, 40, typ: "w"), satz(8, 60), satz(8, 62.5)] }

    func testAufwaermsatzPasstZuAufwaermsatzUndArbeitssaetzeDerReihenNach() {
        let zeilen = [satz(10, nil, typ: "w"), satz(8, nil), satz(8, nil), satz(8, nil)]
        XCTAssertEqual(LetztesMal.satz(zeile: 0, in: zeilen, vorher: vorher), satz(10, 40, typ: "w"))
        XCTAssertEqual(LetztesMal.satz(zeile: 1, in: zeilen, vorher: vorher), satz(8, 60))
        XCTAssertEqual(LetztesMal.satz(zeile: 2, in: zeilen, vorher: vorher), satz(8, 62.5))
        // Mehr Sätze als damals: der letzte Arbeitssatz gilt weiter.
        XCTAssertEqual(LetztesMal.satz(zeile: 3, in: zeilen, vorher: vorher), satz(8, 62.5))
    }

    func testOhneVorgaengerOderMitZuvielenAufwaermsaetzenGibtEsNichts() {
        let zeilen = [satz(10, nil, typ: "w"), satz(10, nil, typ: "w"), satz(8, nil)]
        XCTAssertNil(LetztesMal.satz(zeile: 1, in: zeilen, vorher: vorher)) // zweiter Aufwärmsatz, damals nur einer
        XCTAssertNil(LetztesMal.satz(zeile: 2, in: zeilen, vorher: []))
        XCTAssertNil(LetztesMal.satz(zeile: 9, in: zeilen, vorher: vorher))
        XCTAssertNil(LetztesMal.text(zeile: 2, in: zeilen, vorher: []))
    }

    func testTextUndUebernehmen() {
        let zeilen = [satz(10, nil), satz(10, nil)]
        XCTAssertEqual(LetztesMal.text(zeile: 0, in: zeilen, vorher: vorher), "60 kg × 8")
        XCTAssertEqual(LetztesMal.text(zeile: 0, in: [satz(5, nil)], vorher: [satz(12, nil)]), "12 Wdh")
        let neu = LetztesMal.uebernehmen(zeile: 1, in: zeilen, vorher: vorher)
        XCTAssertEqual(neu[0], zeilen[0])
        XCTAssertEqual(neu[1].kg, 62.5)
        XCTAssertEqual(neu[1].wdh, 8)
        XCTAssertEqual(LetztesMal.uebernehmen(zeile: 1, in: zeilen, vorher: []), zeilen)
    }

    func testGewichtPlusMinusInSchritten() {
        XCTAssertEqual(LetztesMal.kg(60, richtung: 1, schritt: 2.5), 62.5)
        XCTAssertEqual(LetztesMal.kg(60, richtung: -1, schritt: 2.5), 57.5)
        // 61 liegt zwischen den Stufen: Plus geht zur nächsten, Minus zur vorigen Stufe.
        XCTAssertEqual(LetztesMal.kg(61, richtung: 1, schritt: 2.5), 62.5)
        XCTAssertEqual(LetztesMal.kg(61, richtung: -1, schritt: 2.5), 60)
        XCTAssertEqual(LetztesMal.kg(10, richtung: 1, schritt: 2), 12)
    }

    func testGewichtOhneWertStartetBeimSchrittUndKehrtZuOhneZurueck() {
        XCTAssertEqual(LetztesMal.kg(nil, richtung: 1, schritt: 2.5), 2.5)
        XCTAssertNil(LetztesMal.kg(2.5, richtung: -1, schritt: 2.5)) // 0 kg heißt "ohne Gewicht"
        XCTAssertNil(LetztesMal.kg(nil, richtung: -1, schritt: 2.5))
        XCTAssertEqual(LetztesMal.kg(500, richtung: 1, schritt: 2.5), 500) // Obergrenze
    }

    func testSchrittJeGeraet() {
        XCTAssertEqual(LetztesMal.kgSchritt(geraet: "Kurzhantel"), 2)
        XCTAssertEqual(LetztesMal.kgSchritt(geraet: "Kabelzug"), 5)
        XCTAssertEqual(LetztesMal.kgSchritt(geraet: "Langhantel"), 2.5)
        XCTAssertEqual(LetztesMal.kgSchritt(geraet: nil), 2.5)
    }

    func testWiederholungenPlusMinusImBereich() {
        XCTAssertEqual(LetztesMal.wdh(8, richtung: 1), 9)
        XCTAssertEqual(LetztesMal.wdh(8, richtung: -1), 7)
        XCTAssertEqual(LetztesMal.wdh(1, richtung: -1), 1)
        XCTAssertEqual(LetztesMal.wdh(100, richtung: 1), 100)
    }

    func testZeilenAendernLaesstAndereZeilenUndUngueltigeIndizesUnberuehrt() {
        let zeilen = [satz(8, 60), satz(8, 60)]
        let neu = LetztesMal.aendereKg(zeilen, 1, richtung: 1, schritt: 2.5)
        XCTAssertEqual(neu[0].kg, 60)
        XCTAssertEqual(neu[1].kg, 62.5)
        XCTAssertEqual(LetztesMal.aendereWdh(zeilen, 0, richtung: -1)[0].wdh, 7)
        XCTAssertEqual(LetztesMal.aendereKg(zeilen, 7, richtung: 1, schritt: 2.5), zeilen)
        XCTAssertEqual(LetztesMal.aendereWdh(zeilen, -1, richtung: 1), zeilen)
    }
}
