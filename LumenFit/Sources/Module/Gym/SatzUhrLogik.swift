// Quelle: Lovea Health/Workout.swift (WorkoutUhr.satzStarten, satzDauer; hier ohne Satz-Start-Knopf: der Satz beginnt, wenn die Pause endet)
import Foundation

/// Die Satz-Uhr: Nach einer Pause läuft die Uhr des nächsten Satzes hoch. Beim Haken wird die Dauer gemerkt, wenn "Satz-Zeit" an ist.
enum SatzUhrLogik {
    /// Eine Dauer über einer halben Stunde ist kein Satz (Telefon weggelegt): sie wird nicht gespeichert.
    static let hoechstens: TimeInterval = 30 * 60

    /// Wann der nächste Satz beginnt: am Ende der Pause, wenn sie von selbst ablief, sonst (übersprungen, ohne Ziel) jetzt.
    static func satzStart(pause: GymPauseStand, jetzt: Date) -> Date {
        if let ende = pause.ende, ende <= jetzt { return ende }
        return jetzt
    }

    /// Dauer des Satzes beim Haken; nil ohne Start, bei ausgeschaltetem Schalter oder unplausibler Dauer.
    static func dauer(seit: Date?, jetzt: Date, an: Bool) -> Double? {
        guard an, let seit else { return nil }
        let d = jetzt.timeIntervalSince(seit)
        return d >= 1 && d <= hoechstens ? d : nil
    }

    /// true, wenn die Pause ihr Ziel überschritten hat: die Uhr zählt dann rot weiter hoch.
    static func ueberlauf(_ pause: GymPauseStand, jetzt: Date) -> Bool {
        guard let ende = pause.ende else { return false }
        return jetzt >= ende
    }
}
