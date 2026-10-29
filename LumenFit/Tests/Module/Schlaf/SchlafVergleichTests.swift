import XCTest
@testable import LumenFit

/// Aus Lovea `SchlafVergleichTests`: Schätzung wird zum Band, Uhr zu Health. Nicht mitgenommen sind `testSchaetzungNurEinmalJeNacht` und
/// `testSpeichernUndLaden`: es gibt keine eigene Schätzung mehr und nichts mehr in UserDefaults, der Verlauf wird aus Health und Ops gerechnet.
final class SchlafVergleichTests: XCTestCase {
    private func zeit(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        SchlafTestBau.zeit(String(format: "2026-09-%02d", tag), stunde, minute)
    }

    private func wert(_ von: Date, _ bis: Date, _ minuten: Int) -> SchlafWert {
        SchlafWert(von: von, bis: bis, minuten: minuten)
    }

    /// Nacht Nummer `nr` (Aufwachtag 10 + `nr` im September): Health 23:00 bis 07:00 mit 420 min Schlaf; das Band liegt `vonPlus` und `bisPlus` min daneben, `minutenPlus` länger.
    private func nacht(_ nr: Int, vonPlus: Int = 0, bisPlus: Int = 0, minutenPlus: Int = 0, fertig: Bool = true) -> SchlafVergleichNacht {
        let tag = nr + 10
        let health = wert(zeit(tag - 1, 23), zeit(tag, 7), 420)
        let band = wert(health.von.addingTimeInterval(Double(vonPlus) * 60), health.bis.addingTimeInterval(Double(bisPlus) * 60), 420 + minutenPlus)
        return SchlafVergleichNacht(tag: "2026-09-\(String(format: "%02d", tag))", band: band, health: health, fertig: fertig)
    }

    // MARK: - Abweichung

    func testAbweichungBandMinusHealth() {
        let a = SchlafVergleich.abweichung(nacht(10, vonPlus: 12, bisPlus: -5, minutenPlus: 30))
        XCTAssertEqual(a, SchlafAbweichung(einschlafen: 12, aufwachen: -5, dauer: 30))
    }

    func testAbweichungUeberMitternachtSindZwanzigMinuten() {
        let n = SchlafVergleichNacht(tag: "2026-09-10", band: wert(zeit(10, 0, 10), zeit(10, 7), 410),
                                     health: wert(zeit(9, 23, 50), zeit(10, 7), 420), fertig: true)
        XCTAssertEqual(SchlafVergleich.abweichung(n)?.einschlafen, 20)
    }

    func testAbweichungOhneHealthIstNil() {
        var n = nacht(10)
        n.health = nil
        XCTAssertNil(SchlafVergleich.abweichung(n))
    }

    func testAbweichungUeberDieZeitumstellungRechnetMitDate() {
        // 24. auf 25.10.2026 ist eine Stunde länger; das Band liegt 10 Minuten später, das darf kein Stunden-Sprung werden.
        let health = wert(SchlafTestBau.zeit("2026-10-24", 23), SchlafTestBau.zeit("2026-10-25", 7), 540)
        let band = wert(SchlafTestBau.zeit("2026-10-24", 23, 10), SchlafTestBau.zeit("2026-10-25", 7), 530)
        let a = SchlafVergleich.abweichung(SchlafVergleichNacht(tag: "2026-10-25", band: band, health: health, fertig: true))
        XCTAssertEqual(a, SchlafAbweichung(einschlafen: 10, aufwachen: 0, dauer: -10))
    }

    func testAbstandText() {
        XCTAssertEqual(SchlafVergleich.abstand(12, mehr: "später", weniger: "früher"), "12 min später")
        XCTAssertEqual(SchlafVergleich.abstand(-65, mehr: "später", weniger: "früher"), "1 h 05 min früher")
        XCTAssertEqual(SchlafVergleich.abstand(0, mehr: "später", weniger: "früher"), "gleich")
    }

    // MARK: - Abgleich

    func testNurEinWertGiltEinfach() {
        var ohneHealth = nacht(10)
        ohneHealth.health = nil
        XCTAssertEqual(SchlafVergleich.abgleich(ohneHealth, verlauf: [])?.grund, .nurBand)
        var ohneBand = nacht(10)
        ohneBand.band = nil
        XCTAssertEqual(SchlafVergleich.abgleich(ohneBand, verlauf: [])?.quelle, .health)
        XCTAssertNil(SchlafVergleich.abgleich(SchlafVergleichNacht(tag: "2026-09-10", band: nil, health: nil, fertig: true), verlauf: []))
    }

