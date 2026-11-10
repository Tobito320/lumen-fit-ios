import Foundation

extension GymSitzung {
    /// "Kurz · 30 min": den Plantag einchecken und die Übungen in `weg` (Plan-Ids, `GymTabLogik.kurzWeg`) gleich auslassen.
    /// Sie bleiben im Plan, "Plan aktualisieren" löscht sie nicht (`WorkoutLogik.neuerTag` überspringt Leere), und im Training lassen sie sich wieder aufnehmen.
    func starteKurz(_ tag: TrainingsTag, weg: Set<String>) {
        starte(planTag: tag.id)
        for i in liste.indices.reversed() where weg.contains(liste[i].planUebung.id) { auslassen(i) }
    }
}
