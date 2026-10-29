import XCTest
@testable import LumenFit

final class PersoenlicherBereichTests: XCTestCase {
    private let heute = "2026-09-23"

    /// 14 Basiswerte (sieben mal 50, sieben mal 60: Mittel 55) vom 09.09. bis 22.09., dazu der aktuelle Wert am 23.09.
    private func hrv(aktuell: Double, basis: Int = 14) -> [VitalMesswert] {
        let start = Datum.addTage(heute, -basis)
        let werte = (0..<basis).map { $0 % 2 == 0 ? 50.0 : 60.0 } + [aktuell]
        return SchlafTestBau.vitale(.hrv, ab: start, werte)
    }

    func testMittelStreuungUndAnzahlOhneDenAktuellenWert() throws {
        let b = try XCTUnwrap(PersoenlicherBereich.berechne(werte: hrv(aktuell: 61.6), art: .hrv, heute: heute))
        XCTAssertEqual(b.mittel, 55, accuracy: 0.0001)
        XCTAssertEqual(b.streuung, (350.0 / 13).squareRoot(), accuracy: 0.0001)
        XCTAssertEqual(b.anzahl, 14)
        XCTAssertEqual(b.aktuell, 61.6, accuracy: 0.0001)
        XCTAssertEqual(b.aktuellTag, heute)
        let anders = try XCTUnwrap(PersoenlicherBereich.berechne(werte: hrv(aktuell: 1000), art: .hrv, heute: heute))
        XCTAssertEqual(anders.mittel, 55, accuracy: 0.0001, "der aktuelle Wert misst sich nicht an sich selbst")
    }

    func testUnterVierzehnWertenGibtEsKeinenBereich() {
        XCTAssertNil(PersoenlicherBereich.berechne(werte: hrv(aktuell: 61, basis: 13), art: .hrv, heute: heute))
        XCTAssertNotNil(PersoenlicherBereich.berechne(werte: hrv(aktuell: 61, basis: 14), art: .hrv, heute: heute))
    }

    func testAktuellerWertDarfHoechstensSiebenTageAltSein() {
        let alt = SchlafTestBau.vitale(.hrv, ab: "2026-08-01", (0..<20).map { Double($0 % 2 == 0 ? 50 : 60) })
        XCTAssertNil(PersoenlicherBereich.berechne(werte: alt, art: .hrv, heute: heute), "letzter Wert vom 19.08.")
        XCTAssertNil(PersoenlicherBereich.aktuellerWert(alt, art: .hrv, heute: heute))
        let frisch = alt + [VitalMesswert(art: .hrv, tag: "2026-09-17", wert: 58)]
        XCTAssertEqual(PersoenlicherBereich.aktuellerWert(frisch, art: .hrv, heute: heute)?.wert, 58)
        let zuAlt = alt + [VitalMesswert(art: .hrv, tag: "2026-09-16", wert: 58)]
        XCTAssertNil(PersoenlicherBereich.aktuellerWert(zuAlt, art: .hrv, heute: heute), "acht Tage her")
    }

    func testNurDieLetzten60TageUndNurDieRichtigeArt() throws {
        var werte = hrv(aktuell: 61.6)
        werte += SchlafTestBau.vitale(.hrv, ab: "2026-07-01", Array(repeating: 500, count: 20))   // älter als 60 Tage
        werte += SchlafTestBau.vitale(.ruhepuls, ab: "2026-09-01", Array(repeating: 900, count: 20))
        let b = try XCTUnwrap(PersoenlicherBereich.berechne(werte: werte, art: .hrv, heute: heute))
        XCTAssertEqual(b.anzahl, 14)
        XCTAssertEqual(b.mittel, 55, accuracy: 0.0001)
    }

    func testLageTrendUndPosition() throws {
        let hoch = try XCTUnwrap(PersoenlicherBereich.berechne(werte: hrv(aktuell: 61.6), art: .hrv, heute: heute))
        XCTAssertEqual(hoch.lage, .hoch)
        XCTAssertEqual(hoch.trend, .hoeher)
        XCTAssertEqual(hoch.abweichungProzent, 12)
        XCTAssertGreaterThan(hoch.position, 0.5)
        let mitte = try XCTUnwrap(PersoenlicherBereich.berechne(werte: hrv(aktuell: 55), art: .hrv, heute: heute))
        XCTAssertEqual(mitte.lage, .normal)
        XCTAssertEqual(mitte.trend, .gleich)
        XCTAssertEqual(mitte.position, 0.5, accuracy: 0.0001)
        let tief = try XCTUnwrap(PersoenlicherBereich.berechne(werte: hrv(aktuell: 40), art: .hrv, heute: heute))
        XCTAssertEqual(tief.lage, .niedrig)
        XCTAssertEqual(tief.trend, .tiefer)
        XCTAssertEqual(tief.abweichungProzent, -27)
        XCTAssertEqual(tief.position, 0, accuracy: 0.0001, "weit unter dem Bereich: am linken Rand")
    }

