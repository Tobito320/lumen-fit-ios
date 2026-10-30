// Quelle: Lovea Health/Ernaehrung/ErnaehrungEigene.swift (EigenesLebensmittelEditor)
import XCTest
@testable import LumenFit

final class EssenEigenesLogikTests: XCTestCase {
    private func eingabe(name: String = "Brötchen", kcal: String = "260") -> EssenEigenesEingabe {
        EssenEigenesEingabe(name: name, kcal: kcal)
    }

    func testNameUndKalorienSindPflicht() {
        XCTAssertNil(EssenEigenesLogik.lebensmittel(eingabe(name: "  "), barcode: nil, start: nil, id: "eigen-1"))
        XCTAssertNil(EssenEigenesLogik.lebensmittel(eingabe(kcal: ""), barcode: nil, start: nil, id: "eigen-1"))
        XCTAssertNotNil(EssenEigenesLogik.lebensmittel(eingabe(), barcode: nil, start: nil, id: "eigen-1"))
    }

    func testNeuesLebensmittelBekommtDieGegebeneId() throws {
        var e = eingabe()
        e.portion = "60"
        e.portionName = ""
        e.packung = "300"
        e.marke = " Bäcker "
        let l = try XCTUnwrap(EssenEigenesLogik.lebensmittel(e, barcode: "4000000000000", start: nil, id: "eigen-7"))
        XCTAssertEqual(l.id, "eigen-7")
        XCTAssertEqual(l.marke, "Bäcker")
        XCTAssertEqual(l.barcode, "4000000000000")
        XCTAssertEqual(l.portionMenge, 60)
        XCTAssertEqual(l.portionName, "Portion", "ohne Namen heißt die Portion Portion")
        XCTAssertEqual(l.packungMenge, 300)
    }

    func testPortionNameOhneMengeFaelltWeg() throws {
        var e = eingabe()
        e.portionName = "Scheibe"
        let l = try XCTUnwrap(EssenEigenesLogik.lebensmittel(e, barcode: nil, start: nil, id: "eigen-1"))
        XCTAssertNil(l.portionMenge)
        XCTAssertNil(l.portionName)
    }

    func testBearbeitenBehaeltIdMikroUndZutaten() throws {
        let alt = Lebensmittel(id: "eigen-alt", name: "Müsli", marke: "X", barcode: "123", fluessig: false,
                               pro100: Naehrwerte(kcal: 380, protein: 10, kohlenhydrate: 60, fett: 8, salz: 0.02, gesFett: 1.5, mikro: ["eisen": 3]),
                               portionMenge: 40, portionName: "Schale", nutriscore: "b", zutaten: "Haferflocken")
        var e = EssenEigenesLogik.eingabe(alt)
        XCTAssertEqual(e.salz, "0,02", "kleine Werte gehen beim Öffnen nicht verloren")
        XCTAssertEqual(e.gesFett, "1,5")
        e.kcal = "400"
        let neu = try XCTUnwrap(EssenEigenesLogik.lebensmittel(e, barcode: nil, start: alt, id: "eigen-neu"))
        XCTAssertEqual(neu.id, "eigen-alt", "Bearbeiten legt kein Duplikat an")
        XCTAssertEqual(neu.pro100.kcal, 400)
        XCTAssertEqual(neu.pro100.mikro?["eisen"], 3)
        XCTAssertEqual(neu.zutaten, "Haferflocken")
        XCTAssertEqual(neu.nutriscore, "b")
        XCTAssertEqual(neu.barcode, "123")
        XCTAssertEqual(neu.portionName, "Schale")
    }

    func testFotoWerteFuellenNurNaehrwerte() {
        let e = EssenEigenesLogik.eingabe(werte: Naehrwerte(kcal: 250, protein: 7.5, kohlenhydrate: 30, fett: 9, zucker: 4, ballaststoffe: nil, salz: 1.2))
        XCTAssertEqual(e.kcal, "250")
        XCTAssertEqual(e.protein, "7,5")
        XCTAssertEqual(e.zucker, "4")
        XCTAssertEqual(e.ballaststoffe, "")
        XCTAssertEqual(e.name, "")
    }
}
