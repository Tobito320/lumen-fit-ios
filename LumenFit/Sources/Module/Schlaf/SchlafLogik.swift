// Quelle: Lovea Health/SchlafSignale.swift (istWochenende, gewohnheit), Lovea Health/SchlafAutomatik.swift (mindestNacht)
import Foundation

/// Reine Auswertungen rund um bekannte Nächte. Aus Lovea kommt nur die gelernte Gewohnheit; Punktesystem, Signale, Wecker und
/// Erinnerung bleiben dort (Lumen Fit ist nur Health, SPEC 5.8).
enum SchlafLogik {
    /// Unter 3 Stunden ist es keine Nacht (Handy kurz aus, Mittagsschlaf, Uhr kaum getragen).
    static let mindestNacht = 180

    /// Eine sichere Nacht (Aufwachtag, eingeschlafen, aufgewacht).
    struct BekannteNacht: Equatable, Sendable {
        let tag: String
        let von: Date
        let bis: Date
    }

    /// Bitmaske wie bei den Food-Zielen: Montag ist Bit 0, Sonntag Bit 6; `wochentag` zählt 1 (Montag) bis 7 (Sonntag).
    static func istExtraTag(_ extraTage: Int, _ wochentag: Int) -> Bool { extraTage & (1 << (wochentag - 1)) != 0 }

    /// Ziel-Minuten für einen Wochentag: Basis, an den Extra-Tagen plus `extraMinuten` (nie unter 0).
    /// Die Ziele von Lumen Fit haben noch keine Extra-Tage (Wunsch ans Grundgerüst); bis dahin gilt `Ziele.schlafMinuten` an jedem Tag.
    static func ziel(basis: Int, extraMinuten: Int, extraTage: Int, wochentag: Int) -> Int {
        istExtraTag(extraTage, wochentag) ? max(0, basis + extraMinuten) : basis
    }

    /// Aufwachtag ist Samstag oder Sonntag.
    static func istWochenende(_ tag: String) -> Bool { Datum.wochentag(tag) >= 6 }

    /// Übliche Bett- und Aufstehzeit (Minuten ab Mitternacht): Median der letzten 14 Nächte, getrennt nach Werktag und Wochenende.
    /// Unter 3 Nächten: nichts.
    static func gewohnheit(_ naechte: [BekannteNacht], wochenende: Bool) -> (bett: Int, auf: Int)? {
        let passend = naechte.filter { istWochenende($0.tag) == wochenende }.sorted { $0.tag > $1.tag }.prefix(14)
        guard passend.count >= 3 else { return nil }
        func median(_ werte: [Int]) -> Int { werte.sorted()[werte.count / 2] }
        // Bettzeit nach Mitternacht (00:30) liegt hinter 23:00: für den Median läuft die Skala über Mitternacht.
        let bett = median(passend.map { SchlafFormat.bettSkala($0.von) }) % 1440
        return (bett, median(passend.map { SchlafFormat.minuteDesTages($0.bis) }))
    }
}