    func testStreuungNullTeiltNichtDurchNull() throws {
        let gleich = SchlafTestBau.vitale(.ruhepuls, ab: Datum.addTage(heute, -14), Array(repeating: 54, count: 14) + [54])
        let b = try XCTUnwrap(PersoenlicherBereich.berechne(werte: gleich, art: .ruhepuls, heute: heute))
        XCTAssertEqual(b.streuung, 0)
        XCTAssertEqual(b.lage, .normal)
        XCTAssertEqual(b.trend, .gleich)
        XCTAssertEqual(b.position, 0.5, accuracy: 0.0001)
        XCTAssertEqual(b.schnittText, "wie dein Schnitt")
        let anders = SchlafTestBau.vitale(.ruhepuls, ab: Datum.addTage(heute, -14), Array(repeating: 54, count: 14) + [58])
        let c = try XCTUnwrap(PersoenlicherBereich.berechne(werte: anders, art: .ruhepuls, heute: heute))
        XCTAssertEqual(c.lage, .hoch)
        XCTAssertEqual(c.position, 1, accuracy: 0.0001)
        XCTAssertFalse(c.position.isNaN)
    }

    func testTexte() throws {
        let b = try XCTUnwrap(PersoenlicherBereich.berechne(werte: hrv(aktuell: 61.6), art: .hrv, heute: heute))
        XCTAssertEqual(b.bereichText, "50 bis 60 ms")
        XCTAssertEqual(b.schnittText, "12 % über deinem Schnitt")
        XCTAssertEqual(b.lageSatz, "Mit 62 ms liegst du über deinem Bereich (50 bis 60 ms).")
        let tief = try XCTUnwrap(PersoenlicherBereich.berechne(werte: hrv(aktuell: 40), art: .hrv, heute: heute))
        XCTAssertEqual(tief.schnittText, "27 % unter deinem Schnitt")
    }

    func testNichtEndlicheWerteWerdenIgnoriert() {
        var werte = hrv(aktuell: 61.6)
        werte.append(VitalMesswert(art: .hrv, tag: "2026-09-01", wert: .nan))
        werte.append(VitalMesswert(art: .hrv, tag: "2026-09-02", wert: .infinity))
        let b = PersoenlicherBereich.berechne(werte: werte, art: .hrv, heute: heute)
        XCTAssertEqual(b?.anzahl, 14)
        XCTAssertEqual(b?.mittel ?? 0, 55, accuracy: 0.0001)
    }

    // MARK: - Werte-Chips

    func testChipOhneDatenSagtKeineDaten() {
        let s = SchlafVitalStand.bauen(art: .sauerstoff, werte: [], heute: heute)
        XCTAssertNil(s.aktuell)
        XCTAssertEqual(s.untertitel, "Keine Daten")
        XCTAssertEqual(s.sprechSatz, "SpO2: keine Daten. In Health prüfen.")
        XCTAssertFalse(s.sprechSatz.lowercased().contains("abgelehnt"))
    }

    func testChipMitWenigWertenNenntDieLuecke() {
        let werte = SchlafTestBau.vitale(.ruhepuls, ab: Datum.addTage(heute, -5), [54, 55, 53, 56, 54, 55])
        let s = SchlafVitalStand.bauen(art: .ruhepuls, werte: werte, heute: heute)
        XCTAssertEqual(s.aktuell?.wert, 55)
        XCTAssertNil(s.bereich)
        XCTAssertEqual(s.vorhanden, 5)
        XCTAssertEqual(s.untertitel, "Zu wenig Daten für deinen Schnitt (5 von 14)")
        XCTAssertEqual(s.sprechSatz, "Ruhepuls 55 Schläge pro Minute, Zu wenig Daten für deinen Schnitt (5 von 14)")
    }

    func testChipMitBereichZeigtTrendgegenSchnitt() {
        let s = SchlafVitalStand.bauen(art: .hrv, werte: hrv(aktuell: 61.6), heute: heute)
        XCTAssertEqual(s.untertitel, "12 % über deinem Schnitt")
        XCTAssertEqual(s.bereich?.trend, .hoeher)
        XCTAssertEqual(SchlafVitalStand.chipArten, [.ruhepuls, .sauerstoff, .atemfrequenz, .temperatur, .vo2max])
    }

    func testEinheitenUndZahlenMitKomma() {
        XCTAssertEqual(SchlafVitalInfo.text(.ruhepuls, 54.4), "54 /min")
        XCTAssertEqual(SchlafVitalInfo.text(.sauerstoff, 97), "97 %")
        XCTAssertEqual(SchlafVitalInfo.text(.temperatur, 36.4), "36,4 °C")
        XCTAssertEqual(SchlafVitalInfo.text(.atemfrequenz, 14.25), "\(SchlafFormat.zahl(14.25, stellen: 1)) /min")
        XCTAssertTrue(SchlafVitalInfo.text(.vo2max, 44.5).hasSuffix("ml/kg/min"))
        XCTAssertTrue(SchlafVitalInfo.text(.vo2max, 44.5).contains(","), "deutsches Komma")
    }
}
