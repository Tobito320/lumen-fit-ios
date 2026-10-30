import Foundation

/// "Ziel erreicht" wird je Gewohnheit und Tag nur einmal gefeiert (Haptik und Siegel), auch wenn man zurücknimmt und neu abhakt.
enum HabitFeier {
    private static func schluessel(_ habitId: String) -> String { "fit.heute.feier.\(habitId)" }

    /// true genau einmal je Tag und Gewohnheit; merkt sich den Tag.
    static func darfFeiern(habitId: String, tag: String, speicher: UserDefaults = .standard) -> Bool {
        guard speicher.string(forKey: schluessel(habitId)) != tag else { return false }
        speicher.set(tag, forKey: schluessel(habitId))
        return true
    }

    /// Erreicht der nächste Schritt das Ziel? Zählen: +1, Abhaken: Umschalten von offen auf erledigt.
    static func erreichtZiel(_ habit: Habit, wert: Int, ziel: Int?) -> Bool {
        let neu = habit.zaehlen ? wert + 1 : (wert > 0 ? 0 : 1)
        return !HabitLogik.erledigt(habit, wert: wert, ziel: ziel) && HabitLogik.erledigt(habit, wert: neu, ziel: ziel)
    }
}
