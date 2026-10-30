import Foundation

enum FreigabeArt: String, Codable, CaseIterable, Sendable { case schritte, gym, schlaf, essen }
enum PartnerBereich: Sendable { case heute, schlaf }
enum PartnerEreignisArt: String, Codable, Sendable { case gymStart, gymEnde, ziel, rekord, schlafGut }
enum BandMuster: String, Codable, Sendable { case kurz, lang, doppelt, ruf, pauseEnde }

struct TagesZusammenfassung: Codable, Equatable, Sendable {
    var tag: String
    var schritte: Int?
    var gymTageWoche: Int?
    var schlafMinuten: Int?
    var kcal: Int?
    // Erweiterung (Gleichstand Health): alles optional, eine ältere Datei bleibt lesbar. Jedes Feld gehört zu genau einer Freigabe.
    /// Schrittziel (Freigabe schritte).
    var schritteZiel: Int?
    /// Schritte je Tag (`yyyy-MM-dd`) der laufenden Woche (Freigabe schritte).
    var schritteWoche: [String: Int]?
    /// Tage der laufenden Woche mit Gym (Freigabe gym) und das Wochenziel.
    var gymTage: [String]?
    var gymZiel: Int?
    /// Schlaf je Aufwachtag der laufenden Woche in Minuten und das Ziel (Freigabe schlaf).
    var schlafWoche: [String: Int]?
    var schlafZiel: Int?
    /// Energie-Rat von heute: "hoch", "mittel" oder "niedrig" (Freigabe schlaf), dazu der Gym-Satz (zusätzlich Freigabe gym).
    var energieStufe: String?
    var energieGym: String?
    /// Kennungen eingebauter Gewohnheiten, die heute erledigt sind ("gym" mit Freigabe gym, "wasser" mit Freigabe essen).
    var habitsFertig: [String]?
    /// Phase und Tag des Zyklus in kurzen Hinweisen. Nur wenn die Person es in den Zyklus-Einstellungen erlaubt (kein Teil von `FreigabeArt`).
    var zyklus: ZyklusZusammenfassung?

    init(tag: String, schritte: Int? = nil, gymTageWoche: Int? = nil, schlafMinuten: Int? = nil, kcal: Int? = nil) {
        self.tag = tag; self.schritte = schritte; self.gymTageWoche = gymTageWoche
        self.schlafMinuten = schlafMinuten; self.kcal = kcal
    }
}

struct PartnerEreignis: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var art: PartnerEreignisArt
    var zeit: Date
    var text: String
}

/// Form von `zusammenfassung.json` (Lumen Fit schreibt) und `partner.json` (Lovea schreibt).
struct ZusammenfassungDatei: Codable, Equatable, Sendable {
    var version: Int
    var geschrieben: Date
    var profilName: String
    var freigaben: [FreigabeArt]
    var heute: TagesZusammenfassung
    var ereignisse: [PartnerEreignis]
}

struct BandWunsch: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var muster: BandMuster
    var zeit: Date
    var von: String
}

struct BandStatusDatei: Codable, Equatable, Sendable {
    var version: Int
    var geschrieben: Date
    var verbunden: Bool
    var akkuProzent: Int?
    var name: String?
}

enum PartnerStand: Equatable, Sendable {
    case nichtVerbunden
    case verbunden(ZusammenfassungDatei)
    case veraltet(ZusammenfassungDatei)
    case unbekannteVersion
}

struct FreundKarte: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var woche: String
    var schritte: Int
    var gymTage: Int
    var schlafSchnittMinuten: Int?
    var erstellt: Date
    var respekt: Bool
}
