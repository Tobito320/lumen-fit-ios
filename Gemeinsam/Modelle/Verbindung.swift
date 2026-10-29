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
