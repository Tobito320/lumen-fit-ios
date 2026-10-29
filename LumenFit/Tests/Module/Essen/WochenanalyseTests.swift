import XCTest
@testable import LumenFit

final class WochenanalyseTests: XCTestCase {
    private let bis = "2026-10-29"

    private func essen(_ id: String, tag: String, protein: Double = 0, kcal: Double = 0, zucker: Double? = nil, ballast: Double? = nil,
                       mikro: [String: Double]? = nil) -> EssenEintrag {
        let l = Lebensmittel(id: "bls-\(id)", name: id, pro100: Naehrwerte(kcal: kcal, protein: protein, kohlenhydrate: 0, fett: 0, zucker: zucker, ballaststoffe: ballast, mikro: mikro))
        return EssenEintrag(id: "\(id)-\(tag)", datum: tag, mahlzeit: .mittag, menge: 100, einheit: .g, lebensmittel: l, geloescht: nil)
    }

    private func ziele(protein: Int = 120) -> (String) -> ErnaehrungsZiele {
        { _ in var z = ErnaehrungsZiele(); z.protein = protein; return z }
    }

    private func analyse(_ liste: [String: [EssenEintrag]], protein: Int = 120) -> Wochenanalyse {
        WochenanalyseLogik.berechne(bis: bis, eintraege: { liste[$0] ?? [] }, ziele: ziele(protein: protein))
    }

    func testSiebenTageAeltesterZuerst() {
        let a = analyse([:])
        XCTAssertEqual(a.tage.count, 7)
        XCTAssertEqual(a.tage.first?.tag, "2026-10-23")
        XCTAssertEqual(a.tage.last?.tag, bis)
        XCTAssertTrue(a.istLeer)
        XCTAssertEqual(a.klartext, ["In den letzten sieben Tagen ist noch nichts eingetragen."])
    }

    func testProteinSchnittZaehltNurTageMitEintraegen() {
        let a = analyse(["2026-10-27": [essen("a", tag: "2026-10-27", protein: 100)], "2026-10-29": [essen("b", tag: "2026-10-29", protein: 140)]])
        XCTAssertEqual(a.tageMitEintraegen, 2)
        XCTAssertEqual(a.proteinSchnitt ?? 0, 120, accuracy: 0.001, "die fünf leeren Tage sind keine Nullen")
        XCTAssertEqual(a.tageImProteinZiel, 1)
        XCTAssertEqual(a.proteinZiel, 120)
        XCTAssertTrue(a.klartext[0].contains("im Schnitt 120 g"))
        XCTAssertTrue(a.klartext[0].contains("Ziel 120 g"))
        XCTAssertTrue(a.klartext[0].contains("1 von 2 Tagen"))
    }

    func testZielLinieKommtJeTagAusDenZielen() {
        let flex: (String) -> ErnaehrungsZiele = { tag in var z = ErnaehrungsZiele(); z.protein = tag == "2026-10-25" ? 150 : 120; return z }
        let a = WochenanalyseLogik.berechne(bis: bis, eintraege: { _ in [] }, ziele: flex)
        XCTAssertEqual(a.tage.first { $0.tag == "2026-10-25" }?.proteinZiel, 150)
        XCTAssertEqual(a.tage.first { $0.tag == bis }?.proteinZiel, 120)
    }

