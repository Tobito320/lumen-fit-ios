import XCTest
@testable import LumenFit

final class RegelmaessigkeitTests: XCTestCase {
    /// Nächte mit Aufwachtag ab `ab` und den Einschlafzeiten (Stunde, Minute).
    private func naechte(_ betten: [(Int, Int)], ab: String = "2026-09-10") -> [SchlafNacht] {
        betten.enumerated().map { SchlafTestBau.nacht(Datum.addTage(ab, $0.offset), bett: $0.element) }
    }

    func testGleicheBettzeitIstHundert() {
        let e = Regelmaessigkeit.berechne(naechte: naechte(Array(repeating: (23, 0), count: 6)), heute: "2026-09-15")
        XCTAssertEqual(e?.score, 100)
        XCTAssertEqual(e?.streuungMinuten, 0)
        XCTAssertEqual(e?.typischeBettzeit, 23 * 60)
        XCTAssertEqual(e?.stufe, .sehrGleichmaessig)
        XCTAssertEqual(e?.satz, "Du schläfst meist gegen 23:00 ein, mal etwa 0 Minuten früher oder später.")
    }

    func testMitternachtIstKeinSprung() {
        // 23:30 und 00:30 liegen eine Stunde auseinander, nicht 23.
        let e = Regelmaessigkeit.berechne(naechte: naechte([(23, 30), (0, 30), (23, 30), (0, 30), (23, 30), (0, 30)]), heute: "2026-09-15")
        XCTAssertEqual(e?.streuungMinuten, 30)
        XCTAssertEqual(e?.typischeBettzeit, 24 * 60, "Mitte von 23:30 und 00:30 ist Mitternacht")
        XCTAssertEqual(SchlafFormat.uhrzeit(skala: e?.typischeBettzeit ?? 0), "00:00")
        XCTAssertEqual(e?.score, 67)
        XCTAssertEqual(e?.stufe, .gleichmaessig)
    }

    func testStarkeStreuungGibtNiedrigenWertUndRuhigenText() {
        let e = Regelmaessigkeit.berechne(naechte: naechte([(21, 0), (1, 30), (22, 0), (2, 0), (23, 0), (0, 0)]), heute: "2026-09-15")
        XCTAssertNotNil(e)
        XCTAssertLessThan(e?.score ?? 100, 40)
        XCTAssertEqual(e?.stufe, .wechselhaft)
        XCTAssertEqual(Regelmaessigkeit.Stufe.wechselhaft.name, "Jeden Abend anders", "kein Vorwurf im Text")
    }

    func testUnterFuenfNaechtenZuWenigDaten() {
        XCTAssertNil(Regelmaessigkeit.berechne(naechte: naechte(Array(repeating: (23, 0), count: 4)), heute: "2026-09-13"))
    }

    func testNurDieLetzten14Tage() {
        // Alte, wilde Nächte vor dem Fenster zählen nicht.
        let alt = naechte([(20, 0), (3, 0), (21, 0), (4, 0), (22, 0)], ab: "2026-08-01")
        let neu = naechte(Array(repeating: (23, 0), count: 5), ab: "2026-09-11")
        let e = Regelmaessigkeit.berechne(naechte: alt + neu, heute: "2026-09-15")
        XCTAssertEqual(e?.naechte, 5)
        XCTAssertEqual(e?.score, 100)
    }

    func testStufenGrenzen() {
        XCTAssertEqual(Regelmaessigkeit.Ergebnis(score: 80, streuungMinuten: 0, typischeBettzeit: 0, naechte: 5).stufe, .sehrGleichmaessig)
        XCTAssertEqual(Regelmaessigkeit.Ergebnis(score: 79, streuungMinuten: 0, typischeBettzeit: 0, naechte: 5).stufe, .gleichmaessig)
        XCTAssertEqual(Regelmaessigkeit.Ergebnis(score: 60, streuungMinuten: 0, typischeBettzeit: 0, naechte: 5).stufe, .gleichmaessig)
        XCTAssertEqual(Regelmaessigkeit.Ergebnis(score: 59, streuungMinuten: 0, typischeBettzeit: 0, naechte: 5).stufe, .schwankend)
        XCTAssertEqual(Regelmaessigkeit.Ergebnis(score: 40, streuungMinuten: 0, typischeBettzeit: 0, naechte: 5).stufe, .schwankend)
        XCTAssertEqual(Regelmaessigkeit.Ergebnis(score: 39, streuungMinuten: 0, typischeBettzeit: 0, naechte: 5).stufe, .wechselhaft)
    }

    func testBettzeitUeberDieZeitumstellungZeigtDieWanduhr() {
        // Die Nacht auf den 25.10.2026 ist eine Stunde länger, die Bettzeit 23:00 bleibt 23:00.
        let n = naechte(Array(repeating: (23, 0), count: 6), ab: "2026-10-22")
        XCTAssertEqual(Regelmaessigkeit.berechne(naechte: n, heute: "2026-10-27")?.streuungMinuten, 0)
    }
}
