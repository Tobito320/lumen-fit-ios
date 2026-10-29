// Quelle: Lovea Health/GymTageLogik.swift
import Foundation

/// Gym-Tage ohne Einheit: Tage, an denen nur das Gym-Häkchen (Habit) steht, und Einheiten ohne
/// Sätze. Reine Logik für Verlauf, Rückblick und "Training nachtragen".
enum GymTageLogik {
    /// Tage mit Gym-Häkchen, aber ohne gespeicherte Einheit. `gym`: Tag -> Wert der Gym-Habit, über 0 = abgehakt.
    static func nurAbgehakt(sessions: [GymSession], gym: [String: Int]) -> Set<String> {
        Set(gym.filter { $0.value > 0 }.keys).subtracting(sessions.map { Datum.text($0.start) })
    }

    /// Eine Einheit hat Daten, sobald ein Satz abgehakt ist, oder eine Übung ohne Satzstand (Cardio,
    /// alte Einheit) fertig ist. Wie `WorkoutLogik.zeilen`: ein vorhandener Satzstand gilt immer.
    static func hatDaten(_ s: GymSession) -> Bool {
        s.laeufe.contains { lauf in
            guard let stand = lauf.stand else { return lauf.fertig }
            return stand.contains { $0.ok == true }
        }
    }

    /// Die Einheit, die ein Tipp auf `tag` öffnet: eine mit Daten, sonst die erste. `sessions`: neueste zuerst.
    static func einheit(am tag: String, in sessions: [GymSession]) -> GymSession? {
        let amTag = sessions.filter { Datum.text($0.start) == tag }
        return amTag.first(where: hatDaten) ?? amTag.first
    }

    /// Vorschlag für "Training nachtragen" an `datum` (nur bis heute): 18:00 bis 19:30, am heutigen
    /// Tag nie nach `jetzt`. Nur eine Vorbelegung, gespeichert wird erst mit "Sichern".
    static func nachtragVorschlag(datum: String, jetzt: Date) -> (start: Date, ende: Date) {
        let tagAnfang = Datum.datum(datum)
        let abend = tagAnfang.addingTimeInterval(18 * 3600)
        let ende = min(abend.addingTimeInterval(90 * 60), jetzt)
        let start = max(tagAnfang, min(abend, ende.addingTimeInterval(-90 * 60)))
        return (start, ende)
    }

    /// Satz über der Einheit im Rückblick, wenn sie keine Sätze hat. nil mit Daten und solange sie läuft.
    static func leerHinweis(_ s: GymSession, eigene: Bool, jetzt: Date) -> String? {
        guard !hatDaten(s), !TrainingLogik.laufend(s, jetzt: jetzt) else { return nil }
        let kein = "Keine Sätze gespeichert."
        guard eigene else { return kein }
        if s.ende == nil { return kein + " Die Einheit ist nicht ausgecheckt. Trag unter Zeiten das Ende ein, dann lassen sich Sätze nachtragen." }
        return kein + " Mit Übung hinzufügen oder Sätze bearbeiten trägst du sie nach."
    }
}
