// Quelle: Lovea Health/GymNeu/SplitFrei.swift
import Foundation

/// Der heutige Plantag als Karte oben in Health: "Tag 3 diese Woche: Upper".
struct PlantagStand: Equatable {
    var titel: String
    var unter: String
    /// Heute ist Trainingstag.
    var heute: Bool
    /// Id des Plantags (heutiger oder nächster), zum Öffnen.
    var tagId: String
}

/// Ein frischer, eigener Split ohne Vorlage: 1 bis 6 Tage pro Woche, jeder Tag mit eigenem Namen.
/// Anlegen schreibt einen ganz normalen `TrainingsPlan` (`gym.plan`), Umbenennen und Löschen eines
/// Tags macht weiter `SplitEditorView`.
enum SplitFrei {
    static let tageBereich = 1...6

    /// Ein Wochentag je Tag, gleichmäßig verteilt (1 = Mo … 7 = So): 3 Tage = Mo, Mi, Fr.
    static func wochentage(fuer tage: Int) -> [Int] {
        switch tage {
        case ...1: return [1]
        case 2: return [1, 4]
        case 3: return [1, 3, 5]
        case 4: return [1, 2, 4, 5]
        case 5: return [1, 2, 3, 4, 5]
        default: return [1, 2, 3, 4, 5, 6]
        }
    }

    /// Vorgabe für Namensfelder: "Tag 1", "Tag 2" …
    static func standardName(_ nummer: Int) -> String { "Tag \(nummer)" }

    /// Der Plan aus den getippten Namen (leer = "Tag N", Leerraum weg), auf 1 bis 6 Tage begrenzt.
    static func anlegen(name: String, tage getippt: [String], neueId: () -> String = { UUID().uuidString }) -> TrainingsPlan {
        let anzahl = min(max(getippt.count, tageBereich.lowerBound), tageBereich.upperBound)
        let namen = (0..<anzahl).map { i -> String in
            let n = i < getippt.count ? getippt[i].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            return n.isEmpty ? standardName(i + 1) : n
        }
        let tage = wochentage(fuer: anzahl)
        let liste = zip(namen, tage).map { TrainingsTag(id: neueId(), name: $0, wochentage: [$1], uebungen: []) }
        let titel = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return TrainingsPlan(tage: liste, ruhetage: (1...7).filter { !tage.contains($0) }, splitName: titel.isEmpty ? "Mein Split" : titel)
    }

    // MARK: - Heutiger Plantag

    /// "Tag 3 diese Woche: Upper": Platz des heutigen Wochentags unter den Trainingstagen des Plans
    /// (Mo zuerst). Ruhetag: der nächste Trainingstag, in der nächsten Woche wieder der erste.
    /// nil ohne Plan oder ohne feste Wochentage. Es zählt die Woche von `datum` (verlegt, Testwoche);
    /// nach dem letzten Tag der Woche kommt der erste des festen Plans.
    static func plantag(_ plan: TrainingsPlan, datum: String) -> PlantagStand? {
        let woche = WochenLogik.effektiverPlan(plan, woche: datum)
        let feste = Set(woche.tage.flatMap(\.wochentage)).sorted()
        guard !feste.isEmpty else { return nil }
        func tag(_ p: TrainingsPlan, _ w: Int) -> TrainingsTag? { p.tage.first { $0.wochentage.contains(w) } }
        func name(_ t: TrainingsTag) -> String { t.name.isEmpty ? String(localized: "Training") : t.name }
        let heute = Datum.wochentag(datum)
        if let t = tag(woche, heute), let nr = feste.firstIndex(of: heute) {
            return PlantagStand(titel: String(localized: "Tag \(nr + 1) diese Woche: \(name(t))"), unter: unterzeile(t, von: feste.count), heute: true, tagId: t.id)
        }
        let spaeter = feste.first { $0 > heute }
        let quelle = spaeter == nil ? plan : woche
        let tage = Set(quelle.tage.flatMap(\.wochentage)).sorted()
        guard let w = spaeter ?? tage.first, let t = tag(quelle, w), let nr = tage.firstIndex(of: w) else { return nil }
        let wann = w > heute ? TrainingLogik.wochentagName[w - 1] : String(localized: "nächste Woche \(TrainingLogik.wochentagName[w - 1])")
        return PlantagStand(titel: String(localized: "Heute frei"), unter: String(localized: "Als Nächstes Tag \(nr + 1): \(name(t)), \(wann)"), heute: false, tagId: t.id)
    }

    private static func unterzeile(_ t: TrainingsTag, von: Int) -> String {
        let n = t.uebungen.count
        guard n > 0 else { return String(localized: "Noch keine Übungen") }
        let uebungen = n == 1 ? String(localized: "1 Übung") : String(localized: "\(n) Übungen")
        let tage = von == 1 ? String(localized: "1 Trainingstag pro Woche") : String(localized: "\(von) Trainingstage pro Woche")
        return "\(uebungen) · \(tage)"
    }

    // MARK: - Schnell bearbeiten (Sätze, Wiederholungen, kg einer Übung)

    static let maxSaetze = 12

    /// Anzahl der Sätze; neue Sätze kopieren den letzten (`SaetzeListe`).
    static func saetzeAnzahl(_ u: PlanUebung, _ n: Int) -> PlanUebung {
        var u = u
        let ziel = min(max(n, 1), maxSaetze)
        if u.saetze.count > ziel { u.saetze.removeLast(u.saetze.count - ziel) }
        while u.saetze.count < ziel { u.saetze.append(u.saetze.last ?? PlanSatz(wdh: 10, kg: nil, failure: false)) }
        return u
    }

    /// Wiederholungen in allen Sätzen.
    static func alleWdh(_ u: PlanUebung, _ wdh: Int) -> PlanUebung {
        var u = u
        for i in u.saetze.indices { u.saetze[i].wdh = min(max(wdh, 1), 100) }
        return u
    }

    /// Gewicht in allen Sätzen; 0 oder weniger heißt ohne Gewicht.
    static func alleKg(_ u: PlanUebung, _ kg: Double) -> PlanUebung {
        var u = u
        let wert: Double? = kg > 0 ? min(kg, 500) : nil
        for i in u.saetze.indices { u.saetze[i].kg = wert }
        return u
    }

    /// Cardio: Dauer in Minuten (5 bis 180, wie `SaetzeEditor`).
    static func dauer(_ u: PlanUebung, _ minuten: Int) -> PlanUebung {
        var u = u
        u.minuten = min(max(minuten, 5), 180)
        return u
    }
}
