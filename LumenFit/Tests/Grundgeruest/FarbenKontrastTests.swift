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

    /// Die einzigen Paare, die unter 4,5:1 bleiben dürfen: Lovea malt sie selbst so (Systemwerte und `#FF3B5C`), das Theme gibt sie 1:1 wieder
    /// (Auftrag 30.10.: "1:1 wie Lovea", durchfallende Lovea-Werte nicht von selbst ändern). Für sie gilt die Untergrenze 3:1; alle anderen Themes und Paare bleiben streng.
    /// Zahlen: docs/theme-lovea-vergleich.md. Wer abdunkeln will, ändert die Tokens und leert diese Liste.
    private static let loveaBekannt: Set<String> = [
        "lovea hell: text2 auf grund", "lovea hell: text2 auf flaeche",
        "lovea hell: akzent auf grund", "lovea hell: akzent auf flaeche", "lovea hell: aufAkzent auf akzent",
        "lovea dunkel: aufAkzent auf akzent",
    ]

    private func grenze(_ schluessel: String) -> Double { Self.loveaBekannt.contains(schluessel) ? 3.0 : 4.5 }

    func testAlleThemesInBeidenModiHaltenDieGrenzen() {
        for thema in ThemaID.allCases {
            for dunkel in [false, true] {
                let t = LumenFarben.tokens(thema: thema, dunkel: dunkel)
                let name = "\(thema) \(dunkel ? "dunkel" : "hell")"
                for (flaeche, bezeichnung) in [(t.grund, "grund"), (t.flaeche, "flaeche")] {
                    XCTAssertGreaterThanOrEqual(kontrast(t.text, flaeche), 4.5, "\(name): text auf \(bezeichnung)")
                    XCTAssertGreaterThanOrEqual(kontrast(t.text2, flaeche), grenze("\(name): text2 auf \(bezeichnung)"), "\(name): text2 auf \(bezeichnung)")
                    XCTAssertGreaterThanOrEqual(kontrast(t.akzent, flaeche), grenze("\(name): akzent auf \(bezeichnung)"), "\(name): akzent auf \(bezeichnung)")
                    XCTAssertGreaterThanOrEqual(kontrast(t.rand, flaeche), 3.0, "\(name): rand auf \(bezeichnung)")
                }
                XCTAssertGreaterThanOrEqual(kontrast(t.aufAkzent, t.akzent), grenze("\(name): aufAkzent auf akzent"), "\(name): aufAkzent auf akzent")
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
        XCTAssertEqual(ThemaID.allCases.count, 6)
        for thema in ThemaID.allCases {
            for dunkel in [false, true] {
                let t = LumenFarben.tokens(thema: thema, dunkel: dunkel)
                XCTAssertNotEqual(t.grund, t.flaeche, "\(thema) \(dunkel)")
                XCTAssertNotEqual(t.text, t.grund, "\(thema) \(dunkel)")
            }
        }
    }
}
