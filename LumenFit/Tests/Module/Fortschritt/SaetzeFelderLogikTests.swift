import XCTest
@testable import LumenFit

/// Die Felder "Sätze diese Woche": Pegelhöhe, Dichte, versetzte Füllung und das Blatt der Gruppe.
final class SaetzeFelderLogikTests: XCTestCase {
    func testAnteilIstSaetzeDurchZielZwischenNullUndEins() {
        XCTAssertEqual(SaetzeFelderLogik.anteil(saetze: 6, ziel: 12), 0.5)
        XCTAssertEqual(SaetzeFelderLogik.anteil(saetze: 20, ziel: 12), 1)
        XCTAssertEqual(SaetzeFelderLogik.anteil(saetze: 4.5, ziel: 9), 0.5)
        XCTAssertEqual(SaetzeFelderLogik.anteil(saetze: 5, ziel: nil), 0)
        XCTAssertEqual(SaetzeFelderLogik.anteil(saetze: 5, ziel: 0), 0)
        XCTAssertEqual(SaetzeFelderLogik.anteil(saetze: -1, ziel: 10), 0)
    }

    func testMuedeFelderSindDichterAlsErholteUndOhneTrainingLeer() {
        XCTAssertGreaterThan(SaetzeFelderLogik.dichte(.muede), SaetzeFelderLogik.dichte(.fast))
        XCTAssertGreaterThan(SaetzeFelderLogik.dichte(.fast), SaetzeFelderLogik.dichte(.erholt))
        XCTAssertEqual(SaetzeFelderLogik.dichte(nil), 0)
    }

    func testDieFelderFuellenSichNacheinander() {
        XCTAssertEqual(SaetzeFelderLogik.verzoegerung(0), 0)
        XCTAssertEqual(SaetzeFelderLogik.verzoegerung(2), 0.07, accuracy: 0.0001)
        XCTAssertLessThan(SaetzeFelderLogik.verzoegerung(8), 0.3)
    }

    func testAuswahlHatProGruppeUndTeilEineEigeneId() {
        XCTAssertEqual(KoerperAuswahl(gruppe: .ruecken, teil: .rLat).id, "ruecken.rLat")
        XCTAssertNotEqual(KoerperAuswahl(gruppe: .ruecken, teil: nil), KoerperAuswahl(gruppe: .ruecken, teil: .rLat))
        XCTAssertEqual(KoerperAuswahl(gruppe: .beine, teil: nil).id, "beine.")
    }
}
