// Quelle: Lovea Health/Verlauf/KonsistenzLogik.swift
import Foundation

/// Trainings-Konsistenz (W-038): Tag -> Anzahl Workouts -> Stufe, und die Wochen-Spalten eines Jahres
/// (Spalten = Wochen ab Montag, Zeilen = Mo bis So). Rein, ohne Zustand; die Karte zeichnet nur.
enum KonsistenzLogik {
    enum Stufe: Equatable, Sendable { case kein, eins, mehr }

    /// Feste Spaltenzahl für jedes Jahr (54 reicht auch für ein Schaltjahr, das an einem Sonntag beginnt),
    /// damit die Jahre untereinander bündig stehen.
    static let spalten = 54
    /// Platz links für "Mo", "Mi" ... und oben für die Monatsnamen, in Zelleneinheiten.
    static let beschriftung = 5.0
    static let kopf = 2.0
    /// Breite zu Höhe des Zeichenbereichs eines Jahres.
    static let verhaeltnis = (beschriftung + Double(spalten)) / (kopf + 7)

    static let monatsnamen = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    struct Zelle: Equatable, Sendable {
        let tag: String
        let anzahl: Int
        let zukunft: Bool
    }

    struct Monat: Equatable, Sendable {
        let name: String
        let spalte: Int
    }

    struct Jahr: Equatable, Identifiable, Sendable {
        let jahr: Int
        /// Index `spalte * 7 + zeile`; nil vor dem 1. Januar und nach dem 31. Dezember.
        let zellen: [Zelle?]
        let monate: [Monat]
        /// Tage mit mindestens einem Workout, Workouts insgesamt.
        let trainingstage: Int
        let workouts: Int
        /// Letzter Tag mit Training in diesem Jahr (für VoiceOver).
        let letzterTag: String?
        var id: Int { jahr }

        func zelle(spalte: Int, zeile: Int) -> Zelle? {
            guard (0..<KonsistenzLogik.spalten).contains(spalte), (0..<7).contains(zeile) else { return nil }
            return zellen[spalte * 7 + zeile]
        }
    }

    static func stufe(_ anzahl: Int) -> Stufe {
        anzahl >= 2 ? .mehr : (anzahl == 1 ? .eins : .kein)
    }

    /// Workouts je Tag (`yyyy-MM-dd`, Europe/Berlin).
    static func tage(_ sessions: [GymSession]) -> [String: Int] {
        sessions.reduce(into: [:]) { $0[Datum.text($1.start), default: 0] += 1 }
    }

    /// Jahre mit Raster, neuestes zuerst: `auswahl` nil = Gesamt (vom ersten Trainingsjahr bis heute).
    static func jahre(tage: [String: Int], heute: String, auswahl: Int?) -> [Jahr] {
        if let auswahl { return [jahr(auswahl, tage: tage, heute: heute)] }
        return verfuegbar(tage: tage, heute: heute).map { jahr($0, tage: tage, heute: heute) }
    }

    /// Jahre für die Auswahl, neuestes zuerst; ohne Training nur das laufende.
    static func verfuegbar(tage: [String: Int], heute: String) -> [Int] {
        let jetzt = Int(heute.prefix(4)) ?? 2026
        let erstes = tage.keys.compactMap { Int($0.prefix(4)) }.min().map { min($0, jetzt) } ?? jetzt
        return Array((erstes...jetzt).reversed())
    }

    /// Kalender ohne Calendar-Aufrufe je Tag: nur der Wochentag des 1. Januar kommt aus `Datum`.
    static func jahr(_ j: Int, tage: [String: Int], heute: String) -> Jahr {
        var i = Datum.wochentag(String(format: "%04d-01-01", j)) - 1
        let schalt = (j % 4 == 0 && j % 100 != 0) || j % 400 == 0
        let laengen = [31, schalt ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var zellen = [Zelle?](repeating: nil, count: spalten * 7)
        var monate: [Monat] = []
        var trainingstage = 0
        var workouts = 0
        var letzter: String?
        for (m, laenge) in laengen.enumerated() {
            monate.append(Monat(name: monatsnamen[m], spalte: i / 7))
            for d in 1...laenge {
                let tag = String(format: "%04d-%02d-%02d", j, m + 1, d)
                let n = tage[tag] ?? 0
                zellen[i] = Zelle(tag: tag, anzahl: n, zukunft: tag > heute)
                if n > 0 {
                    trainingstage += 1
                    workouts += n
                    letzter = tag
                }
                i += 1
            }
        }
        return Jahr(jahr: j, zellen: zellen, monate: monate, trainingstage: trainingstage, workouts: workouts, letzterTag: letzter)
    }

    /// Spalte und Zeile unter einem Tipp (`x`, `y` im Zeichenbereich der Breite `breite`); nil außerhalb des Rasters.
    static func treffer(x: Double, y: Double, breite: Double) -> (spalte: Int, zeile: Int)? {
        guard breite > 0 else { return nil }
        let einheit = breite / (beschriftung + Double(spalten))
        let spalte = Int(((x / einheit) - beschriftung).rounded(.down))
        let zeile = Int(((y / einheit) - kopf).rounded(.down))
        guard (0..<spalten).contains(spalte), (0..<7).contains(zeile) else { return nil }
        return (spalte, zeile)
    }

    /// "Push · 18:30 · 45 min" für die Zeile unter dem Raster.
    static func zeile(_ s: GymSession, name: String?) -> String {
        var teile = [name ?? String(localized: "Training"), Datum.uhrzeit(s.start)]
        if let ende = s.ende { teile.append("\(max(1, Int(ende.timeIntervalSince(s.start) / 60))) min") }
        return teile.joined(separator: " · ")
    }
}
