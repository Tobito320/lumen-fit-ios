// Quelle: Lovea Health/WorkoutView.swift (SatzRueckgaengig; die Wiederherstellung ist neu und getestet)
import Foundation

/// Merkt die Satzzeilen einer Übung vor "Satz löschen" oder "Satz kopieren". Fünf Sekunden lang bietet die Leiste "Rückgängig" an.
/// `id` ändert sich mit jeder neuen Meldung, damit die Ausblend-Aufgabe der Ansicht neu startet.
struct SatzRueckgaengig: Equatable, Sendable {
    let id = UUID()
    let text: String
    /// Plan-Id der Übung (stabil, auch wenn sich die Reihenfolge der Liste ändert).
    let plan: String
    let vorher: [PlanSatz]
}

enum SatzRueckgaengigLogik {
    /// Wie lange die Leiste steht.
    static let sekunden: Double = 5

    /// Die Übung in `liste`, auf die sich die Meldung bezieht, und die Sätze von vorher. nil, wenn die Übung nicht mehr da ist.
    static func wiederherstellen(_ r: SatzRueckgaengig, in liste: [WorkoutUebung]) -> (index: Int, saetze: [PlanSatz])? {
        guard let i = liste.firstIndex(where: { $0.id == r.plan }) else { return nil }
        return (i, r.vorher)
    }

    /// Der Text der Leiste: "Satz 2 gelöscht", "Satz 2 kopiert". `nummer` ist die Anzeige-Nummer des Satzes ("2", "W", "D", "F").
    static func text(_ aktion: Aktion, nummer: String) -> String {
        switch aktion {
        case .geloescht: "Satz \(nummer) gelöscht"
        case .kopiert: "Satz \(nummer) kopiert"
        }
    }

    enum Aktion: Sendable { case geloescht, kopiert }
}
