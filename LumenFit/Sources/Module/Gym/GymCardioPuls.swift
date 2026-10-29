import Foundation
import Observation

/// Der Puls zu einem Cardio-Eintrag (Idee 29: Dauer, Distanz und Puls). `CardioEintrag` gehört dem Grundgerüst und hat kein Pulsfeld;
/// der Schnittpuls steht deshalb hier, je Eintrag-Kennung, in `gym-cardio-puls.json` im Profilordner. Wunsch ans Grundgerüst: ein Feld `puls`.
@MainActor @Observable
final class GymCardioPuls {
    @ObservationIgnored private let datei: JSONDatei<[String: Int]>?
    private var werte: [String: Int] = [:]

    /// Ohne Ordner nur im Speicher (Vorschau, Tests).
    init(ordner: URL? = nil) {
        datei = ordner.map { JSONDatei<[String: Int]>($0.appendingPathComponent("gym-cardio-puls.json")) }
        if let alt = datei?.lade() { werte = alt }
    }

    func puls(_ eintrag: String) -> Int? { werte[eintrag] }

    /// Setzt den Puls (30 bis 240); alles andere löscht ihn.
    func setze(_ eintrag: String, puls: Int?) {
        if let puls, (30...240).contains(puls) { werte[eintrag] = puls } else { werte[eintrag] = nil }
        datei?.speichere(werte)
    }
}
