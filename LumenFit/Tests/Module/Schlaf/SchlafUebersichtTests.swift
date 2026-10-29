import XCTest
@testable import LumenFit

final class SchlafUebersichtTests: XCTestCase {
    private let heute = "2026-09-23"

    private func health(_ minuten: [Int], ab: String = "2026-09-10", phasen: Bool = true) -> [String: SchlafNacht] {
        var jeTag: [String: SchlafNacht] = [:]
        for (i, m) in minuten.enumerated() {
            let tag = Datum.addTage(ab, i)
            jeTag[tag] = SchlafTestBau.nacht(tag, minuten: m, phasen: phasen)
        }
        return jeTag
    }

    func testOhneDatenIstLeer() {
        let u = SchlafUebersicht.bauen(health: [:], band: [], vitale: [:], zielMinuten: 480, heute: heute)
        XCTAssertFalse(u.hatDaten)
        XCTAssertNil(u.letzte)
        XCTAssertNil(u.schuld)
        XCTAssertNil(u.regelmaessigkeit)
        XCTAssertEqual(u.erholung.stufe, .offen)
        XCTAssertEqual(u.titelLetzte, "Letzte Nacht")
        XCTAssertFalse(u.ohnePhasen)
        XCTAssertEqual(u.chips.map(\.art), SchlafVitalStand.chipArten)
        XCTAssertTrue(u.chips.allSatisfy { $0.aktuell == nil })
    }

    func testLetzteNachtSchuldWocheUndErholungAusDenDaten() {
        let n = health([420, 480, 400, 480, 450, 480, 360, 430, 440, 470, 380, 460, 500, 450])   // 10. bis 23.09.
        let hrv = SchlafTestBau.vitale(.hrv, ab: "2026-09-09", (0..<14).map { $0 % 2 == 0 ? 50.0 : 60.0 } + [61.6])
        let u = SchlafUebersicht.bauen(health: n, band: [], vitale: [.hrv: hrv], zielMinuten: 480, heute: heute)
        XCTAssertEqual(u.letzte?.nacht.tag, heute)
        XCTAssertEqual(u.letzte?.nacht.schlafMinuten, 450)
        XCTAssertEqual(u.titelLetzte, "Letzte Nacht")
        XCTAssertEqual(u.schuld?.naechte, 7)
        XCTAssertEqual(u.woche.diese.naechte, 7)
        XCTAssertNotNil(u.regelmaessigkeit)
        XCTAssertEqual(u.erholung.stufe, .bereit)
        XCTAssertEqual(u.hrv.bereich?.abweichungProzent, 12)
        XCTAssertFalse(u.ohnePhasen)
        XCTAssertEqual(u.lumi(jetzt: SchlafTestBau.zeit(heute, 14)), .bereit)
    }

    func testAlteHrvWirdNichtZurErholungsaussage() {
        // Die HRV ist fünf Tage alt: Chip und Karte zeigen sie mit Datum, "du bist bereit" steht nicht darauf.
        let werte = SchlafTestBau.vitale(.hrv, ab: "2026-09-05", (0..<14).map { $0 % 2 == 0 ? 50.0 : 60.0 } + [61.6])
        let u = SchlafUebersicht.bauen(health: [:], band: [], vitale: [.hrv: werte], zielMinuten: 480, heute: heute)
        XCTAssertEqual(u.hrv.datumHinweis, "vom 19.09.")
        XCTAssertEqual(u.erholung.stufe, .offen)
    }

    func testAeltereNachtTraegtDatumUndZaehltNichtFuerDieErholung() {
        let n = health([420, 440, 450], ab: "2026-09-17")   // letzte Nacht am 19.09., heute 23.09.
        let u = SchlafUebersicht.bauen(health: n, band: [], vitale: [:], zielMinuten: 480, heute: heute)
        XCTAssertEqual(u.titelLetzte, "Nacht auf \(Datum.anzeige("2026-09-19"))")
        XCTAssertEqual(u.erholung.stufe, .offen, "eine Nacht von vor vier Tagen sagt nichts über heute")
    }

    func testNaechteNachHeuteWerdenIgnoriert() {
        let u = SchlafUebersicht.bauen(health: health([420, 420, 420], ab: "2026-09-22"), band: [], vitale: [:], zielMinuten: 480, heute: heute)
        XCTAssertEqual(u.naechte.map(\.nacht.tag), ["2026-09-22", "2026-09-23"])
    }

