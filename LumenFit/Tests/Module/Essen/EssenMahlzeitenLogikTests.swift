import XCTest
@testable import LumenFit

final class EssenMahlzeitenLogikTests: XCTestCase {
    func testRichtwertIstAnteilAmZiel() {
        XCTAssertEqual(EssenMahlzeitenLogik.richtwert(.fruehstueck, zielKcal: 2000), 500)
        XCTAssertEqual(EssenMahlzeitenLogik.richtwert(.snack, zielKcal: 2000), 200)
        XCTAssertEqual(EssenMahlzeitenLogik.richtwert(.mittag, zielKcal: 0), 0)
    }

    func testAnteilWirdGekappt() {
        XCTAssertEqual(EssenMahlzeitenLogik.anteil(kcal: 250, richtwert: 500), 0.5, accuracy: 0.0001)
        XCTAssertEqual(EssenMahlzeitenLogik.anteil(kcal: 900, richtwert: 500), 1)
        XCTAssertEqual(EssenMahlzeitenLogik.anteil(kcal: 100, richtwert: 0), 0)
    }

    func testTagTitel() {
        XCTAssertEqual(EssenMahlzeitenLogik.tagTitel("2026-10-29", heute: "2026-10-29"), "Heute")
        XCTAssertEqual(EssenMahlzeitenLogik.tagTitel("2026-10-28", heute: "2026-10-29"), "Gestern")
        XCTAssertEqual(EssenMahlzeitenLogik.tagTitel("2026-10-30", heute: "2026-10-29"), "Morgen")
        XCTAssertEqual(EssenMahlzeitenLogik.tagTitel("2026-10-20", heute: "2026-10-29"), Datum.anzeige("2026-10-20"))
    }

    func testZahlMitTausenderpunkt() {
        XCTAssertEqual(EssenMahlzeitenLogik.zahl(1850), "1.850")
    }

    func testStartReihenfolgeHaengtNeueAn() {
        let a = TagebuchAnpassung(reihenfolge: ["wasser", "unbekannt", "uebersicht"], ausgeblendet: [], mahlzeitNamen: [:])
        XCTAssertEqual(EssenMahlzeitenLogik.startReihenfolge(a), ["wasser", "uebersicht", "ernaehrung", "koerper"])
    }

    func testAnpassungBereinigtNamenUndFolgtReihenfolge() {
        let a = EssenMahlzeitenLogik.anpassung(reihenfolge: ["koerper", "wasser", "uebersicht", "ernaehrung"],
                                               ausgeblendet: ["wasser", "koerper"],
                                               namen: ["snack": "  ", "mittag": "Lunch"])
        XCTAssertEqual(a.ausgeblendet, ["koerper", "wasser"])
        XCTAssertEqual(a.mahlzeitNamen, ["mittag": "Lunch"])
        XCTAssertEqual(a.sichtbar, ["uebersicht", "ernaehrung"])
    }

    func testKoerperwertNurPositiv() {
        XCTAssertEqual(EssenMahlzeitenLogik.koerperwert("18,5"), 18.5)
        XCTAssertNil(EssenMahlzeitenLogik.koerperwert(""))
        XCTAssertNil(EssenMahlzeitenLogik.koerperwert("0"))
        XCTAssertNil(EssenMahlzeitenLogik.koerperwert(nil))
    }

    func testGrundZeilenNurVorhandene() {
        var n = Naehrwerte()
        XCTAssertTrue(EssenMahlzeitenLogik.grundZeilen(n).isEmpty)
        n.zucker = 12.5
        n.salz = 1
        XCTAssertEqual(EssenMahlzeitenLogik.grundZeilen(n).map(\.menge), ["12,5 g", "1 g"])
    }

    func testMikroZeilenNurVorhandene() {
        var n = Naehrwerte()
        XCTAssertTrue(EssenMahlzeitenLogik.mikroZeilen(n, .vitamine).isEmpty)
        n.mikro = [Mikro.vitaminC.rawValue: 40]
        XCTAssertEqual(EssenMahlzeitenLogik.mikroZeilen(n, .vitamine).map(\.id), [Mikro.vitaminC.rawValue])
        XCTAssertTrue(EssenMahlzeitenLogik.mikroZeilen(n, .mineralstoffe).isEmpty)
    }
}
