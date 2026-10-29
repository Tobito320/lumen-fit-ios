// Quelle: Lovea Health/GymLive.swift (nur die Zuordnung; die Live Activity selbst zeigt das Modul widgets über `liveAnzeige.training`)
import Foundation

/// Was die Live Activity zeigt, aus dem laufenden Training gerechnet: die Übung, die dran ist, ihr Satz und das Ende der Pause.
enum GymLive {
    /// nil, sobald das Training beendet ist (die Anzeige verschwindet).
    static func stand(session: GymSession, liste: [WorkoutUebung], pause: GymPauseStand?, planName: String?, jetzt: Date) -> TrainingLiveStand? {
        guard session.ende == nil else { return nil }
        let dran = SupersatzLogik.dran(liste)
        let pauseEnde = pause.flatMap { p -> Date? in
            guard let ende = p.ende, ende > jetzt else { return nil }
            return ende
        }
        guard let dran else {
            // Alles abgehakt: die Anzeige bleibt bis zum Beenden stehen.
            return TrainingLiveStand(uebung: "Alles geschafft", satz: 0, von: 0, pauseEnde: nil, start: session.start, planName: planName)
        }
        let u = liste[dran.uebung]
        return TrainingLiveStand(uebung: u.planUebung.anzeigeName, satz: dran.satz + 1, von: max(1, u.saetze.count),
                                 pauseEnde: pauseEnde, start: session.start, planName: planName)
    }
}
