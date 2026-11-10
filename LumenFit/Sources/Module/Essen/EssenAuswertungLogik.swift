// Quelle: Lovea Health/Ernaehrung/ErnaehrungAnalyse.swift:140-484 (Rechenteil der Auswertung, ohne Modell und Singletons)
import Foundation

/// Ein Makro im Schnitt des Zeitraums: Gramm je Tag mit Tagen, Ziel und Energiegewicht.
struct EssenMakroSchnitt: Equatable, Sendable, Identifiable {
    var name: String
    var gramm: Double
    var ziel: Int
    var kcalJeGramm: Double
    /// Deckkraft der Fläche im Sektor- und Legendenpunkt (Essen ist monochrom).
    var deckkraft: Double
    var id: String { name }
    var energie: Double { gramm * kcalJeGramm }
}

/// Ein Punkt einer Messreihe (Gewicht in kg, Körperwert in cm oder Prozent).
struct EssenMesspunkt: Equatable, Sendable, Identifiable {
    var tag: String
    var wert: Double
    var id: String { tag }
}

/// Eintrag der Top-Liste: Lebensmittel mit der Summe seiner Kalorien im Zeitraum.
struct EssenTopZeile: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var kcal: Double
}

/// Reine Rechnung hinter der Auswertung. Alles nimmt Werte statt des Stores, damit es ohne Oberfläche testbar ist.
enum EssenAuswertungLogik {
    /// Tagessummen, nur für Tage mit mindestens einem Eintrag (so zählt der Schnitt nur diese Tage).
    static func tagesSummen(_ eintraege: [EssenEintrag]) -> [String: Naehrwerte] {
        Dictionary(grouping: eintraege, by: \.datum).mapValues(ErnaehrungLogik.summe)
    }

    /// Kohlenhydrate, Eiweiß, Fett im Schnitt über die Tage mit Einträgen.
    static func makroSchnitte(_ summen: [String: Naehrwerte], ziele: ErnaehrungsZiele) -> [EssenMakroSchnitt] {
        [
            EssenMakroSchnitt(name: String(localized: "Kohlenhydrate"), gramm: AnalyseLogik.schnitt(summen.mapValues(\.kohlenhydrate)),
                              ziel: ziele.kohlenhydrate, kcalJeGramm: 4, deckkraft: 0.85),
            EssenMakroSchnitt(name: String(localized: "Eiweiß"), gramm: AnalyseLogik.schnitt(summen.mapValues(\.protein)),
                              ziel: ziele.protein, kcalJeGramm: 4, deckkraft: 0.55),
            EssenMakroSchnitt(name: String(localized: "Fett"), gramm: AnalyseLogik.schnitt(summen.mapValues(\.fett)),
                              ziel: ziele.fett, kcalJeGramm: 9, deckkraft: 0.3),
        ]
    }

    /// Anteil an der Gesamtenergie (0 bis 1); 0, solange nichts gegessen wurde.
    static func energieAnteil(_ m: EssenMakroSchnitt, in alle: [EssenMakroSchnitt]) -> Double {
        let gesamt = alle.reduce(0) { $0 + $1.energie }
        return gesamt > 0 ? m.energie / gesamt : 0
    }

    /// Schnitt eines optionalen Feldes, nur über Tage, an denen es einen Wert hat. nil ohne Werte.
    static func schnittOptional(_ summen: [String: Naehrwerte], _ zugriff: (Naehrwerte) -> Double?) -> Double? {
        var werte: [String: Double] = [:]
        for (tag, summe) in summen { if let w = zugriff(summe) { werte[tag] = w } }
        return werte.isEmpty ? nil : AnalyseLogik.schnitt(werte)
    }

    /// Ballaststoffe, Zucker, Salz, gesättigte Fettsäuren: nur Felder, zu denen es Angaben gibt.
    static func grundZeilen(_ summen: [String: Naehrwerte]) -> [NaehrstoffZeile] {
        let felder: [(name: String, zugriff: (Naehrwerte) -> Double?)] = [
            (String(localized: "Ballaststoffe"), { $0.ballaststoffe }),
            (String(localized: "Zucker"), { $0.zucker }),
            (String(localized: "Salz"), { $0.salz }),
            (String(localized: "Gesättigte Fettsäuren"), { $0.gesFett }),
        ]
        return felder.compactMap { feld in
            guard let schnitt = schnittOptional(summen, feld.zugriff) else { return nil }
            return NaehrstoffZeile(id: feld.name, name: feld.name, menge: "\(ErnaehrungLogik.zahl(schnitt)) g", prozent: nil)
        }
    }

