import Foundation

/// Antwort von `GET /stats` (Server `server/stats.js`), auch der Cache `stats-server.json`.
/// Freunde tragen ihre Verbindungs-Id, Einträge in Alle eine öffentliche Id; Konto-Ids kommen nie an.
struct StatsAntwort: Codable, Equatable, Sendable {
    /// Montag der Woche (Berlin), für die die Zahlen gelten.
    var montag: String
    var ich: StatsIch
    var freunde: [StatsFreund]
    var alle: [StatsEintrag]
    /// kg-Verteilung je Übung (Katalog-Id): Gruppe "alle" oder Trainingsjahr ("1" …) -> [[kg, Anzahl]], nur ab 5 Personen.
    var rekorde: [String: [String: [[Double]]]]
}

/// Was der Server von mir hält. `ausgeblendet`: ab 3 Meldungen sehen andere mich in Alle nicht, bis es geprüft ist.
struct StatsIch: Codable, Equatable, Sendable {
    var freunde: Bool
    var oeffentlich: Bool
    var spitzname: String?
    var ausgeblendet: Bool
}

/// Ein Freund, der "Freunde sehen mich" an hat; `rekorde`: schwerstes Gewicht je Übung (Katalog-Id).
struct StatsFreund: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var punkte: Int
    var trainings: Int
    var sets: Int
    var serie: Int
    var rekorde: [String: Double]
}

/// Ein Eintrag in Alle: Spitzname, Trainingsjahr (1 = erstes Jahr) und Zahlen; `ich` ist der eigene.
struct StatsEintrag: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var jahr: Int?
    var punkte: Int
    var trainings: Int
    var sets: Int
    var serie: Int
    var ich: Bool
}

/// Körper von `PUT /stats`. Beide Schalter aus: nur die zwei Felder, der Server löscht dann alles. Fehlende Felder lässt der Encoder weg.
struct StatsMeldung: Codable, Equatable, Sendable {
    var freunde: Bool
    var oeffentlich: Bool
    var spitzname: String?
    var jahr: Int?
    var montag: String?
    var trainings: Int?
    var sets: Int?
    var rekordeNeu: Int?
    var serie: Int?
    var rekorde: [String: Double]?

    static let aus = StatsMeldung(freunde: false, oeffentlich: false)
}

/// Die Messgrößen der Chips über der Liste.
enum StatsMass: String, CaseIterable, Identifiable, Sendable {
    case punkte, trainings, sets, serie

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .punkte: String(localized: "Punkte")
        case .trainings: String(localized: "Trainings")
        case .sets: String(localized: "Sets")
        case .serie: String(localized: "Serie")
        }
    }

    /// Unter dem Platz: "57 Punkte diese Woche", "4 Wochen in Folge".
    func wertText(_ wert: Int) -> String {
        switch self {
        case .punkte: String(localized: "\(wert) Punkte diese Woche")
        case .trainings: String(localized: "\(wert) Trainings diese Woche")
        case .sets: String(localized: "\(wert) Sets diese Woche")
        case .serie: String(localized: "\(wert) Wochen in Folge")
        }
    }

    func wert(_ z: StatsZahlen) -> Int {
        switch self {
        case .punkte: z.punkte
        case .trainings: z.trainings
        case .sets: z.sets
        case .serie: z.serie
        }
    }

    func wert(_ e: StatsEintrag) -> Int {
        switch self {
        case .punkte: e.punkte
        case .trainings: e.trainings
        case .sets: e.sets
        case .serie: e.serie
        }
    }

    func wert(_ f: StatsFreund) -> Int {
        switch self {
        case .punkte: f.punkte
        case .trainings: f.trainings
        case .sets: f.sets
        case .serie: f.serie
        }
    }
}
