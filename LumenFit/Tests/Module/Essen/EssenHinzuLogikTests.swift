// Quelle: Lovea Health/Ernaehrung/ErnaehrungHinzufuegen.swift (Listen, Chips)
import XCTest
@testable import LumenFit

final class EssenHinzuLogikTests: XCTestCase {
    private let brot = Lebensmittel(id: "bls-1", name: "Brot", pro100: Naehrwerte(kcal: 250, protein: 8, kohlenhydrate: 45, fett: 2))
    private let ei = Lebensmittel(id: "bls-2", name: "Ei", pro100: Naehrwerte(kcal: 140, protein: 12, kohlenhydrate: 1, fett: 10),
                                  portionMenge: 55, portionName: "ganze, mittelgroß")

    private func rezept(_ id: String, _ name: String, art: RezeptArt) -> Rezept {
        Rezept(id: id, name: name, portionen: 1, zutaten: [Zutat(id: "z-\(id)", lebensmittel: brot, menge: 100, einheit: .g)], art: art)
    }

    func testLebensmittelListeLaesstRezepteWeg() {
        let r = ErnaehrungLogik.alsLebensmittel(rezept("a", "Suppe", art: .rezept))
        let liste = EssenHinzuLogik.liste(typ: .lebensmittel, sortierung: .haeufig, haeufig: [brot, r, ei], zuletzt: [], favoriten: [], rezepte: [])
        XCTAssertEqual(liste.map(\.id), ["bls-1", "bls-2"])
        let fav = EssenHinzuLogik.liste(typ: .lebensmittel, sortierung: .favoriten, haeufig: [], zuletzt: [], favoriten: [ei, r], rezepte: [])
        XCTAssertEqual(fav.map(\.id), ["bls-2"])
    }

    func testMahlzeitenUndRezepteGetrennt() {
        let m = rezept("m", "Müsli", art: .mahlzeit)
        let s = rezept("s", "Suppe", art: .rezept)
        let nurM = EssenHinzuLogik.liste(typ: .mahlzeiten, sortierung: .zuletzt, haeufig: [], zuletzt: [], favoriten: [], rezepte: [m, s])
        XCTAssertEqual(nurM.map(\.name), ["Müsli"])
        let nurS = EssenHinzuLogik.liste(typ: .rezepte, sortierung: .zuletzt, haeufig: [], zuletzt: [], favoriten: [], rezepte: [m, s])
        XCTAssertEqual(nurS.map(\.name), ["Suppe"])
    }

    func testRezeptListeHaeufigeVorneRestAlphabetisch() {
        let a = rezept("a", "Zebra", art: .rezept)
        let b = rezept("b", "Apfelmus", art: .rezept)
        let c = rezept("c", "Mango", art: .rezept)
        let haeufig = [ErnaehrungLogik.alsLebensmittel(a)]
        let liste = EssenHinzuLogik.liste(typ: .rezepte, sortierung: .haeufig, haeufig: haeufig, zuletzt: [], favoriten: [], rezepte: [a, b, c])
        XCTAssertEqual(liste.map(\.name), ["Zebra", "Apfelmus", "Mango"])
    }

    func testRezeptFavoritenNurMarkierte() {
        let a = rezept("a", "Suppe", art: .rezept)
        let b = rezept("b", "Salat", art: .rezept)
        let fav = [ErnaehrungLogik.alsLebensmittel(b)]
        let liste = EssenHinzuLogik.liste(typ: .rezepte, sortierung: .favoriten, haeufig: [], zuletzt: [], favoriten: fav, rezepte: [a, b])
        XCTAssertEqual(liste.map(\.name), ["Salat"])
    }

    func testChipFiltertTrefferUndZeigtBeiLeererSucheDieGrundliste() {
        let treffer = [brot, ei]
        XCTAssertEqual(EssenHinzuLogik.suchKarten(chip: nil, treffer: treffer, favoriten: [ei], vonMir: [], vonAnderen: []).map(\.id), ["bls-1", "bls-2"])
        XCTAssertEqual(EssenHinzuLogik.suchKarten(chip: .favoriten, treffer: treffer, favoriten: [ei], vonMir: [], vonAnderen: []).map(\.id), ["bls-2"])
        XCTAssertEqual(EssenHinzuLogik.suchKarten(chip: .vonMir, treffer: [], favoriten: [], vonMir: [brot], vonAnderen: [ei]).map(\.id), ["bls-1"])
        XCTAssertEqual(EssenHinzuLogik.suchKarten(chip: .vonAnderen, treffer: [], favoriten: [], vonMir: [brot], vonAnderen: [ei]).map(\.id), ["bls-2"])
        XCTAssertEqual(EssenHinzuLogik.suchKarten(chip: .vonAnderen, treffer: [brot], favoriten: [], vonMir: [], vonAnderen: [ei]).count, 0)
    }

    func testTypLabel() {
        let m = rezept("m", "Müsli", art: .mahlzeit)
        let s = rezept("s", "Suppe", art: .rezept)
        XCTAssertEqual(EssenHinzuLogik.typLabel(ErnaehrungLogik.alsLebensmittel(m), rezepte: [m, s]), "Mahlzeit")
        XCTAssertEqual(EssenHinzuLogik.typLabel(ErnaehrungLogik.alsLebensmittel(s), rezepte: [m, s]), "Rezept")
        XCTAssertEqual(EssenHinzuLogik.typLabel(brot, rezepte: [m, s]), "Lebensmittel")
        XCTAssertNil(EssenHinzuLogik.rezept(zu: brot, in: [m]))
    }

    func testHerkunft() {
        let ich = ProfilID(rawValue: "ich")
        XCTAssertEqual(EssenHinzuLogik.herkunft(ersteller: nil, ich: ich), .keine)
        XCTAssertEqual(EssenHinzuLogik.herkunft(ersteller: ich, ich: ich), .ich)
        XCTAssertEqual(EssenHinzuLogik.herkunft(ersteller: ProfilID(rawValue: "x"), ich: ich), .andere)
    }

    func testPlusMengeNimmtLetzteMengeSonstStart() {
        XCTAssertEqual(EssenHinzuLogik.plusMenge(ei, letzte: (menge: 3, einheit: .portion)).menge, 3)
        let start = EssenHinzuLogik.plusMenge(brot, letzte: nil)
        XCTAssertEqual(start.menge, 100)
        XCTAssertEqual(start.einheit, .g)
        XCTAssertEqual(EssenHinzuLogik.plusMenge(ei, letzte: nil).einheit, .portion)
    }

    func testPortionTextUndKcal() {
        XCTAssertEqual(EssenHinzuLogik.portionText(brot), "100 g")
        XCTAssertEqual(EssenHinzuLogik.portionKcal(brot), 250)
        XCTAssertEqual(EssenHinzuLogik.portionKcal(ei), 77)
        XCTAssertTrue(EssenHinzuLogik.portionText(ei).hasSuffix("(55 g)"))
    }
}
