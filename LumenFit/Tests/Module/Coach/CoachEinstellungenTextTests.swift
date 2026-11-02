import XCTest
@testable import LumenFit

/// Die Coach-Einstellungen sagen die Wahrheit: "Wer antwortet" kennt den Server-Coach, der Datenschutztext unterscheidet beide Wege.
final class CoachEinstellungenTextTests: XCTestCase {
    func testWerAntwortetKenntDenServer() {
        XCTAssertTrue(CoachText.motorText(server: true, modellBereit: true).contains("Server"))
        XCTAssertTrue(CoachText.motorText(server: true, modellBereit: false).contains("Server"))
        XCTAssertEqual(CoachText.motorText(server: false, modellBereit: true), "Apple Intelligence auf deinem iPhone")
        XCTAssertTrue(CoachText.motorText(server: false, modellBereit: false).contains("nicht verfügbar"))
    }

    func testDatenschutzUnterscheidetDieWege() {
        let lokal = CoachText.datenschutzText(server: false)
        let entfernt = CoachText.datenschutzText(server: true)
        XCTAssertTrue(lokal.contains("auf deinem iPhone"))
        XCTAssertFalse(lokal.contains("Server"))
        XCTAssertTrue(entfernt.contains("Server"))
        XCTAssertFalse(entfernt.contains("Alle Antworten entstehen auf deinem iPhone"), "mit Server stimmt der Satz nicht")
        XCTAssertTrue(entfernt.contains("Rohdaten"))
        XCTAssertTrue(lokal.contains("Gedächtnis") && entfernt.contains("Gedächtnis"))
    }
}
