// Quelle: Lovea Health/Koerper/Messungen.swift (nur MessArt; MessPunkt, MessLogik, GewichtLogik liegen im Grundgerüst, Ansichten sind neu)
import Foundation

/// Messungen wie in Hevy: Gewicht ist dasselbe Gewicht wie überall in der App (Habit "gewicht"), keine zweite Datenquelle.
/// Umfänge und Körperfett liegen als Tageswerte unter "mass.<art>" in denselben Habit-Ops. Alle Werte in Zehnteln.
enum MessArt: String, CaseIterable, Identifiable, Sendable {
    case gewicht, taille, brust, schulter, bizeps, oberschenkel, koerperfett

    var id: String { rawValue }
    var habitId: String { self == .gewicht ? Habit.gewicht.id : "mass.\(rawValue)" }

    var titel: String {
        switch self {
        case .gewicht: "Gewicht"
        case .taille: "Taille"
        case .brust: "Brust"
        case .schulter: "Schulter"
        case .bizeps: "Bizeps"
        case .oberschenkel: "Oberschenkel"
        case .koerperfett: "Körperfett"
        }
    }

    var einheit: String {
        switch self {
        case .gewicht: "kg"
        case .koerperfett: "%"
        default: "cm"
        }
    }

    /// 784 -> "78,4 kg".
    func text(_ zehntel: Int) -> String { "\(zehntel / 10),\(zehntel % 10) \(einheit)" }
}
