import XCTest
@testable import LumenFit

@MainActor
final class UebungZiehenTests: XCTestCase {
    private func aufbau() throws -> GymTestAufbau {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        var plan = GymTestAufbau.plan(supersatz: true)
        plan.tage[0].uebungen.append(PlanUebung(id: "c", uebung: "903mzG8", name: nil, saetze: [PlanSatz(wdh: 10, kg: 10, failure: false)], minuten: nil))
        a.daten.training.planSichern(plan)
        return a
    }

    func testGezogeneUebungStehtImTrainingUndImPlanAnDerNeuenStelle() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.sitzung.verschieben("c", auf: "a")
        XCTAssertEqual(a.sitzung.liste.map(\.id), ["c", "a", "b"])
        XCTAssertEqual(a.sitzung.liste[1].fertigZahl, 1, "der Haken wandert mit der Übung")
        XCTAssertEqual(a.daten.training.plan.tage[0].uebungen.map(\.id), ["c", "a", "b"], "die Reihenfolge bleibt für das nächste Training")
        XCTAssertNil(a.daten.training.plan.tage[0].uebungen[1].supersatz, "die Kopplung löst sich wie im Plan-Editor")
        a.sitzung.verschieben("c", auf: "b")
        XCTAssertEqual(a.sitzung.liste.map(\.id), ["a", "b", "c"], "nach unten: an die Stelle der Zielübung")
    }

    func testUnbekannteOderGleicheUebungAendertNichts() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.verschieben("a", auf: "a")
        a.sitzung.verschieben("x", auf: "b")
        XCTAssertEqual(a.sitzung.liste.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(a.daten.training.plan.tage[0].uebungen[0].supersatz, true)
    }

    func testPlantagFolgtDerListeUndBehaeltUebungenOhneZeileHinten() {
        let tag = GymTestAufbau.plan().tage[0]
        var extra = tag
        extra.uebungen.append(PlanUebung(id: "z", uebung: "903mzG8", name: nil, saetze: [], minuten: nil))
        let liste = tag.uebungen.reversed().map { WorkoutUebung(planUebung: $0, saetze: $0.saetze, vorher: [], extra: false) }
        XCTAssertEqual(WorkoutLogik.tagInReihenfolge(extra, liste).uebungen.map(\.id), ["b", "a", "z"])
    }
}
