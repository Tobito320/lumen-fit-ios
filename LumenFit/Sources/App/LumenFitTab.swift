import Foundation

enum LumenFitTab: String, CaseIterable, Hashable, Sendable, Identifiable {
    case heute, gym, essen, schlaf, coach

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .heute: "Heute"
        case .gym: "Gym"
        case .essen: "Essen"
        case .schlaf: "Schlaf"
        case .coach: "Coach"
        }
    }

    var symbolName: String {
        switch self {
        case .heute: "sun.max.fill"
        case .gym: "dumbbell.fill"
        case .essen: "fork.knife"
        case .schlaf: "bed.double.fill"
        case .coach: "bubble.left.fill"
        }
    }

    /// Der Tab, auf dem eine Route liegt; nil für Blätter (Profil, Freunde), die über dem Tab erscheinen.
    static func fuer(_ route: Route) -> LumenFitTab? {
        switch route {
        case .heute, .gewichtEintragen, .verlauf: .heute
        case .gym, .uebung: .gym
        case .essen: .essen
        case .schlaf: .schlaf
        case .coach: .coach
        case .profil, .freund: nil
        }
    }
}
