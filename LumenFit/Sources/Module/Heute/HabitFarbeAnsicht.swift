// Quelle: Lovea Health/HealthStil.swift (Habit-Farben)
import SwiftUI
import UIKit

extension HabitFarbe {
    /// Im hellen Modus dunkler (mindestens 3:1 auf Weiß für Symbole), im dunklen heller.
    var farbe: Color {
        let hex: (hell: UInt32, dunkel: UInt32) = switch self {
        case .mint: (0x0F9D7A, 0x3DDBB0)
        case .amber: (0xC77800, 0xFFB340)
        case .indigo: (0x4B4FD1, 0x8E91FF)
        case .rose: (0xD6336C, 0xFF7AA8)
        case .himmel: (0x1C7FD6, 0x5AC8FA)
        case .limette: (0x5E9E00, 0xA6E22E)
        case .koralle: (0xE0533D, 0xFF8A70)
        case .grau: (0x6E6E73, 0xAEAEB2)
        }
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? Self.uiFarbe(hex.dunkel) : Self.uiFarbe(hex.hell) })
    }

    private static func uiFarbe(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Habit {
    var tint: Color { HabitFarbe.von(farbe).farbe }
}

extension Color {
    /// Zeichen auf gefüllter Habit-Farbe: Weiß auf den dunkleren hellen Tönen, Schwarz auf den hellen des dunklen Modus.
    static let aufHabitFarbe = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
}
