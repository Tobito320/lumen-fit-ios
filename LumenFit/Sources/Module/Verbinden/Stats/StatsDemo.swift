#if DEBUG
import Foundation

/// Feste Stats-Antwort für die Demo (`-lumenFitDemo`): drei Freunde und eine öffentliche Liste mit Spitznamen, ohne Netz.
enum StatsDemo {
    private static let spitznamen = ["Eisenfaust", "Stahlbiene", "Kraftpaket", "Hantelheld", "Muskelmaus", "Bankkönig", "Kniebeugerin", "Ruderfuchs",
                                     "Plattenpanda", "Kreidehand", "Gewichtheber", "Pumpmeister", "Satzsammler", "Rackrakete", "Kurzhantelkunst"]

    static func antwort(jetzt: Date) -> StatsAntwort {
        let freunde = [("demo-v1", "Freund 1", 6, 53, 9), ("demo-v2", "Partner", 5, 45, 6), ("demo-v3", "Freund 2", 3, 15, 2)].map { id, name, t, s, serie in
            StatsFreund(id: id, name: name, punkte: StatsPunkte.punkte(trainings: t, sets: s, rekorde: 0), trainings: t, sets: s, serie: serie, rekorde: [:])
        }
        let alle = spitznamen.enumerated().map { i, name in
            let t = max(1, 6 - i / 3)
            let s = max(4, 60 - i * 4)
            return StatsEintrag(id: String(format: "%032lx", i + 1), name: name, jahr: 1 + i % 2, punkte: StatsPunkte.punkte(trainings: t, sets: s, rekorde: i < 4 ? 2 : 0),
                                trainings: t, sets: s, serie: max(1, 12 - i), ich: false)
        }
        return StatsAntwort(montag: Datum.wochenstart(Datum.text(jetzt)), ich: StatsIch(freunde: false, oeffentlich: false, spitzname: nil, ausgeblendet: false),
                            freunde: freunde, alle: alle, rekorde: [:])
    }
}
#endif
