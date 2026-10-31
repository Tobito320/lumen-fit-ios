import Foundation

/// Welche Seite der Gym-Tab für Bereich, laufendes Training und Aufbau zeigt. Die Wahl ist reine Logik (getestet); `GymTabView` setzt sie in
/// Ansichten um. Beide Aufbauten lesen dieselben Stores (`GymSitzung`): ein Theme-Wechsel tauscht die Seite, nie den Stand.
enum GymSeite: Equatable, Sendable {
    case start, lauf, loveaLauf
    case plan
    case fortschritt

    static func wahl(bereich: GymBereich, laeuft: Bool, aufbau: LumenAufbau) -> GymSeite {
        switch bereich {
        case .training: laeuft ? (aufbau == .lovea ? .loveaLauf : .lauf) : .start
        case .plaene: .plan
        case .fortschritt: .fortschritt
        }
    }
}
