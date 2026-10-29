import XCTest
@testable import LumenFit

/// Aus Lovea `SchlafSignaleTests` (nur die reinen Fälle `gewohnheit`) plus Wochenende und Zeitumstellung.
/// Nicht mitgenommen, mit Grund (Lovea-Datei, Test): `SchlafLogikTests` aus Lovea testet nur die Anwesenheit der Figur (`SchlafLogik.zustand`), nicht den Schlaf;
/// `testSchuldRechnetUeberschussGegenUndNieUnterNull` ist durch `SchlafSchuldTests` ersetzt (Lumen Fit rechnet nur fehlende Minuten, SPEC 10);
/// `testKoffeinVergleichBrauchtGenugNaechteUndUnterschied`: `HabitStore` liefert keine Uhrzeiten je Koffein-Eintrag, ohne sie gibt es keine Quelle;
/// `testGuterMorgenNurAmMorgenUndNurMitGruss` und `testBettErinnerungPlanMitNachMitternachtUndWochenende`: Chat-Signal und Erinnerung entfallen (Umfang-Gate).
final class SchlafLogikTests: XCTestCase {
    private func nacht(_ tag: Int, vonStunde: Int = 23, vonMinute: Int = 0) -> SchlafLogik.BekannteNacht {
        let tagText = String(format: "2026-09-%02d", tag)
        let vortag = Datum.addTage(tagText, -1)
        return SchlafLogik.BekannteNacht(tag: tagText, von: SchlafTestBau.zeit(vortag, vonStunde, vonMinute), bis: SchlafTestBau.zeit(tagText, 7))
    }

    func testGewohnheitMedianUnterWoche() {
        // 21.09. bis 23.09.2026 sind Montag bis Mittwoch.
        let g = SchlafLogik.gewohnheit([nacht(21), nacht(22), nacht(23)], wochenende: false)
        XCTAssertEqual(g?.bett, 23 * 60)
        XCTAssertEqual(g?.auf, 7 * 60)
        XCTAssertNil(SchlafLogik.gewohnheit([nacht(21), nacht(22), nacht(23)], wochenende: true), "keine Wochenend-Nächte bekannt")
    }

    func testGewohnheitUnterDreiNaechtenNichts() {
        XCTAssertNil(SchlafLogik.gewohnheit([nacht(21), nacht(22)], wochenende: false))
    }

    func testGewohnheitBettzeitNachMitternachtLiegtHinter23Uhr() {
        // 23:00, 00:30, 23:30: der Median ist 23:30, nicht 00:30.
        let n = [nacht(21), SchlafLogik.BekannteNacht(tag: "2026-09-22", von: SchlafTestBau.zeit("2026-09-22", 0, 30), bis: SchlafTestBau.zeit("2026-09-22", 8)),
                 nacht(23, vonStunde: 23, vonMinute: 30)]
        XCTAssertEqual(SchlafLogik.gewohnheit(n, wochenende: false)?.bett, 23 * 60 + 30)
    }

    func testWochenendeIstAufwachtagSamstagOderSonntag() {
        XCTAssertFalse(SchlafLogik.istWochenende("2026-09-25"), "Freitag")
        XCTAssertTrue(SchlafLogik.istWochenende("2026-09-26"), "Samstag")
        XCTAssertTrue(SchlafLogik.istWochenende("2026-09-27"), "Sonntag")
        XCTAssertFalse(SchlafLogik.istWochenende("2026-09-28"), "Montag")
    }

    func testGewohnheitWochenendeGetrennt() {
        // 26. und 27.09. Wochenende (Samstag, Sonntag), 3. und 4.10. ebenso: vier Nächte, Bettzeit 00:30.
        let nachts = ["2026-09-26", "2026-09-27", "2026-10-03", "2026-10-04"].map {
            SchlafLogik.BekannteNacht(tag: $0, von: SchlafTestBau.zeit($0, 0, 30), bis: SchlafTestBau.zeit($0, 9))
        }
        let g = SchlafLogik.gewohnheit(nachts, wochenende: true)
        XCTAssertEqual(g?.bett, 30)
        XCTAssertEqual(g?.auf, 9 * 60)
        XCTAssertNil(SchlafLogik.gewohnheit(nachts, wochenende: false))
    }

    func testGewohnheitUeberDieZeitumstellungZeigtDieWanduhr() {
        // Nächte vom 24.10. auf 25.10.2026 (Uhr zurück, 9 Stunden im Bett) und davor: Bettzeit bleibt 23:00, Aufstehen 07:00.
        let n = ["2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"].map {
            SchlafLogik.BekannteNacht(tag: $0, von: SchlafTestBau.zeit(Datum.addTage($0, -1), 23), bis: SchlafTestBau.zeit($0, 7))
        }
        // 24.10. ist Samstag, 25.10. Sonntag, 22. und 23. sind Donnerstag und Freitag.
        XCTAssertNil(SchlafLogik.gewohnheit(n, wochenende: false), "nur zwei Werktage")
        let alle = n + [SchlafLogik.BekannteNacht(tag: "2026-10-21", von: SchlafTestBau.zeit("2026-10-20", 23), bis: SchlafTestBau.zeit("2026-10-21", 7))]
        XCTAssertEqual(SchlafLogik.gewohnheit(alle, wochenende: false)?.bett, 23 * 60)
        XCTAssertEqual(SchlafLogik.gewohnheit(alle, wochenende: false)?.auf, 7 * 60)
    }
}
