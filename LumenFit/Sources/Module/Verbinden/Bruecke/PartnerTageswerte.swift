import Foundation

/// Die Zusatzwerte für `zusammenfassung.json` (Gleichstand Health): Wochenwerte, Energie-Rat und erledigte Gewohnheiten des eigenen Profils.
/// Liest nur Stores und den Gesundheitsstand, nie Health selbst. Der Bauer (`ZusammenfassungBauer`) gibt davon nur frei, was die Freigaben erlauben.
@MainActor
enum PartnerTageswerte {
    struct Werte: Sendable, Equatable {
        var schritteWoche: [String: Int] = [:]
        var gymTage: Set<String> = []
        var schlafWoche: [String: Int] = [:]
        var energie: EnergieRat?
        var habitsFertig: Set<String> = []
    }

    static func sammle(daten: DatenSatz, gesundheit: GesundheitsStand, jetzt: Date) -> Werte {
        let heute = Datum.text(jetzt)
        let woche = HabitLogik.wochenTage(heute: heute).filter { $0 <= heute }
        var w = Werte()
        for tag in woche {
            if let s = gesundheit.tage[tag]?.schritte, s > 0 { w.schritteWoche[tag] = s }
            if let n = TagesformQuellen.nacht(tag, daten: daten, gesundheit: gesundheit) { w.schlafWoche[tag] = n.minuten }
        }
        let gymAlle = WochenStreifenLogik.gymTage(sessions: daten.training.sessions, haken: daten.habits.werte(Habit.gym.id))
        w.gymTage = gymAlle.intersection(woche)
        let trainiert = gymAlle.contains(heute)
        let folge = EnergieLogik.inFolge(heute: heute) { gymAlle.contains($0) }
        if trainiert { w.habitsFertig.insert(Habit.gym.id) }
        let wasser = daten.habits.wert(Habit.wasser.id, heute)
        let wasserZiel = daten.habits.habitZiel(Habit.wasser.id)
        if HabitLogik.erledigt(Habit.wasser, wert: wasser, ziel: wasserZiel) { w.habitsFertig.insert(Habit.wasser.id) }

        let plan = HeutePlanLogik.vorschlag(plan: daten.training.plan, heute: heute, trainiert: trainiert, locker: false, gymInFolge: folge)
        let eingabe = TagesformQuellen.eingabe(daten: daten, gesundheit: gesundheit, tag: heute, jetzt: jetzt)
        let gestern = Datum.addTage(heute, -1)
        let schritteGestern: Int? = gesundheit.tage[gestern].flatMap { $0.schritte > 0 ? $0.schritte : nil }
        w.energie = EnergieLogik.rat(EnergieEingabe(
            naechte: Array(eingabe.schlaf.prefix(3)), wasser: wasser, wasserZiel: wasserZiel ?? 8, stunde: Datum.kalender.component(.hour, from: jetzt),
            schritteGestern: schritteGestern, trainingstag: plan.art == .training, ruhetag: plan.art == .ruhetag,
            planLeer: daten.training.plan.tage.isEmpty, gymInFolge: folge, heuteSchonGym: trainiert))
        return w
    }
}
