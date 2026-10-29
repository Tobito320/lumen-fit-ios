import SwiftUI

/// Liest für die Ansichten des Moduls alles aus `AppUmgebung`: Einheiten, Gewohnheiten, Schlaf, Ziele. Eine Ansicht legt es in `body` an und liest nur;
/// die Stores sind `@Observable`, die Ansicht aktualisiert sich selbst.
@MainActor
struct FortschrittQuelle {
    let umgebung: AppUmgebung

    var daten: DatenSatz? { umgebung.daten }
    var jetzt: Date { umgebung.uhr() }
    var heute: String { Datum.text(jetzt) }
    var sessions: [GymSession] { daten?.training.sessions ?? [] }
    var plan: TrainingsPlan { daten?.training.plan ?? .leer }
    var gym: [String: Int] { daten?.habits.werte(Habit.gym.id) ?? [:] }
    /// Tag zu Zehntel-kg.
    var gewicht: [String: Int] { daten?.habits.werte(Habit.gewicht.id) ?? [:] }
    var gewichtZielKg: Double? { daten?.ziele.ziele.gewichtKg }
    /// Aufwachtag zu Schlafminuten, aus Health und Band.
    var schlaf: [String: Int] { umgebung.gesundheit.naechte.mapValues(\.schlafMinuten) }
    var medaillen: [MeilensteinStand] { daten?.meilensteine.erreicht ?? [] }
    var medaillenDatum: [String: Date] { Dictionary(medaillen.map { ($0.id, $0.erreicht) }, uniquingKeysWith: { erste, _ in erste }) }
    var erreichteIds: Set<String> { Set(medaillen.map(\.id)) }
    var stufe: Int { LumiStufe.stufe(erreicht: medaillen.count) }
    var koerper: KoerperDaten { KoerperDaten.bauen(sessions: sessions, plan: plan, jetzt: jetzt) }
    /// Der Plantag von heute (mit verlegten Tagen und Testwoche), nil an einem Ruhetag.
    var plantagHeute: TrainingsTag? {
        WochenLogik.effektiverPlan(plan, woche: Datum.montagDerWoche(heute)).tage.first { $0.wochentage.contains(Datum.wochentag(heute)) }
    }
    var hatTraining: Bool { !sessions.isEmpty }
    var serieWochen: Int { MeilensteinPruefung.serieWochen(tage: MeilensteinPruefung.trainingsTage(sessions, gym: gym), heute: heute) }

    /// Die Zahlen hinter den Medaillen für "nächstes Ziel".
    var zahlen: MeilensteinZahlen {
        MeilensteinPruefung.zahlen(MeilensteinDaten(
            sessions: sessions, gymTage: gym, gymTageProWoche: daten?.ziele.ziele.gymTageProWoche ?? 3, heute: heute, schlafMinuten: schlaf,
            schlafZiel: daten?.ziele.ziele.schlafMinuten ?? 480, gewicht: gewicht, gewichtZielKg: gewichtZielKg,
            essenTage: daten?.essen.tage ?? [], fruehstueckTage: 0))
    }

    /// Lumis Stimmung aus den Daten: stolz nach einem Training in dieser Woche, sonst bereit.
    var stimmung: LumiStimmung { TrainingLogik.dieseWoche(sessions, heute: heute) > 0 ? .stolz : .bereit }
}
