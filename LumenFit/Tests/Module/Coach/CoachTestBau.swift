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
