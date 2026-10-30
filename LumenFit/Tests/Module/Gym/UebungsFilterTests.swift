import XCTest
@testable import LumenFit

/// Filterblatt der Übungssuche: Zähler und Muskelliste je Körperteil.
final class UebungsFilterTests: XCTestCase {
    private func u(_ id: String, koerper: String, muskel: String) -> Uebung {
        Uebung(id: id, name: id, en: id, muskel: muskel, koerper: koerper, geraet: "Maschine", neben: [])
    }

    func testZaehlerZaehltNurGesetzteFilter() {
        XCTAssertEqual(UebungsFilterLogik.anzahl(koerper: nil, muskel: nil, geraet: nil), 0)
        XCTAssertEqual(UebungsFilterLogik.anzahl(koerper: "Brust", muskel: nil, geraet: "Kabelzug"), 2)
        XCTAssertEqual(UebungsFilterLogik.anzahl(koerper: "Brust", muskel: "Brustmuskel", geraet: "Kabelzug"), 3)
    }

    func testMuskelnGehoerenZumKoerperteilOhneDoppelte() {
        let liste = [u("a", koerper: "Brust", muskel: "Brustmuskel"), u("b", koerper: "Brust", muskel: "Brustmuskel"), u("c", koerper: "Beine", muskel: "Waden")]
        XCTAssertEqual(UebungsFilterLogik.muskeln(koerper: "Brust", in: liste), ["Brustmuskel"])
        XCTAssertEqual(UebungsFilterLogik.muskeln(koerper: nil, in: liste), ["Brustmuskel", "Waden"])
        XCTAssertEqual(UebungsFilterLogik.muskeln(koerper: "Arme", in: liste), [])
    }
}
