import XCTest
@testable import LumenFit

final class HeuteKartenLogikTests: XCTestCase {
    /// Mittwoch, 23.09.2026.
    private let heute = "2026-09-23"

    private func tag(_ id: String, _ name: String, _ wochentage: [Int], uebungen: Int = 0) -> TrainingsTag {
        TrainingsTag(id: id, name: name, wochentage: wochentage,
                     uebungen: (0..<uebungen).map { PlanUebung(id: "u\($0)", uebung: "bankdruecken", name: nil, saetze: Array(repeating: PlanSatz(wdh: 10, kg: 20, failure: false), count: 3), minuten: nil) })
    }

    func testGrussNachTageszeit() {
        XCTAssertEqual(HeuteKartenLogik.gruss(stunde: 4), "Gute Nacht")
        XCTAssertEqual(HeuteKartenLogik.gruss(stunde: 5), "Guten Morgen")
        XCTAssertEqual(HeuteKartenLogik.gruss(stunde: 10), "Guten Morgen")
        XCTAssertEqual(HeuteKartenLogik.gruss(stunde: 11), "Guten Tag")
        XCTAssertEqual(HeuteKartenLogik.gruss(stunde: 17), "Guten Abend")
        XCTAssertEqual(HeuteKartenLogik.gruss(stunde: 22), "Gute Nacht")
    }

    func testPlanWocheHeuteInDerMitte() {
        let plan = TrainingsPlan(tage: [tag("a", "Ganzkörper A", [1, 5]), tag("b", "Ganzkörper B", [3])], ruhetage: [2, 4, 6, 7])
        let w = HeuteKartenLogik.planWoche(heute: heute, plan: plan, gymTage: ["2026-09-21", "2026-09-26"])
        XCTAssertEqual(w.map(\.tag), ["2026-09-20", "2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26"])
        XCTAssertEqual(w.map(\.kuerzel), ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"])
        XCTAssertEqual(w.firstIndex(where: \.istHeute), 3)
        XCTAssertEqual(w.filter(\.zukunft).count, 3)
        XCTAssertEqual(w[1].marke, .erledigt, "Montag trainiert")
        XCTAssertEqual(w[2].marke, .ruhe)
        XCTAssertEqual(w[3].marke, .training(buchstabe: "B", name: "Ganzkörper B"))
        XCTAssertEqual(w[5].marke, .training(buchstabe: "A", name: "Ganzkörper A"))
        XCTAssertEqual(w[6].marke, .ruhe, "ein Haken in der Zukunft zählt nicht")
    }

    func testBuchstabe() {
        XCTAssertEqual(HeuteKartenLogik.buchstabe("Ganzkörper B"), "B")
        XCTAssertEqual(HeuteKartenLogik.buchstabe("Push"), "P")
        XCTAssertEqual(HeuteKartenLogik.buchstabe("oberkörper"), "O")
        XCTAssertEqual(HeuteKartenLogik.buchstabe(""), "–")
    }

    func testMinutenAufFuenfGerundetUndLeerNull() {
        XCTAssertEqual(HeuteKartenLogik.minuten(tag("a", "A", [1])), 0)
        let m = HeuteKartenLogik.minuten(tag("a", "A", [1], uebungen: 5))
        XCTAssertGreaterThan(m, 0)
        XCTAssertEqual(m % 5, 0)
    }

    func testZielWort() {
        XCTAssertEqual(HeuteKartenLogik.zielWort(.aufbauen), "Muskelaufbau")
        XCTAssertEqual(HeuteKartenLogik.zielWort(.abnehmen), "Abnehmen")
    }

    func testFortschrittsSatzNimmtDasGroesstePlus() {
        let zeilen = [
            GewichtZeile(uebungId: "a", name: "Bankdrücken", muskel: "", wochen: [], aktuell: 60, aenderung4Wochen: 5),
            GewichtZeile(uebungId: "b", name: "Beinpresse", muskel: "", wochen: [], aktuell: 120, aenderung4Wochen: 15),
            GewichtZeile(uebungId: "c", name: "Rudern", muskel: "", wochen: [], aktuell: 50, aenderung4Wochen: -5),
        ]
        XCTAssertEqual(HeuteKartenLogik.fortschrittsSatz(zeilen, ruhetag: false), "Beinpresse: +15 kg in 4 Wochen. Weiter so.")
        XCTAssertEqual(HeuteKartenLogik.fortschrittsSatz(zeilen, ruhetag: true), "Beinpresse: +15 kg in 4 Wochen. Heute wachsen die Muskeln.")
        XCTAssertNil(HeuteKartenLogik.fortschrittsSatz([zeilen[2]], ruhetag: false))
        XCTAssertNil(HeuteKartenLogik.fortschrittsSatz([], ruhetag: false))
    }

    func testAenderungZurVorwoche() {
        XCTAssertNil(HeuteKartenLogik.aenderungZurVorwoche([:]))
        XCTAssertNil(HeuteKartenLogik.aenderungZurVorwoche(["2026-09-23": 800]))
        XCTAssertEqual(HeuteKartenLogik.aenderungZurVorwoche(["2026-09-16": 830, "2026-09-23": 824]), -6)
        XCTAssertNil(HeuteKartenLogik.aenderungZurVorwoche(["2026-08-01": 830, "2026-09-23": 824]), "zu alt für die Vorwoche")
        XCTAssertEqual(HeuteKartenLogik.vorwocheText(-6), "−0,6 kg zur Vorwoche")
        XCTAssertEqual(HeuteKartenLogik.vorwocheText(12), "+1,2 kg zur Vorwoche")
    }
}
