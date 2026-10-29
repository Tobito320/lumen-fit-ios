import SwiftUI
import XCTest
@testable import LumenFit

/// WCAG-2.2-Kontrast der Farb-Tokens, gleiche Paarungen und Grenzen wie `docs/research/kontrast.py`:
/// Text und Akzent 4,5:1, Rand von Bedienelementen 3:1. Die Zahlen stehen als Hex in `LumenFarben.tokens`.
final class FarbenKontrastTests: XCTestCase {
    private func linear(_ kanal: UInt32) -> Double {
        let c = Double(kanal) / 255
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private func leuchtdichte(_ hex: UInt32) -> Double {
        0.2126 * linear((hex >> 16) & 0xFF) + 0.7152 * linear((hex >> 8) & 0xFF) + 0.0722 * linear(hex & 0xFF)
    }

    private func kontrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (leuchtdichte(a), leuchtdichte(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    func testRechnerStimmtMitBekanntenWerten() {
        XCTAssertEqual(kontrast(0x000000, 0xFFFFFF), 21, accuracy: 0.001)
        XCTAssertEqual(kontrast(0x767676, 0xFFFFFF), 4.54, accuracy: 0.01)
        XCTAssertEqual(kontrast(0x808080, 0x808080), 1, accuracy: 0.0001)
    }

    func testAlleThemesInBeidenModiHaltenDieGrenzen() {
        for thema in ThemaID.allCases {
            for dunkel in [false, true] {
                let t = LumenFarben.tokens(thema: thema, dunkel: dunkel)
                let name = "\(thema) \(dunkel ? "dunkel" : "hell")"
                for (flaeche, bezeichnung) in [(t.grund, "grund"), (t.flaeche, "flaeche")] {
                    XCTAssertGreaterThanOrEqual(kontrast(t.text, flaeche), 4.5, "\(name): text auf \(bezeichnung)")
                    XCTAssertGreaterThanOrEqual(kontrast(t.text2, flaeche), 4.5, "\(name): text2 auf \(bezeichnung)")
                    XCTAssertGreaterThanOrEqual(kontrast(t.akzent, flaeche), 4.5, "\(name): akzent auf \(bezeichnung)")
                    XCTAssertGreaterThanOrEqual(kontrast(t.rand, flaeche), 3.0, "\(name): rand auf \(bezeichnung)")
                }
                XCTAssertGreaterThanOrEqual(kontrast(t.aufAkzent, t.akzent), 4.5, "\(name): aufAkzent auf akzent")
            }
        }
    }

    func testErhoehterKontrastRueckenDieStufenNachOben() {
        for thema in ThemaID.allCases {
            for dunkel in [false, true] {
                let t = LumenFarben.tokens(thema: thema, dunkel: dunkel)
                let p = LumenFarben.palette(thema: thema, dunkel: dunkel, kontrastHoch: true)
                XCTAssertEqual(p.text2, LumenFarben.farbe(t.text), "\(thema): text2 wird text")
                XCTAssertEqual(p.rand, LumenFarben.farbe(t.text2), "\(thema): rand wird text2")
                XCTAssertEqual(p.haar, LumenFarben.farbe(t.rand), "\(thema): haar wird rand")
                let normal = LumenFarben.palette(thema: thema, dunkel: dunkel, kontrastHoch: false)
                XCTAssertEqual(normal.text2, LumenFarben.farbe(t.text2))
                XCTAssertEqual(normal.akzent, LumenFarben.farbe(t.akzent))
            }
        }
    }

    func testGrundFlaecheUndTextUnterscheidenSich() {
        XCTAssertEqual(ThemaID.allCases.count, 5)
        for thema in ThemaID.allCases {
            for dunkel in [false, true] {
                let t = LumenFarben.tokens(thema: thema, dunkel: dunkel)
                XCTAssertNotEqual(t.grund, t.flaeche, "\(thema) \(dunkel)")
                XCTAssertNotEqual(t.text, t.grund, "\(thema) \(dunkel)")
            }
        }
    }
}
