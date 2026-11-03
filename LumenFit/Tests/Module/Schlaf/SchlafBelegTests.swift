import XCTest
@testable import LumenFit

/// Der Schlaf-Beleg (Diagnose): wann er fällig ist, welche Tage und Quellen hineinkommen, dass er klein bleibt und sich wieder lesen lässt.
final class SchlafBelegTests: XCTestCase {
    private let jetzt = SchlafTestBau.zeit("2026-11-03", 12)

    private func eingabe() -> SchlafBelegLogik.Eingabe {
        SchlafBelegLogik.Eingabe(jetzt: jetzt, build: "1.0 (1)", zone: TimeZone(identifier: "Europe/Berlin")!)
    }

    private func bandOp(_ tag: String) -> BandSchlafOp {
        let bis = SchlafTestBau.zeit(tag, 7)
        let von = bis.addingTimeInterval(-7 * 3600)
        return BandSchlafOp(tag: tag, start: von, ende: bis, phasen: [SchlafAbschnitt(phase: .kern, von: von, bis: bis)])
    }

    func testFaelligNurEinmalJeStundeUndBeiZurueckgestellterUhr() {
        XCTAssertTrue(SchlafBelegLogik.faellig(letzter: nil, jetzt: jetzt))
        XCTAssertFalse(SchlafBelegLogik.faellig(letzter: jetzt.addingTimeInterval(-30 * 60), jetzt: jetzt))
        XCTAssertFalse(SchlafBelegLogik.faellig(letzter: jetzt.addingTimeInterval(-3599), jetzt: jetzt))
        XCTAssertTrue(SchlafBelegLogik.faellig(letzter: jetzt.addingTimeInterval(-3600), jetzt: jetzt))
        XCTAssertTrue(SchlafBelegLogik.faellig(letzter: jetzt.addingTimeInterval(600), jetzt: jetzt), "Uhr zurückgestellt: fällig")
    }

    func testNurDieLetzten14TageKommenHinein() {
        var e = eingabe()
        e.bandOps = [bandOp("2026-11-03"), bandOp("2026-10-21"), bandOp("2026-10-20")]
        e.healthNaechte = ["2026-11-02": SchlafTestBau.nacht("2026-11-02", minuten: 420), "2026-10-01": SchlafTestBau.nacht("2026-10-01", minuten: 420)]
        e.bandSchritte = ["2026-11-03": 100, "2026-10-20": 5]
        let beleg = SchlafBelegLogik.bauen(e)
        XCTAssertEqual(beleg.heute, "2026-11-03")
        XCTAssertEqual(beleg.band.map(\.tag), ["2026-10-21", "2026-11-03"], "14 Tage heißt heute und die 13 davor, aufsteigend")
        XCTAssertEqual(beleg.health.map(\.tag), ["2026-11-02"])
        XCTAssertEqual(beleg.schritte.map(\.tag), ["2026-11-03"])
        XCTAssertEqual(beleg.zeitzone, "Europe/Berlin")
        XCTAssertEqual(beleg.build, "1.0 (1)")
    }

    func testGewaehlteNachtNenntQuelleWeitereUndMinutenJePhase() {
        var e = eingabe()
        let nacht = SchlafTestBau.nacht("2026-11-03", minuten: 600, phasen: true)
        e.gewaehlt = [SchlafGewaehlteNacht(nacht: nacht, quelle: .band, weitere: [.uhr, .handy])]
        let g = SchlafBelegLogik.bauen(e).gewaehlt
        XCTAssertEqual(g.count, 1)
        XCTAssertEqual(g[0].quelle, "Band")
        XCTAssertEqual(g[0].weitere, ["Uhr", "Handy"])
        XCTAssertEqual(g[0].von, nacht.von)
        XCTAssertEqual(g[0].bis, nacht.bis)
        XCTAssertEqual(g[0].phasenMinuten["Kern"], 300)
        XCTAssertEqual(g[0].phasenMinuten["Tief"], 120)
        XCTAssertEqual(g[0].phasenMinuten["REM"], 180)
    }

    func testSchritteJeTagGetrenntNachBandUndHealth() {
        var e = eingabe()
        e.bandSchritte = ["2026-11-02": 4000, "2026-11-01": 100]
        e.healthSchritte = ["2026-11-02": 4200, "2026-11-03": 50]
        let s = SchlafBelegLogik.bauen(e).schritte
        XCTAssertEqual(s, [SchlafBelegSchritte(tag: "2026-11-01", band: 100, health: nil),
                           SchlafBelegSchritte(tag: "2026-11-02", band: 4000, health: 4200),
                           SchlafBelegSchritte(tag: "2026-11-03", band: nil, health: 50)])
    }

