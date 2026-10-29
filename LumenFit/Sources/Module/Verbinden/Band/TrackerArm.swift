// Quelle: Lovea Health/Tracker/TrackerArm.swift
import Foundation

/// Der Pulsverlauf eines Tages, wie ihn der Tracker in Paketen liefert (Befehl 0x15, nach colmi_r02_client, am
/// Gerät nicht belegt): Kopf (Pakete, Abstand), Start (Tag, neun Werte), dann je 13 Werte. Wert 0 heißt "nicht gemessen".
struct PulsVerlauf: Equatable {
    struct Puls: Equatable {
        var wert: Int
        var zeit: Date
    }

    /// Angefragter Tag (Mitternacht als Sekunden, siehe `TrackerProtokoll.tagSekunden`).
    let tag: UInt32
    private(set) var abstand = 5
    private(set) var werte: [UInt8] = []
    /// `false`, wenn der Tracker einen anderen Tag oder "keine Daten" meldet: dann zählt der Verlauf nicht.
    private(set) var gueltig = true
    private var pakete = 0

    init(tag: UInt32) { self.tag = tag }

    /// `true`, sobald der Verlauf vollständig ist oder der Tracker keine Daten meldet.
    mutating func aufnehmen(_ antwort: TrackerProtokoll.Antwort) -> Bool {
        switch antwort {
        case .pulsKopf(let anzahl, let schritt):
            pakete = anzahl
            abstand = schritt > 0 ? schritt : 5
            werte = []
        case .pulsStart(let zeit, let erste):
            gueltig = zeit / 86_400 == tag / 86_400
            werte = erste
        case .pulsWerte(let nr, let weitere):
            werte += weitere
            return nr >= pakete - 1
        case .pulsEnde:
            gueltig = false
            return true
        default:
            break
        }
        return false
    }

    /// Der jüngste Puls im Bereich 30 bis 220 (0 und Werte darüber sind kein Puls), dessen Slot nicht nach `jetzt` liegt.
    func letzter(tagesanfang: Date, bis jetzt: Date) -> Puls? {
        for i in werte.indices.reversed() where (30...220).contains(Int(werte[i])) {
            let zeit = tagesanfang.addingTimeInterval(TimeInterval(i * abstand * 60))
            if zeit <= jetzt { return Puls(wert: Int(werte[i]), zeit: zeit) }
        }
        return nil
    }
}

/// Ob das Band am Arm ist. Reine Regel, ohne Gerät testbar: Bei Dauermessung misst der Tracker alle `intervall`
/// Minuten einen Puls, solange er auf der Haut liegt. Kam in zwei Abständen plus fünf Minuten (Slot-Breite)
/// keiner, gilt das Band als abgelegt. Ohne Dauermessung oder mit altem Stand gibt es kein Urteil.
enum TrackerArm {
    enum Zustand: Equatable {
        case amArm, abgelegt, unbekannt

        /// Für `BandNachrichtVibration.bandAmArm`: `nil` = unbekannt, dann vibriert das Band trotzdem.
        var bandAmArm: Bool? {
            switch self {
            case .amArm: true
            case .abgelegt: false
            case .unbekannt: nil
            }
        }
    }

    static func zustand(pulsAn: Bool, intervallMinuten: Int, letzterPuls: Date?, gelesen: Date?, tagesanfang: Date, jetzt: Date) -> Zustand {
        guard pulsAn, intervallMinuten > 0, let gelesen else { return .unbekannt }
        let fenster = TimeInterval((2 * intervallMinuten + 5) * 60)
        guard jetzt.timeIntervalSince(gelesen) <= fenster else { return .unbekannt }
        if let letzterPuls { return gelesen.timeIntervalSince(letzterPuls) <= fenster ? .amArm : .abgelegt }
        // Heute noch kein Puls: erst nach einem Fenster seit Mitternacht ist das ein Urteil.
        return gelesen.timeIntervalSince(tagesanfang) > fenster ? .abgelegt : .unbekannt
    }
}
