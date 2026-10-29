// Quelle: Lovea Health/Tracker/TrackerVerlauf.swift
import Foundation

/// Messreihen von heute, die der Tracker geliefert hat (Minute des Tages, Wert). Die Verlauf-Karten der Tracker-Seite zeichnen sie.
/// Liegen in `UserDefaults` (wie `BandTage`), damit die Karten auch ohne Verbindung etwas zeigen. Es gilt nur der Tag, zu dem sie
/// gehören: `fuer` gibt für einen anderen Tag leere Reihen zurück.
struct BandReihen: Codable, Equatable, Sendable {
    static let schluessel = "fit.band.reihen.v1"

    struct Punkt: Codable, Equatable, Sendable, Identifiable {
        /// Minute des Tages (0 bis 1439) nach der Uhr des Trackers.
        var minute: Int
        var wert: Int
        var id: Int { minute }
    }

    /// `yyyy-MM-dd`, zu dem die Reihen gehören.
    var tag = ""
    var puls: [Punkt] = []
    var stress: [Punkt] = []
    var hrv: [Punkt] = []

    func fuer(_ heute: String) -> BandReihen { tag == heute ? self : BandReihen(tag: heute) }

    static func laden(_ defaults: UserDefaults = .standard) -> BandReihen {
        defaults.data(forKey: schluessel).flatMap { try? JSONDecoder().decode(BandReihen.self, from: $0) } ?? BandReihen()
    }

    func speichern(_ defaults: UserDefaults = .standard) {
        if let daten = try? JSONEncoder().encode(self) { defaults.set(daten, forKey: Self.schluessel) }
    }

    static func loeschen(_ defaults: UserDefaults = .standard) { defaults.removeObject(forKey: schluessel) }
}

extension PulsVerlauf {
    /// Alle Pulswerte des Tages im Bereich 30 bis 220 (0 heißt "nicht gemessen"), deren Slot nicht nach `jetzt` liegt: der Tracker kann in
    /// Slots, die er noch nicht gemessen hat, Reste vom Vortag halten (siehe Gadgetbridge, `CMD_SYNC_HEART_RATE`).
    func punkte(tagesanfang: Date, bis jetzt: Date) -> [BandReihen.Punkt] {
        var liste: [BandReihen.Punkt] = []
        for i in werte.indices where (30...220).contains(Int(werte[i])) {
            let minute = i * abstand
            guard tagesanfang.addingTimeInterval(TimeInterval(minute * 60)) <= jetzt else { continue }
            liste.append(BandReihen.Punkt(minute: minute, wert: Int(werte[i])))
        }
        return liste
    }
}

/// Der Verlauf von Stress oder HRV eines Tages, wie ihn der Tracker in Paketen liefert (Gadgetbridge, am Gerät ungeprüft): 48 Werte im
/// Halbstundentakt ab 00:00, 0 heißt "nicht gemessen". Paket 1 trägt die Slots 0 bis 11, Paket n ab 2 die Slots 12 + (n - 2) * 13 und folgende.
/// Gadgetbridge rechnet mit vier Datenpaketen; mehr Slots als 48 (das letzte Paket hat drei zu viel) fallen weg.
struct Halbstundenreihe: Equatable, Sendable {
    static let slots = 48
    /// Minuten zwischen zwei Werten.
    static let takt = 30
    private static let letztesPaket = 4

    private(set) var werte = [UInt8](repeating: 0, count: Halbstundenreihe.slots)

    /// `true`, sobald die Antwort vollständig ist (Paket 4) oder der Tracker "keine Daten" meldet. Das Kopfpaket zählt nicht: ob seine
    /// Zahl die Datenpakete oder alle Pakete meint, ist offen. Fehlt ein Paket, geht die Abfrage nach der Ruhezeit weiter (`TrackerModell`).
    mutating func aufnehmen(_ paket: TrackerProtokoll.VerlaufPaket) -> Bool {
        switch paket {
        case .ende:
            return true
        case .kopf:
            return false
        case .werte(let nr, let neue):
            guard nr >= 1 else { return false }
            let start = nr == 1 ? 0 : 12 + (nr - 2) * 13
            for (i, wert) in neue.enumerated() where start + i < Self.slots {
                werte[start + i] = wert
            }
            return nr >= Self.letztesPaket
        }
    }

    /// Die Werte im Bereich (Stress 1 bis 100, HRV 1 bis 250 ms), deren Slot nicht nach `jetzt` liegt.
    func punkte(bereich: ClosedRange<Int>, tagesanfang: Date, bis jetzt: Date) -> [BandReihen.Punkt] {
        var liste: [BandReihen.Punkt] = []
        for i in werte.indices where bereich.contains(Int(werte[i])) {
            let minute = i * Self.takt
            guard tagesanfang.addingTimeInterval(TimeInterval(minute * 60)) <= jetzt else { continue }
            liste.append(BandReihen.Punkt(minute: minute, wert: Int(werte[i])))
        }
        return liste
    }

