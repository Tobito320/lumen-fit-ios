import Foundation

/// Op `fit.coach.merke`.
struct MerkEintrag: Codable, Hashable, Sendable {
    var text: String
    var entfernt: Bool
}

enum CoachRolle: String, Codable, Sendable { case nutzer, coach }

enum CoachAktion: Codable, Hashable, Sendable {
    case antworten(String)
    case gewohnheitAnlegen(name: String)
    case planMorgenLeicht
    case oeffne(Route)
    case nichts
}

struct CoachChip: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var text: String
    var aktion: CoachAktion
}

/// Op `fit.coach.nachricht`.
struct CoachNachricht: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var rolle: CoachRolle
    var text: String
    var zeit: Date
    var chips: [CoachChip]
    var daumen: Bool?
}

struct CoachKontext: Codable, Sendable {
    var tag: String
    var bereitschaft: Int?
    var schlafMinuten: Int?
    var schritte: Int?
    var letztesTraining: String?
    var stimmung: LumiStimmung
    var ziele: Ziele
    var merkzettel: [String]
}

struct CoachAnfrage: Sendable {
    var frage: String
    var verlauf: [CoachNachricht]
    var kontext: CoachKontext
    /// Wunschton der Person ("locker", "knapp", "direkt", leer = Standard), eigenes Ziel in einem Satz und der Schalter "hält mich an den Plan".
    var ton: String = ""
    var ziel: String = ""
    var disziplin = false
}

struct CoachAntwort: Sendable {
    var text: String
    var chips: [CoachChip]
}
