import Foundation

/// Zeit- und Zahlentexte des Schlaf-Moduls. Uhrzeiten immer nach Berliner Zeit (`Datum.kalender`), Dauern immer aus Date-Unterschieden.
enum SchlafFormat {
    private static func zweistellig(_ zahl: Int) -> String { zahl < 10 ? "0\(zahl)" : "\(zahl)" }

    /// "7 h 05 min", unter einer Stunde "45 min".
    static func dauer(_ minuten: Int) -> String {
        let m = max(0, minuten)
        return m < 60 ? "\(m) min" : "\(m / 60) h \(zweistellig(m % 60)) min"
    }

    /// "7:12" für die Heldenzahl.
    static func stundenMinuten(_ minuten: Int) -> String {
        let m = max(0, minuten)
        return "\(m / 60):\(zweistellig(m % 60))"
    }

    /// Für VoiceOver: "7 Stunden 12 Minuten".
    static func sprechDauer(_ minuten: Int) -> String {
        let m = max(0, minuten)
        let stunden = m / 60
        let rest = m % 60
        if stunden == 0 { return rest == 1 ? "1 Minute" : "\(rest) Minuten" }
        let h = stunden == 1 ? "1 Stunde" : "\(stunden) Stunden"
        return rest == 0 ? h : "\(h) \(rest == 1 ? "1 Minute" : "\(rest) Minuten")"
    }

    /// Minute des Tages (0 bis 1439) nach Berliner Uhr. Über die Zeitumstellung hinweg zählt, was die Wanduhr zeigt.
    static func minuteDesTages(_ zeit: Date) -> Int {
        let teile = Datum.kalender.dateComponents([.hour, .minute], from: zeit)
        return (teile.hour ?? 0) * 60 + (teile.minute ?? 0)
    }

    /// Bettzeit auf einer Skala, auf der Mitternacht mitten liegt: vor 12 Uhr zählt 24 Stunden dazu (00:30 liegt hinter 23:00).
    static func bettSkala(_ zeit: Date) -> Int {
        let m = minuteDesTages(zeit)
        return m < 720 ? m + 1440 : m
    }

    /// Zurück auf "HH:mm" aus der Skala von `bettSkala`.
    static func uhrzeit(skala: Int) -> String { Datum.uhrzeit(minuten: skala % 1440) }

    /// "12 min später", "1 h 05 min früher", "gleich".
    static func abstand(_ minuten: Int, mehr: String, weniger: String) -> String {
        let betrag = abs(minuten)
        guard betrag > 0 else { return "gleich" }
        return "\(dauer(betrag)) \(minuten > 0 ? mehr : weniger)"
    }

    /// "18.09." aus "2026-09-18".
    static func kurzesDatum(_ tag: String) -> String {
        let teile = tag.split(separator: "-")
        guard teile.count == 3, let monat = Int(teile[1]), let tagZahl = Int(teile[2]) else { return tag }
        return "\(zweistellig(tagZahl)).\(zweistellig(monat))."
    }

    /// Kurzer Wochentag "Mo" bis "So" für die Balken.
    static func wochentagKurz(_ tag: String) -> String {
        ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][max(1, min(7, Datum.wochentag(tag))) - 1]
    }

    /// Zahl mit deutschem Komma und fester Zahl von Nachkommastellen ("36,5").
    static func zahl(_ wert: Double, stellen: Int = 0) -> String {
        wert.formatted(.number.precision(.fractionLength(stellen)).locale(Locale(identifier: "de_DE")))
    }
}
