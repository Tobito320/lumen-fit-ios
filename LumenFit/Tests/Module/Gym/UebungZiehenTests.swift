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
        XCTAssertEqual(a.daten.training.plan.tage[0].uebungen.map(\.supersatz), [nil, true, nil], "c war in keinem Paar: a und b bleiben gekoppelt")
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

    private func vier() -> TrainingsTag {
        func u(_ id: String, _ kg: Double, paar: Bool) -> PlanUebung {
            PlanUebung(id: id, uebung: "903mzG8", name: nil, saetze: [PlanSatz(wdh: 8, kg: kg, failure: false)], minuten: nil, supersatz: paar ? true : nil)
        }
        return TrainingsTag(id: "t", name: "T", wochentage: [], uebungen: [u("a", 10, paar: true), u("b", 20, paar: false), u("c", 30, paar: true), u("d", 40, paar: false)])
    }

    func testNurDieVerschobeneUebungFaelltAusIhremSupersatz() {
        let tag = vier()
        let neu = PlanEditor.verschieben(tag, von: 0, nach: 3)
        XCTAssertEqual(neu.uebungen.map(\.id), ["b", "c", "d", "a"])
        XCTAssertEqual(neu.uebungen.map(\.supersatz), [nil, true, nil, nil], "c und d bleiben gekoppelt, nur a ist raus (b damit allein)")
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: neu.uebungen.map { ($0.id, $0.saetze) }),
                       Dictionary(uniqueKeysWithValues: tag.uebungen.map { ($0.id, $0.saetze) }), "Sätze und Gewichte bleiben")
    }

    func testAbgelegtAufEinPaarLandetDavorOderDahinterNieDazwischen() {
        let tag = vier()
        let runter = PlanEditor.verschieben(tag, von: 0, nach: 2)
        XCTAssertEqual(runter.uebungen.map(\.id), ["b", "c", "d", "a"], "nach unten auf c: hinter das Paar c+d")
        XCTAssertEqual(runter.uebungen.map(\.supersatz), [nil, true, nil, nil])
        let rauf = PlanEditor.verschieben(tag, von: 3, nach: 1)
        XCTAssertEqual(rauf.uebungen.map(\.id), ["d", "a", "b", "c"], "nach oben auf b: vor das Paar a+b")
        XCTAssertEqual(rauf.uebungen.map(\.supersatz), [nil, true, nil, nil])
    }
}
