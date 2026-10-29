import XCTest
@testable import LumenFit

@MainActor
final class CsvExportTests: XCTestCase {
    private let start = TestUhr().lesen

    private func session() -> GymSession {
        let saetze = [PlanSatz(wdh: 8, kg: 60, failure: false, ok: true), PlanSatz(wdh: 6, kg: 62.5, failure: true, ok: true)]
        let lauf = UebungsLauf(plan: "p1", uebung: "beispiel-bank", start: start, ende: start.addingTimeInterval(600), fertig: true, saetze: saetze)
        return GymSession(id: "s1", tag: "push", start: start, ende: start.addingTimeInterval(3_600), laeufe: [lauf])
    }

    private func zeilen(_ csv: String) -> [String] {
        csv.replacingOccurrences(of: ProfilCsvExport.bom, with: "").components(separatedBy: "\r\n").filter { !$0.isEmpty }
    }

    func testTrainingHatKopfUndEineZeileJeSatz() {
        let csv = ProfilCsvExport.training([session()]) { $0 == "beispiel-bank" ? "Beispiel-Bankdrücken" : nil }
        XCTAssertTrue(csv.hasPrefix(ProfilCsvExport.bom), "BOM, damit deutsche Tabellenprogramme Umlaute lesen")
        XCTAssertTrue(csv.hasSuffix("\r\n"))
        let z = zeilen(csv)
        XCTAssertEqual(z.count, 3)
        XCTAssertEqual(z[0], "Datum;Beginn;Ende;Plantag;Übung;Satz;Wiederholungen;Gewicht (kg);Art;Abgehakt")
        XCTAssertEqual(z[1], "2026-09-23;12:00;13:00;push;Beispiel-Bankdrücken;1;8;60;Arbeitssatz;ja")
        XCTAssertEqual(z[2], "2026-09-23;12:00;13:00;push;Beispiel-Bankdrücken;2;6;62,5;Versagen;ja")
    }

    func testUnbekannteUebungZeigtDieKennung() {
        let z = zeilen(ProfilCsvExport.training([session()]) { _ in nil })
        XCTAssertTrue(z[1].contains(";beispiel-bank;"))
    }

    func testAufwaermsatzUndOffenerSatz() {
        let stand = [PlanSatz(wdh: 12, kg: 20, failure: false, typ: "w", ok: true), PlanSatz(wdh: 8, kg: 60, failure: false, ok: false),
                     PlanSatz(wdh: 8, kg: nil, failure: false, typ: "d", ok: true)]
        var lauf = UebungsLauf(plan: "p1", uebung: "x", start: start, ende: nil, fertig: false, saetze: nil)
        lauf.stand = stand
        let s = GymSession(id: "s2", tag: nil, start: start, ende: nil, laeufe: [lauf])
        let z = zeilen(ProfilCsvExport.training([s]) { _ in nil })
        XCTAssertTrue(z[1].hasSuffix(";12;20;Aufwärmen;ja"))
        XCTAssertTrue(z[2].hasSuffix(";8;60;Arbeitssatz;nein"))
        XCTAssertTrue(z[3].hasSuffix(";8;;Dropsatz;ja"), "ohne Gewicht bleibt das Feld leer")
        XCTAssertTrue(z[1].hasPrefix("2026-09-23;12:00;;;"), "laufende Einheit ohne Ende und ohne Plantag")
    }

    func testEinheitenSindNachBeginnSortiert() {
        var spaeter = session()
        spaeter.id = "s0"
        spaeter.start = start.addingTimeInterval(86_400)
        let z = zeilen(ProfilCsvExport.training([spaeter, session()]) { _ in nil })
        XCTAssertTrue(z[1].hasPrefix("2026-09-23"))
        XCTAssertTrue(z[3].hasPrefix("2026-09-24"))
    }

    func testEssenMitNaehrwerten() {
        let hafer = TestDaten.haferflocken
        let mittag = EssenEintrag(id: "b", datum: "2026-09-23", mahlzeit: .mittag, menge: 1, einheit: .portion, lebensmittel: hafer, geloescht: nil)
        let fruehstueck = EssenEintrag(id: "a", datum: "2026-09-23", mahlzeit: .fruehstueck, menge: 60, einheit: .g, lebensmittel: hafer, geloescht: nil)
        let weg = EssenEintrag(id: "c", datum: "2026-09-23", mahlzeit: .snack, menge: 10, einheit: .g, lebensmittel: hafer, geloescht: true)
        let frueher = EssenEintrag(id: "d", datum: "2026-09-22", mahlzeit: .abend, menge: 100, einheit: .g, lebensmittel: hafer, geloescht: nil)
        let z = zeilen(ProfilCsvExport.essen([mittag, fruehstueck, weg, frueher]))
        XCTAssertEqual(z.count, 4, "Kopf und drei Einträge, der gelöschte fehlt")
        XCTAssertEqual(z[0], "Datum;Mahlzeit;Lebensmittel;Marke;Menge;Einheit;kcal;Protein (g);Kohlenhydrate (g);Fett (g)")
        XCTAssertTrue(z[1].hasPrefix("2026-09-22;Abendessen;Beispiel-Haferflocken;;100;g;370;13;59;7"))
        XCTAssertEqual(z[2], "2026-09-23;Frühstück;Beispiel-Haferflocken;;60;g;222;7,8;35,4;4,2")
        XCTAssertTrue(z[3].contains(";Mittagessen;"))
    }

    func testEscapingUndFormelSchutz() {
        XCTAssertEqual(ProfilCsvExport.feld("Hafer; fein"), "\"Hafer; fein\"")
        XCTAssertEqual(ProfilCsvExport.feld("Der \"Beste\""), "\"Der \"\"Beste\"\"\"")
        XCTAssertEqual(ProfilCsvExport.feld("zwei\nZeilen"), "\"zwei\nZeilen\"")
        XCTAssertEqual(ProfilCsvExport.feld("=SUMME(A1)"), "'=SUMME(A1)", "eine Formel wird zu Text")
        XCTAssertEqual(ProfilCsvExport.feld("@cmd"), "'@cmd")
        XCTAssertEqual(ProfilCsvExport.feld("-Haferbrei"), "'-Haferbrei")
        XCTAssertEqual(ProfilCsvExport.feld("-1,5"), "-1,5", "eine negative Zahl bleibt eine Zahl")
        XCTAssertEqual(ProfilCsvExport.feld("normal"), "normal")
    }

    func testZahlenMitKomma() {
        XCTAssertEqual(ProfilCsvExport.zahl(60), "60")
        XCTAssertEqual(ProfilCsvExport.zahl(62.5), "62,5")
        XCTAssertEqual(ProfilCsvExport.zahl(0.333), "0,33")
        XCTAssertEqual(ProfilCsvExport.zahl(1_234.5), "1234,5")
        XCTAssertEqual(ProfilCsvExport.zahl(.nan), "")
    }

    func testAusEchtenOpsDesProfils() throws {
        let (_, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let sessions = daten.training.sessions
        let csv = ProfilCsvExport.training(sessions) { UebungsKatalog.nachId[$0]?.name }
        XCTAssertEqual(zeilen(csv).count, 3, "Kopf und die zwei Sätze der Einheit")
        let essen = ProfilCsvExport.essen(daten.essen.tage.sorted().flatMap { daten.essen.eintraege($0) })
        XCTAssertEqual(zeilen(essen).count, 2)
        XCTAssertEqual(ProfilCsvExport.dateiname("training", jetzt: start), "lumenfit-training-2026-09-23.csv")
    }
}
