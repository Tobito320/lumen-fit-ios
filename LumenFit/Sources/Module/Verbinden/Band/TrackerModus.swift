// Quelle: Lovea Health/Tracker/TrackerModus.swift
import Foundation

/// Tracker-Modus (Nutzer 15.10.2026): "Sparen" hält den Akku so lange wie möglich und lässt die Kernfunktionen (Schritte, Schlaf,
/// Partner-Vibration) in Ruhe; "Viele Daten" holt so viel aus dem Band, wie es misst, und achtet im Maß auf den Akku. Nutzer wählt
/// aktiv; solange nichts gewählt ist, schreibt Lumen Fit nichts an den Tracker.
///
/// Die Tabelle schreibt nur Befehle, die das Protokoll belegt (Vault: "Lovea – Armband Protokoll (H59MAX)"):
/// - Puls-Abstand 0x16 (Schreiben 0x02, Byte 2 = 1 an, Byte 3 = Minuten): am H59MAX belegt (Grad A). Gadgetbridge rundet auf 5 Minuten und
///   begrenzt auf 60 (`YawellRingDeviceSupport.onSendConfiguration`, `AbstractYawellRingCoordinator.getHeartRateMeasurementIntervals`).
/// - SpO2 0x2C, Stress 0x36, HRV 0x38 (Schreiben 0x02, Byte 2 = 1 an / 0 aus): Lesen am Gerät belegt (A), Schreiben nach Gadgetbridge
///   (`onSendConfiguration`) und colmi_r02_client, am Gerät noch nicht geprüft.
/// Bewusst nicht dabei, weil für den H59 nicht belegt: Dauer-Temperatur (0x3A, Gadgetbridge erlaubt sie nur beim R05, R09 und R10) und
/// Display-Einstellung 0x05 (Anheben, Helligkeit; Gadgetbridge zeigt sie nur beim R11 und R12, und das Band meldet sie nie zurück).
///
/// "Einmal nachts" synchronisieren gibt es nicht: Lumen Fit hat keinen Hintergrund-Auslöser dafür. Sparen fragt deshalb nur beim Öffnen der App,
/// bei jeder (Wieder-)Verbindung und stündlich ab, solange die App läuft.
enum TrackerModus: String, CaseIterable, Identifiable, Sendable {
    case sparen, daten

    var id: String { rawValue }

    /// `UserDefaults`: der gewählte Modus. Fehlt er, hat Nutzer nie gewählt.
    static let schluessel = "fit.band.modus"
    /// `UserDefaults`: der Modus ist gewählt, aber noch nicht am Tracker angekommen (nicht verbunden oder die Umstellung läuft).
    static let offenSchluessel = "fit.band.modus.offen"
    /// Abstand der App-Abfragen ohne Modus (wie vor dem Modus).
    static let standardAbstand: TimeInterval = 600
    /// Wählbare Puls-Abstände in Minuten (Gadgetbridge `getHeartRateMeasurementIntervals`: 5, 10, 15, 30, 45, 60).
    static let pulsAbstaende = [5, 10, 15, 30, 45, 60]

    static var gewaehlt: TrackerModus? {
        UserDefaults.standard.string(forKey: schluessel).flatMap(TrackerModus.init(rawValue:))
    }

    var name: String {
        switch self {
        case .sparen: "Sparen"
        case .daten: "Viele Daten"
        }
    }

    // MARK: Tabelle

    /// Puls-Abstand am Tracker in Minuten. Sparen nimmt den Spar-Abstand von `TrackerEnergie`; 5 ist das Kürzeste, das Gadgetbridge erlaubt.
    var pulsMinuten: Int {
        switch self {
        case .sparen: TrackerEnergie.sparMinuten
        case .daten: 5
        }
    }

    /// SpO2, Stress und HRV laufen im Modus "Viele Daten" den ganzen Tag mit, im Modus "Sparen" gar nicht.
    func messung(_ art: TrackerProtokoll.Dauermessung) -> Bool { self == .daten }

    /// Sekunden zwischen zwei Abfragen der App, solange die Verbindung steht. Beim Öffnen der App und bei jeder Verbindung wird ohnehin gefragt.
    /// Sparen höchstens so selten, wie die Am-Arm-Erkennung (`TrackerArm`: zwei Puls-Abstände plus fünf Minuten) trägt.
    var abfrageAbstand: TimeInterval {
        switch self {
        case .sparen: 3600
        case .daten: Self.standardAbstand
        }
    }

