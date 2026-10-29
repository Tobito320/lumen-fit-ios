import Foundation

/// Ein Punkt der Kraftkurve: die Woche (Montag, `yyyy-MM-dd`) mit dem besten Gewicht, dem geschätzten Einer-Maximum und dem Volumen.
struct KraftPunkt: Identifiable, Equatable, Sendable {
    let woche: String
    /// Schwerster gezählter Satz der Woche in kg.
    let gewicht: Double
    /// Bester Satz nach Epley (`VerlaufLogik.e1rm`) in kg.
    let e1rm: Double
    /// Summe kg mal Wiederholungen aller gezählten Sätze der Woche.
    let volumen: Double

    var id: String { woche }
}

/// Eine Übung, die schon gemacht wurde, für die Auswahl über der Kurve.
struct KraftUebung: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// Einheiten (Trainings) mit gezählten Sätzen und Gewicht.
    let einheiten: Int
}

/// Kraftkurve je Übung (Idee 31): bestes Gewicht, 1RM nach Epley und Volumen je Woche. Aufwärmsätze zählen nie. Rein, ohne Zustand.
enum KraftKurve {
    /// So viele Wochen zeigt die Kurve höchstens.
    static let wochen = 12

    /// Die gezählten Sätze eines Laufs: ohne Aufwärmen (`typ` "w"), nur mit Gewicht über 0 und Wiederholungen über 0.
    static func arbeitssaetze(_ lauf: UebungsLauf) -> [PlanSatz] {
        guard lauf.fertig else { return [] }
        return (lauf.saetze ?? []).filter { $0.typ != "w" && ($0.kg ?? 0) > 0 && $0.wdh > 0 }
    }

    /// Je Woche mit Training in `uebung` ein Punkt, älteste zuerst, höchstens `wochen` Wochen bis `heute` zurück. Wochen ohne Training fehlen.
    static func punkte(_ sessions: [GymSession], uebung: String, heute: String, wochen: Int = KraftKurve.wochen) -> [KraftPunkt] {
        let ab = Datum.addTage(Datum.montagDerWoche(heute), -7 * (max(wochen, 1) - 1))
        var jeWoche: [String: [PlanSatz]] = [:]
        for s in sessions {
            let woche = Datum.montagDerWoche(Datum.text(s.start))
            guard woche >= ab, woche <= Datum.montagDerWoche(heute) else { continue }
            for lauf in s.laeufe where lauf.uebung == uebung { jeWoche[woche, default: []] += arbeitssaetze(lauf) }
        }
        return jeWoche.filter { !$0.value.isEmpty }.map { woche, saetze in
            KraftPunkt(woche: woche,
                       gewicht: saetze.compactMap(\.kg).max() ?? 0,
                       e1rm: saetze.compactMap(VerlaufLogik.e1rm).max() ?? 0,
                       volumen: saetze.reduce(0) { $0 + ($1.kg ?? 0) * Double($1.wdh) })
        }.sorted { $0.woche < $1.woche }
    }

    /// Übungen mit gezählten Sätzen und Gewicht, die meistgemachte zuerst, bei Gleichstand nach Name. Übungen außerhalb des Katalogs (eigene Übungen) fehlen: sie haben keinen Namen und keine Muskelgruppe.
    static func uebungen(_ sessions: [GymSession], katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [KraftUebung] {
        var einheiten: [String: Set<String>] = [:]
        var namen: [String: String] = [:]
        for s in sessions {
            for lauf in s.laeufe where !arbeitssaetze(lauf).isEmpty {
                guard let u = katalog(lauf.uebung), !u.istCardio else { continue }
                einheiten[u.id, default: []].insert(s.id)
                namen[u.id] = u.name
            }
        }
        return einheiten.map { KraftUebung(id: $0.key, name: namen[$0.key] ?? $0.key, einheiten: $0.value.count) }
            .sorted { $0.einheiten != $1.einheiten ? $0.einheiten > $1.einheiten : $0.name < $1.name }
    }

    /// Die Aussage als Titel: "Bankdrücken: 70 kg, plus 10", bei gleichem Gewicht "unverändert", bei nur einem Punkt ohne Vergleich.
    static func aussage(name: String, _ punkte: [KraftPunkt]) -> String {
        guard let neu = punkte.last else { return "\(name): noch keine Sätze mit Gewicht" }
        let kg = VerlaufLogik.zahl(neu.gewicht)
        guard punkte.count >= 2, let alt = punkte.first else { return "\(name): \(kg) kg" }
        let diff = neu.gewicht - alt.gewicht
        if abs(diff) < 0.05 { return "\(name): \(kg) kg, unverändert" }
        return "\(name): \(kg) kg, \(diff > 0 ? "plus" : "minus") \(VerlaufLogik.zahl(abs(diff)))"
    }

    /// Die Kernzeile unter dem Titel: bestes Gewicht, 1RM und Volumen der letzten Woche mit Training.
    static func kernzeile(_ punkte: [KraftPunkt]) -> String {
        guard let neu = punkte.last else { return "Sobald du Sätze mit Gewicht abhakst, wächst hier die Kurve." }
        let volumen = neu.volumen.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
        return "Letzte Woche mit Training: bestes Gewicht \(VerlaufLogik.zahl(neu.gewicht)) kg, 1RM \(VerlaufLogik.zahl(neu.e1rm.rounded())) kg, Volumen \(volumen) kg"
    }
}
