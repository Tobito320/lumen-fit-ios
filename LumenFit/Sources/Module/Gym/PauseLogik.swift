import Foundation

/// Die laufende Pause nach einem Satz. Gespeichert werden nur Zeitpunkte, die Anzeige rechnet daraus (`Text(timerInterval:)`),
/// ein Timer im Hintergrund läuft nie (Akku). `ziel` 0 = ohne Ziel (die Pause zählt nur hoch).
struct GymPauseStand: Codable, Equatable, Sendable {
    var session: String
    var plan: String
    var satz: Int
    var seit: Date
    var ziel: Int

    /// Wann die Pause zu Ende ist; nil ohne Ziel.
    var ende: Date? { ziel > 0 ? seit.addingTimeInterval(Double(ziel)) : nil }
}

/// Pausen-Timer (Idee 23): startet beim Haken von selbst, plus und minus 15 Sekunden, eigene Pause je Übung.
enum PauseLogik {
    static let standard = WorkoutLogik.standardPause
    static let schritt = 15
    static let kleinste = 15

    /// Pausenziel einer Übung: ihre eigene, sonst die Standardpause. 0 heißt "ohne Ziel".
    static func ziel(fuer u: PlanUebung) -> Int { u.pause ?? standard }

    /// Nach "+15 s" oder "−15 s": nie unter 15 Sekunden.
    static func geaendert(_ ziel: Int, um sekunden: Int) -> Int { max(kleinste, ziel + sekunden) }

    /// Die Pause nach dem Satz einer Übung. nil = keine Pause starten. Ein Supersatz wechselt zur nächsten Übung ohne Pause;
    /// nach der zweiten Übung des Paares gilt die längere der beiden Pausen, einmal je Runde.
    /// `index` ist die Stelle der Übung in `liste` (Planreihenfolge).
    static func nach(uebung index: Int, in liste: [PlanUebung]) -> Int? {
        guard liste.indices.contains(index) else { return nil }
        let paar = SupersatzLogik.paar(index, in: liste)
        guard let letzte = paar.last, index == letzte else { return paar.count > 1 ? nil : ziel(fuer: liste[index]) }
        let ziele = paar.map { ziel(fuer: liste[$0]) }
        return ziele.contains(0) ? 0 : ziele.max()
    }

    /// Sekunden bis zum Ende, nie negativ; nil ohne Ziel.
    static func rest(_ stand: GymPauseStand, jetzt: Date) -> Int? {
        stand.ende.map { max(0, Int($0.timeIntervalSince(jetzt).rounded(.up))) }
    }

    static func vorbei(_ stand: GymPauseStand, jetzt: Date) -> Bool {
        stand.ende.map { $0 <= jetzt } ?? false
    }

    /// Der Zeitraum für `Text(timerInterval:)`: von jetzt bis zum Ende. nil ohne Ziel oder wenn die Pause schon vorbei ist.
    static func zeitraum(_ stand: GymPauseStand, jetzt: Date) -> ClosedRange<Date>? {
        guard let ende = stand.ende, ende > jetzt else { return nil }
        return jetzt...ende
    }

    /// "+15 s" oder "−15 s" auf die laufende Pause.
    static func aendern(_ stand: GymPauseStand, um sekunden: Int) -> GymPauseStand {
        guard stand.ziel > 0 else { return stand }
        var neu = stand
        neu.ziel = geaendert(stand.ziel, um: sekunden)
        return neu
    }

    /// Wie lange die Pause wirklich dauerte (für `PlanSatz.pause`).
    static func gedauert(_ stand: GymPauseStand, jetzt: Date) -> Double {
        max(0, jetzt.timeIntervalSince(stand.seit))
    }
}
