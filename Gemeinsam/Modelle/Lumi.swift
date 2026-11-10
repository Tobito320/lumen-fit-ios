import Foundation

/// Lumis Zustand (Set vom 10.11.2026, 14 Fälle). Die ersten fünf Rohwerte sind gespeichert (`fit.lumi.stimmung`, Widget-Snapshot) und bleiben;
/// `stolz` ist der Zustand "Neuer Rekord". Welcher Zustand gilt, sagt `LumiLogik`.
enum LumiStimmung: String, Codable, CaseIterable, Sendable {
    case bereit, muede, stolz, schlaeft, denkt
    case willkommen, anfeuern, pause, ziel, serie, erschoepft, ruhetag, muskelkater, vermisst
}

/// Name für `LumiLogik` und neue Aufrufer; derselbe Typ wie die gespeicherte Stimmung.
typealias LumiZustand = LumiStimmung

/// Antwort des Morgen-Checks (Op `fit.lumi.stimmung`): 1 bis 5, 1 = schwer, 5 = top.
struct StimmungsEintrag: Codable, Hashable, Sendable {
    var tag: String
    var wert: Int
    var stimmung: LumiStimmung
}

/// Lumis Stufe 1 bis 9 aus der Zahl erreichter Meilensteine (25 Medaillen). Fortschritt zeigt den Pfad, rechnet die Stufe nicht neu.
enum LumiStufe {
    /// Erreichte Meilensteine, ab denen Stufe 1 ... 9 gilt.
    nonisolated static let schwellen = [0, 1, 3, 5, 8, 11, 15, 19, 23]

    static func stufe(erreicht: Int) -> Int {
        schwellen.lastIndex { erreicht >= $0 }.map { $0 + 1 } ?? 1
    }
}

/// Op `fit.lumi.meilenstein`: gleiche `id` ersetzt, die letzte Op gewinnt.
struct MeilensteinStand: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var erreicht: Date
}

/// Op `fit.band.schlaf` (schreibt das Modul verbinden).
struct BandSchlafOp: Codable, Hashable, Sendable {
    var tag: String
    var start: Date
    var ende: Date
    var phasen: [SchlafAbschnitt]
}

/// Op `fit.band.tag` (schreibt das Modul verbinden). Zählt seit 10.11.2026 nicht mehr für die Schritte (nur Apple Health); die Ops bleiben gespeichert.
struct BandTagOp: Codable, Hashable, Sendable {
    var tag: String
    var schritte: Int
    var meter: Int
}
