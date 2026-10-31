import SwiftUI

/// Der Aufbau der Health-Seiten. `.lovea` heißt: Aufbau, Reihenfolge, Karten und Wege wie der Health-Tab der Lovea-App
/// (`docs/theme-lovea-ansicht.md`). `.lumen` ist der heutige Aufbau aller anderen Themes. Die Wahl fällt einmal an der Wurzel
/// (`AppRootView`); jede Tab-Wurzel liest sie und entscheidet allein über ihren Aufbau, die Karten selbst kennen sie nicht.
enum LumenAufbau: Sendable, Equatable {
    case lumen, lovea

    /// Theme Lovea mit Freigabe heißt Lovea-Aufbau. Ein gespeichertes `lovea` ohne Freigabe gilt als Monochrom (`ProfilThemaWahl.wirksam`)
    /// und bekommt den heutigen Aufbau. Maßstab ist die Freigabe des Servers, nie der Name.
    static func wahl(_ gewaehlt: ThemaID, loveaErlaubt: Bool) -> LumenAufbau {
        ProfilThemaWahl.wirksam(gewaehlt, loveaErlaubt: loveaErlaubt) == .lovea ? .lovea : .lumen
    }
}

extension EnvironmentValues {
    /// Der Aufbau der Health-Seiten (gesetzt an der Wurzel der App).
    @Entry var lumenAufbau: LumenAufbau = .lumen
}
