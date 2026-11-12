import HealthKit
import XCTest
@testable import LumenFit

/// Health-Blatt je Typ nur einmal für immer (Wunsch 12.11.2026).
final class HealthFrageGedaechtnisTests: XCTestCase {
    private func ablage() -> UserDefaults {
        let name = "health-gedaechtnis-\(UUID().uuidString)"
        let a = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return a
    }

    func testGemerktBleibtGemerkt() {
        let a = ablage()
        let k = HealthFrageGedaechtnis.lesen(HKObjectType.workoutType())
        XCTAssertFalse(HealthFrageGedaechtnis.gefragt(k, ablage: a))
        HealthFrageGedaechtnis.merke([k], ablage: a)
        XCTAssertTrue(HealthFrageGedaechtnis.gefragt(k, ablage: a))
        // Lesen und Schreiben desselben Typs sind getrennte Fragen.
        XCTAssertFalse(HealthFrageGedaechtnis.gefragt(HealthFrageGedaechtnis.schreiben(HKObjectType.workoutType()), ablage: a))
    }

    func testAltbestandNurBeimErstenMal() {
        let a = ablage()
        HealthFrageGedaechtnis.uebernimmAltbestand(HealthFrageGedaechtnis.alleKennungen(fuer: [.gewicht]), ablage: a)
        XCTAssertTrue(HealthFrageGedaechtnis.gefragt(HealthFrageGedaechtnis.lesen(HKQuantityType(.bodyMass)), ablage: a))
        XCTAssertTrue(HealthFrageGedaechtnis.gefragt(HealthFrageGedaechtnis.schreiben(HKQuantityType(.bodyMass)), ablage: a))
        XCTAssertTrue(HealthFrageGedaechtnis.gefragt(HealthFrageGedaechtnis.schreiben(HKObjectType.workoutType()), ablage: a))
        // Später gewählte Bereiche werden nicht nachträglich als gefragt übernommen: das Blatt kommt für sie genau einmal.
        HealthFrageGedaechtnis.uebernimmAltbestand(HealthFrageGedaechtnis.alleKennungen(fuer: [.schlaf]), ablage: a)
        XCTAssertFalse(HealthFrageGedaechtnis.gefragt(HealthFrageGedaechtnis.lesen(HKCategoryType(.sleepAnalysis)), ablage: a))
    }
}
