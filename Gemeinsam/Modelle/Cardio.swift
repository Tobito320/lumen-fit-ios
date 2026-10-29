// Quelle: Lovea Health/Cardio.swift (nur Modell, ohne Ansichten)
import Foundation

/// Laufband/Stairmaster: am Ende abtippen, was das Gerät anzeigt. Op `cardio.setzen` (ersetzt per id), `cardio.loeschen {id}`.
struct CardioEintrag: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var datum: String
    var geraet: String // "laufband" | "stairmaster"
    var minuten: Int
    var kcal: Int?
    var km: Double?
    var hoehe: Int?
    var steigung: Double?
    var kmh: Double?
    var etagen: Int?
    var stufen: Int?
    var stufe: Int?

    var titel: String { geraet == "stairmaster" ? "Stairmaster" : "Laufband" }
    var symbol: String { geraet == "stairmaster" ? "figure.stair.stepper" : "figure.walk.treadmill" }

    /// ponytail: estimate, ~1.300 steps per walked km, one step per stair. Real counts would need
    /// HealthKit steps inside the session window.
    var schritteCa: Int? {
        if geraet == "stairmaster" { return stufen }
        return km.map { Int(($0 * 1300).rounded()) }
    }
}

/// Reine Faltung der Cardio-Ops eines Profils (in Lovea `CardioModell`); der `TrainingStore` hält sie.
struct CardioFaltung: Sendable {
    nonisolated static let arten: Set<String> = ["cardio.setzen", "cardio.loeschen"]

    private(set) var eintraege: [ProfilID: [String: CardioEintrag]] = [:]

    mutating func anwenden(_ op: Op) {
        if op.art == "cardio.setzen", let e = op.daten(CardioEintrag.self) {
            eintraege[op.von, default: [:]][e.id] = e
        } else if op.art == "cardio.loeschen", let d = op.daten([String: String].self), let id = d["id"] {
            eintraege[op.von]?[id] = nil
        }
    }

    func am(_ tag: String, von profil: ProfilID) -> [CardioEintrag] {
        (eintraege[profil] ?? [:]).values.filter { $0.datum == tag }.sorted { $0.id < $1.id }
    }
}