    /// Alle 48 Werte als Hex fürs versteckte Log (`TrackerMeldung`).
    var hex: String { werte.map { String(format: "%02x", $0) }.joined() }
}

/// Akku-Verlauf des Trackers für die Karte (Prozent über die Zeit). Eigener Speicher (UserDefaults), damit die Karte auch ohne Verbindung etwas zeigt.
/// Ein Punkt bei jeder Änderung, sonst höchstens einer alle 30 Minuten; sieben Tage.
struct TrackerAkkuVerlauf: Codable, Equatable, Sendable {
    static let schluessel = "fit.band.akkuverlauf.v1"
    static let behalten: TimeInterval = 7 * 86_400
    static let mindestAbstand: TimeInterval = 30 * 60

    struct Punkt: Codable, Equatable, Sendable, Identifiable {
        var zeit: Int
        var prozent: Int
        var laedt: Bool
        var id: Int { zeit }
        var datum: Date { Date(timeIntervalSince1970: TimeInterval(zeit)) }
    }

    var punkte: [Punkt] = []

    mutating func aufnehmen(zeit: Date, prozent: Int, laedt: Bool) {
        let jetzt = Int(zeit.timeIntervalSince1970)
        if let letzter = punkte.last {
            guard jetzt > letzter.zeit else { return } // Uhr zurückgesprungen oder derselbe Punkt
            let gleich = letzter.prozent == prozent && letzter.laedt == laedt
            if gleich && TimeInterval(jetzt - letzter.zeit) < Self.mindestAbstand { return }
        }
        punkte.append(Punkt(zeit: jetzt, prozent: prozent, laedt: laedt))
        let grenze = jetzt - Int(Self.behalten)
        punkte.removeAll { $0.zeit < grenze }
    }

    static func laden(_ defaults: UserDefaults = .standard) -> TrackerAkkuVerlauf {
        defaults.data(forKey: schluessel).flatMap { try? JSONDecoder().decode(TrackerAkkuVerlauf.self, from: $0) } ?? TrackerAkkuVerlauf()
    }

    func speichern(_ defaults: UserDefaults = .standard) {
        if let daten = try? JSONEncoder().encode(self) { defaults.set(daten, forKey: Self.schluessel) }
    }

    static func loeschen(_ defaults: UserDefaults = .standard) { defaults.removeObject(forKey: schluessel) }
}

/// Rechnung hinter den Verlauf-Karten.
enum TrackerVerlauf {
    struct Stunde: Identifiable, Equatable, Sendable {
        let stunde: Int
        let schritte: Int
        var id: Int { stunde }
    }

    /// Die 24 Stunden des Tages mit den Schritten laut Tracker. Der Tracker zählt in Viertelstunden (Slot 0 bis 95, 0x44 = 17:00).
    static func schritteJeStunde(_ tag: BandTag) -> [Stunde] {
        var summe = [Int](repeating: 0, count: 24)
        for (slot, zeile) in tag.zeilen where (0..<96).contains(slot) {
            summe[slot / 4] += zeile.schritte
        }
        return summe.enumerated().map { Stunde(stunde: $0.offset, schritte: $0.element) }
    }

    /// Stress und HRV legt der Tracker im Halbstundentakt ab: öfter als alle 30 Minuten lohnt das Lesen nicht (zehn Pakete je Abfrage).
    static let verlaufAbstand: TimeInterval = 30 * 60

    /// Ob Stress oder HRV jetzt wieder gelesen werden. Springt die Uhr zurück (letztes Lesen "in der Zukunft"), ist es fällig.
    static func verlaufFaellig(letzte: Date?, jetzt: Date) -> Bool {
        guard let letzte else { return true }
        let seitdem = jetzt.timeIntervalSince(letzte)
        return seitdem < 0 || seitdem >= verlaufAbstand
    }

    struct PulsStatistik: Equatable, Sendable {
        let niedrig: Int
        let hoch: Int
        let letzter: Int
        let anzahl: Int
    }

    static func pulsStatistik(_ punkte: [BandReihen.Punkt]) -> PulsStatistik? {
        let werte: [Int] = punkte.map(\.wert)
        guard let letzter = punkte.max(by: { $0.minute < $1.minute }), let niedrig = werte.min(), let hoch = werte.max() else { return nil }
        return PulsStatistik(niedrig: niedrig, hoch: hoch, letzter: letzter.wert, anzahl: punkte.count)
    }
}
