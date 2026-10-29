import XCTest
@testable import LumenFit

final class BereitScoreTests: XCTestCase {
    /// 29 Tage im Wechsel 48 und 52: Schnitt 50, Streuung 2 (die Streuung hat einen Boden von 8 % des Schnitts, also 4).
    private var hrvBasis: [Double] { (0..<29).map { $0 % 2 == 0 ? 48 : 52 } }
    private var pulsBasis: [Double] { [Double](repeating: 55, count: 29) }
    private func last(_ neu: Double, _ ueblich: Double) -> [Double?] { [Double?](repeating: neu, count: 3) + [Double?](repeating: ueblich, count: 28) }

    private func voll() -> BereitScore.Eingabe {
        BereitScore.Eingabe(schlafMinuten: 480, schlafZiel: 480, hrv: 50, hrvBasis: hrvBasis, ruhepuls: 55, ruhepulsBasis: pulsBasis,
                            last: last(200, 200))
    }

    // MARK: Volle Daten

    func testVolleDatenRechnenDieDreiTeile() {
        let e = BereitScore.rechnen(voll())
        // Schlaf 100, Erholung 75 (HRV und Ruhepuls genau im Schnitt), Belastung 100: 0,4 * 100 + 0,4 * 75 + 0,2 * 100 = 90.
        XCTAssertEqual(e.punkte, 90)
        XCTAssertEqual(e.stufe, .bereit)
        XCTAssertEqual(e.teile.map(\.art), [.schlaf, .erholung, .belastung])
        XCTAssertEqual(e.fehlend, [])
        XCTAssertEqual(e.teil(.erholung)?.wert ?? 0, 75, accuracy: 0.001)
        XCTAssertTrue(e.satz.hasPrefix("Gut erholt."))
        XCTAssertFalse(e.satz.contains("gerechnet"), "nichts fehlt, also steht nichts davon im Satz")
    }

    func testSchlechteWerteSenkenDieZahlUndNennenDenGrund() {
        var eingabe = voll()
        eingabe.schlafMinuten = 300                  // 0,625 im Quadrat = 39
        eingabe.hrv = 38                             // 3 Standardabweichungen (Boden 4) unter dem Schnitt: 75 - 60 = 15
        eingabe.ruhepuls = 61                        // 6 Schläge über dem Schnitt: 75 - 36 = 39
        eingabe.last = last(500, 200)                // 2,5-faches: 40 - 20 = 20
        let e = BereitScore.rechnen(eingabe)
        XCTAssertEqual(e.stufe, .schonen)
        XCTAssertLessThan(e.punkte ?? 100, BereitScore.normalAb)
        XCTAssertTrue(e.satz.hasPrefix("Dein Körper will Ruhe."))
        XCTAssertTrue(e.satz.contains("Am meisten bremst"))
    }

    func testPunkteBleibenZwischenNullUndHundert() {
        var oben = voll()
        oben.hrv = 500
        oben.ruhepuls = 20
        XCTAssertLessThanOrEqual(BereitScore.rechnen(oben).punkte ?? 0, 100)
        var unten = voll()
        unten.schlafMinuten = 1
        unten.hrv = 1
        unten.ruhepuls = 200
        unten.last = last(5_000, 100)
        XCTAssertGreaterThanOrEqual(BereitScore.rechnen(unten).punkte ?? -1, 0)
    }

    // MARK: Teilweise Daten

    func testNurMitIPhoneRechnetMitSchlafUndBelastungUndNenntWasFehlt() {
        let eingabe = BereitScore.Eingabe(schlafMinuten: 360, schlafZiel: 480, last: last(400, 200))
        let e = BereitScore.rechnen(eingabe)
        // Schlaf 0,75 im Quadrat = 56,25; Belastung 2-fach = 40; gewichtet über 0,6: (0,4 * 56,25 + 0,2 * 40) / 0,6 = 50,8.
        XCTAssertEqual(e.punkte, 51)
        XCTAssertEqual(e.stufe, .normal)
        XCTAssertEqual(e.fehlend, [.erholung])
        XCTAssertTrue(e.satz.contains("Ohne Erholung gerechnet"))
        XCTAssertTrue(e.satz.contains("Apple Watch"), "der Satz sagt, woher HRV und Ruhepuls kommen")
    }

    func testNurSchlafGenugtFuerEineZahl() {
        let e = BereitScore.rechnen(BereitScore.Eingabe(schlafMinuten: 300, schlafZiel: 480))
        XCTAssertEqual(e.punkte, 39)
        XCTAssertEqual(e.stufe, .schonen)
        XCTAssertEqual(Set(e.fehlend), [.erholung, .belastung])
    }

