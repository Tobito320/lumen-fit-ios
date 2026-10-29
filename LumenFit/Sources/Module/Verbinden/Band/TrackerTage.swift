// Quelle: Lovea Health/Tracker/TrackerTage.swift
import Foundation

/// Was der Tracker über einen Tag gemeldet hat: je Viertelstunde (Slot) der größte gesehene Wert.
/// Der Tracker liefert nur Viertelstunden mit Bewegung und wiederholt sie bei jeder Abfrage; ein
/// abgebrochener Abruf liefert weniger Zeilen. Darum zählt je Slot das Maximum, und eine Abfrage kann
/// einen Tag nie verkleinern. Summieren über Abfragen gibt es nicht (sonst wäre jede Abfrage doppelt gezählt).
struct BandTag: Codable, Equatable, Sendable {
    struct Zeile: Codable, Equatable, Sendable {
        var schritte: Int
        var meter: Int
    }

    var zeilen: [Int: Zeile] = [:]

    var schritte: Int { zeilen.values.reduce(0) { $0 + $1.schritte } }
    var meter: Int { zeilen.values.reduce(0) { $0 + $1.meter } }
    /// Beginn der letzten Viertelstunde mit Bewegung, in Minuten seit Mitternacht.
    var letzteMinute: Int? { zeilen.keys.max().map { $0 * 15 } }

    mutating func aufnehmen(_ zeile: TrackerProtokoll.SchrittSlot) {
        let alt = zeilen[zeile.slot]
        zeilen[zeile.slot] = Zeile(schritte: max(alt?.schritte ?? 0, zeile.schritte), meter: max(alt?.meter ?? 0, zeile.meter))
    }
}

/// Die Tage, die der Tracker zuletzt geliefert hat (heute und die Tage davor), mit Stand der letzten
/// vollständigen Abfrage. Nur im Speicher: dauerhaft sind die Ops `fit.band.tag` (`BandTagOp`, eine je Tag), die
/// `GesundheitsStand` je Tag mit dem Maximum aus Health und Band verrechnet. Die Viertelstunden (`BandTag.zeilen`) sind nötig,
/// damit eine neue Abfrage einen Tag nie verkleinert und nie doppelt zählt.
struct BandTage: Codable, Equatable, Sendable {
    /// So viele Tage bleiben im Speicher. Der Tracker kennt selbst nur wenige Tage zurück.
    static let behalten = 14

    var tage: [String: BandTag] = [:]
    /// Ende der letzten Abfrage, die bis zum Schluss durchlief.
    var stand: Date?

    mutating func aufnehmen(_ zeile: TrackerProtokoll.SchrittSlot) {
        tage[zeile.tag, default: BandTag()].aufnehmen(zeile)
    }

    /// `nil`, wenn der Tracker für den Tag nie Zeilen geliefert hat.
    func schritte(_ tag: String) -> Int? { tage[tag]?.schritte }
    func meter(_ tag: String) -> Int? { tage[tag]?.meter }

    /// Wirft Tage vor dem Fenster weg. Tage sind `yyyy-MM-dd`, also stimmt der Textvergleich.
    mutating func kuerzen(heute: String) {
        let grenze = Datum.addTage(heute, -(Self.behalten - 1))
        tage = tage.filter { $0.key >= grenze }
    }

    /// Die Ops, die noch nicht geschrieben sind: je Tag eine, wenn der Tracker mehr meldet als die letzte Op dieses Tages
    /// (`bisher`: Tag -> zuletzt geschriebene Werte). So wächst ein Tag nur und eine halbe Abfrage verkleinert ihn nie.
    func ops(bisher: [String: BandTagOp]) -> [BandTagOp] {
        tage.keys.sorted().compactMap { tag in
            guard let werte = tage[tag] else { return nil }
            let alt = bisher[tag]
            let op = BandTagOp(tag: tag, schritte: max(werte.schritte, alt?.schritte ?? 0), meter: max(werte.meter, alt?.meter ?? 0))
            return op == alt || op.schritte == 0 && alt == nil ? nil : op
        }
    }
}
