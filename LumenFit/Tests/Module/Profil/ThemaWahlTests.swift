import SwiftUI
import XCTest
@testable import LumenFit

@MainActor
final class ThemaWahlTests: XCTestCase {
    func testStandardIstMonochromUndSystem() {
        let e = Einstellungen()
        XCTAssertEqual(e.thema, .monochrom)
        XCTAssertEqual(e.erscheinung, .system)
    }

    func testGraphitUndGlutWaehlenEinmaligDunkelVor() {
        for thema in [ThemaID.graphit, .glut] {
            let neu = ProfilThemaWahl.waehle(thema, aktuell: Einstellungen())
            XCTAssertEqual(neu.thema, thema)
            XCTAssertEqual(neu.erscheinung, .dunkel, "\(thema) schaltet von System auf Dunkel")
        }
        for thema in [ThemaID.monochrom, .stahl, .wald] {
            XCTAssertEqual(ProfilThemaWahl.waehle(thema, aktuell: Einstellungen()).erscheinung, .system, "\(thema) lässt System stehen")
        }
    }

    func testDieVorwahlEntmuendigtNieEineEigeneWahl() {
        var e = Einstellungen()
        e.erscheinung = .hell
        XCTAssertEqual(ProfilThemaWahl.waehle(.graphit, aktuell: e).erscheinung, .hell, "wer Hell gewählt hat, behält Hell")

        // Einmalig: nach Graphit (Dunkel) wählt der Mensch Hell, tippt Graphit noch einmal an: bleibt Hell.
        var g = ProfilThemaWahl.waehle(.graphit, aktuell: Einstellungen())
        g.erscheinung = .hell
        XCTAssertEqual(ProfilThemaWahl.waehle(.graphit, aktuell: g).erscheinung, .hell)
        XCTAssertEqual(ProfilThemaWahl.waehle(.stahl, aktuell: g).erscheinung, .hell, "ein anderes Theme ändert die Erscheinung nie")
    }

    func testZwoelfKombinationenHabenEinePalette() {
        XCTAssertEqual(ProfilThemaWahl.kombinationen(loveaErlaubt: true).count, 12)
        XCTAssertEqual(Set(ProfilThemaWahl.kombinationen(loveaErlaubt: true).map { "\($0.thema)-\($0.dunkel)" }).count, 12)
        for (thema, dunkel) in ProfilThemaWahl.kombinationen(loveaErlaubt: true).map({ ($0.thema, $0.dunkel) }) {
            let palette = LumenFarben.palette(thema: thema, dunkel: dunkel, kontrastHoch: false)
            XCTAssertNotEqual(palette.grund, palette.text, "\(thema) \(dunkel): Text und Grund sind verschieden")
            XCTAssertNotEqual(palette.grund, palette.akzent, "\(thema) \(dunkel): Akzent und Grund sind verschieden")
            XCTAssertNotEqual(palette.grund, palette.flaeche, "\(thema) \(dunkel): Karte hebt sich vom Grund ab")
            let kontrast = LumenFarben.palette(thema: thema, dunkel: dunkel, kontrastHoch: true)
            XCTAssertEqual(kontrast.text2, kontrast.text, "erhöhter Kontrast: text2 wird text")
        }
        for thema in ThemaID.allCases {
            XCTAssertNotEqual(LumenFarben.palette(thema: thema, dunkel: false, kontrastHoch: false).grund,
                              LumenFarben.palette(thema: thema, dunkel: true, kontrastHoch: false).grund, "\(thema) hat Hell und Dunkel")
        }
    }

    func testJedesThemeHatEigenesMusterUndBeschreibung() {
        XCTAssertEqual(Set(ThemaID.allCases.map(ProfilThemaWahl.muster)).count, 6)
        for thema in ThemaID.allCases {
            XCTAssertFalse(ProfilThemaWahl.beschreibung(thema).isEmpty)
            XCTAssertFalse(thema.anzeigeName.isEmpty)
        }
    }

    func testErscheinungSystemFolgtDemSystem() {
        XCTAssertTrue(ProfilThemaWahl.istDunkel(.system, systemDunkel: true))
        XCTAssertFalse(ProfilThemaWahl.istDunkel(.system, systemDunkel: false))
        XCTAssertFalse(ProfilThemaWahl.istDunkel(.hell, systemDunkel: true))
        XCTAssertTrue(ProfilThemaWahl.istDunkel(.dunkel, systemDunkel: false))
    }

    func testDieWahlWirktSofortUndUeberlebtEinenNeustart() throws {
        let ordner = try tempOrdner()
        let kanal = EreignisKanal()
        let store = EinstellungenStore(ordner: ordner, ereignisse: kanal)
        store.werte = ProfilThemaWahl.waehle(.glut, aktuell: store.werte)
        XCTAssertEqual(store.werte.thema, .glut, "sofort, ohne Neustart")
        XCTAssertEqual(store.werte.erscheinung, .dunkel)
        XCTAssertEqual(EinstellungenStore(ordner: ordner).werte.thema, .glut, "gespeichert")
    }

    func testAlleDreiErscheinungenHabenNamen() {
        XCTAssertEqual(Erscheinung.allCases.map(\.anzeigeName), ["System", "Hell", "Dunkel"])
    }
}
