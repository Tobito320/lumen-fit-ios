// Quelle: Lovea Health/Heute/SchreibZeile.swift (EintragsChips)
import Foundation

/// Ein erkannter Eintrag als Chip in der Karte "Schreib, was war".
struct FreitextChip: Identifiable, Equatable, Sendable {
    let id: Int
    let symbol: String
    let text: String
    let eintrag: FreitextEintrag
}

enum FreitextChips {
    static func chips(_ liste: [FreitextEintrag]) -> [FreitextChip] {
        liste.enumerated().map { FreitextChip(id: $0.offset, symbol: symbol($0.element), text: text($0.element), eintrag: $0.element) }
    }

    /// Die Hinweiszeile, wenn nichts erkannt wurde.
    static let nichts = "Nichts erkannt. Schreib Uhrzeiten mit „Uhr“, Gewicht mit „kg“, Wasser mit „l“ oder „Glas“."

    static func text(_ e: FreitextEintrag) -> String {
        switch e {
        case .schlaf(let bett, let auf):
            let minuten = max(0, Int(auf.timeIntervalSince(bett) / 60))
            return "Schlaf \(Datum.uhrzeit(bett)) bis \(Datum.uhrzeit(auf)), \(minuten / 60) h \(minuten % 60) min"
        case .gewicht(let zehntel): return "Gewicht \(GewichtText.anzeige(zehntel))"
        case .wasser(let n): return "Wasser +\(n) \(n == 1 ? "Glas" : "Gläser") (\(n * Int(FreitextLogik.glasMl)) ml)"
        case .creatin(let n):
            let gramm = String(format: "%.1f", Double(n) * Habit.creatinGramm).replacingOccurrences(of: ".", with: ",")
            return "Creatin +\(n) \(n == 1 ? "Klick" : "Klicks") (\(gramm) g)"
        }
    }

    static func symbol(_ e: FreitextEintrag) -> String {
        switch e {
        case .schlaf: "bed.double.fill"
        case .gewicht: "scalemass.fill"
        case .wasser: "drop.fill"
        case .creatin: "pills.fill"
        }
    }

    /// Tageswerte der drei Zähler (Gewicht in Zehntel-kg, Wasser in Gläsern, Creatin in Klicks); 0 = nichts eingetragen.
    struct Werte: Equatable, Sendable {
        var gewicht = 0
        var wasser = 0
        var creatin = 0
    }

    /// Werte nach dem Sichern: Gewicht ersetzt, Wasser und Creatin zählen dazu. Schlaf ändert hier nichts.
    static func nachher(_ liste: [FreitextEintrag], vorher: Werte) -> Werte {
        var w = vorher
        for e in liste {
            switch e {
            case .gewicht(let z): w.gewicht = z
            case .wasser(let n): w.wasser += n
            case .creatin(let n): w.creatin += n
            case .schlaf: break
            }
        }
        return w
    }
}
