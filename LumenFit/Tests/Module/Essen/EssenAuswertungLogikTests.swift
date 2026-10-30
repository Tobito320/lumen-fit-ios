// Quelle: Lovea Health/Ernaehrung/ErnaehrungAnalyse.swift:140-484 (Rechenteil der Auswertung, neu getestet)
import XCTest
@testable import LumenFit

final class EssenAuswertungLogikTests: XCTestCase {
    private func eintrag(_ tag: String, _ id: String, kcal: Double, protein: Double = 0, g: Double = 100, ballast: Double? = nil) -> EssenEintrag {
        let l = Lebensmittel(id: id, name: "Essen \(id)", pro100: Naehrwerte(kcal: kcal, protein: protein, kohlenhydrate: 10, fett: 5, ballaststoffe: ballast))
        return EssenEintrag(id: "e-\(tag)-\(id)", datum: tag, mahlzeit: .mittag, menge: g, einheit: .g, lebensmittel: l, geloescht: nil)
    }

    func testZeitraumGruppierungUndTage() {
        XCTAssertEqual(AnalyseZeitraum.woche.rawValue, 7)
        XCTAssertEqual(AnalyseZeitraum.woche.gruppierung, .tag)
        XCTAssertEqual(AnalyseZeitraum.dreiMonate.gruppierung, .woche)
        XCTAssertEqual(AnalyseZeitraum.zweiJahre.gruppierung, .monat)
        XCTAssertEqual(AnalyseZeitraum.allCases.map(\.name), ["Woche", "Monat", "3 Monate", "Jahr", "2 Jahre"])
    }

    func testTagesSummenNurTageMitEintraegen() {
        let summen = EssenAuswertungLogik.tagesSummen([eintrag("2026-10-01", "a", kcal: 100), eintrag("2026-10-01", "b", kcal: 50), eintrag("2026-10-03", "a", kcal: 100)])
        XCTAssertEqual(Set(summen.keys), ["2026-10-01", "2026-10-03"])
        XCTAssertEqual(summen["2026-10-01"]?.kcal ?? 0, 150, accuracy: 0.001)
    }

    func testMakroSchnitteUndEnergieAnteil() {
        let summen = EssenAuswertungLogik.tagesSummen([eintrag("2026-10-01", "a", kcal: 100, protein: 20)])
        let schnitte = EssenAuswertungLogik.makroSchnitte(summen, ziele: ErnaehrungsZiele())
        XCTAssertEqual(schnitte.map(\.name), ["Kohlenhydrate", "Eiweiß", "Fett"])
        // 10 g KH, 20 g Eiweiß, 5 g Fett = 40 + 80 + 45 kcal
        let anteile = schnitte.map { EssenAuswertungLogik.energieAnteil($0, in: schnitte) }
        XCTAssertEqual(anteile.reduce(0, +), 1, accuracy: 0.0001)
        XCTAssertEqual(anteile[1], 80.0 / 165.0, accuracy: 0.0001)
    }

    func testEnergieAnteilOhneEssenIstNull() {
        let schnitte = EssenAuswertungLogik.makroSchnitte([:], ziele: ErnaehrungsZiele())
        XCTAssertEqual(EssenAuswertungLogik.energieAnteil(schnitte[0], in: schnitte), 0)
    }

    func testGrundZeilenNurMitAngaben() {
        let mit = EssenAuswertungLogik.tagesSummen([eintrag("2026-10-01", "a", kcal: 100, ballast: 5)])
        XCTAssertEqual(EssenAuswertungLogik.grundZeilen(mit).map(\.name), ["Ballaststoffe"])
        XCTAssertTrue(EssenAuswertungLogik.grundZeilen([:]).isEmpty)
    }

    func testMikroZeilenProzentDerReferenz() {
        var n = Naehrwerte(kcal: 100)
        n.mikro = [Mikro.vitaminC.rawValue: 40]
        let zeilen = EssenAuswertungLogik.mikroZeilen(["2026-10-01": n], gruppe: .vitamine)
        XCTAssertEqual(zeilen.count, 1)
        XCTAssertEqual(zeilen[0].prozent ?? 0, 50, accuracy: 0.001)
        XCTAssertTrue(EssenAuswertungLogik.mikroZeilen(["2026-10-01": n], gruppe: .mineralstoffe).isEmpty)
    }

    func testGewichtReiheFiltertZeitraumUndNull() {
        let quelle = ["2026-09-30": 800, "2026-10-01": 784, "2026-10-02": 0, "2026-10-03": 790, "2026-10-09": 700]
        let reihe = EssenAuswertungLogik.gewichtReihe(quelle, von: "2026-10-01", bis: "2026-10-05")
        XCTAssertEqual(reihe.map(\.tag), ["2026-10-01", "2026-10-03"])
        XCTAssertEqual(reihe[0].wert, 78.4, accuracy: 0.0001)
        XCTAssertEqual(EssenAuswertungLogik.gewichtVeraenderungZehntel(reihe), 6)
        XCTAssertEqual(EssenAuswertungLogik.gewichtVeraenderungZehntel([]), 0)
    }

    func testKoerperReiheNurEchteTage() {
        let reihe = EssenAuswertungLogik.koerperReihe(tage: ["2026-10-01", "2026-10-02", "2026-10-03"]) { tag in
            // 10-02 liefert den fortgeschriebenen Wert vom 10-01: zählt nicht.
            KoerperwertD(datum: tag == "2026-10-02" ? "2026-10-01" : tag, art: .taille, wert: 80, geloescht: nil)
        }
        XCTAssertEqual(reihe.map(\.tag), ["2026-10-01", "2026-10-03"])
    }

    func testTopSortiertUndSummiert() {
        let top = EssenAuswertungLogik.top([eintrag("2026-10-01", "a", kcal: 100), eintrag("2026-10-02", "a", kcal: 100),
                                            eintrag("2026-10-01", "b", kcal: 150), eintrag("2026-10-01", "c", kcal: 10)], limit: 2)
        XCTAssertEqual(top.map(\.id), ["a", "b"])
        XCTAssertEqual(top[0].kcal, 200, accuracy: 0.001)
    }

    func testKernzeilen() {
        XCTAssertEqual(EssenAuswertungLogik.kalorienKernzeile(schnitt: 1850.4, imZiel: 4, tageMitEintraegen: 6), "Im Schnitt 1850 kcal, 4 von 6 Tagen im Ziel")
        XCTAssertEqual(EssenAuswertungLogik.kalorienKernzeile(schnitt: 0, imZiel: 0, tageMitEintraegen: 0), "Noch keine Einträge in diesem Zeitraum")
        let reihe = [EssenMesspunkt(tag: "2026-10-01", wert: 78.4), EssenMesspunkt(tag: "2026-10-03", wert: 79)]
        XCTAssertEqual(EssenAuswertungLogik.gewichtKernzeile(reihe), "79 kg, +0,6 kg im Zeitraum")
        XCTAssertEqual(EssenAuswertungLogik.gewichtKernzeile([]), "")
    }
}
