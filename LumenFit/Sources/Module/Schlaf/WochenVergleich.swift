import Foundation

/// Ideen 56 und 59, Wochenübersicht und Wochen im Vergleich: die letzten 7 Tage gegen die 7 Tage davor, Wochenende gegen Werktag.
/// Eine "Woche" sind die 7 Tage bis einschließlich `heute` (nicht Montag bis Sonntag, sonst hätte der Montag nur eine Nacht).
/// Ein Tag ist der Aufwachtag; Wochenende heißt Aufwachtag Samstag oder Sonntag (wie `SchlafLogik.istWochenende`).
struct WochenVergleich: Equatable, Sendable {
    static let mindestNaechteJeSeite = 2
    /// Unter 6 Stunden gilt eine Nacht als kurz.
    static let kurzeNachtMinuten = 360

    struct Woche: Equatable, Sendable {
        let schnittMinuten: Int?
        let naechte: Int
        /// Nächte unter 6 Stunden.
        let unterSechsStunden: Int
    }

    struct Tag: Equatable, Sendable, Identifiable {
        let tag: String
        let minuten: Int?
        var id: String { tag }
    }

    /// Die sieben Tage der letzten Woche, ältester zuerst; `minuten` ist `nil` ohne Nacht.
    let tage: [Tag]
    let diese: Woche
    let letzte: Woche
    /// Diese Woche minus letzte Woche in Minuten; `nil`, wenn eine Seite unter 2 Nächte hat.
    let unterschiedMinuten: Int?
    /// Schnitt der Werktag-Nächte und der Wochenend-Nächte aus beiden Wochen; `nil` unter 2 Nächten je Seite.
    let werktagSchnitt: Int?
    let wochenendeSchnitt: Int?

    private static func schnitt(_ werte: [Int]) -> Int? {
        werte.isEmpty ? nil : Int((Double(werte.reduce(0, +)) / Double(werte.count)).rounded())
    }

    private static func woche(_ werte: [Int]) -> Woche {
        Woche(schnittMinuten: schnitt(werte), naechte: werte.count, unterSechsStunden: werte.filter { $0 < kurzeNachtMinuten }.count)
    }

    static func berechne(naechte: [SchlafNacht], heute: String) -> WochenVergleich {
        var jeTag: [String: Int] = [:]
        for n in naechte { jeTag[n.tag] = n.schlafMinuten }
        let start = Datum.addTage(heute, -6)
        let vorStart = Datum.addTage(heute, -13)
        let dieseTage = (0..<7).map { Datum.addTage(start, $0) }
        let letzteTage = (0..<7).map { Datum.addTage(vorStart, $0) }
        let diese = woche(dieseTage.compactMap { jeTag[$0] })
        let letzte = woche(letzteTage.compactMap { jeTag[$0] })
        var unterschied: Int?
        if let a = diese.schnittMinuten, let b = letzte.schnittMinuten, diese.naechte >= mindestNaechteJeSeite, letzte.naechte >= mindestNaechteJeSeite {
            unterschied = a - b
        }
        let beide = (letzteTage + dieseTage).compactMap { tag in jeTag[tag].map { (tag: tag, minuten: $0) } }
        let werktag = beide.filter { !SchlafLogik.istWochenende($0.tag) }.map(\.minuten)
        let wochenende = beide.filter { SchlafLogik.istWochenende($0.tag) }.map(\.minuten)
        let genug = werktag.count >= mindestNaechteJeSeite && wochenende.count >= mindestNaechteJeSeite
        return WochenVergleich(tage: dieseTage.map { Tag(tag: $0, minuten: jeTag[$0]) }, diese: diese, letzte: letzte, unterschiedMinuten: unterschied,
                               werktagSchnitt: genug ? schnitt(werktag) : nil, wochenendeSchnitt: genug ? schnitt(wochenende) : nil)
    }

    /// "Diese Woche schläfst du im Schnitt 22 min länger als letzte Woche."; `nil` ohne Vergleich.
    var vergleichSatz: String? {
        guard let unterschiedMinuten else { return nil }
        if abs(unterschiedMinuten) < 5 { return "Diese Woche schläfst du etwa so lang wie letzte Woche." }
        let wie = SchlafFormat.dauer(abs(unterschiedMinuten))
        return "Diese Woche schläfst du im Schnitt \(wie) \(unterschiedMinuten > 0 ? "länger" : "kürzer") als letzte Woche."
    }

    /// "Am Wochenende schläfst du im Schnitt 45 min länger als unter der Woche."; `nil` ohne Vergleich.
    var wochenendeSatz: String? {
        guard let werktagSchnitt, let wochenendeSchnitt else { return nil }
        let unterschied = wochenendeSchnitt - werktagSchnitt
        if abs(unterschied) < 5 { return "Am Wochenende schläfst du etwa so lang wie unter der Woche." }
        let wie = SchlafFormat.dauer(abs(unterschied))
        return "Am Wochenende schläfst du im Schnitt \(wie) \(unterschied > 0 ? "länger" : "kürzer") als unter der Woche."
    }
}
