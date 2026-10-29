import Foundation

/// Das Modul Fortschritt: Prüfung der Medaillen und Lumis Stufe. Die Ansichten lesen alles aus `AppUmgebung`; gespeichert wird nur der Op `fit.lumi.meilenstein`.
enum FortschrittModul {
    /// Der eine Wächter der App; die Ansichten hängen seinen Toast mit `.fortschrittToast()` an.
    @MainActor static let waechter = MeilensteinWaechter()

    /// Idempotent und synchron (läuft in `ModulStart.starteAlle`).
    @MainActor static func start(_ umgebung: AppUmgebung) {
        waechter.start(umgebung)
    }

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte): zehn Wochen Training mit steigenden Gewichten, ein Monat Gewicht mit Ziel und
    /// die fälligen Medaillen. Feste Kennungen: ein zweiter Aufruf legt nichts doppelt an. Ohne Toast beim Start.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        guard let daten = umgebung.daten else { return }
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        if daten.training.sessions.isEmpty { saeTraining(daten, heute: heute, jetzt: jetzt) }
        if daten.habits.werte(Habit.gewicht.id).isEmpty {
            for i in stride(from: 28, through: 0, by: -2) {
                daten.habits.setze(Habit.gewicht.id, datum: Datum.addTage(heute, -i), wert: 774 + i + (i % 4 == 0 ? 2 : 0))
            }
        }
        if daten.ziele.ziele.gewichtKg == nil {
            var ziele = daten.ziele.ziele
            ziele.gewichtKg = 76
            daten.ziele.ziele = ziele
        }
        waechter.pruefe(daten, naechte: umgebung.gesundheit.naechte, heute: heute)
        waechter.toast = nil
    }

    /// Drei Einheiten je Woche (Mo, Mi, Fr), die letzten zehn Wochen, bis heute. Jede Einheit dauert 50 Minuten und hat gezählte Sätze.
    @MainActor private static func saeTraining(_ daten: DatenSatz, heute: String, jetzt: Date) {
        let montag = Datum.montagDerWoche(heute)
        let tage: [(versatz: Int, name: String, uebungen: [(id: String, kg: Double)])] = [
            (0, "Push", [("EIeI8Vf", 50), ("67n3r98", 30), ("fSrPP6B", 25)]),
            (2, "Pull", [("RVwzP10", 45), ("G08RZcQ", 12)]),
            (4, "Beine", [("lv-beinpresse-sitzend", 100), ("17lJ1kr", 35), ("my33uHU", 40), ("TFqbd8t", 0)]),
        ]
        for woche in stride(from: 9, through: 0, by: -1) {
            for (nr, tag) in tage.enumerated() {
                if nr == 2 && woche % 3 == 1 { continue }
                let datum = Datum.addTage(montag, -7 * woche + tag.versatz)
                let start = Datum.datum(datum).addingTimeInterval(18 * 3600)
                guard start < jetzt else { continue }
                let session = "demo-\(datum)"
                let fortschritt = Double(9 - woche) / 2
                var eintraege: [(String, GymD, Date)] = [("gym.checkin", GymD(session: session, tag: tag.name, start: start), start)]
                for (i, u) in tag.uebungen.enumerated() {
                    let kg = u.kg == 0 ? nil : u.kg + (fortschritt * 2.5).rounded(.down)
                    let saetze = (0..<3).map { _ in PlanSatz(wdh: 8, kg: kg, failure: false, ok: true) }
                    eintraege.append(("gym.uebung", GymD(session: session, plan: "demo-\(i)", uebung: u.id, status: "satz", saetze: saetze), start + Double(600 * (i + 1))))
                }
                eintraege.append(("gym.checkout", GymD(session: session, ende: start + 3000, status: "ende"), start + 3000))
                for (art, d, zeit) in eintraege {
                    daten.raum.einreihen(Op(id: "demo-\(art)-\(session)-\(Int(zeit.timeIntervalSince1970))", art: art, von: daten.profil, zeit: zeit,
                                            d: (try? JSONEncoder().encode(d)) ?? Data()))
                }
                daten.habits.setzeGym(datum: datum, an: true)
            }
        }
    }
}
