import Foundation

/// Was der Bauer aus den Stores braucht, als reine Werte (testbar ohne `AppUmgebung`).
struct WidgetEingabe: Sendable {
    var jetzt: Date
    var profilName: String
    var profilKennung: String
    var thema: ThemaID
    var erscheinung: Erscheinung
    var ziele: Ziele
    var schritte: Int?
    var schlafMinuten: Int?
    var hrv: Int?
    var sessions: [GymSession]
    var plan: TrainingsPlan
    var kcal: Int
    var kcalZiel: Int
    var protein: Int
    var proteinZiel: Int
    var habits: [WidgetHabitEingabe]
    var lumi: LumiStimmung
    var lumiStufe: Int
}

/// Eine sichtbare Gewohnheit mit ihren Tageswerten und dem Ziel aus den Einstellungen (`HabitStore.habitZiel`).
struct WidgetHabitEingabe: Sendable {
    var habit: Habit
    var werte: [String: Int]
    var ziel: Int?
}

/// Macht aus den Werten des aktiven Profils den `WidgetSnapshot`. Rein.
enum WidgetSnapshotBauer {
    /// Mehr Gewohnheiten passen auf kein Widget.
    nonisolated static let hoechstensHabits = 6
    /// Wie weit der Plan vorausgeschaut wird, um den nächsten Trainingstag zu finden.
    nonisolated static let planTage = 7

    static func baue(_ e: WidgetEingabe) -> WidgetSnapshot {
        let heute = Datum.text(e.jetzt)
        return WidgetSnapshot(
            geschrieben: e.jetzt, profilName: e.profilName, profilKennung: e.profilKennung, tag: heute, thema: e.thema, erscheinung: e.erscheinung,
            lumi: e.lumi, lumiStufe: e.lumiStufe,
            boegen: WidgetBoegenWerte(schritte: e.schritte, schritteZiel: e.ziele.schritte, trainingTage: trainingTage(e.sessions, heute: heute),
                                      trainingZiel: e.ziele.gymTageProWoche, schlafMinuten: e.schlafMinuten, schlafZiel: e.ziele.schlafMinuten, hrv: e.hrv),
            plan: naechsterTag(plan: e.plan, sessions: e.sessions, heute: heute),
            serieWochen: TrainingLogik.serieWochen(e.sessions, heute: heute),
            essen: WidgetEssenStand(kcal: e.kcal, kcalZiel: e.kcalZiel, protein: e.protein, proteinZiel: e.proteinZiel),
            habits: e.habits.prefix(hoechstensHabits).map { kachel($0, heute: heute) })
    }

    /// Verschiedene Tage mit Training in der Woche von `heute` (zwei Einheiten an einem Tag zählen einmal).
    static func trainingTage(_ sessions: [GymSession], heute: String) -> Int {
        let montag = Datum.montagDerWoche(heute)
        return Set(sessions.map { Datum.text($0.start) }.filter { Datum.montagDerWoche($0) == montag }).count
    }

    /// Der nächste Plantag ab heute; war heute schon Training, ab morgen. Ohne Plantag in den nächsten sieben Tagen nil.
    static func naechsterTag(plan: TrainingsPlan, sessions: [GymSession], heute: String) -> WidgetPlanTag? {
        let heuteTrainiert = sessions.contains { Datum.text($0.start) == heute }
        for abstand in (heuteTrainiert ? 1 : 0)..<planTage {
            let tag = Datum.addTage(heute, abstand)
            if let plantag = TrainingLogik.tag(plan, datum: tag) { return WidgetPlanTag(name: plantag.name, tag: tag) }
        }
        return nil
    }

    static func kachel(_ eingabe: WidgetHabitEingabe, heute: String) -> WidgetHabitKachel {
        let h = eingabe.habit
        return WidgetHabitKachel(
            id: h.id, name: h.name, symbol: h.symbol, zaehlen: h.zaehlen,
            ziel: h.zaehlen ? max(1, eingabe.ziel ?? h.tagesziel ?? 1) : 1,
            heute: eingabe.werte[heute] ?? 0,
            serie: HabitLogik.serie(h, werte: eingabe.werte, ziel: eingabe.ziel, heute: heute))
    }
}
