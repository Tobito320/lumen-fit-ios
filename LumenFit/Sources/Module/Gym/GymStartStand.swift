// Quelle: Lovea Health/GymNeu/GymStartView.swift (GymStartStand, GymStartKnopf; ohne Partner und Körperwoche, die Wochenleiste ist neu)
import Foundation

enum GymStartKnopf: Equatable, Sendable {
    case starten, weiter, fortsetzen

    var titel: String {
        switch self {
        case .starten: String(localized: "Starten")
        case .weiter: String(localized: "Weiter")
        case .fortsetzen: String(localized: "Fortsetzen")
        }
    }

    var symbolName: String { self == .fortsetzen ? "arrow.uturn.backward" : "play.fill" }
}

/// Ein Tag der Wochenleiste auf der Gym-Seite.
struct GymWochenTag: Identifiable, Equatable, Sendable {
    var datum: String
    var kuerzel: String
    /// Name des geplanten Tages (mit Verlegung und Testwoche); nil an einem Ruhetag.
    var geplant: String?
    var gemacht: Bool
    var heute: Bool
    var gewaehlt: Bool

    var id: String { datum }

    /// "Mittwoch, 23. September, Push geplant" für VoiceOver.
    var sprechtext: String {
        let zustand = gemacht ? String(localized: "trainiert") : geplant.map { String(localized: "\($0) geplant") } ?? String(localized: "Ruhetag")
        return "\(Datum.anzeige(datum)), \(zustand)"
    }
}

/// Alles, was die Startseite des Trainings zeigt, als Werte. `bauen` rechnet es aus Plan und Einheiten.
struct GymStartStand: Equatable, Sendable {
    var gewaehlt: String
    var heute: String
    var tag: TrainingsTag?
    /// "54 min · 27 Sätze", "geplant: Push", "Ruhetag" (`GymStartLogik.status`).
    var status: String
    var splitName: String?
    var planTage: Int
    /// Nur am heutigen Tag.
    var knopf: GymStartKnopf?
    var vergessen: Bool
    /// Zeitfenster des Studios (`ZeitSchaetzung.slot`), nil = keine feste Uhrzeit.
    var slotMinuten: Int? = nil
    /// Wohin der gewählte Tag diese Woche verlegt werden kann (`WochenLogik.verlegeZiele`): "heute Beine statt Push".
    var ziele: [WochenLogik.Ziel] = []
    /// Diese Woche sind Tage verlegt: dann gibt es "Zurück auf Plan".
    var verlegt = false
    /// "Testwoche: …, ab Montag wieder …", solange die laufende Woche getestet wird.
    var testHinweis: String? = nil
    var woche: [GymWochenTag] = []

    static func bauen(sessions: [GymSession], plan: TrainingsPlan, gewaehlt: String, jetzt: Date, slotMinuten: Int? = nil) -> GymStartStand {
        let heute = Datum.text(jetzt)
        let gemacht = Set(sessions.map { Datum.text($0.start) })
        let name = TrainingLogik.tag(plan, datum: gewaehlt).map { $0.name.isEmpty ? String(localized: "Training") : $0.name }
        var knopf: GymStartKnopf?
        if gewaehlt == heute {
            if sessions.contains(where: { TrainingLogik.laufend($0, jetzt: jetzt) }) { knopf = .weiter }
            else if TrainingLogik.fortsetzbar(sessions, jetzt: jetzt) != nil { knopf = .fortsetzen }
            else { knopf = .starten }
        }
        let montag = Datum.montagDerWoche(gewaehlt)
        let leiste = (0..<7).map { i -> GymWochenTag in
            let d = Datum.addTage(montag, i)
            let geplant = TrainingLogik.tag(plan, datum: d).map { $0.name.isEmpty ? String(localized: "Training") : $0.name }
            return GymWochenTag(datum: d, kuerzel: HabitLogik.wochentagKuerzel[i], geplant: geplant, gemacht: gemacht.contains(d), heute: d == heute, gewaehlt: d == gewaehlt)
        }
        return GymStartStand(
            gewaehlt: gewaehlt, heute: heute, tag: TrainingLogik.tag(plan, datum: gewaehlt),
            status: GymStartLogik.status(sessions, datum: gewaehlt, heute: heute, geplant: name, jetzt: jetzt),
            splitName: plan.splitName, planTage: Set(plan.tage.flatMap(\.wochentage)).count, knopf: knopf,
            vergessen: TrainingLogik.vergessen(sessions, jetzt: jetzt) != nil, slotMinuten: slotMinuten,
            ziele: WochenLogik.verlegeZiele(plan, von: gewaehlt, heute: heute, gemacht: gemacht),
            verlegt: WochenLogik.verlegt(plan, heute: heute), testHinweis: WochenLogik.testHinweis(plan, heute: heute),
            woche: leiste
        )
    }

    /// "Heute Beine statt Push" (Idee 27): der Plan sah für diesen Tag etwas anderes vor als das, was gewählt wurde.
    static func abweichung(geplant: TrainingsTag?, gewaehlt: TrainingsTag?) -> String? {
        guard let gewaehlt, let geplant, geplant.id != gewaehlt.id else { return nil }
        let heute = gewaehlt.name.isEmpty ? String(localized: "Training") : gewaehlt.name
        let statt = geplant.name.isEmpty ? String(localized: "Training") : geplant.name
        return String(localized: "Heute \(heute) statt \(statt)")
    }
}
