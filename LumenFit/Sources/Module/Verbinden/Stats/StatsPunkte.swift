import Foundation

/// Die Zahlen der laufenden Woche für Stats: Tage mit Training, gezählte Sets, neue Rekorde und die Serie in Wochen.
/// Die Punkte rechnet der Server für "Alle" genauso (`server/stats.js`).
struct StatsZahlen: Codable, Equatable, Sendable {
    var trainings = 0
    var sets = 0
    var rekorde = 0
    var serie = 0

    var punkte: Int { StatsPunkte.punkte(trainings: trainings, sets: sets, rekorde: rekorde) }
}

/// Punkte für Stats und Erfolge, eine Rechnung für beide (Besitzer 10.11.2026: Training +10, Satz +1, Rekord +5):
/// - Training +10 je Tag mit mindestens einem gezählten Satz. Ein zweites Training am selben Tag zählt nicht (sonst brächte Aufteilen Punkte).
/// - Set +1 je gezähltem Satz: abgehakt, ohne Aufwärmen (`CrewLogik.saetze`, wie "Sätze diese Woche").
/// - Rekord +5 je Übung, deren schwerstes Gewicht in einer Einheit alles davor übertrifft (`RekordLogik.wert(_:.gewicht)`); das erste Mal ist
///   kein Rekord, Übungen ohne Gewicht haben keinen. Katalog-Übungen über ihre Id, eigene über ihren Plan-Eintrag.
/// Die Woche läuft Montag bis Sonntag nach Berliner Zeit (`CrewLogik.wochenZeitraum`).
enum StatsPunkte {
    static let jeTraining = 10
    static let jeSet = 1
    static let jeRekord = 5

    static func punkte(trainings: Int, sets: Int, rekorde: Int) -> Int {
        jeTraining * trainings + jeSet * sets + jeRekord * rekorde
    }

    /// Punkte der laufenden Woche ("+N Punkte diese Woche", Stats).
    static func woche(_ sessions: [GymSession], jetzt: Date) -> Int {
        zahlen(sessions, jetzt: jetzt).punkte
    }

    /// Punkte über alle Trainings (Level in Erfolge).
    static func gesamt(_ sessions: [GymSession]) -> Int {
        let e = einheiten(sessions)
        return punkte(trainings: Set(e.map(\.tag)).count, sets: e.reduce(0) { $0 + $1.sets }, rekorde: e.reduce(0) { $0 + $1.rekorde })
    }

    /// Die Zahlen der laufenden Woche samt Serie.
    static func zahlen(_ sessions: [GymSession], jetzt: Date) -> StatsZahlen {
        let e = einheiten(sessions)
        let z = CrewLogik.wochenZeitraum(jetzt: jetzt)
        let drin = e.filter { $0.start >= z.von && $0.start < z.bis }
        return StatsZahlen(trainings: Set(drin.map(\.tag)).count, sets: drin.reduce(0) { $0 + $1.sets },
                           rekorde: drin.reduce(0) { $0 + $1.rekorde }, serie: serie(e, jetzt: jetzt))
    }

    /// Wochen in Folge mit mindestens einem Training bis jetzt; die laufende Woche ohne Training bricht die Serie noch nicht.
    static func serie(_ sessions: [GymSession], jetzt: Date) -> Int {
        serie(einheiten(sessions), jetzt: jetzt)
    }

    private static func serie(_ e: [Einheit], jetzt: Date) -> Int {
        let wochen = Set(e.map { Datum.wochenstart($0.tag) })
        var woche = Datum.wochenstart(Datum.text(jetzt))
        if !wochen.contains(woche) { woche = Datum.addTage(woche, -7) }
        var n = 0
        while wochen.contains(woche) {
            n += 1
            woche = Datum.addTage(woche, -7)
        }
        return n
    }

    /// Eine Einheit mit gezählten Sätzen: Tag, Sets und in wie vielen Übungen sie das schwerste Gewicht von davor übertroffen hat.
    private struct Einheit {
        let start: Date
        let tag: String
        let sets: Int
        let rekorde: Int
    }

    private static func einheiten(_ sessions: [GymSession]) -> [Einheit] {
        var bestes: [String: Double] = [:]
        var aus: [Einheit] = []
        for s in sessions.sorted(by: { $0.start < $1.start }) {
            var sets = 0
            var schwerstes: [String: Double] = [:]
            for l in s.laeufe {
                let saetze = CrewLogik.saetze(l)
                sets += saetze.count
                guard let kg = RekordLogik.wert(saetze, .gewicht) else { continue }
                let schluessel = l.uebung == PlanUebung.eigen ? "eigen:\(l.plan)" : l.uebung
                schwerstes[schluessel] = max(schwerstes[schluessel] ?? 0, kg)
            }
            var rekorde = 0
            for (schluessel, kg) in schwerstes {
                if let alt = bestes[schluessel], kg > alt { rekorde += 1 }
                bestes[schluessel] = max(bestes[schluessel] ?? 0, kg)
            }
            if sets > 0 { aus.append(Einheit(start: s.start, tag: Datum.text(s.start), sets: sets, rekorde: rekorde)) }
        }
        return aus
    }
}