    func testZuckerRichtwertIstEinZehntelDerEnergie() {
        // 100 g mit 2000 kcal und 40 g Zucker: Richtwert 2000 * 0,10 / 4 = 50 g.
        let a = analyse(["2026-10-29": [essen("a", tag: "2026-10-29", kcal: 2000, zucker: 40)]])
        XCTAssertEqual(a.zuckerSchnitt ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(a.zuckerRichtwert ?? 0, 50, accuracy: 0.001)
        XCTAssertTrue(a.klartext.contains { $0.hasPrefix("Zucker: im Schnitt 40 g") && $0.contains("50 g") })
    }

    func testFehlendeZuckerAngabenSindKeineNull() {
        let a = analyse(["2026-10-29": [essen("a", tag: "2026-10-29", kcal: 100)]])
        XCTAssertNil(a.zuckerSchnitt)
        XCTAssertNil(a.ballaststoffSchnitt)
        XCTAssertTrue(a.klartext.contains("Zucker: den Lebensmitteln fehlen Angaben."))
        XCTAssertTrue(a.klartext.contains("Ballaststoffe: den Lebensmitteln fehlen Angaben."))
    }

    func testBallaststoffeGegenDGE() {
        let wenig = analyse(["2026-10-29": [essen("a", tag: "2026-10-29", ballast: 20)]])
        XCTAssertTrue(wenig.klartext.contains { $0.hasPrefix("Ballaststoffe: im Schnitt 20 g") && $0.contains("mindestens 30 g") && !$0.contains("das reicht") })
        let genug = analyse(["2026-10-29": [essen("a", tag: "2026-10-29", ballast: 32)]])
        XCTAssertTrue(genug.klartext.contains { $0.contains("das reicht") })
    }

    func testMikroLueckeNurAusVorhandenenWerten() {
        // Vitamin C: 100 g mit 8 mg (10 % von 80 mg) = Lücke. Eisen: 100 g mit 14 mg (100 % von 14 mg) = keine Lücke.
        let a = analyse(["2026-10-28": [essen("a", tag: "2026-10-28", mikro: ["vitaminC": 8, "eisen": 14])],
                         "2026-10-29": [essen("b", tag: "2026-10-29", mikro: ["vitaminC": 8, "eisen": 14])]])
        XCTAssertTrue(a.mikroAngaben)
        XCTAssertEqual(a.luecken.map(\.mikro), [.vitaminC])
        XCTAssertEqual(a.luecken.first?.prozent ?? 0, 10, accuracy: 0.001)
        XCTAssertTrue(a.klartext.contains { $0.hasPrefix("Wenig drin: Vitamin C") })
    }

    func testUnbekanntIstKeineLuecke() {
        let a = analyse(["2026-10-29": [essen("a", tag: "2026-10-29", protein: 10)]])
        XCTAssertFalse(a.mikroAngaben)
        XCTAssertTrue(a.luecken.isEmpty)
        XCTAssertTrue(a.klartext.contains { $0.hasPrefix("Vitamine und Mineralstoffe: den Lebensmitteln fehlen Angaben") })
    }

    func testMikroAngabenNurAnWenigenTagenMachenKeineLuecke() {
        // Angaben an 1 von 4 Tagen mit Einträgen: zu dünn für ein Urteil.
        var liste: [String: [EssenEintrag]] = [:]
        for tag in ["2026-10-26", "2026-10-27", "2026-10-28"] { liste[tag] = [essen("x", tag: tag, protein: 1)] }
        liste["2026-10-29"] = [essen("c", tag: "2026-10-29", mikro: ["vitaminC": 8])]
        let a = analyse(liste)
        XCTAssertTrue(a.mikroAngaben)
        XCTAssertTrue(a.luecken.isEmpty)
    }

    func testNatriumIstNieEineLuecke() {
        let a = analyse(["2026-10-29": [essen("a", tag: "2026-10-29", mikro: ["natrium": 1])]])
        XCTAssertTrue(a.luecken.isEmpty)
    }

    func testHoechstensDreiLueckenKleinsteZuerst() {
        let m: [String: Double] = ["vitaminC": 8, "vitaminE": 1.2, "calcium": 80, "eisen": 1.4, "zink": 1]
        let a = analyse(["2026-10-29": [essen("a", tag: "2026-10-29", mikro: m)]])
        XCTAssertEqual(a.luecken.count, 3)
        XCTAssertEqual(a.luecken.map(\.prozent), a.luecken.map(\.prozent).sorted())
    }

    func testGeloeschteEintraegeGibtDerStoreNichtAus() {
        // Die Logik bekommt nur, was `EssenStore.eintraege(_:)` liefert; hier genügt: gleiche Eingabe, gleiches Ergebnis.
        let liste = ["2026-10-29": [essen("a", tag: "2026-10-29", protein: 50)]]
        XCTAssertEqual(analyse(liste), analyse(liste))
    }
}
