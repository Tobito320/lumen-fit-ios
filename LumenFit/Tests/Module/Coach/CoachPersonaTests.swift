import XCTest
@testable import LumenFit

/// Die Tonregeln des Coachs sind Tests (Idee 63, 70): schwere Tage, Beschwerden, fehlende Daten, Anweisung fürs Modell.
final class CoachPersonaTests: XCTestCase {
    private func kontext(schlaf: Int? = 450, bereitschaft: Int? = 70, stimmung: LumiStimmung = .bereit) -> CoachKontext {
        CoachTestBau.kontext(bereitschaft: bereitschaft, schlafMinuten: schlaf, stimmung: stimmung)
    }

    func testSchwererTagBeiWenigSchlafNiedrigerBereitschaftOderMuedeStimmung() {
        XCTAssertFalse(CoachPersona.schwererTag(kontext()))
        XCTAssertTrue(CoachPersona.schwererTag(kontext(schlaf: 359)))
        XCTAssertFalse(CoachPersona.schwererTag(kontext(schlaf: 360)))
        XCTAssertTrue(CoachPersona.schwererTag(kontext(bereitschaft: 39)))
        XCTAssertFalse(CoachPersona.schwererTag(kontext(bereitschaft: 40)))
        XCTAssertTrue(CoachPersona.schwererTag(kontext(stimmung: .muede)))
        XCTAssertFalse(CoachPersona.schwererTag(kontext(schlaf: nil, bereitschaft: nil)), "ohne Zahlen gilt kein schwerer Tag")
    }

    func testBeschwerdenWerdenErkannt() {
        for frage in ["Mein Knie tut weh", "Ich habe Schmerzen im Rücken", "Mir ist schwindelig, Schwindel seit gestern", "Kribbeln im Arm",
                      "Ich habe Atemnot beim Laufen"] {
            XCTAssertTrue(CoachPersona.istBeschwerde(frage), frage)
        }
        for frage in ["Wie läuft mein Training?", "Was soll ich heute essen?", "Tagesbericht"] {
            XCTAssertFalse(CoachPersona.istBeschwerde(frage), frage)
        }
    }

    func testFehlendeDatenNennenWasFehlt() {
        let leer = CoachTestBau.kontext(bereitschaft: nil, schlafMinuten: nil, schritte: nil, letztesTraining: nil)
        XCTAssertEqual(CoachPersona.fehlendeDaten(frage: "Wie habe ich geschlafen?", kontext: leer), [.schlaf])
        XCTAssertEqual(CoachPersona.fehlendeDaten(frage: "Wie viele Schritte bin ich gelaufen?", kontext: leer), [.schritte])
        XCTAssertEqual(CoachPersona.fehlendeDaten(frage: "Wie läuft mein Training?", kontext: leer), [.training])
        XCTAssertEqual(CoachPersona.fehlendeDaten(frage: "Wie fühle ich mich?", kontext: leer), [.schlaf])
        XCTAssertTrue(CoachPersona.fehlendeDaten(frage: "Wie fühle ich mich?", kontext: CoachTestBau.kontext(schlafMinuten: nil)).isEmpty, "Bereitschaft reicht fürs Gefühl")
        XCTAssertTrue(CoachPersona.fehlendeDaten(frage: "Wie habe ich geschlafen?", kontext: CoachTestBau.kontext()).isEmpty)
    }

    func testAnweisungNenntDieRegeln() {
        let text = CoachPersona.anweisung.lowercased()
        for teil in ["per du", "höchstens drei kurze sätze", "echte zahlen", "nie, dass du eine ki", "keine diagnosen", "ärztin", "schweren tagen", "keine emojis"] {
            XCTAssertTrue(text.contains(teil), "Anweisung fehlt: \(teil)")
        }
    }

    func testFehlerTextIstRuhigOhneFehlerwort() {
        XCTAssertEqual(CoachPersona.fehlerText, "Gerade nicht erreichbar, ich merke mir deine Frage.")
        let klein = CoachPersona.fehlerText.lowercased()
        for wort in ["error", "fehler", "exception", "nil", "code"] { XCTAssertFalse(klein.contains(wort), wort) }
    }

    func testDieRegelnLassenSichNichtLeerraeumen() {
        XCTAssertEqual(CoachPersona.maxSaetze, 3)
        XCTAssertEqual(CoachPersona.maxFragen, 1)
        XCTAssertFalse(CoachPersona.alsKI.isEmpty)
        XCTAssertFalse(CoachPersona.diagnosen.isEmpty)
        XCTAssertFalse(CoachPersona.belehrend.isEmpty)
        XCTAssertFalse(CoachPersona.druck.isEmpty)
    }
}
