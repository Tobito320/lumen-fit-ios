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
    /// Die Zahl, aus der Lumis Stufe folgt (ohne Ziel-Medaillen).
    var stufenZahl: Int { MeilensteinKatalog.stufenZahl(medaillen.map(\.id)) }
    var stufe: Int { LumiStufe.stufe(erreicht: stufenZahl) }
    /// Die Satzziele aus der Befragung (`ziel.prio.*`, `ziel.saetze.*`); leer, solange sie nicht gemacht ist.
    var zielWerte: [String: Int] { daten.map { ZieleLogik.werte(in: $0.raum) } ?? [:] }
    var zieleGesetzt: Bool { ZieleLogik.befragt(zielWerte) }
    var koerper: KoerperDaten {
        let werte = zielWerte
        return KoerperDaten.bauen(sessions: sessions, plan: plan, wert: { werte[$0] }, jetzt: jetzt)
    }
    /// Der Plantag von heute (mit verlegten Tagen und Testwoche), nil an einem Ruhetag.
    var plantagHeute: TrainingsTag? {
        WochenLogik.effektiverPlan(plan, woche: Datum.montagDerWoche(heute)).tage.first { $0.wochentage.contains(Datum.wochentag(heute)) }
    }
    var hatTraining: Bool { !sessions.isEmpty }
    var serieWochen: Int { MeilensteinPruefung.serieWochen(tage: MeilensteinPruefung.trainingsTage(sessions, gym: gym), heute: heute) }

    /// Die Zahlen hinter den Medaillen (für "nächstes Ziel" und die Fortschrittsbalken der Meilensteine).
    var zahlen: MeilensteinZahlen {
        guard let daten else { return MeilensteinZahlen() }
        return MeilensteinPruefung.zahlen(MeilensteinDaten.aus(daten, naechte: umgebung.gesundheit.naechte, schritte: umgebung.gesundheit.tage.mapValues(\.schritte), heute: heute))
    }
    /// Sind die Essensziele eingerichtet? Sonst gibt es keine Protein- und Kalorien-Medaillen.
    var essenZielDa: Bool { daten?.essen.ernaehrungsZiele.eingerichtet ?? false }

    /// Lumis Stimmung aus den Daten: stolz nach einem Training in dieser Woche, sonst bereit.
    var stimmung: LumiStimmung { TrainingLogik.dieseWoche(sessions, heute: heute) > 0 ? .stolz : .bereit }
}