    func testProbenBleibenBegrenztUndDieNeuestenBleiben() {
        var e = eingabe()
        let basis = SchlafTestBau.zeit("2026-11-02", 23)
        e.healthProben = (0..<(SchlafBelegLogik.hoechstProben + 50)).map { i in
            HealthSchlafProbe(wert: 3, von: basis.addingTimeInterval(Double(i) * 60), bis: basis.addingTimeInterval(Double(i) * 60 + 60), quelle: "quelle.a", geraet: "Watch1,1")
        }
        e.healthProben.append(HealthSchlafProbe(wert: 3, von: SchlafTestBau.zeit("2026-09-01", 23), bis: SchlafTestBau.zeit("2026-09-02", 6), quelle: "alt", geraet: nil))
        let p = SchlafBelegLogik.bauen(e).healthProben
        XCTAssertEqual(p.count, SchlafBelegLogik.hoechstProben)
        XCTAssertFalse(p.contains { $0.quelle == "alt" }, "Proben vor dem Fenster fallen weg")
        XCTAssertEqual(p.last?.von, basis.addingTimeInterval(Double(SchlafBelegLogik.hoechstProben + 49) * 60), "die neuesten bleiben")
        XCTAssertEqual(p.sorted { $0.von < $1.von }, p, "aufsteigend")
    }

    func testBandLogWirdGekuerztUndZeigtDieUhrZeilen() {
        var e = eingabe()
        e.bandLog = (0..<100).map { "12:00:\($0)  schlaf-roh: x" } + ["12:01:00  zeit: gesendet 0102", "12:01:01  zeit: Antwort 0103", String(repeating: "a", count: 5000)]
        let b = SchlafBelegLogik.bauen(e)
        XCTAssertEqual(b.bandLog.count, SchlafBelegLogik.hoechstLogZeilen)
        XCTAssertEqual(b.bandLog.last?.count, SchlafBelegLogik.hoechstZeile)
        XCTAssertEqual(b.bandUhrLog, ["12:01:00  zeit: gesendet 0102", "12:01:01  zeit: Antwort 0103"])
    }

    func testBelegLaesstSichKodierenUndLesenUndBleibtKlein() throws {
        var e = eingabe()
        e.letzterBandSync = jetzt.addingTimeInterval(-600)
        e.bandOps = (0..<14).map { bandOp(Datum.addTage("2026-11-03", -$0)) }
        e.healthProben = (0..<5000).map { i in
            HealthSchlafProbe(wert: 4, von: jetzt.addingTimeInterval(-Double(i) * 60), bis: jetzt.addingTimeInterval(-Double(i) * 60 + 60), quelle: "com.apple.health.0000", geraet: "Watch1,1")
        }
        let beleg = SchlafBelegLogik.bauen(e)
        let daten = try XCTUnwrap(SchlafBelegLogik.kodieren(beleg))
        XCTAssertLessThan(daten.count, 400_000, "weit unter dem Limit des Servers (512 KB)")
        XCTAssertEqual(daten, SchlafBelegLogik.kodieren(beleg), "gleiche Eingabe, gleiche Bytes")
        let dekodierer = JSONDecoder()
        dekodierer.dateDecodingStrategy = .iso8601
        let zurueck = try dekodierer.decode(SchlafBeleg.self, from: daten)
        XCTAssertEqual(zurueck.band.count, 14)
        XCTAssertEqual(zurueck.healthProben.count, SchlafBelegLogik.hoechstProben)
        XCTAssertEqual(zurueck.version, 1)
    }

    func testLeereEingabeGibtEinenLeerenBelegMitZeitzone() throws {
        let beleg = SchlafBelegLogik.bauen(eingabe())
        XCTAssertTrue(beleg.gewaehlt.isEmpty && beleg.band.isEmpty && beleg.healthProben.isEmpty && beleg.schritte.isEmpty)
        XCTAssertEqual(beleg.zeitzoneOffsetSekunden, 3600, "Berlin im November: MEZ")
        XCTAssertNotNil(SchlafBelegLogik.kodieren(beleg))
    }
}
