import XCTest
@testable import LumenFit

/// Energie und Tagesform (Woche aus dem Gefühl) und die Stufen der Sets-Hitzekarte.
final class FortEnergieSetsTests: XCTestCase {
    func testEnergieWocheMontagBisSonntag() {
        let heute = "2026-11-11"
        let werte = ["2026-11-08": 1, "2026-11-09": 3, "2026-11-10": 5, "2026-11-11": 9, "2026-11-12": 4]
        let woche = FortEnergie.woche(werte, heute: heute)
        XCTAssertEqual(woche, [3, 5, 5, nil, nil, nil, nil])
        XCTAssertEqual(FortEnergie.urteil(woche), 4)
        XCTAssertNil(FortEnergie.urteil(Array(repeating: nil, count: 7)))
    }

    func testSetsStufen() {
        XCTAssertEqual(FortSets.stufe(0), 0)
        XCTAssertEqual(FortSets.stufe(0.5), 1)
        XCTAssertEqual(FortSets.stufe(4.5), 1)
        XCTAssertEqual(FortSets.stufe(5), 2)
        XCTAssertEqual(FortSets.stufe(9.5), 2)
        XCTAssertEqual(FortSets.stufe(10), 3)
    }

    func testSetsZeileOhneZielGegenZwanzig() {
        XCTAssertEqual(FortSetsZeile(gruppe: .brust, saetze: 10, ziel: 0).anteil, 0.5)
        XCTAssertEqual(FortSetsZeile(gruppe: .brust, saetze: 10, ziel: 8).anteil, 1)
        XCTAssertTrue(FortSetsZeile(gruppe: .brust, saetze: 10, ziel: 8).erreicht)
        XCTAssertFalse(FortSetsZeile(gruppe: .brust, saetze: 10, ziel: 0).erreicht)
    }

    func testSetsZeilenHabenAlleGruppen() {
        let zeilen = FortSets.zeilen([], heute: "2026-11-11", ziele: KoerperZiele.lesen(wert: { _ in nil }))
        XCTAssertEqual(Set(zeilen.map(\.gruppe)), Set(MuskelGruppe.allCases))
        XCTAssertEqual(zeilen.count, MuskelGruppe.allCases.count)
    }
}
