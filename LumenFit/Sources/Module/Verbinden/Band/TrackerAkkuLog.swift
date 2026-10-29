// Quelle: Lovea Health/Tracker/TrackerAkkuLog.swift
import Foundation

/// Anzeige-Regel des Akku-Werts (Idee 88). Loveas Akku-Log mit Messpunkten, Puffer und Server-Upload (`POST /band/akku`) entfällt:
/// Lumen Fit ist client-only. Den Verlauf der letzten Tage hält `TrackerAkkuVerlauf`.
enum TrackerAkkuLog {
    /// Ein Akku-Wert, der länger her ist (zwei Abfrage-Runden), zeigt die Seite als nicht aktuell. Das gilt bei zehn Minuten Abstand;
    /// bei seltenerer Abfrage (Modus Sparen) gibt die Seite zwei Abstände mit (`grenze`).
    static let veraltetNach: TimeInterval = 20 * 60

    /// Ob die Seite den Akku-Wert als nicht aktuell kennzeichnet: Verbindung weg oder die letzte Antwort ist zu alt.
    /// Ein Wert, der Stunden alt ist, darf nicht wie der heutige aussehen.
    static func veraltet(gelesen: Date, verbunden: Bool, jetzt: Date, grenze: TimeInterval = veraltetNach) -> Bool {
        !verbunden || jetzt.timeIntervalSince(gelesen) > grenze
    }
}
