import Foundation

/// Welche Seite der Gym-Tab für Bereich und laufendes Training zeigt. Die Wahl ist reine Logik (getestet); `GymTabView` setzt sie in
/// Ansichten um. Alle Seiten lesen dieselben Stores (`GymSitzung`): ein Seitenwechsel tauscht die Seite, nie den Stand.
enum GymSeite: Equatable, Sendable {
    case start, lauf
    case plan
    case fortschritt

    static func wahl(bereich: GymBereich, laeuft: Bool) -> GymSeite {
        switch bereich {
        case .training: laeuft ? .lauf : .start
        case .plaene: .plan
        case .fortschritt: .fortschritt
        case .geschafft: .start // Training laufend: "Geschafft" ist eine eigene Seite auf Heute (`GeschafftView`), nie im Gym-Tab
        }
    }
}