    func testNurHandyHatKeinePhasenUndKeineVitale() {
        let u = SchlafUebersicht.bauen(health: health([420, 430, 440], ab: "2026-09-21", phasen: false), band: [], vitale: [:], zielMinuten: 480, heute: heute)
        XCTAssertTrue(u.ohnePhasen)
        XCTAssertEqual(u.letzte?.quelle, .handy)
        XCTAssertNil(u.hrv.aktuell)
        XCTAssertEqual(u.hrv.untertitel, "Keine Daten")
        XCTAssertEqual(u.erholung.stufe, .normal, "nur die Nacht gegen das Ziel")
    }

    func testBandUndHealthDerselbenNachtErscheinenEinmalMitVergleich() throws {
        let h = SchlafTestBau.nacht(heute, minuten: 440)
        let op = BandSchlafOp(tag: heute, start: h.von.addingTimeInterval(900), ende: h.bis, phasen: [])
        let u = SchlafUebersicht.bauen(health: [heute: h], band: [op], vitale: [:], zielMinuten: 480, heute: heute)
        XCTAssertEqual(u.naechte.count, 1)
        XCTAssertEqual(u.letzte?.quelle, .band)
        XCTAssertEqual(u.letzte?.weitere, [.handy])
        XCTAssertNotNil(u.vergleichLetzte)
        let vergleich = try XCTUnwrap(u.vergleichLetzte)
        XCTAssertEqual(SchlafVergleich.abweichung(vergleich)?.einschlafen, 15)
    }

    func testGewohnheitGetrenntNachWerktagUndWochenende() {
        // 14 Nächte, Bettzeit Werktag 23:00 (Aufstehen 07:00), Wochenende 00:30 (Aufstehen 09:00).
        var n: [String: SchlafNacht] = [:]
        for tag in SchlafTestBau.tage(ab: "2026-09-10", 14) {
            n[tag] = SchlafLogik.istWochenende(tag) ? SchlafTestBau.nacht(tag, bett: (0, 30), auf: (9, 0)) : SchlafTestBau.nacht(tag, bett: (23, 0))
        }
        let u = SchlafUebersicht.bauen(health: n, band: [], vitale: [:], zielMinuten: 480, heute: heute)
        XCTAssertEqual(u.werktag?.text, "23:00 bis 07:00")
        XCTAssertEqual(u.wochenende?.text, "00:30 bis 09:00")
    }

    func testTageSindDieLetztenNTageMitLuecken() {
        let u = SchlafUebersicht.bauen(health: health([420, 430], ab: "2026-09-21"), band: [], vitale: [:], zielMinuten: 480, heute: heute)
        let tage = u.tage(5)
        XCTAssertEqual(tage.map(\.tag), ["2026-09-19", "2026-09-20", "2026-09-21", "2026-09-22", "2026-09-23"])
        XCTAssertEqual(tage.map(\.minuten), [nil, nil, 420, 430, nil])
        XCTAssertTrue(u.tage(0).isEmpty)
    }

    // MARK: - Lumi

    func testLumiSchlaeftNachtsZwischen22Und5() {
        for (stunde, minute) in [(22, 0), (23, 59), (0, 0), (3, 30), (4, 59)] {
            XCTAssertEqual(SchlafLumi.stimmung(jetzt: SchlafTestBau.zeit(heute, stunde, minute), letzteNachtMinuten: 480, erholung: .bereit), .schlaeft, "\(stunde):\(minute)")
        }
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: SchlafTestBau.zeit(heute, 5), letzteNachtMinuten: 480, erholung: .bereit), .bereit)
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: SchlafTestBau.zeit(heute, 21, 59), letzteNachtMinuten: 480, erholung: .bereit), .bereit)
    }

    func testLumiMuedeNachKurzerNachtOderBeiSchonen() {
        let tag = SchlafTestBau.zeit(heute, 12)
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: tag, letzteNachtMinuten: 359, erholung: nil), .muede)
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: tag, letzteNachtMinuten: 360, erholung: .normal), .bereit)
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: tag, letzteNachtMinuten: 480, erholung: .schonen), .muede)
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: tag, letzteNachtMinuten: nil, erholung: .offen), .bereit)
    }

    func testLumiNachtsGiltAuchInDerNachtDerZeitumstellung() {
        // 25.10.2026: 02:30 gibt es zweimal, beide Male ist es Nacht.
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: SchlafTestBau.zeit("2026-10-25", 2, 30), letzteNachtMinuten: 480, erholung: nil), .schlaeft)
        XCTAssertEqual(SchlafLumi.stimmung(jetzt: SchlafTestBau.zeit("2026-10-25", 5), letzteNachtMinuten: 480, erholung: nil), .bereit)
    }
}
