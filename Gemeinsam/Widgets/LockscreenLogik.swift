// Quelle: Lovea Health/LoveaWidgets/Shared/LockscreenLogik.swift
import Foundation

/// Reine Rechnung für die Sperrbildschirm-Widgets und den Plan. Liegt in `Gemeinsam`, damit App, Widget und Tests sie erreichen.
/// Gegenüber Lovea: der "Treffen"-Teil heißt `tageBis(tag:heute:)` und zählt die Tage bis zum nächsten Trainingstag (kein Partner).
enum LockscreenLogik {
    /// Tage bis `tag`, `nil` ohne Tag oder wenn er vorbei ist (der Stand kann veraltet sein).
    static func tageBis(tag: String?, heute: String) -> Int? {
        guard let tag else { return nil }
        let tage = Datum.tageZwischen(heute, tag)
        return tage >= 0 ? tage : nil
    }

    /// "in 12 Tagen", "morgen", "heute".
    static func countdownText(tage: Int) -> String {
        switch tage {
        case 0: return String(localized: "heute")
        case 1: return String(localized: "morgen")
        default: return String(localized: "in \(tage) Tagen")
        }
    }

    /// "18.10." aus "2026-10-18", unabhängig von der Zeitzone des Geräts.
    static func datumKurz(_ tag: String) -> String {
        let teile = tag.split(separator: "-")
        guard teile.count == 3, let monat = Int(teile[1]), let tagZahl = Int(teile[2]) else { return tag }
        return "\(tagZahl).\(monat)."
    }

    /// 432 -> "7:12".
    static func schlafText(minuten: Int) -> String {
        String(format: "%d:%02d", minuten / 60, minuten % 60)
    }

    /// 4210 -> "4,2k", 950 -> "950".
    static func kurzZahl(_ wert: Int) -> String {
        wert >= 1000 ? (Double(wert) / 1000).formatted(.number.precision(.fractionLength(1)).locale(Datum.anzeigeLocale)) + "k" : "\(wert)"
    }
}
