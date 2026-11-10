// Quelle: Lovea Health/HealthModell.swift (schritteEintragen) und HealthTab.swift (SchritteEintragenBlatt)
import Foundation

/// Inhalt der Op `fit.schritte.hand`: Schritte eines Tages von Hand, wenn kein Tracker zählt.
struct SchritteHandD: Codable, Equatable, Sendable {
    var tag: String
    var anzahl: Int
}

/// Schritte von Hand. Die letzte Op je Tag gilt. Seit 10.11.2026 (Besitzer: Schritte nur aus Apple Health) zählt ein Eintrag nur an einem Tag,
/// an dem Health keine Schritte hat. `AppUmgebung` reicht die Hand-Tage an den `GesundheitsStand`.
enum SchritteHandLogik {
    nonisolated static let art = "fit.schritte.hand"
    /// Obergrenze gegen Tippfehler.
    nonisolated static let hoechstens = 100_000

    /// Eingabetext zur Zahl: nur Ziffern zählen ("12.500" -> 12500); leer oder über der Obergrenze -> nil.
    static func anzahl(_ text: String) -> Int? {
        guard let n = Int(text.filter(\.isNumber)), n <= hoechstens else { return nil }
        return n
    }

    /// Letzter Wert je Tag aus den Ops (älteste zuerst).
    static func tage(ops: [Op]) -> [String: Int] {
        var ergebnis: [String: Int] = [:]
        for op in ops { if let d = op.daten(SchritteHandD.self) { ergebnis[d.tag] = max(0, d.anzahl) } }
        return ergebnis
    }

    /// Health-Tage plus Hand-Tage: Schritte und Strecke kommen aus Health; ein Eintrag von Hand füllt nur Tage, an denen Health keine Schritte hat.
    static func zusammen(health: [String: TagesWerte], hand: [String: Int]) -> [String: TagesWerte] {
        var ergebnis = health
        for (tag, anzahl) in hand where anzahl > 0 && (health[tag]?.schritte ?? 0) == 0 {
            var t = health[tag] ?? TagesWerte(tag: tag)
            t.schritte = anzahl
            ergebnis[tag] = t
        }
        return ergebnis
    }
}
