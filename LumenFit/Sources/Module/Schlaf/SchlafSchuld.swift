import Foundation

/// Idee 53, Schlafschuld über 7 Nächte gegen dein Ziel. Nur fehlende Minuten zählen: eine lange Nacht gleicht keine kurze aus
/// (anders als Loveas `schuld`, das Überschuss verrechnet; SPEC 10 und der Modulauftrag verlangen "nur fehlende Minuten").
/// Nächte ohne Daten werden übersprungen, nie als 0 gezählt.
enum SchlafSchuld {
    static let fenster = 7
    static let mindestNaechte = 3

    struct Ergebnis: Equatable, Sendable {
        /// Fehlende Minuten gegen das Ziel, summiert über die Nächte mit Daten.
        let minuten: Int
        /// Nächte mit Daten im Fenster.
        let naechte: Int
        /// Heute Abend so viele Minuten früher ins Bett; `nil`, wenn kaum Schuld da ist.
        let fruehervorschlag: Int?

        var satz: String {
            if minuten == 0 { return String(localized: "Keine Schlafschuld: Du hast dein Ziel in jeder gemessenen Nacht erreicht.") }
            if fruehervorschlag == nil { return String(localized: "Kaum Schlafschuld: \(SchlafFormat.dauer(minuten)) in den letzten \(SchlafSchuld.fenster) Tagen.") }
            return String(localized: "Schlafschuld: \(SchlafFormat.dauer(minuten)) in den letzten \(SchlafSchuld.fenster) Tagen.")
        }

        var vorschlagSatz: String? { fruehervorschlag.map { String(localized: "Heute \($0) Minuten früher ins Bett.") } }
    }

    /// Summe der fehlenden Minuten gegen das Ziel, nur Nächte unter dem Ziel zählen.
    static func minuten(nachtMinuten: [Int], ziel: Int) -> Int {
        nachtMinuten.reduce(0) { $0 + max(0, ziel - $1) }
    }

    /// Auf 15 Minuten aufgerundet, höchstens 45 (mehr auf einmal hält niemand durch); unter 15 Minuten Schuld kein Vorschlag.
    static func vorschlag(schuldMinuten: Int) -> Int? {
        guard schuldMinuten >= 15 else { return nil }
        return min(45, (schuldMinuten + 14) / 15 * 15)
    }

    /// Die 7 Tage bis einschließlich `heute`. `nil` unter 3 Nächten mit Daten oder ohne Ziel ("zu wenig Daten").
    static func berechne(naechte: [SchlafNacht], heute: String, ziel: Int) -> Ergebnis? {
        let ab = Datum.addTage(heute, -(fenster - 1))
        let werte = naechte.filter { $0.tag >= ab && $0.tag <= heute }.map(\.schlafMinuten)
        guard werte.count >= mindestNaechte, ziel > 0 else { return nil }
        let schuld = minuten(nachtMinuten: werte, ziel: ziel)
        return Ergebnis(minuten: schuld, naechte: werte.count, fruehervorschlag: vorschlag(schuldMinuten: schuld))
    }
}
