import XCTest
@testable import LumenFit

/// Erfolge: Level aus Punkten und die Farbe der Medaillen im Raster.
final class FortErfolgeTests: XCTestCase {
    func testLevelSchwellen() {
        XCTAssertEqual(FortErfolgeLogik.level(0).index, 0)
        XCTAssertEqual(FortErfolgeLogik.level(499).index, 0)
        XCTAssertEqual(FortErfolgeLogik.level(500).index, 1)
        let eisen = FortErfolgeLogik.level(2340)
        XCTAssertEqual(eisen.index, 2)
        XCTAssertEqual(eisen.nummer, 3)
        XCTAssertEqual(eisen.naechsteAb, 3000)
        XCTAssertEqual(eisen.rest, 660)
        XCTAssertEqual(eisen.anteil, 840.0 / 1500, accuracy: 0.0001)
        let diamant = FortErfolgeLogik.level(20000)
        XCTAssertEqual(diamant.index, 5)
        XCTAssertNil(diamant.naechsteAb)
        XCTAssertNil(diamant.naechsterName)
        XCTAssertEqual(diamant.rest, 0)
        XCTAssertEqual(FortErfolgeLogik.level(-5).index, 0)
    }

    func testAbzeichenFaechernReihenAuf() {
        let abschnitte = MedaillenAnsicht.abschnitte(zeigt: { _ in true }, erreicht: [])
        let gym = abschnitte.first { $0.gruppe == .gym }
        let abzeichen = gym.map(FortErfolgeLogik.abzeichen) ?? []
        // Keine Medaille geht verloren: so viele Abzeichen wie die Seite zählt.
        XCTAssertEqual(abschnitte.flatMap(FortErfolgeLogik.abzeichen).count, MedaillenAnsicht.zaehlung(abschnitte, erreicht: []).gesamt)
        XCTAssertEqual(abzeichen.first { $0.id == "gym-10" }?.stufe, .bronze)
        XCTAssertEqual(abzeichen.first { $0.id == "gym-50" }?.stufe, .silber)
        XCTAssertEqual(abzeichen.first { $0.id == "gym-200" }?.stufe, .platin)
        XCTAssertEqual(abzeichen.first { $0.id == "erster-satz" }?.stufe, .bronze)
    }
}