    func testVierNaechteGebenNochKeinenAbgleich() {
        let verlauf = (1...4).map { nacht($0) }
        let urteil = SchlafVergleich.abgleich(verlauf[3], verlauf: verlauf)
        XCTAssertEqual(urteil?.grund, .zuWenig(naechte: 4))
        XCTAssertEqual(urteil?.quelle, .health)
    }

    func testFuenfNaechteGebenAbgleich() {
        let verlauf = (1...5).map { nacht($0) }
        XCTAssertEqual(SchlafVergleich.abgleich(verlauf[4], verlauf: verlauf)?.quelle, .gemischt)
    }

    func testNichtFertigeNaechteZaehlenNichtMit() {
        let verlauf = (1...4).map { nacht($0) } + [nacht(5, fertig: false)]
        XCTAssertEqual(SchlafVergleich.abgleich(verlauf[0], verlauf: verlauf)?.grund, .zuWenig(naechte: 4))
    }

    func testGleichmaessigeAbweichungWirdKorrigiertUndGemischt() {
        // Das Band liegt immer 20 min zu spät, die Dauer stimmt: Streuung 0, Gewicht des Bands 50 %.
        let verlauf = (1...4).map { nacht($0, vonPlus: 20, bisPlus: 20) }
        let heute = nacht(5, vonPlus: 40, bisPlus: 20, minutenPlus: 20)
        let urteil = SchlafVergleich.abgleich(heute, verlauf: verlauf + [heute])
        XCTAssertEqual(urteil?.grund, .gemischt(bandProzent: 50))
        // Korrigiert 20 min nach Health, Mittel mit Health: 10 min nach Health.
        XCTAssertEqual(urteil?.wert.von, zeit(14, 23, 10))
        XCTAssertEqual(urteil?.wert.bis, zeit(15, 7))
        XCTAssertEqual(urteil?.wert.minuten, 430)
    }

    func testStreuungSenktDasGewichtDesBands() {
        // Dauer-Abweichungen -10, 0, 10, 20: Median 5, Streuung 10, Gewicht 0,5 * 30 / 40 = 37,5 %.
        let verlauf = [nacht(1, minutenPlus: -10), nacht(2), nacht(3, minutenPlus: 10), nacht(4, minutenPlus: 20)]
        let heute = nacht(5, minutenPlus: 5)
        XCTAssertEqual(SchlafVergleich.abgleich(heute, verlauf: verlauf + [heute])?.grund, .gemischt(bandProzent: 38))
    }

    func testAusreisserGiltHealth() {
        let verlauf = (1...4).map { nacht($0) }
        let heute = nacht(5, minutenPlus: 120)
        let urteil = SchlafVergleich.abgleich(heute, verlauf: verlauf + [heute])
        XCTAssertEqual(urteil?.grund, .ausreisser)
        XCTAssertEqual(urteil?.quelle, .health)
        XCTAssertEqual(urteil?.wert.minuten, 420)
    }

    func testUhrNichtGetragenGiltDasBand() {
        let verlauf = (1...4).map { nacht($0) }
        var heute = nacht(5, minutenPlus: 0)
        heute.health = wert(zeit(5, 5), zeit(5, 7), 100)
        let urteil = SchlafVergleich.abgleich(heute, verlauf: verlauf + [heute])
        XCTAssertEqual(urteil?.grund, .ausreisser)
        XCTAssertEqual(urteil?.quelle, .band)
        XCTAssertEqual(urteil?.wert.minuten, 420)
    }

    func testDieNachtSelbstVerfaelschtDenVerlaufNicht() {
        // Steht die Nacht schon im Verlauf, wird sie dort ausgelassen: sonst zöge sie ihren eigenen Ausreißer in den Median.
        let verlauf = (1...4).map { nacht($0) } + [nacht(5, minutenPlus: 120)]
        XCTAssertEqual(SchlafVergleich.abgleich(verlauf[4], verlauf: verlauf)?.grund, .ausreisser)
    }

