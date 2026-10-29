import XCTest
@testable import LumenFit

final class EssenMengeTests: XCTestCase {
    private let ei = Lebensmittel(id: "bls-ei", name: "Hühnerei", pro100: Naehrwerte(kcal: 137, protein: 12.4, kohlenhydrate: 0.7, fett: 9.3),
                                  portionen: [LebensmittelPortion(name: "ganze, mittelgroß", gramm: 55)])

    func testGrammEinerPortion() {
        let stueck = MengenOption.portion(LebensmittelPortion(name: "ganze, mittelgroß", gramm: 55))
        XCTAssertEqual(EssenMenge.gramm(2, stueck), 110)
        XCTAssertEqual(EssenMenge.gramm(150, .gramm), 150)
        XCTAssertEqual(EssenMenge.gramm(250, .milliliter), 250)
    }

    func testUmrechnenGrammInStueckUndZurueck() {
        let stueck = MengenOption.portion(LebensmittelPortion(name: "ganze, mittelgroß", gramm: 50))
        XCTAssertEqual(EssenMenge.umrechnen(150, von: .gramm, nach: stueck), 3)
        XCTAssertEqual(EssenMenge.umrechnen(3, von: stueck, nach: .gramm), 150)
        XCTAssertEqual(EssenMenge.umrechnen(60, von: .gramm, nach: stueck), 1.25, "auf Viertel gerundet")
        XCTAssertEqual(EssenMenge.umrechnen(1, von: .gramm, nach: stueck), 0.25, "nie null")
    }

    func testStueckInAnderePortionUmrechnen() {
        let a = MengenOption.portion(LebensmittelPortion(name: "Scheibe", gramm: 30))
        let b = MengenOption.portion(LebensmittelPortion(name: "Packung", gramm: 300))
        XCTAssertEqual(EssenMenge.umrechnen(10, von: a, nach: b), 1)
    }

    func testNaehrwerteRollenMitDerMenge() {
        let stueck = MengenOption.portion(LebensmittelPortion(name: "ganze, mittelgroß", gramm: 55))
        let eins = ErnaehrungLogik.naehrwerte(ErnaehrungLogik.mitPortion(ei, LebensmittelPortion(name: "ganze, mittelgroß", gramm: 55)), menge: 1, einheit: stueck.einheit)
        let zwei = ErnaehrungLogik.naehrwerte(ErnaehrungLogik.mitPortion(ei, LebensmittelPortion(name: "ganze, mittelgroß", gramm: 55)), menge: 2, einheit: stueck.einheit)
        XCTAssertEqual(eins.kcal, 137 * 0.55, accuracy: 0.01)
        XCTAssertEqual(zwei.kcal, eins.kcal * 2, accuracy: 0.01)
    }

    func testSchieberBereichUndSchritt() {
        let stueck = MengenOption.portion(LebensmittelPortion(name: "x", gramm: 10))
        XCTAssertEqual(EssenMenge.schritt(stueck), 0.25)
        XCTAssertEqual(EssenMenge.schritt(.gramm), 5)
        XCTAssertEqual(EssenMenge.bereich(stueck), 0...10)
        XCTAssertEqual(EssenMenge.bereich(.gramm), 0...1000)
    }

    func testStartNimmtLetzteMengeSonstMittlerePortionSonstHundert() {
        let eiPortion = ErnaehrungLogik.mitPortion(ei, LebensmittelPortion(name: "ganze, mittelgroß", gramm: 55))
        let letzte = EssenMenge.start(eiPortion, letzte: (menge: 3, einheit: .portion))
        XCTAssertEqual(letzte.zahl, 3)
        if case .portion(let p) = letzte.option { XCTAssertEqual(p.name, "ganze, mittelgroß") } else { XCTFail("Portion erwartet") }
        let neu = EssenMenge.start(ei, letzte: nil)
        XCTAssertEqual(neu.zahl, 1)
        let reis = Lebensmittel(id: "bls-reis", name: "Reis", pro100: Naehrwerte(kcal: 350, protein: 7, kohlenhydrate: 78, fett: 0.6))
        let r = EssenMenge.start(reis, letzte: nil)
        XCTAssertEqual(r.zahl, 100)
        XCTAssertEqual(r.option, .gramm)
        let milch = Lebensmittel(id: "bls-milch", name: "Milch", fluessig: true, pro100: Naehrwerte(kcal: 64, protein: 3.4, kohlenhydrate: 4.8, fett: 3.6))
        XCTAssertEqual(EssenMenge.start(milch, letzte: nil).option, .milliliter)
    }
}
