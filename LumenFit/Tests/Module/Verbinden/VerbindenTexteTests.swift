import XCTest
@testable import LumenFit

final class VerbindenTexteTests: XCTestCase {
    func testOhneLoveaUpdateSagenDieTexteDieWahrheit() {
        XCTAssertTrue(VerbindenTexte.freigabenFuss(loveaTauscht: false).contains("erst nach einem eigenen Update"))
        XCTAssertTrue(VerbindenTexte.vorschauFuss(loveaTauscht: false).contains("noch nichts"))
        XCTAssertTrue(VerbindenTexte.wunschFuss(loveaTauscht: false).contains("erst nach einem eigenen Update"))
    }

    func testMitLoveaUpdateFallenDieZusaetzeWeg() {
        XCTAssertFalse(VerbindenTexte.freigabenFuss(loveaTauscht: true).contains("Update"))
        XCTAssertFalse(VerbindenTexte.vorschauFuss(loveaTauscht: true).contains("noch nichts"))
        XCTAssertFalse(VerbindenTexte.wunschFuss(loveaTauscht: true).contains("Update"))
    }

    func testPauseTextVersprichtKeineMitteilung() {
        XCTAssertFalse(VerbindenTexte.pauseFuss.contains("Mitteilung"), "es gibt keinen geplanten Wecker (Annahme 32)")
        XCTAssertTrue(VerbindenTexte.pauseFuss.contains("Sperrbildschirm"))
    }

    func testStandHeuteIstOhneLoveaRunde() {
        XCTAssertFalse(VerbindenTexte.loveaTauschtDateien)
    }
}
