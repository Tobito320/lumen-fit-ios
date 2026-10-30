// Quelle: Lovea Health/SchritteAnsichten.swift, Health/SchlafCard.swift
import Foundation

/// Die Rechnung hinter den Vergleichsansichten mit dem Partner (Schritte-Woche, "Ihr beide" im Schlaf, Personenpunkte). Rein und ohne Oberfläche testbar.
/// Der Partner kommt nur mit dem, was er freigegeben hat und was in der Datei steht; sonst fehlt der Wert (nie 0).
enum PartnerVergleich {
    /// Ein Tag des Schritte-Vergleichs: `mein` und `sein` sind nil ohne Wert.
    struct SchrittTag: Identifiable, Equatable, Sendable {
        var tag: String
        var kuerzel: String
        var mein: Int?
        var sein: Int?
        var zukunft: Bool
        var id: String { tag }

        /// Mein Wert minus seiner, nur wenn beide da sind (positiv: ich liege vorn).
        var differenz: Int? { mein.flatMap { m in sein.map { m - $0 } } }
    }

    struct SchrittWoche: Equatable, Sendable {
        var tage: [SchrittTag]
        var meinGesamt: Int
        var seinGesamt: Int
        var differenz: Int { meinGesamt - seinGesamt }
        /// Der höchste Tageswert beider (mindestens 1), die Länge der Balken.
        var hoechster: Int { max(tage.flatMap { [$0.mein, $0.sein].compactMap { $0 } }.max() ?? 0, 1) }
    }

    /// Die Schritte der Partnerin oder des Partners je Tag der laufenden Woche. Ohne Wochenwerte zählt der Wert von heute.
    static func partnerSchritte(_ datei: ZusammenfassungDatei) -> [String: Int] {
        guard datei.freigaben.contains(.schritte) else { return [:] }
        var werte = datei.heute.schritteWoche ?? [:]
        if let s = datei.heute.schritte, werte[datei.heute.tag] == nil { werte[datei.heute.tag] = s }
        return werte
    }

    /// Nil, wenn der Partner keine Schritte freigibt oder keinen einzigen Wert in der Woche hat.
    static func schritteWoche(heute: String, mein: [String: Int], datei: ZusammenfassungDatei) -> SchrittWoche? {
        let sein = partnerSchritte(datei)
        let woche = HabitLogik.wochenTage(heute: heute)
        guard woche.contains(where: { sein[$0] != nil }) else { return nil }
        let tage = woche.enumerated().map { index, tag in
            let zukunft = tag > heute
            return SchrittTag(tag: tag, kuerzel: HabitLogik.wochentagKuerzel[index], mein: zukunft ? nil : mein[tag], sein: zukunft ? nil : sein[tag], zukunft: zukunft)
        }
        return SchrittWoche(tage: tage, meinGesamt: tage.compactMap(\.mein).reduce(0, +), seinGesamt: tage.compactMap(\.sein).reduce(0, +))
    }

    /// 12345 -> "12.345" (deutsche Tausenderpunkte).
    static func zahl(_ wert: Int) -> String {
        wert.formatted(.number.grouping(.automatic).locale(Locale(identifier: "de_DE")))
    }

    /// "+1.234", "−567", "±0" (deutsche Tausenderpunkte, echtes Minuszeichen).
    static func differenzText(_ d: Int) -> String {
        let betrag = zahl(abs(d))
        return d > 0 ? "+\(betrag)" : d < 0 ? "\u{2212}\(betrag)" : "\u{00B1}0"
    }

    /// Zieht den Tag zur Auswahl: das Kürzel im Diagramm findet den Tag.
    static func tag(zu kuerzel: String?, in tage: [SchrittTag]) -> SchrittTag? {
        kuerzel.flatMap { k in tage.first { $0.kuerzel == k } }
    }

    // MARK: Schlaf "Ihr beide"

    struct SchlafTag: Identifiable, Equatable, Sendable {
        var tag: String
        var kuerzel: String
        var istHeute: Bool
        var mein: Int?
        var sein: Int?
        var id: String { tag }
    }

    /// Der Schlaf des Partners je Aufwachtag der Woche; ohne Wochenwerte zählt die letzte Nacht (heute). Nur mit Freigabe schlaf.
    static func partnerSchlaf(_ datei: ZusammenfassungDatei) -> [String: Int] {
        guard datei.freigaben.contains(.schlaf) else { return [:] }
        var werte = datei.heute.schlafWoche ?? [:]
        if let m = datei.heute.schlafMinuten, werte[datei.heute.tag] == nil { werte[datei.heute.tag] = m }
        return werte
    }

    /// Sieben Tage Mo bis So; nil, wenn der Partner keinen Schlafwert in der Woche hat.
    static func schlafWoche(heute: String, mein: [String: Int], datei: ZusammenfassungDatei) -> [SchlafTag]? {
        let sein = partnerSchlaf(datei)
        let woche = HabitLogik.wochenTage(heute: heute)
        guard woche.contains(where: { sein[$0] != nil }) else { return nil }
        return woche.enumerated().map { index, tag in
            SchlafTag(tag: tag, kuerzel: HabitLogik.wochentagKuerzel[index], istHeute: tag == heute, mein: mein[tag], sein: sein[tag])
        }
    }

    /// Die Höhe eines Schlafbalkens (0 bis 1) gegen den längsten Wert der Woche; ohne Wert nil.
    static func schlafAnteil(_ minuten: Int?, hoechster: Int) -> Double? {
        minuten.map { min(1, Double($0) / Double(max(hoechster, 1))) }
    }

    /// Der längste Schlaf beider in der Woche, mindestens 60 Minuten (wie Lovea), sonst 480 ohne Werte.
    static func schlafHoechster(_ tage: [SchlafTag]) -> Int {
        let alle = tage.flatMap { [$0.mein, $0.sein].compactMap { $0 } }
        return max(alle.max() ?? 480, 60)
    }
}
