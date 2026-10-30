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

extension MessArt {
    /// Plausibler Bereich in Zehnteln (Gewicht 30 bis 249,9 kg wie im Gewichtsblatt, Körperfett 1 bis 60 %, Umfänge 10 bis 300 cm): ein Tippfehler wie 7,84 oder 7840 wird nicht gespeichert.
    var erlaubt: ClosedRange<Int> {
        switch self {
        case .gewicht: 300...2499
        case .koerperfett: 10...600
        default: 100...3000
        }
    }
}

/// Ein Wert, den das Blatt "Messung erfassen" speichern will.
struct MessWert: Equatable, Sendable {
    let art: MessArt
    let zehntel: Int
}

/// Das Blatt "Messung erfassen": aus den Textfeldern die Werte, die gespeichert werden, und die Felder, die nicht stimmen. Leere Felder bleiben unberührt.
enum MessErfassung {
    struct Ergebnis: Equatable, Sendable {
        let gueltig: [MessWert]
        let ungueltig: [MessArt]
    }

    static func pruefe(_ texte: [MessArt: String]) -> Ergebnis {
        var gueltig: [MessWert] = [], ungueltig: [MessArt] = []
        for art in MessArt.allCases {
            let roh = (texte[art] ?? "").trimmingCharacters(in: .whitespaces)
            guard !roh.isEmpty else { continue }
            if let zehntel = GewichtText.zehntel(roh), art.erlaubt.contains(zehntel) {
                gueltig.append(MessWert(art: art, zehntel: zehntel))
            } else {
                ungueltig.append(art)
            }
        }
        return Ergebnis(gueltig: gueltig, ungueltig: ungueltig)
    }

    /// Letzter Wert und die Änderung gegen den davor, z. B. "-0,4 kg seit 28.09."; nil bei weniger als zwei Punkten.
    static func aenderung(_ punkte: [MessPunkt], art: MessArt) -> String? {
        guard punkte.count >= 2, let letzter = punkte.last else { return nil }
        let davor = punkte[punkte.count - 2]
        let diff = letzter.zehntel - davor.zehntel
        let vorzeichen = diff > 0 ? "+" : diff < 0 ? "-" : ""
        let teile = davor.tag.split(separator: "-")
        let datum = teile.count == 3 ? "\(teile[2]).\(teile[1])." : davor.tag
        return "\(vorzeichen)\(abs(diff) / 10),\(abs(diff) % 10) \(art.einheit) seit \(datum)"
    }
}
