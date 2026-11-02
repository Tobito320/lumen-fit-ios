import XCTest
@testable import LumenFit

final class EssenTagebuchLogikTests: XCTestCase {
    func testTitelMitGesternUndMorgen() {
        XCTAssertEqual(EssenTagebuchLogik.titel(tag: "2026-10-29", heute: "2026-10-29"), "Heute")
        XCTAssertEqual(EssenTagebuchLogik.titel(tag: "2026-10-28", heute: "2026-10-29"), "Gestern")
        XCTAssertEqual(EssenTagebuchLogik.titel(tag: "2026-10-30", heute: "2026-10-29"), "Morgen")
        XCTAssertEqual(EssenTagebuchLogik.titel(tag: "2026-10-20", heute: "2026-10-29"), Datum.anzeige("2026-10-20"))
    }

    func testLiterMitKomma() {
        XCTAssertEqual(EssenTagebuchLogik.liter(1750), "1,75 l")
        XCTAssertEqual(EssenTagebuchLogik.liter(2000), "2 l")
        XCTAssertEqual(EssenTagebuchLogik.liter(250), "0,25 l")
        XCTAssertEqual(EssenTagebuchLogik.liter(0), "0 l")
    }

    func testGlasRasterWaechstUeberDasZiel() {
        XCTAssertEqual(EssenTagebuchLogik.glasAnzahl(ziel: 8, voll: 3), 8)
        XCTAssertEqual(EssenTagebuchLogik.glasAnzahl(ziel: 8, voll: 8), 9)
        XCTAssertEqual(EssenTagebuchLogik.glasAnzahl(ziel: 8, voll: 8, bearbeitbar: false), 8)
    }

    func testTippAufVollesGlasGehtZurueck() {
        XCTAssertEqual(EssenTagebuchLogik.glaeserNachTipp(index: 2, voll: 5), 2)
        XCTAssertEqual(EssenTagebuchLogik.glaeserNachTipp(index: 5, voll: 5), 6)
        XCTAssertEqual(EssenTagebuchLogik.glaeserNachTipp(index: 0, voll: 1), 0)
    }

    func testRichtwertUndAnteil() {
        XCTAssertEqual(EssenTagebuchLogik.richtwert(.mittag, zielKcal: 2000), 700)
        XCTAssertEqual(EssenTagebuchLogik.anteil(ist: 350, soll: 700), 0.5, accuracy: 0.0001)
        XCTAssertEqual(EssenTagebuchLogik.anteil(ist: 900, soll: 700), 1)
        XCTAssertEqual(EssenTagebuchLogik.anteil(ist: 10, soll: 0), 0)
    }

    func testGewichtTexte() {
        XCTAssertEqual(EssenTagebuchLogik.gewichtText(zehntel: nil), "–")
        XCTAssertEqual(EssenTagebuchLogik.gewichtText(zehntel: 805), "80,5 kg")
        XCTAssertEqual(EssenTagebuchLogik.gewichtUnterzeile(datum: nil, tag: "2026-10-29"), "Noch nicht eingetragen")
        XCTAssertEqual(EssenTagebuchLogik.gewichtUnterzeile(datum: "2026-10-29", tag: "2026-10-29"), "An diesem Tag eingetragen")
        XCTAssertEqual(EssenTagebuchLogik.gewichtUnterzeile(datum: "2026-10-03", tag: "2026-10-29"), "Zuletzt am 03.10.")
    }

    func testGewichtSchrittBegrenzt() {
        XCTAssertEqual(EssenTagebuchLogik.gewichtNach(zehntel: 800, schritt: 1), 801)
        XCTAssertEqual(EssenTagebuchLogik.gewichtNach(zehntel: 300, schritt: -1), 300)
        XCTAssertEqual(EssenTagebuchLogik.gewichtNach(zehntel: 2499, schritt: 1), 2499)
    }
}
