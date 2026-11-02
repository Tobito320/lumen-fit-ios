import Foundation

/// Der eine Ort für Gewicht-Grenzen und Maß-Arten. Gewicht liegt im Gewicht-Habit, die Maße als Tageswerte unter "mass.<art>" in denselben
/// Habit-Ops (alle in Zehnteln). Das Essen-Tagebuch (`KoerperArt`, Op `koerper.setzen`) schreibt in dieselben Habit-Werte; ältere Werte aus dem Op bleiben lesbar.
enum Koerpermasse {
    /// Gewicht 30 bis 249,9 kg in Zehnteln; überall, wo ein Gewicht eingegeben wird.
    static let gewichtZehntel = 300...2499
    static let gewichtKg = 30.0...249.9

    /// Die Reihe einer Maß-Art: Habit-Werte (Zehntel) und ältere Tagebuch-Werte (Op, als Kommazahl). Am selben Tag gewinnt der Habit-Wert; nichts steht doppelt.
    static func reihe(habit: [String: Int], essen: [String: Double]) -> [String: Int] {
        var r: [String: Int] = [:]
        for (tag, wert) in essen where wert.isFinite && wert > 0 { r[tag] = Int((wert * 10).rounded()) }
        for (tag, zehntel) in habit where zehntel > 0 { r[tag] = zehntel }
        return r
    }
}

/// Messungen wie in Hevy: Gewicht ist dasselbe Gewicht wie überall in der App (Habit "gewicht"), keine zweite Datenquelle.
/// `bizeps` ist der Oberarm (gespeicherte Art, darum nicht umbenannt).
enum MessArt: String, CaseIterable, Identifiable, Sendable {
    case gewicht, koerperfett, taille, huefte, brust, schulter, bizeps, oberschenkel

    var id: String { rawValue }
    var habitId: String { self == .gewicht ? Habit.gewicht.id : "mass.\(rawValue)" }

    var titel: String {
        switch self {
        case .gewicht: "Gewicht"
        case .koerperfett: "Körperfett"
        case .taille: "Taille"
        case .huefte: "Hüfte"
        case .brust: "Brust"
        case .schulter: "Schulter"
        case .bizeps: "Oberarm"
        case .oberschenkel: "Oberschenkel"
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

    /// Plausibler Bereich in Zehnteln (Gewicht 30 bis 249,9 kg, Körperfett 1 bis 60 %, Umfänge 10 bis 300 cm): ein Tippfehler wie 7,84 oder 7840 wird nicht gespeichert.
    var erlaubt: ClosedRange<Int> {
        switch self {
        case .gewicht: Koerpermasse.gewichtZehntel
        case .koerperfett: 10...600
        default: 100...3000
        }
    }

    /// Die Art im Essen-Tagebuch; Gewicht gibt es dort nicht.
    var essenArt: KoerperArt? {
        switch self {
        case .gewicht: nil
        case .koerperfett: .koerperfett
        case .taille: .taille
        case .huefte: .huefte
        case .brust: .brust
        case .schulter: .schulter
        case .bizeps: .oberarm
        case .oberschenkel: .oberschenkel
        }
    }
}

extension KoerperArt {
    var messArt: MessArt {
        switch self {
        case .koerperfett: .koerperfett
        case .taille: .taille
        case .huefte: .huefte
        case .brust: .brust
        case .schulter: .schulter
        case .oberarm: .bizeps
        case .oberschenkel: .oberschenkel
        }
    }
}
