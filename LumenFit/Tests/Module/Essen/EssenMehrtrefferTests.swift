// Quelle: Lovea Health/Ernaehrung/ErnaehrungHinzufuegen.swift (vorschlaegeAuswahl)
import XCTest
@testable import LumenFit

final class EssenMehrtrefferTests: XCTestCase {
    func testVorschlagWirdEigenesMitCode() {
        let v = Lebensmittel(id: "off-111", name: "Skyr", marke: "Beispiel", barcode: "111", pro100: Naehrwerte(kcal: 63, protein: 11, kohlenhydrate: 4, fett: 0.2),
                             quelle: "off", zutaten: "Magermilch")
        let k = EssenMehrtrefferLogik.alsEigenes(v, code: " 012345678905\n", id: "eigen-1")
        XCTAssertEqual(k.id, "eigen-1")
        XCTAssertEqual(k.barcode, "0012345678905")
        XCTAssertEqual(k.name, "Skyr")
        XCTAssertEqual(k.pro100, v.pro100)
        XCTAssertNil(k.quelle, "ein selbst bestätigter Vorschlag zählt als Eigenes")
        XCTAssertEqual(k.zutaten, "Magermilch")
        XCTAssertFalse(EssenMehrtrefferLogik.alsEigenes(v, code: "111").id == v.id)
    }
}
