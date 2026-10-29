import XCTest
@testable import LumenFit

/// Daumen und Merkliste (Idee 69): der Coach lernt aus Daumen runter Länge und Ton, sonst nichts.
final class CoachLernenTests: XCTestCase {
    private func antwort(_ i: Int, _ text: String, daumen: Bool?) -> CoachNachricht {
        CoachTestBau.nachricht("a\(i)", .coach, text, Date(timeIntervalSince1970: Double(i)), daumen: daumen)
    }

    private let kurz = "Gut geschlafen."
    private let lang = "Du hast sieben Stunden geschlafen und das ist ein solider Wert für deine Woche. Dazu passt deine Bereitschaft."

    func testOhneBewertungKeineVorliebe() {
        XCTAssertTrue(CoachLernen.stil([]).istLeer)
        XCTAssertTrue(CoachLernen.stil([antwort(1, lang, daumen: nil)]).istLeer)
        XCTAssertTrue(CoachLernen.stil([antwort(1, lang, daumen: true)]).istLeer, "Daumen hoch allein ändert nichts")
    }

    func testDaumenRunterBeiLangenAntwortenWollenKuerzer() {
        let stil = CoachLernen.stil([antwort(1, kurz, daumen: true), antwort(2, lang, daumen: false)])
        XCTAssertTrue(stil.kuerzer)
        XCTAssertFalse(stil.nuechtern)
        XCTAssertEqual(stil.hinweis, "Antworte noch kürzer, höchstens zwei Sätze.")
    }

    func testDaumenRunterBeiKurzenAntwortenWollenNichtKuerzer() {
        let stil = CoachLernen.stil([antwort(1, lang, daumen: true), antwort(2, kurz, daumen: false)])
        XCTAssertFalse(stil.kuerzer)
    }

    func testDaumenRunterBeiAusrufezeichenWollenNuechterner() {
        let stil = CoachLernen.stil([antwort(1, "Stark gemacht.", daumen: true), antwort(2, "Stark gemacht!", daumen: false)])
        XCTAssertTrue(stil.nuechtern)
        XCTAssertTrue(stil.hinweis.contains("ohne Ausrufezeichen"))
    }

    func testNurDieJuengstenZwanzigZaehlen() {
        var verlauf = [antwort(0, lang, daumen: false)]
        verlauf += (1...20).map { antwort($0, kurz, daumen: true) }
        XCTAssertTrue(CoachLernen.stil(verlauf).istLeer, "die alte Bewertung ist aus dem Fenster")
    }

    func testKuerzenBehaeltZweiAussagenUndDieFrage() {
        let text = "Eins ist gut. Zwei ist auch gut. Drei folgt noch. Wie geht es dir?"
        XCTAssertEqual(CoachLernen.kuerzen(text), "Eins ist gut. Zwei ist auch gut. Wie geht es dir?")
        XCTAssertEqual(CoachLernen.kuerzen("Eins ist gut. Zwei ist auch gut."), "Eins ist gut. Zwei ist auch gut.", "schon kurz")
    }

    func testKuerzenLaesstDenVerstaendnisSatzStehen() {
        let text = "Das klingt nach einem schweren Tag. Du hast sieben Stunden geschlafen. Heute zählt nur, was dir guttut."
        let kurz = CoachLernen.kuerzen(text, behalte: "Heute zählt nur, was dir guttut.")
        XCTAssertTrue(kurz.contains("Heute zählt nur, was dir guttut."))
        XCTAssertEqual(CoachAntwortPruefung.saetze(kurz).count, 2)
    }

    func testKuerzenFasstDenArztHinweisNieAn() {
        let text = "Eins ist gut. Zwei ist auch gut. Drei folgt noch. Sprich dazu bitte mit deiner Ärztin oder deinem Arzt."
        XCTAssertEqual(CoachLernen.kuerzen(text), text)
    }

    func testNuechternTauschtAusrufezeichen() {
        XCTAssertEqual(CoachLernen.nuechtern("Stark! Weiter so!"), "Stark. Weiter so.")
    }
}
