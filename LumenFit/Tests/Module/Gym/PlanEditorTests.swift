import XCTest
@testable import LumenFit

final class PlanEditorTests: XCTestCase {
    private func tag(_ id: String, _ namen: [String], tage: [Int] = []) -> TrainingsTag {
        TrainingsTag(id: id, name: id, wochentage: tage, uebungen: namen.map {
            PlanUebung(id: $0, uebung: PlanUebung.eigen, name: $0, saetze: [PlanSatz(wdh: 10, kg: nil, failure: false)], minuten: nil)
        })
    }

    func testNeuerTagIstFlexibelUndBekommtStandardName() {
        let plan = PlanEditor.neuerTag(TrainingsPlan(tage: [tag("a", [])]), name: "  ", neueId: { "neu" })
        XCTAssertEqual(plan.tage.map(\.id), ["a", "neu"])
        XCTAssertEqual(plan.tage[1].name, "Tag 2")
        XCTAssertTrue(plan.tage[1].wochentage.isEmpty)
    }

    func testNeuerTagMitName() {
        let plan = PlanEditor.neuerTag(.leer, name: " Beine ", neueId: { "x" })
        XCTAssertEqual(plan.tage.first?.name, "Beine")
    }

    func testTagWegLaesstAndereStehen() {
        let plan = PlanEditor.tagWeg(TrainingsPlan(tage: [tag("a", []), tag("b", [])]), id: "a")
        XCTAssertEqual(plan.tage.map(\.id), ["b"])
    }

    func testVerschiebenSetztReihenfolgeUndLaesstAnderePaareStehen() {
        var t = tag("a", ["u1", "u2", "u3"])
        t.uebungen[0].supersatz = true
        let neu = PlanEditor.verschieben(t, von: 2, nach: 0)
        XCTAssertEqual(neu.uebungen.map(\.id), ["u3", "u1", "u2"])
        XCTAssertEqual(neu.uebungen.map(\.supersatz), [nil, true, nil], "u3 war in keinem Paar: u1 und u2 bleiben gekoppelt")
        XCTAssertEqual(PlanEditor.verschieben(t, von: 1, nach: 1), t)
        XCTAssertEqual(PlanEditor.verschieben(t, von: 0, nach: 9), t)
    }

    func testWegLoestDieKopplungDavor() {
        var t = tag("a", ["u1", "u2", "u3"])
        t.uebungen[0].supersatz = true
        let neu = PlanEditor.weg(t, id: "u2")
        XCTAssertEqual(neu.uebungen.map(\.id), ["u1", "u3"])
        XCTAssertNil(neu.uebungen[0].supersatz)
        XCTAssertEqual(PlanEditor.weg(t, id: "gibtsNicht"), t)
    }

    func testWochentagNimmtDenTagInDenPlanUndAnDerenTagenWeg() {
        let plan = TrainingsPlan(tage: [tag("a", [], tage: [1, 3]), tag("b", [], tage: [5])])
        let neu = TrainingLogik.tagSetzen(plan, PlanEditor.wochentag(plan.tage[1], 3, an: true))
        XCTAssertEqual(neu.tage[0].wochentage, [1])
        XCTAssertEqual(neu.tage[1].wochentage, [3, 5])
        XCTAssertEqual(PlanEditor.wochentag(neu.tage[1], 5, an: false).wochentage, [3])
    }
}
