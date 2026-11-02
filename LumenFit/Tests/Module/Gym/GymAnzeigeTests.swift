import XCTest
@testable import LumenFit

final class GymAnzeigeTests: XCTestCase {
    func testRpeSpalteIstOhneGespeicherteWahlAus() throws {
        let d = try XCTUnwrap(UserDefaults(suiteName: "gym-anzeige-\(UUID().uuidString)"))
        XCTAssertNil(d.object(forKey: GymAnzeige.rpeSpalteSchluessel))
        XCTAssertFalse(d.object(forKey: GymAnzeige.rpeSpalteSchluessel) as? Bool ?? GymAnzeige.rpeSpalteStandard)
    }

    func testGespeicherteWahlGewinntGegenDenStandard() throws {
        let d = try XCTUnwrap(UserDefaults(suiteName: "gym-anzeige-\(UUID().uuidString)"))
        d.set(true, forKey: GymAnzeige.rpeSpalteSchluessel)
        XCTAssertTrue(d.object(forKey: GymAnzeige.rpeSpalteSchluessel) as? Bool ?? GymAnzeige.rpeSpalteStandard)
    }
}
