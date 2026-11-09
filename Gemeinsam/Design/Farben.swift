import SwiftUI

/// Die drei Datenbereiche, je eine Farbe wie bei Apple Fitness: Bewegen (rot), Trainieren (grün), Erholen (blau).
/// Eine Farbe heißt immer dieselbe Sache und trägt nie allein die Aussage (Symbol und Zahl stehen dabei).
enum Datenbereich: String, CaseIterable, Sendable {
    case bewegen, trainieren, erholen

    var symbolName: String {
        switch self {
        case .bewegen: "figure.run"
        case .trainieren: "figure.strengthtraining.traditional"
        case .erholen: "bed.double.fill"
        }
    }

    var name: String {
        switch self {
        case .bewegen: "Bewegen"
        case .trainieren: "Trainieren"
        case .erholen: "Erholen"
        }
    }
}

/// Farb-Tokens eines Themes in einem Modus (design.md 3.2).
struct Palette: Sendable {
    let grund: Color, flaeche: Color, text: Color, text2: Color, rand: Color, haar: Color, akzent: Color, aufAkzent: Color
}

enum LumenFarben {
    /// Hex (0xRRGGBB) als Farbe.
    static func farbe(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// Token-Zeile: grund, flaeche, text, text2, rand, haar, akzent, aufAkzent.
    typealias Tokens = (grund: UInt32, flaeche: UInt32, text: UInt32, text2: UInt32, rand: UInt32, haar: UInt32, akzent: UInt32, aufAkzent: UInt32)

    /// Ein Theme, hell und dunkel nach System (Auftrag 09.11.: "Ein theme. Dark/white. Kein wählbarer Theme."). `thema` bleibt als Parameter,
    /// weil gespeicherte Einstellungen und Widget-Snapshots noch alle `ThemaID`-Werte tragen; jeder Wert liefert dieselbe Zeile.
    static func tokens(thema: ThemaID, dunkel: Bool) -> Tokens {
        dunkel ? (0x000000, 0x1C1C1E, 0xFFFFFF, 0x98989F, 0x8E8E93, 0x2C2C2E, 0x5B9DFF, 0x0B0C0E)
               : (0xFFFFFF, 0xF2F2F7, 0x000000, 0x5E5E62, 0x8A8A8E, 0xE5E5EA, 0x0B5ED7, 0xFFFFFF)
    }

    /// Erhöhter Kontrast: `text2` wird `text`, `rand` wird `text2`, `haar` wird `rand` (design.md 3.7).
    static func palette(thema: ThemaID, dunkel: Bool, kontrastHoch: Bool) -> Palette {
        let t = tokens(thema: thema, dunkel: dunkel)
        return Palette(
            grund: farbe(t.grund), flaeche: farbe(t.flaeche), text: farbe(t.text),
            text2: farbe(kontrastHoch ? t.text : t.text2),
            rand: farbe(kontrastHoch ? t.text2 : t.rand),
            haar: farbe(kontrastHoch ? t.rand : t.haar),
            akzent: farbe(t.akzent), aufAkzent: farbe(t.aufAkzent))
    }

    /// Ring-Originale: nur auf der schwarzen Platte und als große gefüllte Flächen, nie als Text.
    static func ring(_ bereich: Datenbereich, dunkel: Bool) -> Color {
        switch bereich {
        case .bewegen: farbe(0xFA114F)
        case .trainieren: farbe(dunkel ? 0xA6FF00 : 0x2DBE4F)
        case .erholen: farbe(dunkel ? 0x00E0F0 : 0x0A9FE0)
        }
    }

    /// Tief-Varianten für Text und dünne Linien auf Flächen (Kontrast mindestens 4,5:1). Bei erhöhtem Kontrast gelten dieselben Werte.
    static func tief(_ bereich: Datenbereich, dunkel: Bool, kontrastHoch: Bool) -> Color {
        switch bereich {
        case .bewegen: farbe(dunkel ? 0xFF4F7E : 0xD00A3C)
        case .trainieren: farbe(dunkel ? 0xA6FF00 : 0x16742F)
        case .erholen: farbe(dunkel ? 0x00E0F0 : 0x00699E)
        }
    }

    nonisolated static let ringPlatte = Color(red: 0, green: 0, blue: 0)

    /// Der Lovea-Akzent aus dem App-Icon (Lovea `Color.loveaRose`, `AccentColor`): hell wie dunkel gleich. Nur für Flächen ohne Text (Schalterspur), 3,48:1 auf Weiß.
    nonisolated static let loveaRose = Color(red: 0xFF / 255, green: 0x3B / 255, blue: 0x5C / 255)
}

extension EnvironmentValues {
    @Entry var palette: Palette = LumenFarben.palette(thema: .schlicht, dunkel: false, kontrastHoch: false)
    @Entry var lumenThema: ThemaID = .schlicht
}
