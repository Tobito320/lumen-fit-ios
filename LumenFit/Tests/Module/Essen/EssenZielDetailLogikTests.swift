// Quelle: Lovea Health/Ernaehrung/ErnaehrungZiele.swift (Regeln der Seite, neu getestet)
import XCTest
@testable import LumenFit

final class EssenZielDetailLogikTests: XCTestCase {
    func testVorschauKgReihenfolge() {
        XCTAssertEqual(EssenZielDetailLogik.vorschauKg(eingabe: "80,5", gespeichert: 70), 80.5, accuracy: 0.0001)
        XCTAssertEqual(EssenZielDetailLogik.vorschauKg(eingabe: "", gespeichert: 70), 70, accuracy: 0.0001)
        XCTAssertEqual(EssenZielDetailLogik.vorschauKg(eingabe: "abc", gespeichert: nil), 75, accuracy: 0.0001)
    }

    func testOhneGewicht() {
        XCTAssertTrue(EssenZielDetailLogik.ohneGewicht(eingabe: "", gespeichert: nil))
        XCTAssertFalse(EssenZielDetailLogik.ohneGewicht(eingabe: "", gespeichert: 70))
        XCTAssertFalse(EssenZielDetailLogik.ohneGewicht(eingabe: "70", gespeichert: nil))
    }

    func testEigeneWerteNurWennEingerichtetUndAbweichend() {
        var z = ErnaehrungsZiele()
        XCTAssertFalse(EssenZielDetailLogik.eigeneWerteAn(z, kg: 75))
        z = ErnaehrungLogik.berechnet(z, kg: 75)
        z.eingerichtet = true
        XCTAssertFalse(EssenZielDetailLogik.eigeneWerteAn(z, kg: 75))
        z.kcal += 200
        XCTAssertTrue(EssenZielDetailLogik.eigeneWerteAn(z, kg: 75))
    }

    func testZuSichernBerechnetOderEigen() {
        var z = ErnaehrungsZiele()
        z.kcal = 1234
        XCTAssertEqual(EssenZielDetailLogik.zuSichern(z, eigeneWerte: true, kg: 75).kcal, 1234)
        XCTAssertEqual(EssenZielDetailLogik.zuSichern(z, eigeneWerte: false, kg: 75).kcal, ErnaehrungLogik.berechnet(z, kg: 75).kcal)
    }

    func testGewichtZumSchreiben() {
        XCTAssertNil(EssenZielDetailLogik.gewichtZumSchreiben(eingabe: "78,4", gespeichert: 78.4))
        XCTAssertEqual(EssenZielDetailLogik.gewichtZumSchreiben(eingabe: "78,9", gespeichert: 78.4), 789)
        XCTAssertEqual(EssenZielDetailLogik.gewichtZumSchreiben(eingabe: "70", gespeichert: nil), 700)
        XCTAssertNil(EssenZielDetailLogik.gewichtZumSchreiben(eingabe: "", gespeichert: 70))
    }

    func testExtraTageBitmaske() {
        var maske = 0
        maske = EssenZielDetailLogik.extraTageUmgeschaltet(maske, wochentag: 6)
        maske = EssenZielDetailLogik.extraTageUmgeschaltet(maske, wochentag: 7)
        XCTAssertEqual(maske, 0b1100000)
        XCTAssertEqual(EssenZielDetailLogik.tageText(maske), "Samstag, Sonntag")
        XCTAssertEqual(EssenZielDetailLogik.extraTageUmgeschaltet(maske, wochentag: 6), 0b1000000)
        XCTAssertEqual(EssenZielDetailLogik.extraTageUmgeschaltet(maske, wochentag: 0), maske)
        XCTAssertEqual(EssenZielDetailLogik.extraTageUmgeschaltet(maske, wochentag: 8), maske)
        XCTAssertEqual(EssenZielDetailLogik.tageText(0), "kein Tag")
    }

    func testExtraText() {
        XCTAssertEqual(EssenZielDetailLogik.extraText(300), "+300 kcal")
        XCTAssertEqual(EssenZielDetailLogik.extraText(-200), "-200 kcal")
        XCTAssertEqual(EssenZielDetailLogik.extraText(0), "+0 kcal")
    }

    func testFlexibleTageRechnenMakrosMit() {
        var z = ErnaehrungsZiele()
        z.extraKcal = 300
        z.extraTage = EssenZielDetailLogik.extraTageUmgeschaltet(0, wochentag: Datum.wochentag("2026-10-31"))
        XCTAssertEqual(z.fuer(tag: "2026-10-31").kcal, z.kcal + 300)
    }
}
