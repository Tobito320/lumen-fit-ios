import XCTest
@testable import LumenFit

/// Start des Moduls (Port gesetzt, doppelt starten schadet nicht) und die Demo-Saat (erfundene Trainings der letzten Wochen).
@MainActor
final class GymModulTests: XCTestCase {
    func testStartSetztDenPortUndIstIdempotent() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.umgebung.trainingSteuerung = KeineTrainingSteuerung()
        GymModul.start(a.umgebung)
        let erste = a.umgebung.trainingSteuerung as? GymSitzung
        XCTAssertNotNil(erste)
        GymModul.start(a.umgebung)
        XCTAssertTrue((a.umgebung.trainingSteuerung as? GymSitzung) === erste)
    }

    func testDemoSaatLegtPlanUndVergangeneTrainingsAnOhneHeute() throws {
        XCTAssertFalse(SplitLogik.fuer(nil, tage: 3).isEmpty, "splits.json muss im App-Bundle liegen")
        let a = try GymTestAufbau(ordner: try tempOrdner())
        GymModul.demoSaat(a.umgebung)
        let t = a.daten.training
        XCTAssertFalse(t.plan.tage.isEmpty)
        XCTAssertGreaterThan(t.sessions.count, 5)
        let heute = Datum.text(a.uhr.lesen)
        XCTAssertTrue(t.sessions.allSatisfy { Datum.text($0.start) < heute })
        XCTAssertTrue(t.sessions.allSatisfy { $0.ende != nil })
        XCTAssertTrue(t.sessions.contains { $0.laeufe.contains { ($0.saetze?.isEmpty == false) } })
    }
}
