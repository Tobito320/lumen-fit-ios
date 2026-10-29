// Quelle: Lovea Health/Coach/CoachTage.swift
import Foundation

// Health-Coach, ein Chat je Kalendertag. Der Chat zeigt nur heute, der Verlauf (`CoachVerlaufView`) listet die Tage davor.
// Gespeichert bleibt alles, hier wird nur gefiltert und gruppiert. Reine Logik: Kalender und Zeit kommen von außen.

enum CoachTage {
    /// Ein vergangener Tag mit Nachrichten, in Chat-Reihenfolge.
    struct Tag: Identifiable, Equatable, Sendable {
        /// Mitternacht dieses Tages im übergebenen Kalender.
        let beginn: Date
        let nachrichten: [CoachNachricht]

        var id: Date { beginn }
        var anzahl: Int { nachrichten.count }

        /// Eine Zeile für die Liste: die erste Frage der Person, sonst die erste Nachricht.
        var vorschau: String {
            guard let erste = nachrichten.first(where: { $0.rolle == .nutzer }) ?? nachrichten.first else { return "" }
            return CoachText.vorschau(erste.text, maximal: 80)
        }
    }

    /// Mitternacht des Tages von `jetzt`.
    static func beginn(jetzt: Date, kalender: Calendar) -> Date {
        kalender.startOfDay(for: jetzt)
    }

    /// Der Chat: alles ab Mitternacht. Nach oben offen, damit eine Nachricht mit leicht vorgehender Serveruhr nicht verschwindet.
    static func heute(_ nachrichten: [CoachNachricht], beginn: Date) -> [CoachNachricht] {
        nachrichten.filter { $0.zeit >= beginn }
    }

    /// Die Tage davor, neueste zuerst. Nur Tage mit Nachrichten; innerhalb eines Tages bleibt die Reihenfolge der Eingabe.
    static func vergangene(_ nachrichten: [CoachNachricht], beginn: Date, kalender: Calendar) -> [Tag] {
        var gruppen: [Date: [CoachNachricht]] = [:]
        for nachricht in nachrichten where nachricht.zeit < beginn {
            gruppen[kalender.startOfDay(for: nachricht.zeit), default: []].append(nachricht)
        }
        let tage = gruppen.map { Tag(beginn: $0.key, nachrichten: $0.value) }
        return tage.sorted { $0.beginn > $1.beginn }
    }

    /// Die Nachrichten eines Tages, für den Leser.
    static func nachrichten(am beginn: Date, in liste: [CoachNachricht], kalender: Calendar) -> [CoachNachricht] {
        liste.filter { kalender.isDate($0.zeit, inSameDayAs: beginn) }
    }
}
