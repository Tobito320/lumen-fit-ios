// Quelle: Lovea Zyklus/ZyklusVorhersage.swift
import Foundation

/// Wie breit die Perioden-Vorhersage angezeigt wird (Einstellungen). -1 = automatisch.
enum ZyklusZeitraum {
    static let wahl: [(wert: Int, text: String)] = [(-1, "Automatisch"), (0, "Genau ein Tag"), (1, "± 1 Tag"), (2, "± 2 Tage"), (3, "± 3 Tage")]

    static func breite(_ wert: Int) -> Int? { wert < 0 ? nil : wert }

    /// "am 3. November" oder "3. bis 6. November" / "30. Oktober bis 2. November".
    static func text(_ r: ClosedRange<String>) -> String {
        let von = Datum.datum(r.lowerBound), bis = Datum.datum(r.upperBound)
        if r.lowerBound == r.upperBound { return "am \(tagMonat(von))" }
        let gleicherMonat = Datum.kalender.component(.month, from: von) == Datum.kalender.component(.month, from: bis)
        let anfang = gleicherMonat ? "\(Datum.kalender.component(.day, from: von))." : tagMonat(von)
        return "\(anfang) bis \(tagMonat(bis))"
    }

    /// "3. November". Fester Aufbau statt Format-Skelett, damit der Punkt sicher dasteht.
    private static func tagMonat(_ d: Date) -> String {
        let monat = d.formatted(Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone).month(.wide))
        return "\(Datum.kalender.component(.day, from: d)). \(monat)"
    }

    static let erklaerung = "Lumen Fit rechnet mit dem Median deiner letzten sechs Zyklen. Ein einzelner Ausreißer verschiebt die Vorhersage kaum. Je mehr Perioden du einträgst, desto genauer wird sie. Wie breit der Zeitraum ist, stellst du in den Zyklus-Einstellungen ein."
    static let keineVerhuetung = "Wichtig: Die Vorhersage ist eine Schätzung. Sie taugt nicht zur Verhütung."
}

/// Alltag und Periode: wenig Schlaf, ein großes Kaloriendefizit oder stark schwankendes Essen können die
/// Periode ein paar Tage verschieben. Nur Hinweis, kein Befund. Liest nur, was schon in Health steht.
enum ZyklusAlltag {
    struct Hinweis: Equatable, Sendable {
        let texte: [String]
        /// Um so viele Tage wird der Zeitraum nach hinten offener.
        let spaeter: Int
    }

    /// `schlaf14` und `schlaf60`: Minuten pro Nacht (nur Nächte mit Wert); `kcal14`: gegessene kcal der Tage mit Einträgen.
    static func hinweis(schlaf14: [Int], schlaf60: [Int], kcal14: [Double], kcalZiel: Int) -> Hinweis? {
        var texte: [String] = []
        if schlaf14.count >= 7 {
            let kurz = schnitt(schlaf14.map(Double.init))
            let lang = schlaf60.count >= 14 ? schnitt(schlaf60.map(Double.init)) : nil
            if kurz < 360 || (lang.map { kurz < $0 - 45 } ?? false) {
                texte.append("Du schläfst seit zwei Wochen weniger als sonst. Schlafmangel und Stress können die Periode ein paar Tage verschieben.")
            }
        }
        let gegessen = kcal14.filter { $0 > 0 }
        if gegessen.count >= 7 {
            let m = schnitt(gegessen)
            if kcalZiel > 0, m < Double(kcalZiel) * 0.75 {
                texte.append("Du isst seit zwei Wochen deutlich unter deinem Ziel. Ein großes Defizit kann die Periode verzögern.")
            } else if m > 0, streuung(gegessen) / m > 0.35 {
                texte.append("Dein Essen schwankt stark von Tag zu Tag. Regelmäßige Mahlzeiten helfen einem ruhigen Zyklus.")
            }
        }
        return texte.isEmpty ? nil : Hinweis(texte: texte, spaeter: 2)
    }

    private static func schnitt(_ w: [Double]) -> Double { w.reduce(0, +) / Double(max(w.count, 1)) }

    private static func streuung(_ w: [Double]) -> Double {
        let m = schnitt(w)
        return (w.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(max(w.count, 1))).squareRoot()
    }
}
