import Foundation

extension WidgetSnapshot {
    /// Erfundene Werte für die Widget-Galerie, den Platzhalter und die Demo (`-lumenFitDemo`).
    static func beispiel(jetzt: Date = Date(), thema: ThemaID = .monochrom) -> WidgetSnapshot {
        let heute = Datum.text(jetzt)
        return WidgetSnapshot(
            geschrieben: jetzt, profilName: "Beispiel", profilKennung: "beispiel-profil", tag: heute, thema: thema, erscheinung: .system,
            lumi: .bereit, lumiStufe: 3,
            boegen: WidgetBoegenWerte(schritte: 8_412, schritteZiel: 10_000, trainingTage: 2, trainingZiel: 3, schlafMinuten: 432, schlafZiel: 480, hrv: 68),
            plan: WidgetPlanTag(name: "Push", tag: Datum.addTage(heute, 1)), serieWochen: 4,
            essen: WidgetEssenStand(kcal: 1_560, kcalZiel: 2_400, protein: 98, proteinZiel: 140),
            habits: [
                WidgetHabitKachel(id: "gym", name: "Gym", symbol: "dumbbell.fill", zaehlen: false, ziel: 1, heute: 0, serie: 4),
                WidgetHabitKachel(id: "wasser", name: "Wasser", symbol: "drop.fill", zaehlen: true, ziel: 8, heute: 5, serie: 2),
                WidgetHabitKachel(id: "dehnen", name: "Dehnen", symbol: "figure.mind.and.body", zaehlen: false, ziel: 1, heute: 1, serie: 6),
            ],
            gymWoche: HabitLogik.wochenTage(heute: heute).enumerated().map { WidgetGymTag(tag: $1, erledigt: $0 == 0 || $0 == 2) },
            partner: WidgetPartnerStand(name: "Partner", tag: heute, schritte: 10_450, schritteZiel: 10_000,
                                        gymTage: Array(HabitLogik.wochenTage(heute: heute).prefix(2)), gymZiel: 3, schlafMinuten: 450, schlafZiel: 480))
    }
}
