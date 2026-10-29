import XCTest
@testable import LumenFit

/// Coach-Frage und Hintergrund: nur ein Fehler nach dem Hintergrund wird genau einmal wiederholt (die Wache mit UIKit prüft das Gerät).
final class CoachHintergrundTests: XCTestCase {
    func testErfolgBleibtErfolg() {
        for hinten in [false, true] {
            for schon in [false, true] {
                XCTAssertEqual(CoachHintergrund.naechsterSchritt(gelungen: true, warImHintergrund: hinten, schonWiederholt: schon), .erfolg)
            }
        }
    }

    func testFehlerNachHintergrundWirdEinmalWiederholt() {
        XCTAssertEqual(CoachHintergrund.naechsterSchritt(gelungen: false, warImHintergrund: true, schonWiederholt: false), .nochmalFragen)
        XCTAssertEqual(CoachHintergrund.naechsterSchritt(gelungen: false, warImHintergrund: true, schonWiederholt: true), .fehlerZeigen, "nie zweimal")
    }

    func testFehlerImVordergrundWirdSofortGezeigt() {
        XCTAssertEqual(CoachHintergrund.naechsterSchritt(gelungen: false, warImHintergrund: false, schonWiederholt: false), .fehlerZeigen)
        XCTAssertEqual(CoachHintergrund.naechsterSchritt(gelungen: false, warImHintergrund: false, schonWiederholt: true), .fehlerZeigen)
    }
}