    func testSaetze() {
        XCTAssertEqual(SchlafVergleich.satz(SchlafUrteil(quelle: .health, wert: wert(zeit(10, 1), zeit(10, 7), 300), grund: .nurHealth)),
                       "Kein Band für diese Nacht. Es zählt Health.")
        XCTAssertEqual(SchlafVergleich.satz(SchlafUrteil(quelle: .health, wert: wert(zeit(10, 1), zeit(10, 7), 300), grund: .zuWenig(naechte: 2))),
                       "Abgleich ab 5 Nächten mit Band und Health, bisher 2. Bis dahin zählt Health.")
        XCTAssertEqual(SchlafVergleich.satz(SchlafUrteil(quelle: .gemischt, wert: wert(zeit(10, 1), zeit(10, 7), 300), grund: .gemischt(bandProzent: 38))),
                       "Gemischt: 62 % Health, 38 % Band, das Band um seine übliche Abweichung korrigiert.")
    }

    // MARK: - Liste

    func testEinsetzenUeberschreibtNieMitNil() {
        let alt = nacht(10)
        var nurHealth = SchlafVergleichNacht(tag: alt.tag, band: nil, health: wert(zeit(9, 23, 30), zeit(10, 7), 400), fertig: false)
        var liste = SchlafVergleich.einsetzen([alt], nurHealth)
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste[0].health?.minuten, 400)
        XCTAssertEqual(liste[0].band, alt.band)
        XCTAssertTrue(liste[0].fertig)
        nurHealth.health = nil
        liste = SchlafVergleich.einsetzen(liste, nurHealth)
        XCTAssertEqual(liste[0].health?.minuten, 400)
    }

    func testEinsetzenSortiertUndBehaeltDieLetzten() {
        var liste: [SchlafVergleichNacht] = []
        for t in (1...28).reversed() {
            for m in [7, 8, 9] {
                liste = SchlafVergleich.einsetzen(liste, SchlafVergleichNacht(tag: "2026-0\(m)-\(String(format: "%02d", t))", band: nil, health: nil, fertig: false))
            }
        }
        XCTAssertEqual(liste.count, SchlafVergleich.behalten)
        XCTAssertEqual(liste.last?.tag, "2026-09-28")
        XCTAssertEqual(liste.map(\.tag), liste.map(\.tag).sorted())
        XCTAssertEqual(liste.first?.tag, "2026-07-25")
    }

    // MARK: - Verlauf aus Health und Band

    func testVerlaufPaartDieNaechteJeTag() {
        let health = SchlafTestBau.nacht("2026-09-22", minuten: 420, phasen: true)
        let nurHealth = SchlafTestBau.nacht("2026-09-21", minuten: 400)
        let bandOp = BandSchlafOp(tag: "2026-09-22", start: health.von.addingTimeInterval(600), ende: health.bis, phasen: health.abschnitte)
        let nurBand = BandSchlafOp(tag: "2026-09-23", start: SchlafTestBau.zeit("2026-09-22", 23), ende: SchlafTestBau.zeit("2026-09-23", 7), phasen: [])
        let liste = SchlafVergleich.verlauf(health: [health.tag: health, nurHealth.tag: nurHealth], band: [bandOp, nurBand], heute: "2026-09-23")
        XCTAssertEqual(liste.map(\.tag), ["2026-09-21", "2026-09-22", "2026-09-23"])
        XCTAssertNil(liste[0].band)
        XCTAssertNotNil(liste[1].band)
        XCTAssertNotNil(liste[1].health)
        XCTAssertEqual(SchlafVergleich.abweichung(liste[1])?.einschlafen, 10)
        XCTAssertNil(liste[2].health)
        XCTAssertEqual(liste.map(\.fertig), [true, true, false], "heute ist noch nicht fertig")
    }

    func testVerlaufLetzteBandOpJeTagGewinnt() {
        let von = SchlafTestBau.zeit("2026-09-21", 23)
        let alt = BandSchlafOp(tag: "2026-09-22", start: von, ende: SchlafTestBau.zeit("2026-09-22", 5), phasen: [])
        let neu = BandSchlafOp(tag: "2026-09-22", start: von, ende: SchlafTestBau.zeit("2026-09-22", 7), phasen: [])
        let liste = SchlafVergleich.verlauf(health: [:], band: [alt, neu], heute: "2026-09-25")
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.band?.minuten, 480)
    }
}
