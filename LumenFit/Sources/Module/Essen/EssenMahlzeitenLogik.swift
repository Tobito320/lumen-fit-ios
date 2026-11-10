// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (mahlzeitZeile, TagebuchAnpassenBlatt) und ErnaehrungMahlzeit.swift (tagTitel); reine Logik ohne Oberfläche
import Foundation

/// Reine Regeln für Mahlzeit-Seite, Mahlzeiten-Übersicht und "Tagebuch anpassen", getestet ohne Oberfläche.
enum EssenMahlzeitenLogik {
    /// Richtwert einer Mahlzeit in kcal: ihr Anteil am Tagesziel.
    nonisolated static func richtwert(_ m: Mahlzeit, zielKcal: Int) -> Int {
        Int((m.anteil * Double(zielKcal)).rounded())
    }

    /// Anteil für den Mini-Ring, 0 bis 1 (darüber wird gekappt); ohne Richtwert 0.
    nonisolated static func anteil(kcal: Int, richtwert: Int) -> Double {
        richtwert > 0 ? min(1, max(0, Double(kcal) / Double(richtwert))) : 0
    }

    /// "Heute", "Gestern", "Morgen" oder das Datum.
    nonisolated static func tagTitel(_ tag: String, heute: String) -> String {
        if tag == heute { return String(localized: "Heute") }
        if tag == Datum.addTage(heute, -1) { return String(localized: "Gestern") }
        if tag == Datum.addTage(heute, 1) { return String(localized: "Morgen") }
        return Datum.anzeige(tag)
    }

    /// Ganze Zahl mit deutschem Tausenderpunkt.
    nonisolated static func zahl(_ n: Int) -> String { n.formatted(.number.locale(Locale(identifier: "de_DE"))) }

    /// Namen der Lebensmittel einer Mahlzeit für die Untertitelzeile.
    nonisolated static func namenZeile(_ eintraege: [EssenEintrag]) -> String {
        eintraege.map(\.lebensmittel.name).joined(separator: ", ")
    }

    // MARK: Tagebuch anpassen

    nonisolated static func abschnittTitel(_ id: String) -> String {
        switch id {
        case "uebersicht": String(localized: "Übersicht")
        case "ernaehrung": String(localized: "Ernährung")
        case "wasser": String(localized: "Wasserzähler")
        default: String(localized: "Körperwerte")
        }
    }

    /// Gespeicherte Reihenfolge (nur bekannte Abschnitte), neue hinten angehängt.
    nonisolated static func startReihenfolge(_ a: TagebuchAnpassung) -> [String] {
        let bekannt = a.reihenfolge.filter { TagebuchAnpassung.alleAbschnitte.contains($0) }
        return bekannt + TagebuchAnpassung.alleAbschnitte.filter { !bekannt.contains($0) }
    }

    /// Leere Namen fallen weg (dann gilt der Standardname).
    nonisolated static func bereinigteNamen(_ namen: [String: String]) -> [String: String] {
        namen.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Die Anpassung, wie sie gespeichert wird; `ausgeblendet` folgt der Reihenfolge.
    nonisolated static func anpassung(reihenfolge: [String], ausgeblendet: Set<String>, namen: [String: String]) -> TagebuchAnpassung {
        TagebuchAnpassung(reihenfolge: reihenfolge, ausgeblendet: reihenfolge.filter { ausgeblendet.contains($0) },
                          mahlzeitNamen: bereinigteNamen(namen))
    }

    // MARK: Körperwerte

    /// Eingabefeld eines Körperwerts: positive Zahl, sonst nil (leer bleibt unverändert).
    nonisolated static func koerperwert(_ text: String?) -> Double? {
        guard let text, let w = ErnaehrungLogik.eingabe(text), w > 0 else { return nil }
        return w
    }

    // MARK: Tages-Nährwerte

    /// Zeilen einer Mikro-Gruppe mit Menge und % der EU-Referenz; nur Werte, die es gibt.
    nonisolated static func mikroZeilen(_ summe: Naehrwerte, _ gruppe: Mikro.Gruppe) -> [NaehrstoffZeile] {
        Mikro.allCases.filter { $0.gruppe == gruppe }.compactMap { m in
            guard let wert = summe.wert(m) else { return nil }
            return NaehrstoffZeile(id: m.rawValue, name: m.name, menge: "\(ErnaehrungLogik.zahl(wert)) \(m.einheit)",
                                   prozent: AnalyseLogik.prozentReferenz(wert, m))
        }
    }

    /// Grundnährstoffe, die es gibt (Ballaststoffe, Zucker, Salz, gesättigte Fettsäuren).
    nonisolated static func grundZeilen(_ summe: Naehrwerte) -> [NaehrstoffZeile] {
        let felder: [(String, Double?)] = [(String(localized: "Ballaststoffe"), summe.ballaststoffe), (String(localized: "Zucker"), summe.zucker),
                                           (String(localized: "Salz"), summe.salz), (String(localized: "Gesättigte Fettsäuren"), summe.gesFett)]
        return felder.compactMap { name, wert in
            wert.map { NaehrstoffZeile(id: name, name: name, menge: "\(ErnaehrungLogik.zahl($0)) g", prozent: nil) }
        }
    }

    /// Einträge ohne jede Angabe zu einem Vitamin (weder ein Wert noch 0).
    nonisolated static func ohneVitamine(_ eintraege: [EssenEintrag]) -> Int {
        let vitamine = Mikro.allCases.filter { $0.gruppe == .vitamine }
        return eintraege.filter { e in !vitamine.contains { e.naehrwerte.wert($0) != nil } }.count
    }
}
