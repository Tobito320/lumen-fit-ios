import XCTest
@testable import LumenFit

/// Die Prüfung jeder Antwort gegen die Persona-Regeln (Länge, Anrede, Verbotsliste, Arzthinweis, Rückfrage).
final class CoachAntwortPruefungTests: XCTestCase {
    private let normal = CoachTestBau.kontext()
    private let leer = CoachTestBau.kontext(bereitschaft: nil, schlafMinuten: nil, schritte: nil, letztesTraining: nil)

    private func fehler(_ text: String, frage: String = "Tagesbericht", kontext: CoachKontext? = nil) -> [CoachAntwortPruefung.Verstoss] {
        CoachAntwortPruefung.pruefe(text, frage: frage, kontext: kontext ?? normal)
    }

    // MARK: - Sätze

    func testSaetzeTrennenNurAnSatzzeichenMitLeerraum() {
        XCTAssertEqual(CoachAntwortPruefung.saetze("Du hast 8.200 Schritte. Das sind 7,5 km! Gut?"), ["Du hast 8.200 Schritte.", "Das sind 7,5 km!", "Gut?"])
        XCTAssertEqual(CoachAntwortPruefung.saetze("Ohne Punkt"), ["Ohne Punkt"])
        XCTAssertTrue(CoachAntwortPruefung.saetze("  ").isEmpty)
    }

    // MARK: - Länge

    func testDreiSaetzePlusEineFrageSindErlaubt() {
        XCTAssertEqual(fehler("Du hast 6.200 Schritte. Dein Ziel sind 10.000. Ein kurzer Spaziergang hilft. Magst du heute noch raus?"), [])
    }

    func testVierSaetzeSindZuViele() {
        XCTAssertEqual(fehler("Eins. Zwei. Drei. Vier."), [.zuVieleSaetze])
    }

    func testZweiFragenSindZuViele() {
        XCTAssertEqual(fehler("Wie war dein Tag? Wie war deine Nacht?"), [.zuVieleFragen])
    }

    func testLangerSatzUndLangerTextWerdenGemeldet() {
        let langerSatz = Array(repeating: "wort", count: 26).joined(separator: " ") + "."
        XCTAssertTrue(fehler(langerSatz).contains(.satzZuLang))
        let langerText = (0..<3).map { _ in Array(repeating: "wortwort", count: 24).joined(separator: " ") + "." }.joined(separator: " ")
        XCTAssertTrue(fehler(langerText).contains(.zuLang))
    }

    func testLeereAntwortIstEinVerstoss() {
        XCTAssertEqual(fehler("  \n "), [.leer])
    }

    // MARK: - Anrede, KI, Diagnose, Belehrung

    func testSieAnredeWirdGemeldetDuNicht() {
        XCTAssertEqual(fehler("Wie geht es Ihnen heute?"), [.sieAnrede])
        XCTAssertEqual(fehler("Haben Sie gut geschlafen?"), [.sieAnrede])
        XCTAssertEqual(fehler("Hast du gut geschlafen?"), [])
        XCTAssertEqual(fehler("Sie sind heute weit gelaufen."), [], "Sie am Satzanfang kann auch sie heißen und ist ohne Ihnen kein Beleg")
    }

    func testAlsKIWirdGemeldet() {
        XCTAssertEqual(fehler("Als KI kann ich dir sagen, dass das gut ist."), [.alsKI])
        XCTAssertEqual(fehler("Ich bin ein Sprachmodell und kenne dich."), [.alsKI])
    }

    func testDiagnosenWerdenGemeldet() {
        XCTAssertEqual(fehler("Das klingt nach einer Zerrung."), [.diagnose])
        XCTAssertEqual(fehler("Du hast vermutlich zu wenig Schlaf."), [.diagnose])
        XCTAssertEqual(fehler("Meine Diagnose ist klar."), [.diagnose])
    }

    func testBelehrungUndVorwurfWerdenGemeldet() {
        XCTAssertEqual(fehler("Du musst mehr trainieren."), [.belehrend])
        XCTAssertEqual(fehler("Du hättest früher ins Bett gehen sollen."), [.belehrend])
        XCTAssertEqual(fehler("Das ist nur eine faule Ausrede."), [.belehrend])
    }

    func testDruckGiltNurAnSchwerenTagen() {
        let schwer = CoachTestBau.kontext(schlafMinuten: 300)
        XCTAssertEqual(fehler("Heute heißt es durchziehen.", kontext: schwer), [.druckAmSchwerenTag])
        XCTAssertEqual(fehler("Heute heißt es durchziehen.", kontext: normal), [])
    }

    func testEmojiWirdGemeldet() {
        XCTAssertEqual(fehler("Super gemacht \u{1F4AA}"), [.emoji])
    }

    // MARK: - Beschwerden und fehlende Daten

    func testBeschwerdeBrauchtDenArztHinweis() {
        XCTAssertEqual(fehler("Das tut mir leid. Ruh dich aus.", frage: "Mein Knie tut weh"), [.arztFehlt])
        XCTAssertEqual(fehler("Das tut mir leid. Sprich dazu bitte mit deiner Ärztin oder deinem Arzt.", frage: "Mein Knie tut weh"), [])
    }

    func testFehlendeDatenBrauchenEineRueckfrage() {
        XCTAssertEqual(fehler("Du hast 7 h geschlafen.", frage: "Wie habe ich geschlafen?", kontext: leer), [.rueckfrageFehlt])
        XCTAssertEqual(fehler("Dazu fehlen mir deine Schlafdaten. Wie lange hast du geschlafen?", frage: "Wie habe ich geschlafen?", kontext: leer), [])
        XCTAssertEqual(fehler("Du hast 7 h 30 min geschlafen.", frage: "Wie habe ich geschlafen?", kontext: normal), [])
    }

    func testIstFasstDieListeZusammen() {
        XCTAssertTrue(CoachAntwortPruefung.ist("Gut gemacht.", frage: "Tagesbericht", kontext: normal))
        XCTAssertFalse(CoachAntwortPruefung.ist("Als KI sage ich: gut.", frage: "Tagesbericht", kontext: normal))
    }
}
