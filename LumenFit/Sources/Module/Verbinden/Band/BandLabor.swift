// Quelle: Lovea Health/Tracker/BandLabor.swift
import Foundation

// Band-Labor (Entwickler): Nutzer trägt das Band, löst den Finden-Befehl aus und tippt beim Spüren auf Start und Ende. Daraus wird gerechnet, wie
// lang ein Puls wirklich ist und was ein zweiter Befehl mitten im Puls tut. Reine Rechnung und Speicher (UserDefaults), getestet in
// `BandLaborTests`. Gesendet wird nur, was `TrackerProtokoll` belegt (Finden); sonst wird nur gelesen.

struct BandLaborMessung: Codable, Equatable, Identifiable, Sendable {
    enum Art: String, Codable, Sendable { case einzel, doppel }

    var id = UUID()
    var datum: Date
    var art: Art
    /// Nur bei `doppel`: Sekunden zwischen den zwei Befehlen.
    var abstand: Double?
    /// Sekunden von "spüre ich" bis "vorbei".
    var dauer: Double
    /// Sekunden vom Senden bis "spüre ich" (Funk und Reaktion).
    var verzoegerung: Double?
    /// Nur bei `doppel`: was die Rechnung daraus macht.
    var urteil: BandLaborAuswertung.Doppel?
}

enum BandLaborAuswertung {
    /// Messungen außerhalb davon sind Fehlbedienung (zu schnell getippt, vergessen).
    static let pulsGrenzen = 0.3...120.0
    static let abstaende: [Double] = [0.2, 0.5, 1, 2, 3]

    enum Doppel: String, Codable, Sendable {
        /// Der zweite Befehl ändert nichts, der Puls bleibt so lang wie allein.
        case ignoriert
        /// Der Puls dauert länger als allein, aber nicht so lang wie ein Neustart.
        case verlaengert
        /// Der zweite Befehl startet den Puls neu: Dauer = Abstand + Pulslänge.
        case neuGestartet
        /// Der zweite Puls läuft nach dem ersten: Dauer = zwei Pulslängen.
        case angehaengt
        /// Der Puls ist kürzer als allein: der zweite Befehl hat ihn abgebrochen.
        case abgebrochen
        /// Der Abstand ist so groß wie ein Puls: zwei getrennte Pulse, keine Aussage über Überlappung.
        case getrennt
        case unklar

        var text: String {
            switch self {
            case .ignoriert: String(localized: "Zweiter Befehl wird ignoriert")
            case .verlaengert: String(localized: "Zweiter Befehl verlängert den Puls")
            case .neuGestartet: String(localized: "Zweiter Befehl startet den Puls neu")
            case .angehaengt: String(localized: "Zweiter Puls kommt nach dem ersten")
            case .abgebrochen: String(localized: "Zweiter Befehl bricht den Puls ab")
            case .getrennt: String(localized: "Abstand so groß wie ein Puls: zwei getrennte Pulse")
            case .unklar: String(localized: "Passt zu keinem Muster, noch einmal messen")
            }
        }
    }

    /// Die Pulslänge aus den Einzelmessungen: der Mittelwert der Mitte (Median), Fehlbedienung ausgenommen. `nil` ohne brauchbare Messung.
    static func pulsLaenge(_ messungen: [BandLaborMessung]) -> Double? {
        let werte = messungen.filter { $0.art == .einzel && pulsGrenzen.contains($0.dauer) }.map(\.dauer).sorted()
        guard !werte.isEmpty else { return nil }
        let mitte = werte.count / 2
        return werte.count % 2 == 1 ? werte[mitte] : (werte[mitte - 1] + werte[mitte]) / 2
    }

    /// Was zwei Befehle im `abstand` bewirken, wenn die Gesamtdauer `gesamt` war und ein Puls allein `puls` dauert. Die Toleranz deckt
    /// Tipp-Ungenauigkeit ab (mindestens eine Sekunde, sonst 15 Prozent der Pulslänge).
    static func beurteile(puls: Double, abstand: Double, gesamt: Double) -> Doppel {
        let toleranz = max(1, 0.15 * puls)
        if abstand >= puls - toleranz { return .getrennt }
        if gesamt < puls - toleranz { return .abgebrochen }
        if gesamt <= puls + toleranz { return .ignoriert }
        if abs(gesamt - (abstand + puls)) <= toleranz { return .neuGestartet }
        if gesamt < abstand + puls { return .verlaengert }
        if abs(gesamt - 2 * puls) <= toleranz { return .angehaengt }
        return .unklar
    }

    /// Das Urteil über alle Doppelmessungen: das häufigste (bei Gleichstand das jüngste). `nil` ohne Doppelmessung.
    static func gesamtUrteil(_ messungen: [BandLaborMessung]) -> Doppel? {
        let urteile = messungen.compactMap(\.urteil).filter { $0 != .getrennt && $0 != .unklar }
        let zaehler = Dictionary(grouping: urteile, by: { $0 }).mapValues(\.count)
        guard let hoechste = zaehler.values.max() else { return nil }
        return urteile.last { zaehler[$0] == hoechste }
    }
}

/// Die Messungen (die letzten 40) und die Wahl "gemessene Pulslänge nutzen", lokal in UserDefaults. Der Standard ist wie bisher: Annahme.
enum BandLaborSpeicher {
    static let messungenSchluessel = "fit.bandlabor.messungen"
    static let pulsSchluessel = "fit.bandlabor.pulsdauer"
    static let nutzenSchluessel = "fit.bandlabor.nutzen"
    static let hoechstens = 40

    static func messungen(_ defaults: UserDefaults = .standard) -> [BandLaborMessung] {
        guard let daten = defaults.data(forKey: messungenSchluessel) else { return [] }
        return (try? JSONDecoder().decode([BandLaborMessung].self, from: daten)) ?? []
    }

    static func anhaengen(_ messung: BandLaborMessung, _ defaults: UserDefaults = .standard) {
        let liste = Array((messungen(defaults) + [messung]).suffix(hoechstens))
        if let daten = try? JSONEncoder().encode(liste) { defaults.set(daten, forKey: messungenSchluessel) }
    }

    static func loeschen(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: messungenSchluessel)
    }

    /// Die gemessene Pulslänge, nur wenn sie eingeschaltet und plausibel ist; sonst `nil` (dann gilt die Annahme).
    static func pulsDauer(_ defaults: UserDefaults = .standard) -> TimeInterval? {
        guard defaults.bool(forKey: nutzenSchluessel) else { return nil }
        let wert = defaults.double(forKey: pulsSchluessel)
        return BandLaborAuswertung.pulsGrenzen.contains(wert) ? wert : nil
    }

    static func pulsDauerSetzen(_ wert: Double, _ defaults: UserDefaults = .standard) {
        defaults.set(wert, forKey: pulsSchluessel)
    }
}
