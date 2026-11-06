import XCTest
@testable import LumenFit

/// Das Postfach für Agenten: ein abgelegter Plan landet über `planSichern` im Store, nur erlaubte Arten, unlesbares bleibt liegen.
@MainActor
final class PostfachTests: XCTestCase {
    private func antwort(_ ops: String, planMelden: Bool = false) -> Data {
        Data(#"{"ops":[\#(ops)],"planMelden":\#(planMelden)}"#.utf8)
    }

    private let plan = #"{"tage":[{"id":"neu","name":"Beine","wochentage":[2],"uebungen":[]}]}"#

    func testGymPlanWirdEingespieltUndQuittiert() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        let r = PostfachLogik.anwenden(antwort(#"{"id":7,"art":"gym.plan","daten":\#(plan)}"#, planMelden: true), auf: a.daten.training)
        XCTAssertEqual(r.ids, [7])
        XCTAssertTrue(r.planMelden)
        XCTAssertEqual(a.daten.training.plan.tage.map(\.id), ["neu"])
    }

    func testUnbekannteArtUndKaputterPlanAendernNichtsUndWerdenNichtQuittiert() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        let vorher = a.daten.training.plan
        let ops = #"{"id":1,"art":"einstellung.setzen","daten":{}},{"id":2,"art":"gym.plan","daten":{"tage":"x"}}"#
        let r = PostfachLogik.anwenden(antwort(ops), auf: a.daten.training)
        XCTAssertEqual(r.ids, [])
        XCTAssertEqual(a.daten.training.plan, vorher)
        XCTAssertEqual(PostfachLogik.anwenden(Data("kaputt".utf8), auf: a.daten.training).ids, [])
    }
}
