import SwiftUI
import XCTest
@testable import LumenFit

@MainActor
final class ThemaWahlTests: XCTestCase {
    func testStandardIstSchlichtUndSystem() {
        let e = Einstellungen()
        XCTAssertEqual(e.thema, .schlicht)
        XCTAssertEqual(e.erscheinung, .system)
    }

    func testErscheinungSystemFolgtDemSystem() {
        XCTAssertTrue(ProfilThemaWahl.istDunkel(.system, systemDunkel: true))
        XCTAssertFalse(ProfilThemaWahl.istDunkel(.system, systemDunkel: false))
        XCTAssertFalse(ProfilThemaWahl.istDunkel(.hell, systemDunkel: true))
        XCTAssertTrue(ProfilThemaWahl.istDunkel(.dunkel, systemDunkel: false))
    }

    func testDieErscheinungWirktSofortUndUeberlebtEinenNeustart() throws {
        let ordner = try tempOrdner()
        let store = EinstellungenStore(ordner: ordner, ereignisse: EreignisKanal())
        store.aendere { $0.erscheinung = .dunkel }
        XCTAssertEqual(store.werte.erscheinung, .dunkel, "sofort, ohne Neustart")
        XCTAssertEqual(EinstellungenStore(ordner: ordner).werte.erscheinung, .dunkel, "gespeichert")
    }

    func testJedesThemeHatNochEinenNamen() {
        for thema in ThemaID.allCases { XCTAssertFalse(thema.anzeigeName.isEmpty) }
    }

    func testAlleDreiErscheinungenHabenNamen() {
        XCTAssertEqual(Erscheinung.allCases.map(\.anzeigeName), ["System", "Hell", "Dunkel"])
    }
}