    /// Vitamine oder Mineralstoffe mit EU-Referenz, in Prozent der Referenz.
    static func mikroZeilen(_ summen: [String: Naehrwerte], gruppe: Mikro.Gruppe) -> [NaehrstoffZeile] {
        Mikro.allCases.filter { $0.gruppe == gruppe && $0.referenz != nil }.compactMap { m in
            guard let schnitt = schnittOptional(summen, { $0.wert(m) }) else { return nil }
            return NaehrstoffZeile(id: m.rawValue, name: m.name, menge: "\(ErnaehrungLogik.zahl(schnitt)) \(m.einheit)",
                                   prozent: AnalyseLogik.prozentReferenz(schnitt, m))
        }
    }

    /// Gewicht in kg je Tag im Zeitraum (Zehntel-kg aus dem Gewicht-Habit), älteste zuerst. Null und Leeres fällt weg.
    static func gewichtReihe(_ quelle: [String: Int], von: String, bis: String) -> [EssenMesspunkt] {
        quelle.filter { $0.value > 0 && $0.key >= von && $0.key <= bis }
            .sorted { $0.key < $1.key }
            .map { EssenMesspunkt(tag: $0.key, wert: Double($0.value) / 10) }
    }

    /// Veränderung vom ersten zum letzten Wert in Zehntel (ganzzahlig, sonst stört Gleitkomma-Rauschen: 0,1 + 0,2).
    static func gewichtVeraenderungZehntel(_ reihe: [EssenMesspunkt]) -> Int {
        guard let erstes = reihe.first, let letztes = reihe.last else { return 0 }
        return Int((letztes.wert * 10).rounded()) - Int((erstes.wert * 10).rounded())
    }

    /// Nur echte Einträge im Zeitraum: `lesen(tag)` fortschreibt den letzten Wert, zählt hier aber nur, wenn sein Datum genau dieser Tag ist.
    static func koerperReihe(tage: [String], lesen: (String) -> KoerperwertD?) -> [EssenMesspunkt] {
        tage.compactMap { tag in
            guard let w = lesen(tag), w.datum == tag else { return nil }
            return EssenMesspunkt(tag: tag, wert: w.wert)
        }
    }

    /// Lebensmittel mit den meisten Kalorien im Zeitraum, absteigend.
    static func top(_ eintraege: [EssenEintrag], limit: Int = 10) -> [EssenTopZeile] {
        var summeJe: [String: EssenTopZeile] = [:]
        for e in eintraege {
            let id = e.lebensmittel.id
            let bisher = summeJe[id]?.kcal ?? 0
            summeJe[id] = EssenTopZeile(id: id, name: e.lebensmittel.anzeigeName, kcal: bisher + e.naehrwerte.kcal)
        }
        // gleiche Summe: nach Name, damit die Liste bei jedem Zeichnen gleich bleibt
        return Array(summeJe.values.sorted { $0.kcal != $1.kcal ? $0.kcal > $1.kcal : $0.name < $1.name }.prefix(limit))
    }

    /// Satz über der Kalorien-Grafik: "Im Schnitt 1 850 kcal, 4 von 6 Tagen im Ziel".
    static func kalorienKernzeile(schnitt: Double, imZiel: Int, tageMitEintraegen: Int) -> String {
        guard tageMitEintraegen > 0 else { return String(localized: "Noch keine Einträge in diesem Zeitraum") }
        return String(localized: "Im Schnitt \(String(Int(schnitt.rounded()))) kcal, \(imZiel) von \(tageMitEintraegen) Tagen im Ziel")
    }

    /// Satz über der Gewichts-Grafik: "78,4 kg, +0,6 kg seit Beginn".
    static func gewichtKernzeile(_ reihe: [EssenMesspunkt]) -> String {
        guard let letztes = reihe.last else { return "" }
        let diff = gewichtVeraenderungZehntel(reihe)
        let vorzeichen = diff > 0 ? "+" : diff < 0 ? "-" : ""
        return String(localized: "\(ErnaehrungLogik.zahl(letztes.wert)) kg, \(vorzeichen)\(ErnaehrungLogik.zahl(Double(abs(diff)) / 10)) kg im Zeitraum")

    }
}
