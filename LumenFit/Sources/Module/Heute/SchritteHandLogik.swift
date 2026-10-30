// Quelle: Lovea Health/HealthModell.swift (schritteEintragen) und HealthTab.swift (SchritteEintragenBlatt)
import Foundation

/// Inhalt der Op `fit.schritte.hand`: Schritte eines Tages von Hand, wenn kein Tracker zählt.
struct SchritteHandD: Codable, Equatable, Sendable {
    var tag: String
    var anzahl: Int
}

/// Schritte von Hand. Die letzte Op je Tag gilt; mit Health und Band zählt je Tag der größte Wert (nie die Summe, alle zählen dieselben Schritte).
/// `AppUmgebung` reicht das Ergebnis als Band-Tage an den `GesundheitsStand`.
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

    /// Band-Tage plus Hand-Tage: je Tag der größere Schrittwert, die Meter bleiben die des Bands.
    static func zusammen(band: [String: BandTagOp], hand: [String: Int]) -> [BandTagOp] {
        var ergebnis = band
        for (tag, anzahl) in hand {
            if var b = ergebnis[tag] {
                b.schritte = max(b.schritte, anzahl)
                ergebnis[tag] = b
            } else {
                ergebnis[tag] = BandTagOp(tag: tag, schritte: anzahl, meter: 0)
            }
        }
        return Array(ergebnis.values)
    }
}
