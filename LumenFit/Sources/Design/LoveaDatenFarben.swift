import SwiftUI

/// Daten- und Diagrammfarben des Lovea-Aufbaus (Quelle: Lovea `SchlafNachtDiagramm.swift:19-39`, `ErnaehrungView.swift:41`, `HealthStil.swift`).
/// Nur im Aufbau `.lovea` benutzt; alle anderen Themes behalten Muster und Palette (nie nur Farbe: Muster und Beschriftung bleiben).
enum LoveaDaten {
    static let schlafWach = Color.orange
    static let schlafKern = Color.indigo
    static var schlafRem: Color { HabitFarbe.himmel.farbe }
    static var schlafTief: Color { Color.indigo.mix(with: .black, by: 0.4) }
    static let essen = LumenFarben.loveaEssen
    static let wasser = Color(red: 0.35, green: 0.72, blue: 1)
    static let ueber = Color.orange
    static var coach: Color { HabitFarbe.himmel.farbe }
    static let gymGruen = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)

    static func schlaf(_ phase: SchlafPhase) -> Color {
        switch phase {
        case .wach: schlafWach
        case .rem: schlafRem
        case .kern: schlafKern
        case .tief: schlafTief
        case .unbestimmt: schlafKern.opacity(0.45)
        }
    }
}

extension LumenAufbau {
    /// Im Lovea-Aufbau die Lovea-Farbe, sonst die bisherige.
    func farbe(_ lovea: @autoclosure () -> Color, sonst: Color) -> Color { self == .lovea ? lovea() : sonst }
}
