import Foundation

/// Antwort auf "Wie war das Set?" (Entwurf `fbRow`).
enum SatzGefuehl: String, Sendable {
    case leicht, passt, schwer
}

/// Hilfen der ersten Wochen im laufenden Training (Entwurf: Formtipp `.tip1`, Set-Feedback `fbRow`).
// shortcut: "Anfänger" heißt hier "erste 14 Tage seit dem ersten beendeten Training"; sobald Präferenzen eine Erfahrung speichern, diese nehmen.
enum LaufHilfe {
    nonisolated static let ersteWochenTage: Double = 14

    /// Noch in den ersten zwei Wochen: kein beendetes Training oder das erste ist jünger als 14 Tage.
    static func ersteWochen(_ sessions: [GymSession], jetzt: Date) -> Bool {
        guard let erstes = sessions.filter({ $0.ende != nil }).map(\.start).min() else { return true }
        return jetzt.timeIntervalSince(erstes) < ersteWochenTage * 86400
    }

    /// Der häufigste Fehler der Übung (`UebungsAnleitungen`), nil ohne Anleitung.
    static func formtipp(_ katalogId: String) -> String? { UebungsAnleitungen.finden(katalogId)?.fehler }

    /// Die Frage steht unter dem zuletzt abgehakten Set, solange danach noch ein offenes Set mit Gewicht kommt.
    static func gefuehlFrage(_ saetze: [PlanSatz], satz i: Int) -> Bool {
        guard saetze.indices.contains(i), saetze[i].ok == true, saetze.lastIndex(where: { $0.ok == true }) == i else { return false }
        return naechstesOffenes(saetze, nach: i) != nil
    }

    /// Das nächste offene Set mit Gewicht nach `i`; das stellen "Leicht" und "Schwer" um eine Stufe.
    static func naechstesOffenes(_ saetze: [PlanSatz], nach i: Int) -> Int? {
        saetze.indices.first { $0 > i && saetze[$0].ok != true && saetze[$0].kg != nil }
    }
}
