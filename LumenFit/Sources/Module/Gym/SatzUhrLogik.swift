// Quelle: Lovea Health/Workout.swift (WorkoutUhr.satzStarten, satzDauer), WorkoutView.swift :805 (Knopf "Übung starten" / "Nächster Satz" / "Satz fertig")
import Foundation

/// Ein Satz, dessen Uhr läuft, weil jemand im Lovea-Aufbau "Übung starten" oder "Nächster Satz" getippt hat (Lovea `WorkoutUhr.Stand` ohne Pause).
/// Wird wie die Pause in `gym-satz.json` gemerkt, damit die Uhr einen App-Neustart übersteht. Ein Haken (und damit die nächste Pause) beendet ihn.
struct SatzLauf: Codable, Equatable, Sendable {
    var session: String
    var plan: String
    var satz: Int
    var seit: Date
}

/// Die Satz-Uhr: Nach einer Pause läuft die Uhr des nächsten Satzes hoch (Lumen-Aufbau) oder ab dem Tipp auf "Übung starten" / "Nächster Satz"
/// (Lovea-Aufbau, `SatzLauf`). Beim Haken wird die Dauer gemerkt, wenn "Satz-Zeit" an ist.
enum SatzUhrLogik {
    /// Beschriftung des großen Knopfs in der Leiste der Übung (Lovea `WorkoutView.swift:807`): läuft ein Satz, "Satz fertig"; sonst
    /// "Übung starten" für den ersten offenen Satz und "Nächster Satz" für jeden späteren.
    static func knopfText(laeuft: Bool, offener: Int) -> String {
        laeuft ? "Satz fertig" : offener == 0 ? "Übung starten" : "Nächster Satz"
    }

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
