import Foundation

/// Tabellenexport (Idee 80): Training und Essen als CSV zum Teilen. Trennzeichen Semikolon, Zahlen mit Komma und ein BOM vorweg,
/// damit deutsche Tabellenprogramme Umlaute und Zahlen richtig lesen.
enum ProfilCsvExport {
    static let bom = "\u{FEFF}"
    static let trenner = ";"

    /// Eine Zeile je Satz, nach Beginn der Einheit sortiert. Aufwärmsätze und offene Sätze stehen drin und sind in Spalte "Art" und "Abgehakt" erkennbar.
    static func training(_ sessions: [GymSession], uebungName: (String) -> String?) -> String {
        var zeilen = [[String(localized: "Datum"), String(localized: "Beginn"), String(localized: "Ende"), String(localized: "Plantag"), String(localized: "Übung"), String(localized: "Satz"), String(localized: "Wiederholungen"), String(localized: "Gewicht (kg)"), String(localized: "Art"), String(localized: "Abgehakt")]]
        for session in sessions.sorted(by: { ($0.start, $0.id) < ($1.start, $1.id) }) {
            for lauf in session.laeufe {
                let name = lauf.name ?? uebungName(lauf.uebung) ?? lauf.uebung
                let saetze = lauf.stand ?? lauf.saetze ?? []
                for (i, satz) in saetze.enumerated() {
                    let datum: String = Datum.text(session.start)
                    let beginn: String = Datum.uhrzeit(session.start)
                    let ende: String = session.ende.map { Datum.uhrzeit($0) } ?? ""
                    let kg: String = satz.kg.map { zahl($0) } ?? ""
                    let abgehakt = satz.ok == false ? String(localized: "nein") : String(localized: "ja")
                    zeilen.append([datum, beginn, ende, session.tag ?? "", name, String(i + 1), String(satz.wdh), kg, art(satz), abgehakt])
                }
            }
        }
        return tabelle(zeilen)
    }

    /// Eine Zeile je Eintrag im Tagebuch, nach Tag und Mahlzeit sortiert (gelöschte Einträge fehlen schon).
    static func essen(_ eintraege: [EssenEintrag]) -> String {
        var zeilen = [[String(localized: "Datum"), String(localized: "Mahlzeit"), String(localized: "Lebensmittel"), String(localized: "Marke"), String(localized: "Menge"), String(localized: "Einheit"), "kcal", String(localized: "Protein (g)"), String(localized: "Kohlenhydrate (g)"), String(localized: "Fett (g)")]]
        let reihenfolge = Mahlzeit.allCases
        let sortiert = eintraege.filter { $0.geloescht != true }.sorted {
            ($0.datum, reihenfolge.firstIndex(of: $0.mahlzeit) ?? 0, $0.id) < ($1.datum, reihenfolge.firstIndex(of: $1.mahlzeit) ?? 0, $1.id)
        }
        for e in sortiert {
            let n = e.naehrwerte
            zeilen.append([e.datum, e.mahlzeit.name, e.lebensmittel.name, e.lebensmittel.marke ?? "", zahl(e.menge), e.einheit.rawValue,
                           zahl(n.kcal), zahl(n.protein), zahl(n.kohlenhydrate), zahl(n.fett)])
        }
        return tabelle(zeilen)
    }

    // MARK: - Bausteine

    static func art(_ satz: PlanSatz) -> String {
        if satz.typ == "w" { return String(localized: "Aufwärmen") }
        if satz.typ == "d" { return String(localized: "Dropsatz") }
        return satz.failure ? String(localized: "Versagen") : String(localized: "Arbeitssatz")
    }

    /// Höchstens zwei Nachkommastellen, ohne überflüssige Nullen, mit Komma.
    static func zahl(_ wert: Double) -> String {
        guard wert.isFinite else { return "" }
        var text = String(format: "%.2f", wert)
        while text.contains("."), text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    /// Felder mit Trenner, Anführungszeichen oder Zeilenumbruch kommen in Anführungszeichen. Ein Feld, das mit `=`, `+`, `-` oder `@` beginnt,
    /// bekommt ein Hochkomma davor (Tabellenprogramme würden es sonst als Formel lesen); Zahlen mit Minus (Komma-Schreibweise) bleiben.
    static func feld(_ text: String) -> String {
        var t = text
        if let erster = t.first, "=+@".contains(erster) || (erster == "-" && Double(t.replacingOccurrences(of: ",", with: ".")) == nil) { t = "'" + t }
        guard t.contains(trenner) || t.contains("\"") || t.contains("\n") || t.contains("\r") else { return t }
        return "\"" + t.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func tabelle(_ zeilen: [[String]]) -> String {
        bom + zeilen.map { $0.map(feld).joined(separator: trenner) }.joined(separator: "\r\n") + "\r\n"
    }

    static func dateiname(_ art: String, jetzt: Date) -> String { "lumenfit-\(art)-\(Datum.text(jetzt)).csv" }
}
