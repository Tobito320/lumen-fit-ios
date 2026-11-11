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
/// Schritte (ab 1.0.1) nur, wenn er sie mitzählt und mir Schritte zeigt; sonst nil (auch im Cache von 1.0).
struct StatsFreund: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var punkte: Int
    var trainings: Int
    var sets: Int
    var serie: Int
    var rekorde: [String: Double]
    var schritteHeute: Int?
    var schritteMonat: Int?
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
    /// Schritte heute und seit dem 1. des Monats; nil = zählt keine Schritte mit (oder Cache von 1.0).
    var schritteHeute: Int?
    var schritteMonat: Int?
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
    /// Schritte aus Apple Health (Tag, heute, Summe seit dem 1.): nur mit Mitzählen > Schritte und Health-Freigabe, sonst fehlen alle drei.
    var schritteTag: String?
    var schritteHeute: Int?
    var schritteMonat: Int?

    static let aus = StatsMeldung(freunde: false, oeffentlich: false)

    /// Dieselbe Meldung ohne Schritte: ändern sich nur die Schritte, geht sie höchstens alle `StatsDienst.sendePause` hoch.
    var ohneSchritte: StatsMeldung {
        var m = self
        m.schritteTag = nil
        m.schritteHeute = nil
        m.schritteMonat = nil
        return m
    }
}

/// Die Messgrößen der Chips über der Liste. Schritte ist ein Chip mit zwei Zeiträumen (Heute | Monat darunter).
enum StatsMass: String, CaseIterable, Identifiable, Sendable {
    case schritteHeute, schritteMonat, punkte, trainings, sets, serie

    /// Die Chips von links: Schritte zuerst (Besitzer 11.11.2026), dann Punkte, Trainings, Sets, Serie.
    static let chips: [StatsMass] = [.schritteHeute, .punkte, .trainings, .sets, .serie]

    var id: String { rawValue }

    var istSchritte: Bool { self == .schritteHeute || self == .schritteMonat }

    var titel: String {
        switch self {
        case .schritteHeute, .schritteMonat: String(localized: "Schritte")
        case .punkte: String(localized: "Punkte")
        case .trainings: String(localized: "Trainings")
        case .sets: String(localized: "Sets")
        case .serie: String(localized: "Serie")
        }
    }

    /// Unter dem Platz: "6.240 Schritte heute", "187.300 Schritte im November", "57 Punkte diese Woche", "4 Wochen in Folge".
    func wertText(_ wert: Int, jetzt: Date) -> String {
        switch self {
        case .schritteHeute: return String(localized: "\(StatsLogik.zahl(wert)) Schritte heute")
        case .schritteMonat:
            let monat = jetzt.formatted(Date.FormatStyle(locale: Datum.anzeigeLocale, calendar: Datum.kalender, timeZone: Datum.zone).month(.wide))
            return String(localized: "\(StatsLogik.zahl(wert)) Schritte im \(monat)")
        case .punkte: return String(localized: "\(wert) Punkte diese Woche")
        case .trainings: return String(localized: "\(wert) Trainings diese Woche")
        case .sets: return String(localized: "\(wert) Sets diese Woche")
        case .serie: return String(localized: "\(wert) Wochen in Folge")
        }
    }

    /// Mein Wert; Schritte nil, wenn ich sie nicht mitzähle (dann stehe ich nicht in der Schritte-Liste).
    func wert(_ e: StatsEigene) -> Int? {
        switch self {
        case .schritteHeute: e.schritte?.heute
        case .schritteMonat: e.schritte?.monat
        case .punkte: e.zahlen.punkte
        case .trainings: e.zahlen.trainings
        case .sets: e.zahlen.sets
        case .serie: e.zahlen.serie
        }
    }

    func wert(_ e: StatsEintrag) -> Int? {
        switch self {
        case .schritteHeute: e.schritteHeute
        case .schritteMonat: e.schritteMonat
        case .punkte: e.punkte
        case .trainings: e.trainings
        case .sets: e.sets
        case .serie: e.serie
        }
    }

    func wert(_ f: StatsFreund) -> Int? {
        switch self {
        case .schritteHeute: f.schritteHeute
        case .schritteMonat: f.schritteMonat
        case .punkte: f.punkte
        case .trainings: f.trainings
        case .sets: f.sets
        case .serie: f.serie
        }
    }
}
