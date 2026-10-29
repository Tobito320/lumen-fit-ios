import XCTest
@testable import LumenFit

/// Lumi-Stufen 1 bis 9 (Idee 38): der Pfad und das nächste Ziel kommen aus `LumiStufe.schwellen` (die Stufe selbst testet `LumiStufeTests` im Grundgerüst).
final class LumiPfadTests: XCTestCase {
    func testPfadHatNeunKnotenAusDenSchwellen() {
        let s = LumiPfad.stand(erreicht: 4, serieWochen: 2)
        XCTAssertEqual(s.knoten.map(\.stufe), Array(1...9))
        XCTAssertEqual(s.knoten.map(\.ab), LumiStufe.schwellen)
        XCTAssertEqual(s.stufe, LumiStufe.stufe(erreicht: 4))
        XCTAssertEqual(s.knoten.filter(\.erreicht).count, s.stufe, "alle Knoten bis zur aktuellen Stufe sind erreicht")
    }

    func testNaechstesZielZaehltDieFehlendenMedaillen() {
        let s = LumiPfad.stand(erreicht: 2, serieWochen: 0)
        XCTAssertEqual(s.stufe, 2)
        XCTAssertEqual(s.naechsteStufe, 3)
        XCTAssertEqual(s.fehlen, LumiStufe.schwellen[2] - 2)
        XCTAssertEqual(s.ziel, "Noch 1 Medaille bis Stufe 3")
        XCTAssertEqual(s.anteil, 0.5, accuracy: 0.0001, "eine von zwei Medaillen zwischen Stufe 2 und 3")
    }

    func testJederWertVonNullBisFuenfundzwanzigStimmtMitDenSchwellenUeberein() {
        for erreicht in 0...25 {
            let s = LumiPfad.stand(erreicht: erreicht, serieWochen: 0)
            XCTAssertEqual(s.stufe, LumiStufe.stufe(erreicht: erreicht), "\(erreicht)")
            XCTAssertTrue((0...1).contains(s.anteil), "\(erreicht)")
            if let fehlen = s.fehlen, let naechste = s.naechsteStufe {
                XCTAssertEqual(fehlen, LumiStufe.schwellen[naechste - 1] - erreicht, "\(erreicht)")
                XCTAssertGreaterThan(fehlen, 0, "\(erreicht)")
            }
        }
    }

    func testAmAnfangUndAmEnde() {
        let anfang = LumiPfad.stand(erreicht: 0, serieWochen: 0)
        XCTAssertEqual(anfang.stufe, 1)
        XCTAssertEqual(anfang.anteil, 0)
        XCTAssertEqual(anfang.ziel, "Noch 1 Medaille bis Stufe 2")
        let ende = LumiPfad.stand(erreicht: 25, serieWochen: 3)
        XCTAssertEqual(ende.stufe, 9)
        XCTAssertNil(ende.naechsteStufe)
        XCTAssertNil(ende.fehlen)
        XCTAssertEqual(ende.anteil, 1)
        XCTAssertEqual(ende.ziel, "Höchste Stufe erreicht")
        XCTAssertEqual(LumiPfad.stand(erreicht: LumiStufe.schwellen[8], serieWochen: 0).stufe, 9, "genau auf der letzten Schwelle")
    }

    func testMehrereMedaillenZeigenDenPluralUndDieSerie() {
        XCTAssertEqual(LumiPfad.stand(erreicht: 5, serieWochen: 0).ziel, "Noch 3 Medaillen bis Stufe 5")
        XCTAssertEqual(LumiPfad.stand(erreicht: 0, serieWochen: 1).serieText, "1 Woche in Folge")
        XCTAssertEqual(LumiPfad.stand(erreicht: 0, serieWochen: 12).serieText, "12 Wochen in Folge")
    }

    // MARK: Nächste Medaille

    func testNaechstesZielIstDieAmWeitestenGediehene() {
        var z = MeilensteinZahlen()
        z.gymTage = 80
        z.volumenKg = 7_000
        let ziel = LumiPfad.naechstesZiel(z, schon: [])
        XCTAssertEqual(ziel?.meilenstein.id, "gym-100", "80 Prozent schlagen 70 Prozent")
        XCTAssertEqual(ziel?.text, "80 von 100 Tagen")
        XCTAssertEqual(ziel?.anteil ?? 0, 0.8, accuracy: 0.0001)
    }

    func testNaechstesZielUeberspringtErreichtes() {
        var z = MeilensteinZahlen()
        z.gymTage = 80
        z.volumenKg = 7_000
        let ohne = LumiPfad.naechstesZiel(z, schon: ["gym-100"])
        XCTAssertEqual(ohne?.meilenstein.id, "volumen-10000", "gym-100 ist schon vergeben: 70 Prozent gegen 40 Prozent bei gym-200")
        XCTAssertEqual(ohne?.text, "7.000 von 10.000 kg")
        XCTAssertEqual(LumiPfad.naechstesZiel(z, schon: ["gym-100", "volumen-10000"])?.meilenstein.id, "gym-200")
    }

    func testNaechstesZielNurMitZaehlerUndNochOffen() {
        XCTAssertNotNil(LumiPfad.naechstesZiel(MeilensteinZahlen(), schon: []), "bei null ist die erste zählbare dran")
        let alle = Set(MeilensteinKatalog.alle.map(\.id))
        XCTAssertNil(LumiPfad.naechstesZiel(MeilensteinZahlen(), schon: alle))
        var z = MeilensteinZahlen()
        z.gymTage = 10
        XCTAssertNotEqual(LumiPfad.naechstesZiel(z, schon: ["gym-10"])?.meilenstein.id, "gym-10")
    }

    func testZaehlerKenntNurZaehlbareMedaillen() {
        let z = MeilensteinZahlen()
        XCTAssertNil(LumiPfad.zaehler("erster-satz", z))
        XCTAssertNil(LumiPfad.zaehler("fruehstueck", z))
        XCTAssertNil(LumiPfad.zaehler("gewicht-ziel", z))
        XCTAssertNil(LumiPfad.zaehler("lange-einheit", z))
        XCTAssertEqual(LumiPfad.zaehler("schlaf-7", z)?.ziel, 7)
        XCTAssertEqual(LumiPfad.zaehler("tagebuch-30", z)?.ziel, 30)
        XCTAssertEqual(LumiPfad.zaehler("rekorde-25", z)?.einheit, "Rekorden")
    }

    func testAnteilUndTextEinesZiels() {
        let m = MeilensteinKatalog.alle[0]
        XCTAssertEqual(MeilensteinZiel(meilenstein: m, aktuell: 25, ziel: 100, einheit: "Tagen").anteil, 0.25)
        XCTAssertEqual(MeilensteinZiel(meilenstein: m, aktuell: 250, ziel: 100, einheit: "Tagen").anteil, 1)
        XCTAssertEqual(MeilensteinZiel(meilenstein: m, aktuell: 0, ziel: 0, einheit: "Tagen").anteil, 0)
    }
}
