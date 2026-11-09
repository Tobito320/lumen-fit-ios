import XCTest
@testable import LumenFit

/// `TrainingStore.sessions` merkt sich die abgeleiteten Einheiten bis zur nächsten gym-Op: dieselbe Antwort ohne Neuberechnung, eine frische nach jeder Op.
@MainActor
final class TrainingStoreMerkenTests: XCTestCase {
    func testSessionsFolgenJederGymOpUndBleibenSonstGleich() throws {
        let satz = DatenSatz(profil: .testA, ordner: try tempOrdner(), ereignisse: EreignisKanal(), uhr: { Date() })
        XCTAssertTrue(satz.training.sessions.isEmpty)
        let id = satz.training.einchecken(tag: nil)
        XCTAssertEqual(satz.training.sessions.map(\.id), [id], "die neue Op macht den gemerkten Stand ungültig")
        XCTAssertNil(satz.training.sessions.first?.ende)
        satz.training.auschecken(id)
        XCTAssertNotNil(satz.training.sessions.first?.ende)
        satz.raum.senden("fit.test", ["a": 1])   // eine fremde Op ändert an den Einheiten nichts
        XCTAssertEqual(satz.training.sessions.map(\.id), [id])
    }
}
