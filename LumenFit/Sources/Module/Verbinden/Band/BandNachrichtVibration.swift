// Quelle: Lovea Health/Tracker/BandNachrichtVibration.swift
import Foundation

/// Reine Regel: vibriert das Armband jetzt, weil der Partner etwas gemeldet hat? Ohne Gerät testbar.
enum BandNachrichtRegel {
    /// Pause in Minuten zwischen zwei Vibrationen.
    static let pausen = [0, 1, 2, 3, 5, 10]
    static let standardPause = 3
    /// So alt darf eine Meldung höchstens sein, damit sie noch vibriert; ältere sind erledigt.
    static let frischGrenze: TimeInterval = 120

    /// Stärke = Zahl der Pulse (gespeichert bleiben "sanft", "normal", "stark"; angezeigt wird die ehrliche Zahl). Der Tracker hat nur einen Vibrationsbefehl (`TrackerProtokoll.findenAnfrage`): je Befehl ein Puls von fester
    /// Stärke und Länge (rund 5 bis 10 s). Vermutung, am Band noch zu prüfen: ein Befehl mitten im laufenden Puls wirkt nicht als
    /// eigener Puls (verlängert ihn oder wird ignoriert). Eine schwächere oder kürzere Vibration als "Sanft" gibt es darum nicht; "Normal" und
    /// "Stark" sind zwei und drei Pulse mit Abstand über der Pulslänge.
    enum Staerke: String, CaseIterable, Identifiable, Sendable {
        case sanft, normal, stark
        var id: String { rawValue }
        var name: String {
            switch self {
            case .sanft: "1 Puls"
            case .normal: "2 Pulse"
            case .stark: "3 Pulse"
            }
        }
        var pulse: Int {
            switch self {
            case .sanft: 1
            case .normal: 2
            case .stark: 3
            }
        }
        init(gespeichert: String?) { self = gespeichert.flatMap(Self.init(rawValue:)) ?? .sanft }
    }

    /// Sekunden zwischen dem Start der Pulse: länger als ein Puls (`TrackerProtokoll.findenPulsDauer`), sonst verschmelzen sie.
    static var pulsAbstand: TimeInterval { TrackerProtokoll.findenPulsDauer + 4 }

    /// Wann je ein Finden-Befehl geht, in Sekunden ab dem Start. Die längste Folge (Stark, 24 s) soll unter der Zeit bleiben, die iOS einer
    /// Hintergrundaufgabe gibt (Annahme rund 30 s, nicht geprüft); wird sie vorher gekappt, fehlen die letzten Pulse.
    static func zeiten(_ staerke: Staerke) -> [TimeInterval] {
        (0..<staerke.pulse).map { TimeInterval($0) * pulsAbstand }
    }

    /// `bandAmArm`: `nil` = unbekannt, dann trotzdem vibrieren. `letzte`: die letzte Vibration (bleibt gespeichert,
    /// ein Hintergrund-Start hat sonst keinen Speicher). Die Pause läuft ab der letzten Vibration, nicht ab der
    /// letzten Meldung; springt die Uhr zurück, ist sie vorbei.
    static func vibriert(an: Bool, bandAmArm: Bool?, zeit: Date, jetzt: Date, letzte: Date?, pause: TimeInterval,
                         frisch: TimeInterval = frischGrenze) -> Bool {
        guard an, bandAmArm != false, jetzt.timeIntervalSince(zeit) < frisch else { return false }
        guard let letzte else { return true }
        let seitdem = jetzt.timeIntervalSince(letzte)
        return seitdem < 0 || seitdem >= pause
    }
}
