// Quelle: Lovea Health/Ernaehrung/ErnaehrungHinzufuegen.swift (SchnellEintragenBlatt)
import XCTest
@testable import LumenFit

final class EssenSchnellEintragenTests: XCTestCase {
    func testOhneKalorienKeinEintrag() {
        XCTAssertNil(EssenSchnellLogik.lebensmittel(name: "Kuchen", kcal: "", protein: "5", kohlenhydrate: "", fett: ""))
        XCTAssertNil(EssenSchnellLogik.lebensmittel(name: "Kuchen", kcal: "viel", protein: "", kohlenhydrate: "", fett: ""))
        XCTAssertNil(EssenSchnellLogik.lebensmittel(name: "Kuchen", kcal: "-5", protein: "", kohlenhydrate: "", fett: ""))
    }

    func testNurKalorienGenuegen() throws {
        let l = try XCTUnwrap(EssenSchnellLogik.lebensmittel(name: "  ", kcal: "320,5", protein: "", kohlenhydrate: "", fett: "", id: "schnell-1"))
        XCTAssertEqual(l.name, "Schnell eingetragen")
        XCTAssertEqual(l.pro100.kcal, 320.5)
        XCTAssertEqual(l.pro100.protein, 0)
        XCTAssertTrue(l.istEinmalig, "Schnell-Einträge landen nicht in Zuletzt und Häufig")
        // Eine Portion zu 100 g: 1 Portion liefert genau die eingegebenen Werte.
        let n = ErnaehrungLogik.naehrwerte(l, menge: 1, einheit: .portion)
        XCTAssertEqual(n.kcal, 320.5, accuracy: 0.001)
    }

    func testMakrosUndNameWerdenUebernommen() throws {
        let l = try XCTUnwrap(EssenSchnellLogik.lebensmittel(name: " Eis ", kcal: "200", protein: "4,5", kohlenhydrate: "30", fett: "8"))
        XCTAssertEqual(l.name, "Eis")
        XCTAssertEqual(l.pro100.protein, 4.5)
        XCTAssertEqual(l.pro100.kohlenhydrate, 30)
        XCTAssertEqual(l.pro100.fett, 8)
        XCTAssertTrue(l.id.hasPrefix("schnell-"))
    }
}
