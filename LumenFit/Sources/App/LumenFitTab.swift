import Foundation

enum LumenFitTab: String, CaseIterable, Hashable, Sendable, Identifiable {
    case heute, gym, essen, schlaf

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .heute: "Heute"
        case .gym: "Gym"
        case .essen: "Essen"
        case .schlaf: "Schlaf"
        }
    }

    var symbolName: String {
        switch self {
        case .heute: "sun.max.fill"
        case .gym: "dumbbell.fill"
        case .essen: "fork.knife"
        case .schlaf: "bed.double.fill"
        }
    }

    /// Der wählbare Bereich des Tabs; nil bei Heute (bleibt immer).
    var bereich: AppBereich? {
        switch self {
        case .gym: .gym
        case .essen: .essen
        case .schlaf: .schlaf
        case .heute: nil
        }
    }

    /// Der Tab, auf dem eine Route liegt; nil für Blätter (Profil, Freunde), die über dem Tab erscheinen.
    static func fuer(_ route: Route) -> LumenFitTab? {
        switch route {
        case .heute, .gewichtEintragen, .verlauf: .heute
        case .gym, .uebung: .gym
        case .essen: .essen
        case .schlaf: .schlaf
        case .profil, .freund: nil
        }
    }
}

extension Einstellungen {
    /// Zeigt die App diesen Tab? Heute immer.
    func zeigt(_ tab: LumenFitTab) -> Bool { tab.bereich.map(zeigt) ?? true }

    /// Zeigt die App die Seite dieser Route? Blätter (Profil, Freunde) und Heute-Seiten immer.
    func zeigt(_ route: Route) -> Bool { LumenFitTab.fuer(route).map(zeigt) ?? true }
}
