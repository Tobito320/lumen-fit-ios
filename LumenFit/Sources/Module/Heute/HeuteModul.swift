import Foundation

/// Modul heute: der Heute-Tab. Ansichten bauen ihr `HeuteModell` selbst und rechnen nur bei Ereignissen; es gibt keinen Timer und keinen Hintergrundauftrag.
enum HeuteModul {
    /// Heute braucht beim App-Start nichts: kein Port, keine Beobachtung, keine Abruf-Aufgabe (Akku: Bewegung nur bei Ereignissen).
    /// Der Aufruf bleibt, weil `ModulStart.starteAlle` jedes Modul gleich behandelt, und ist deshalb von selbst idempotent.
    @MainActor static func start(_ umgebung: AppUmgebung) {}

    /// Füllt für `-lumenFitDemo` ein glaubwürdiges Bild (erfundene Werte): ein Plan für heute, zwei Gym-Tage, Wasser, ein Morgen-Check, eigene
    /// Gewohnheit und ein Gewichtsverlauf. Schritte, Schlaf und Vitalwerte liefert der Demo-Health-Leser.
    @MainActor static func demoSaat(_ umgebung: AppUmgebung) {
        guard let daten = umgebung.daten else { return }
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)

        if daten.training.plan.tage.isEmpty {
            func satz() -> PlanSatz { PlanSatz(wdh: 8, kg: 60, failure: false) }
            let uebungen = ["Kniebeuge", "Rumänisches Kreuzheben", "Beinpresse", "Wadenheben"].enumerated().map { index, name in
                PlanUebung(id: "demo-heute-\(index)", uebung: PlanUebung.eigen, name: name, saetze: [satz(), satz(), satz()], minuten: nil)
            }
            let tag = TrainingsTag(id: "demo-heute", name: "Beine", wochentage: [Datum.wochentag(heute)], uebungen: uebungen)
            daten.training.planSichern(TrainingsPlan(tage: [tag], ruhetage: []))
        }

        for zurueck in [1, 3] {
            let tag = Datum.addTage(heute, -zurueck)
            daten.habits.setzeGym(datum: tag, an: true)
            daten.habits.setzeWasser(datum: tag, anzahl: 6 + zurueck)
        }
        daten.habits.setzeWasser(datum: heute, anzahl: 3)

        if !daten.habits.habits.keys.contains("demo-dehnen") {
            daten.habits.anlegen(Habit(id: "demo-dehnen", name: "Dehnen", symbol: "figure.yoga", farbe: HabitFarbe.grau.rawValue, zaehlen: false,
                                       tagesziel: nil, haeufigkeit: .taeglich, fuer: "ich"))
            for zurueck in 1...4 { daten.habits.setze("demo-dehnen", datum: Datum.addTage(heute, -zurueck), wert: 1) }
        }

        // Gewicht: alle drei Tage ein Wert, langsam fallend (783 = 78,3 kg)
        for schritt in 0..<10 {
            daten.habits.setze(Habit.gewicht.id, datum: Datum.addTage(heute, -3 * schritt), wert: 783 + 2 * schritt)
        }

        // Morgen-Check von heute: "gut" (4); das Modul coach schreibt dieselbe Op
        let hatStimmung = daten.raum.ops(arten: ["fit.lumi.stimmung"]).contains { $0.daten(StimmungsEintrag.self)?.tag == heute }
        if !hatStimmung { daten.raum.senden("fit.lumi.stimmung", StimmungsEintrag(tag: heute, wert: 4, stimmung: .bereit)) }
    }
}
