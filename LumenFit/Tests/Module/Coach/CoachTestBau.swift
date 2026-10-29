import Foundation
@testable import LumenFit

/// Kleine Baustelle der Coach-Tests: Nachrichten und Kontexte mit erfundenen Werten.
enum CoachTestBau {
    static func nachricht(_ id: String, _ rolle: CoachRolle, _ text: String, _ zeit: Date, chips: [CoachChip] = [], daumen: Bool? = nil) -> CoachNachricht {
        CoachNachricht(id: id, rolle: rolle, text: text, zeit: zeit, chips: chips, daumen: daumen)
    }

    /// Ein normaler Tag mit erfundenen Zahlen.
    static func kontext(tag: String = "2026-10-08", bereitschaft: Int? = 72, schlafMinuten: Int? = 450, schritte: Int? = 6200,
                        letztesTraining: String? = "Push, gestern, 52 Minuten, 14 Sätze", stimmung: LumiStimmung = .bereit,
                        merkzettel: [String] = []) -> CoachKontext {
        CoachKontext(tag: tag, bereitschaft: bereitschaft, schlafMinuten: schlafMinuten, schritte: schritte, letztesTraining: letztesTraining,
                     stimmung: stimmung, ziele: Ziele(), merkzettel: merkzettel)
    }

    static func anfrage(_ frage: String, verlauf: [CoachNachricht] = [], kontext: CoachKontext = kontext()) -> CoachAnfrage {
        CoachAnfrage(frage: frage, verlauf: verlauf, kontext: kontext)
    }
}

enum CoachTestFehler: Error { case keinProfil }

extension CoachTestBau {
    /// Eine Vorschau-Umgebung mit einem Profil und einer Uhr, die auf `uhrzeit` Stunden am 23.09.2026 (Mittwoch) steht.
    @MainActor
    static func umgebung(stunde: Double = 12, motor: (any CoachMotor)? = nil) throws -> (umgebung: AppUmgebung, daten: DatenSatz, uhr: TestUhr) {
        let uhr = TestUhr(Datum.datum("2026-09-23").addingTimeInterval(stunde * 3600))
        let umgebung = AppUmgebung.vorschau(uhr: uhr.uhr)
        _ = try umgebung.profil.anlegen(name: "Beispiel", passwort: "abcd")
        guard let daten = umgebung.daten else { throw CoachTestFehler.keinProfil }
        if let motor { umgebung.coachMotor = motor }
        return (umgebung, daten, uhr)
    }

    /// Ein Plan mit einem Tag am Donnerstag (4): vier Arbeitssätze mit Aufwärmsatz, eine Übung mit zwei Sätzen, Cardio mit 20 Minuten.
    static func plan(minutenCardio: Int = 20, saetze: Int = 4, wochentag: Int = 4) -> TrainingsPlan {
        let kraft = PlanUebung(id: "u1", uebung: PlanUebung.eigen, name: "Bankdrücken",
                               saetze: [PlanSatz(wdh: 10, kg: 20, failure: false, typ: "w")] + Array(repeating: PlanSatz(wdh: 8, kg: 60, failure: false), count: saetze),
                               minuten: nil)
        let kurz = PlanUebung(id: "u2", uebung: PlanUebung.eigen, name: "Fliegende",
                              saetze: Array(repeating: PlanSatz(wdh: 12, kg: 10, failure: false), count: 2), minuten: nil)
        let cardio = PlanUebung(id: "u3", uebung: PlanUebung.eigen, name: "Laufband", saetze: [], minuten: minutenCardio)
        return TrainingsPlan(tage: [TrainingsTag(id: "t1", name: "Push", wochentage: [wochentag], uebungen: [kraft, kurz, cardio])])
    }
}