    func testNurHRVUndRuhepulsGenuegenAuch() {
        var eingabe = voll()
        eingabe.schlafMinuten = nil
        eingabe.last = []
        let e = BereitScore.rechnen(eingabe)
        XCTAssertEqual(e.punkte, 75)
        XCTAssertEqual(Set(e.fehlend), [.schlaf, .belastung])
    }

    func testNurBelastungIstZuWenigFuerEineZahl() {
        let e = BereitScore.rechnen(BereitScore.Eingabe(last: last(100, 100)))
        XCTAssertNil(e.punkte)
        XCTAssertEqual(e.stufe, .keine)
        XCTAssertEqual(e.teile.map(\.art), [.belastung], "der Teil bleibt sichtbar, auch wenn die Zahl fehlt")
    }

    func testHRVMitZuWenigVergleichstagenFaelltAus() {
        var eingabe = voll()
        eingabe.hrvBasis = Array(hrvBasis.prefix(4))
        eingabe.ruhepulsBasis = []
        let e = BereitScore.rechnen(eingabe)
        XCTAssertNil(e.teil(.erholung))
        XCTAssertEqual(e.punkte, 100, "Schlaf 100 und Belastung 100 über das Gewicht 0,6")
    }

    func testEinzelnerRuhepulsOhneHRVZaehltAlsErholung() {
        var eingabe = voll()
        eingabe.hrv = nil
        eingabe.ruhepuls = 52                        // 3 Schläge unter dem Schnitt: 75 + 18 = 93
        let e = BereitScore.rechnen(eingabe)
        XCTAssertEqual(e.teil(.erholung)?.wert ?? 0, 93, accuracy: 0.001)
    }

    func testBelastungBrauchtSiebenVergleichstage() {
        let kurz = BereitScore.Eingabe(schlafMinuten: 480, last: [Double?](repeating: 200, count: 3 + 6))
        XCTAssertNil(BereitScore.rechnen(kurz).teil(.belastung))
        let genug = BereitScore.Eingabe(schlafMinuten: 480, last: [Double?](repeating: 200, count: 3 + 7))
        XCTAssertNotNil(BereitScore.rechnen(genug).teil(.belastung))
    }

    func testBelastungStufen() {
        func wert(_ neu: Double) -> Double { BereitScore.rechnen(BereitScore.Eingabe(schlafMinuten: 480, last: last(neu, 100))).teil(.belastung)?.wert ?? -1 }
        XCTAssertEqual(wert(100), 100, accuracy: 0.001)
        XCTAssertEqual(wert(120), 100, accuracy: 0.001, "bis 1,2-fach volle Punkte")
        XCTAssertEqual(wert(200), 40, accuracy: 0.001)
        XCTAssertEqual(wert(300), 0, accuracy: 0.001)
        XCTAssertEqual(wert(0), 100, accuracy: 0.001, "drei Ruhetage lassen volle Luft")
    }

    // MARK: Leere Daten

    func testLeereDatenGebenKeineZahlUndSagenEsDeutlich() {
        let e = BereitScore.rechnen(BereitScore.Eingabe())
        XCTAssertNil(e.punkte)
        XCTAssertEqual(e.stufe, .keine)
        XCTAssertTrue(e.teile.isEmpty)
        XCTAssertEqual(Set(e.fehlend), Set(BereitScore.Art.allCases))
        XCTAssertTrue(e.satz.hasPrefix("Noch zu wenig Daten"))
    }

    func testSchlafOhneMinutenUndOhneZielZaehltNicht() {
        XCTAssertNil(BereitScore.rechnen(BereitScore.Eingabe(schlafMinuten: 0)).teil(.schlaf))
        XCTAssertNil(BereitScore.rechnen(BereitScore.Eingabe(schlafMinuten: 400, schlafZiel: 0)).teil(.schlaf))
    }

    func testGewichteSindEins() {
        XCTAssertEqual(BereitScore.Art.allCases.reduce(0.0) { $0 + $1.gewicht }, 1, accuracy: 0.0001)
        XCTAssertFalse(BereitScore.klartext.isEmpty)
    }

    func testStundenText() {
        XCTAssertEqual(BereitScore.stunden(370), "6:10 h")
        XCTAssertEqual(BereitScore.stunden(480), "8:00 h")
    }
}
