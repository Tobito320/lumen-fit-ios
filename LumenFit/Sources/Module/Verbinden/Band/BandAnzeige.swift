// Quelle: Lovea Health/Tracker/TrackerSeite.swift
import Foundation

/// Die Texte und Zustände der Band-Seite als reine Regeln, ohne Oberfläche testbar. Das Band heißt hier "Band" (Lovea: "Tracker").
enum BandAnzeige {
    struct Status: Equatable {
        var symbol: String
        var titel: String
        var hilfe: String?
        /// Rote Zustände (Bluetooth, Fehler): die Hilfe bekommt ein Warnsymbol.
        var warnung = false
        /// Sucht oder liest: statt des Symbols dreht ein Fortschrittsring.
        var arbeitet = false
    }

    static let wecken = String(localized: "Das Band einmal antippen oder bewegen. Es sendet nach dem Trennen nicht mehr, bis es geweckt wird.")

    /// Ein Zustand, ein Titel, ein Satz, der sagt, was jetzt hilft. Der Status steht immer mit Symbol und Text, nie nur in Farbe.
    static func status(_ zustand: TrackerModell.Zustand, gekoppelt: Bool, abfrageLaeuft: Bool) -> Status {
        switch zustand {
        case .verbunden:
            Status(symbol: "checkmark.circle.fill", titel: abfrageLaeuft ? String(localized: "Verbunden, liest") : String(localized: "Verbunden"), hilfe: nil, arbeitet: abfrageLaeuft)
        case .sucht:
            Status(symbol: "magnifyingglass", titel: String(localized: "Sucht das Band"), hilfe: nil, arbeitet: true)
        case .wartet:
            Status(symbol: "hourglass", titel: String(localized: "Wartet auf das Band"), hilfe: wecken)
        case .nichtGefunden:
            Status(symbol: "exclamationmark.circle", titel: String(localized: "Nicht gefunden"), hilfe: wecken, warnung: true)
        case .getrennt:
            gekoppelt
                ? Status(symbol: "circle.dashed", titel: String(localized: "Getrennt"), hilfe: String(localized: "Lumen Fit hält keine Verbindung offen. Tippe auf Verbinden."))
                : Status(symbol: "circle.dashed", titel: String(localized: "Nicht verbunden"), hilfe: String(localized: "Das Band antippen, dann auf Band suchen tippen."))
        case .bluetoothAus:
            Status(symbol: "bolt.horizontal.circle", titel: String(localized: "Bluetooth ist aus"), hilfe: String(localized: "Schalte Bluetooth im Kontrollzentrum ein."), warnung: true)
        case .nichtErlaubt:
            Status(symbol: "lock.circle", titel: String(localized: "Bluetooth nicht erlaubt"), hilfe: String(localized: "Erlaube Bluetooth für Lumen Fit in den iOS-Einstellungen."), warnung: true)
        case .nichtVerfuegbar:
            Status(symbol: "xmark.circle", titel: String(localized: "Bluetooth nicht verfügbar"),
                   hilfe: String(localized: "Dieses Gerät kann Bluetooth gerade nicht nutzen. Starte das iPhone neu, wenn es so bleibt."), warnung: true)
        case .fehler(let text):
            Status(symbol: "exclamationmark.triangle", titel: String(localized: "Verbindung fehlgeschlagen"),
                   hilfe: String(localized: "\(text). Das Band antippen und erneut auf Verbinden tippen."), warnung: true)
        }
    }

    static func akkuText(prozent: Int, laedt: Bool, vermutet: Bool) -> String {
        guard laedt else { return "\(prozent) %" }
        return vermutet ? String(localized: "\(prozent) %, lädt vermutlich") : String(localized: "\(prozent) %, lädt")
    }

    /// Ein Wert, der Stunden alt ist (Verbindung weg), trägt sein Alter; VoiceOver sagt "nicht aktuell".
    static func akkuSprechtext(prozent: Int, laedt: Bool, vermutet: Bool, veraltet: Bool) -> String {
        var text = String(localized: "\(prozent) Prozent")
        if laedt { text += vermutet ? String(localized: ", lädt vermutlich") : String(localized: ", lädt") }
        if veraltet { text += String(localized: ", nicht aktuell") }
        return text
    }

    /// Das Akku-Symbol zur Füllung; beim Laden mit Blitz.
    static func akkuSymbol(prozent: Int, laedt: Bool) -> String {
        if laedt { return "battery.100percent.bolt" }
        switch prozent {
        case 88...: return "battery.100percent"
        case 63...: return "battery.75percent"
        case 38...: return "battery.50percent"
        case 13...: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    /// Anteil für den Akku-Balken, immer zwischen 0 und 1.
    static func akkuAnteil(_ prozent: Int) -> Double { Double(min(max(prozent, 0), 100)) / 100 }

    /// Bis zu sechs Tage vor heute, an denen das Band Schritte geliefert hat, neueste zuerst.
    static func fruehereTage(_ tage: [String: BandTag], heute: String) -> [(tag: String, schritte: Int)] {
        tage.filter { $0.key < heute && $0.value.schritte > 0 }
            .sorted { $0.key > $1.key }
            .prefix(6)
            .map { (tag: $0.key, schritte: $0.value.schritte) }
    }

    /// Die Wahl des Abstands der Puls-Dauermessung: die Liste des Modus plus der Wert, den das Band hat, auch wenn die Liste ihn nicht kennt.
    static func abstandsListe(aktuell: Int) -> [Int] {
        Array(Set(TrackerModus.pulsAbstaende + [aktuell])).sorted()
    }

    /// Die Zeile unter "Puls jetzt messen"; `nil`, wenn keine Messung läuft oder lief.
    static func pulsMessungText(_ messung: TrackerModell.PulsMessung) -> String? {
        switch messung {
        case .aus: nil
        case .misst: String(localized: "Misst. Das dauert bis zu 45 Sekunden, das Band muss eng am Arm sitzen.")
        case .fertig(let wert, let um): String(localized: "Zuletzt \(wert) Schläge/Min. um \(Datum.uhrzeit(um)) Uhr.")
        case .fehler(let text): text
        }
    }

    /// Strecke in Kilometern mit zwei Stellen, deutsches Komma.
    static func kilometer(meter: Int) -> String {
        (Double(meter) / 1000).formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "de_DE"))) + " km"
    }
}
