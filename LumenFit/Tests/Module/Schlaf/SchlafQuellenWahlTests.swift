import XCTest
@testable import LumenFit

final class SchlafQuellenWahlTests: XCTestCase {
    private func band(_ tag: String, von: Date, bis: Date, phasen: [SchlafAbschnitt] = []) -> BandSchlafOp {
        BandSchlafOp(tag: tag, start: von, ende: bis, phasen: phasen)
    }

    func testHealthMitPhasenIstUhrOhnePhasenIstHandy() {
        XCTAssertEqual(SchlafQuellenWahl.quelle(health: SchlafTestBau.nacht("2026-09-23", minuten: 450, phasen: true)), .uhr)
        XCTAssertEqual(SchlafQuellenWahl.quelle(health: SchlafTestBau.nacht("2026-09-23", minuten: 450)), .handy)
    }

    func testEineNachtOhneZweiteQuelleHatKeineWeiteren() {
        let n = SchlafTestBau.nacht("2026-09-23", minuten: 450, phasen: true)
        let liste = SchlafQuellenWahl.waehle(health: [n.tag: n], band: [])
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.quelle, .uhr)
        XCTAssertEqual(liste.first?.weitere, [])
        XCTAssertEqual(liste.first?.erklaerung, "Quelle: Uhr.")
    }

    func testDoppelteNachtErscheintEinmalUndPhasenSchlagenNurDauer() {
        // Das Handy kennt nur die Dauer, das Band hat Phasen: dieselbe Nacht, zählt einmal, Band gewinnt.
        let handy = SchlafTestBau.nacht("2026-09-23", minuten: 440)
        let von = SchlafTestBau.zeit("2026-09-22", 23, 10)
        let bis = SchlafTestBau.zeit("2026-09-23", 6, 40)
        let phasen = [SchlafAbschnitt(phase: .kern, von: von, bis: von.addingTimeInterval(4 * 3600)),
                      SchlafAbschnitt(phase: .tief, von: von.addingTimeInterval(4 * 3600), bis: bis)]
        let liste = SchlafQuellenWahl.waehle(health: [handy.tag: handy], band: [band("2026-09-23", von: von, bis: bis, phasen: phasen)])
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.quelle, .band)
        XCTAssertEqual(liste.first?.weitere, [.handy])
        XCTAssertEqual(liste.first?.nacht.schlafMinuten, 450)
        XCTAssertEqual(liste.first?.erklaerung, "Quelle: Band. Auch gemeldet von: Handy. Es zählt Band, weil diese Quelle die Schlafphasen kennt.")
    }

    func testBandOhnePhasenVerliertGegenUhrMitPhasen() {
        let uhr = SchlafTestBau.nacht("2026-09-23", minuten: 450, phasen: true)
        let b = band("2026-09-23", von: SchlafTestBau.zeit("2026-09-22", 23), bis: SchlafTestBau.zeit("2026-09-23", 7))
        let liste = SchlafQuellenWahl.waehle(health: [uhr.tag: uhr], band: [b])
        XCTAssertEqual(liste.first?.quelle, .uhr)
        XCTAssertEqual(liste.first?.weitere, [.band])
    }

    func testBeiGleicherGenauigkeitGiltBandVorUhrVorHandy() {
        let uhr = SchlafTestBau.nacht("2026-09-23", minuten: 450, phasen: true)
        let phasen = uhr.abschnitte
        let b = band("2026-09-23", von: uhr.von.addingTimeInterval(300), bis: uhr.bis, phasen: phasen)
        XCTAssertEqual(SchlafQuellenWahl.waehle(health: [uhr.tag: uhr], band: [b]).first?.quelle, .band)
        let handy = SchlafTestBau.nacht("2026-09-23", minuten: 450)
        let bOhne = band("2026-09-23", von: handy.von, bis: handy.bis)
        XCTAssertEqual(SchlafQuellenWahl.waehle(health: [handy.tag: handy], band: [bOhne]).first?.quelle, .band, "Band vor Handy")
    }

    func testUeberlappungOhneGleichenTagIstDieselbeNacht() {
        // Aufwachtag unterscheidet sich (Band 22.09. gebucht, Health 23.09.), die Zeiten überlappen.
        let health = SchlafTestBau.nacht("2026-09-23", minuten: 450, phasen: true)
        let b = band("2026-09-22", von: health.von.addingTimeInterval(600), bis: health.bis.addingTimeInterval(-600))
        let liste = SchlafQuellenWahl.waehle(health: [health.tag: health], band: [b])
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.quelle, .uhr)
    }

    func testVerschiedeneNaechteBleibenGetrenntUndSortiert() {
        let n1 = SchlafTestBau.nacht("2026-09-22", minuten: 400)
        let n2 = SchlafTestBau.nacht("2026-09-23", minuten: 420, phasen: true)
        let b = band("2026-09-24", von: SchlafTestBau.zeit("2026-09-23", 23), bis: SchlafTestBau.zeit("2026-09-24", 7))
        let liste = SchlafQuellenWahl.waehle(health: [n2.tag: n2, n1.tag: n1], band: [b])
        XCTAssertEqual(liste.map(\.nacht.tag), ["2026-09-22", "2026-09-23", "2026-09-24"])
        XCTAssertEqual(liste.map(\.quelle), [.handy, .uhr, .band])
    }

    func testBandJeTagGewinntDieLetzteOp() {
        let von = SchlafTestBau.zeit("2026-09-22", 23)
        let alt = band("2026-09-23", von: von, bis: SchlafTestBau.zeit("2026-09-23", 5))
        let neu = band("2026-09-23", von: von, bis: SchlafTestBau.zeit("2026-09-23", 7))
        let liste = SchlafQuellenWahl.waehle(health: [:], band: [alt, neu])
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.nacht.schlafMinuten, 480)
    }

    func testKaputteBandOpsWerdenUebersprungen() {
        let von = SchlafTestBau.zeit("2026-09-22", 23)
        XCTAssertNil(SchlafQuellenWahl.nacht(band: band("2026-09-23", von: von, bis: von)), "Ende nicht nach Beginn")
        XCTAssertNil(SchlafQuellenWahl.nacht(band: band("kaputt", von: von, bis: von.addingTimeInterval(3600))), "kaputter Tag")
        let nurWach = [SchlafAbschnitt(phase: .wach, von: von, bis: von.addingTimeInterval(3600))]
        XCTAssertNil(SchlafQuellenWahl.nacht(band: band("2026-09-23", von: von, bis: von.addingTimeInterval(3600), phasen: nurWach)), "kein Schlaf")
    }

    func testBandPhasenMitWachzeitZaehlenNurSchlaf() {
        let von = SchlafTestBau.zeit("2026-09-22", 23)
        let phasen = [SchlafAbschnitt(phase: .kern, von: von, bis: von.addingTimeInterval(3 * 3600)),
                      SchlafAbschnitt(phase: .wach, von: von.addingTimeInterval(3 * 3600), bis: von.addingTimeInterval(3 * 3600 + 1200)),
                      SchlafAbschnitt(phase: .tief, von: von.addingTimeInterval(3 * 3600 + 1200), bis: von.addingTimeInterval(5 * 3600))]
        let n = SchlafQuellenWahl.nacht(band: band("2026-09-23", von: von, bis: von.addingTimeInterval(5 * 3600), phasen: phasen))
        XCTAssertEqual(n?.schlafMinuten, 280)
    }

    // MARK: - Zeitumstellung

    func testNachtImFruehjahrHatSiebenStundenObwohlDieUhrAchtZeigt() {
        // 28. auf 29.03.2026: um 02:00 springt die Uhr auf 03:00.
        let b = band("2026-03-29", von: SchlafTestBau.zeit("2026-03-28", 23), bis: SchlafTestBau.zeit("2026-03-29", 7))
        XCTAssertEqual(SchlafQuellenWahl.nacht(band: b)?.schlafMinuten, 420)
    }

    func testNachtImHerbstHatNeunStundenObwohlDieUhrAchtZeigt() {
        // 24. auf 25.10.2026: um 03:00 springt die Uhr auf 02:00.
        let b = band("2026-10-25", von: SchlafTestBau.zeit("2026-10-24", 23), bis: SchlafTestBau.zeit("2026-10-25", 7))
        XCTAssertEqual(SchlafQuellenWahl.nacht(band: b)?.schlafMinuten, 540)
    }

    func testDieselbeNachtUeberMitternachtImHerbstWirdZusammengefuehrt() {
        let health = SchlafTestBau.nacht("2026-10-25", bett: (23, 0), auf: (7, 0), phasen: true)
        XCTAssertEqual(health.schlafMinuten, 540)
        let b = band("2026-10-25", von: SchlafTestBau.zeit("2026-10-24", 23, 5), bis: SchlafTestBau.zeit("2026-10-25", 7), phasen: health.abschnitte)
        let liste = SchlafQuellenWahl.waehle(health: [health.tag: health], band: [b])
        XCTAssertEqual(liste.count, 1)
    }
}
