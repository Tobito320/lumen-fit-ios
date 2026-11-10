import XCTest
@testable import LumenFit

/// Kurzversion starten: der Rest des Tages ist ausgelassen, nicht gelöscht; der Plan bleibt gleich.
@MainActor
final class GymKurzStartTests: XCTestCase {
    func testKurzStartLaesstDenRestAusUndAendertDenPlanNicht() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        let plan = a.daten.training.plan
        let tag = try XCTUnwrap(plan.tag(id: "push"))
        a.sitzung.starteKurz(tag, weg: ["b"])
        XCTAssertEqual(a.sitzung.laufende?.tag, "push")
        XCTAssertEqual(a.sitzung.liste.map(\.id), ["a", "b"])
        XCTAssertFalse(a.sitzung.liste[0].ausgelassen)
        XCTAssertTrue(a.sitzung.liste[1].ausgelassen)
        XCTAssertNil(a.sitzung.neuerTag)
        XCTAssertEqual(a.daten.training.plan, plan)
    }

    func testOhneWegIstEsDerGanzeTag() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        let tag = try XCTUnwrap(a.daten.training.plan.tag(id: "push"))
        a.sitzung.starteKurz(tag, weg: [])
        XCTAssertFalse(a.sitzung.liste.contains { $0.ausgelassen })
    }
}
