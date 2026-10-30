// Quelle: Lovea Health/Ernaehrung/ErnaehrungEigene.swift (RezeptEditor)
import XCTest
@testable import LumenFit

final class EssenRezeptLogikTests: XCTestCase {
    private let hafer = Lebensmittel(id: "bls-1", name: "Hafer", pro100: Naehrwerte(kcal: 370, protein: 13, kohlenhydrate: 60, fett: 7))
    private func zutat(_ id: String, _ g: Double) -> Zutat { Zutat(id: id, lebensmittel: hafer, menge: g, einheit: .g) }

    func testSichernBrauchtNameUndZutat() {
        XCTAssertFalse(EssenRezeptLogik.kannSichern(name: "", zutaten: [zutat("a", 50)]))
        XCTAssertFalse(EssenRezeptLogik.kannSichern(name: "  ", zutaten: [zutat("a", 50)]))
        XCTAssertFalse(EssenRezeptLogik.kannSichern(name: "Brei", zutaten: []))
        XCTAssertTrue(EssenRezeptLogik.kannSichern(name: "Brei", zutaten: [zutat("a", 50)]))
    }

    func testStartPortionenUndTitel() {
        XCTAssertEqual(EssenRezeptLogik.startPortionen(start: nil, art: .rezept), 4)
        XCTAssertEqual(EssenRezeptLogik.startPortionen(start: nil, art: .mahlzeit), 1)
        let r = Rezept(id: "r", name: "Suppe", portionen: 6, zutaten: [], art: .rezept)
        XCTAssertEqual(EssenRezeptLogik.startPortionen(start: r, art: .rezept), 6)
        XCTAssertEqual(EssenRezeptLogik.titel(start: nil, art: .mahlzeit), "Neue Mahlzeit")
        XCTAssertEqual(EssenRezeptLogik.titel(start: nil, art: .rezept), "Neues Rezept")
        XCTAssertEqual(EssenRezeptLogik.titel(start: r, art: .rezept), "Rezept bearbeiten")
        XCTAssertEqual(EssenRezeptLogik.titel(start: r, art: .mahlzeit), "Mahlzeit bearbeiten")
    }

    func testRezeptNaehrwertePortionSummeMahlzeit() {
        let z = [zutat("a", 200)] // 740 kcal gesamt
        XCTAssertEqual(EssenRezeptLogik.naehrwerte(art: .mahlzeit, portionen: 4, zutaten: z).kcal, 740, accuracy: 0.01)
        XCTAssertEqual(EssenRezeptLogik.naehrwerte(art: .rezept, portionen: 4, zutaten: z).kcal, 185, accuracy: 0.01)
        XCTAssertEqual(EssenRezeptLogik.naehrwerte(art: .rezept, portionen: 1, zutaten: z).kcal, 740, accuracy: 0.01)
        XCTAssertEqual(EssenRezeptLogik.naehrwerte(art: .rezept, portionen: 4, zutaten: []).kcal, 0)
    }

    func testRezeptBauenBehaeltIdUndBereinigtText() {
        let alt = Rezept(id: "alt", name: "Brei", portionen: 2, zutaten: [], art: .rezept)
        let neu = EssenRezeptLogik.rezept(start: alt, art: .rezept, name: " Haferbrei ", portionen: 3, zutaten: [zutat("a", 50)], anleitung: "  kochen  ", id: "neu")
        XCTAssertEqual(neu.id, "alt")
        XCTAssertEqual(neu.name, "Haferbrei")
        XCTAssertEqual(neu.portionen, 3)
        XCTAssertEqual(neu.anleitung, "kochen")
        XCTAssertFalse(neu.istMahlzeit)
        let ohne = EssenRezeptLogik.rezept(start: nil, art: .rezept, name: "X", portionen: 2, zutaten: [], anleitung: "   ", id: "neu")
        XCTAssertEqual(ohne.id, "neu")
        XCTAssertNil(ohne.anleitung)
    }

    func testMahlzeitHatEinePortionUndKeineAnleitung() {
        let m = EssenRezeptLogik.rezept(start: nil, art: .mahlzeit, name: "Müsli", portionen: 5, zutaten: [zutat("a", 50)], anleitung: "egal", id: "m")
        XCTAssertEqual(m.portionen, 1)
        XCTAssertNil(m.anleitung)
        XCTAssertTrue(m.istMahlzeit)
    }

    func testMengeErsetzenNurDieEineZutat() {
        let liste = [zutat("a", 50), zutat("b", 100)]
        let neu = EssenRezeptLogik.ersetzen(liste, id: "b", menge: 2, einheit: .portion)
        XCTAssertEqual(neu[0].menge, 50)
        XCTAssertEqual(neu[0].einheit, .g)
        XCTAssertEqual(neu[1].menge, 2)
        XCTAssertEqual(neu[1].einheit, .portion)
        XCTAssertEqual(EssenRezeptLogik.ersetzen(liste, id: "x", menge: 9, einheit: .g), liste)
    }
}