    /// Alles, was der Modus am Tracker einstellt, in der Reihenfolge, in der Lumen Fit es schreibt.
    var aenderungen: [TrackerProtokoll.Aenderung] {
        var liste: [TrackerProtokoll.Aenderung] = [.puls(an: true, minuten: pulsMinuten)]
        for art in TrackerProtokoll.Dauermessung.allCases { liste.append(.messung(art, an: messung(art))) }
        return liste
    }

    // MARK: Abgleich

    /// Was der Tracker anders hat als der Modus. Ein ungelesener Stand (`nil`) gilt als abweichend: Lumen Fit rät nicht.
    func abweichungen(puls: TrackerProtokoll.PulsEinstellung?, messungen: [TrackerProtokoll.Dauermessung: Bool]) -> [TrackerProtokoll.Aenderung] {
        var liste: [TrackerProtokoll.Aenderung] = []
        if puls != TrackerProtokoll.PulsEinstellung(an: true, intervallMinuten: pulsMinuten) {
            liste.append(.puls(an: true, minuten: pulsMinuten))
        }
        for art in TrackerProtokoll.Dauermessung.allCases where messungen[art] != messung(art) {
            liste.append(.messung(art, an: messung(art)))
        }
        return liste
    }

    /// Was noch zu schreiben ist: die Abweichungen ohne die, die in dieser Verbindung schon versucht wurden. Lehnt der Tracker eine
    /// Einstellung ab, versucht Lumen Fit sie nicht in jeder Runde neu.
    func offene(puls: TrackerProtokoll.PulsEinstellung?, messungen: [TrackerProtokoll.Dauermessung: Bool],
                versucht: [TrackerProtokoll.Aenderung]) -> [TrackerProtokoll.Aenderung] {
        abweichungen(puls: puls, messungen: messungen).filter { !versucht.contains($0) }
    }

    // MARK: Texte

    /// Eine Zeile: was sich im Modus ändert.
    var erklaerung: String {
        switch self {
        case .sparen:
            return "Puls alle \(pulsMinuten) Min., Blutsauerstoff, Stress und HRV aus, Abfrage stündlich. Schritte, Schlaf und Vibrationswünsche bleiben."
        case .daten:
            return "Puls alle \(pulsMinuten) Min., Blutsauerstoff, Stress und HRV an, Abfrage alle 10 Min. Mehr Verlauf, dafür hält der Akku kürzer."
        }
    }

    /// Ein Satz zum Akku. Gemessen ist noch nichts: das Akku-Log hält den Modus je Messpunkt fest.
    var akkuSatz: String {
        switch self {
        case .sparen: "Spart Akku am Tracker (der Sensor misst seltener) und am iPhone (weniger Abfragen). Wie viel, ist noch nicht gemessen."
        case .daten: "Kostet Akku am Tracker (der Sensor misst öfter) und am iPhone (mehr Abfragen). Wie viel, ist noch nicht gemessen."
        }
    }

    /// "alle 10 Minuten" für die Texte der Tracker-Seite.
    static func abfrageText(_ modus: TrackerModus?) -> String {
        "alle \(Int((modus?.abfrageAbstand ?? standardAbstand) / 60)) Minuten"
    }

    private static func bezeichnung(_ aenderung: TrackerProtokoll.Aenderung) -> String {
        switch aenderung {
        case .puls: "Puls"
        case .messung(let art, _): art.name
        }
    }

    /// Die Zeile unter der Wahl. Sagt nur, was Lumen Fit weiß: ohne gelesenen Stand keine Behauptung, ob der Tracker passt.
    static func status(modus: TrackerModus?, offen: Bool, verbunden: Bool, gelesen: Bool,
                       abweichungen: [TrackerProtokoll.Aenderung]) -> String {
        guard modus != nil else { return "Noch kein Modus gewählt. Lumen Fit ändert nichts am Tracker." }
        if offen { return verbunden ? "Lumen Fit stellt den Tracker gerade um." : "Lumen Fit stellt den Tracker um, sobald er verbunden ist." }
        guard gelesen else { return "Der Tracker meldet seine Einstellungen, sobald er verbunden ist." }
        if abweichungen.isEmpty { return "Der Tracker hat die Einstellungen dieses Modus." }
        let namen: String = abweichungen.map { bezeichnung($0) }.joined(separator: ", ")
        return "Am Tracker weicht ab: \(namen)."
    }
}
