// Quelle: Lovea Health/Heute/HeuteView.swift (Tagesform, TagesformLogik)
import Foundation

// Tagesform (reine Logik). Die Zahl der Energie-Bank rechnet `TagesformRechnung`; dies sind die Grundregeln, die sie mitbenutzt.

struct Tagesform: Equatable, Sendable {
    /// nil = noch gar keine Daten, dann zeigt die Karte "–".
    var akku: Int?
    var urteil: String
    var satz: String
}

/// Woher ein Schlafwert stammt. Die Rohtexte entscheiden in `TagesformRechnung.schlafSicherheit`, wie sehr man ihm traut.
enum TagesformSchlafQuelle: String, Sendable, Equatable {
    case eingetragen
    case appleWatch = "Apple Watch"
    /// Schlaf direkt vom Armband (Op `fit.band.schlaf`).
    case armband = "Armband"
    /// iPhone allein, ohne Phasen: die Dauer ist echt, aber grober.
    case iPhone = "Apple Health, wahrscheinlich"
}

enum TagesformLogik {
    static let schlafSollMinuten = 480

    /// Obergrenze aus dem Schlaf: 15 bei 0 h bis 100 beim Schlafziel.
    static func schlafGrenze(schlafMinuten: Int, schlafZiel: Int) -> Int {
        guard schlafZiel > 0 else { return 100 }
        return Int((15 + 85 * min(1, max(0, Double(schlafMinuten) / Double(schlafZiel)))).rounded())
    }

    static func urteil(_ akku: Int) -> String {
        akku >= 85 ? String(localized: "Voll geladen") : akku >= 70 ? String(localized: "Gut geladen") : akku >= 50 ? String(localized: "Halb leer") : String(localized: "Sparmodus")
    }

    /// Mittlere Erholung 0...1. Teile ohne Training fehlen in `MuskelLogik.erholung` und zählen als 100.
    static func erholungMittel(_ werte: [MuskelTeil: Int]) -> Double {
        let alle = MuskelTeil.allCases
        return Double(alle.map { werte[$0] ?? 100 }.reduce(0, +)) / Double(alle.count * 100)
    }
}
