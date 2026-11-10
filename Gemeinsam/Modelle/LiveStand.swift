import Foundation

/// Was die Live Activity und das Pausen-Ende brauchen (der ActivityKit-Typ gehört dem Modul widgets).
struct TrainingLiveStand: Codable, Hashable, Sendable {
    var uebung: String
    var satz: Int
    var von: Int
    var pauseEnde: Date?
    var start: Date
    var planName: String?
    /// Der Satz, der dran ist: Gewicht und Wiederholungen ("60 kg × 8"). Fehlt bei Cardio und alten Ständen.
    var kg: Double? = nil
    var wdh: Int? = nil
    /// Seit wann der Satz läuft (Ende der Pause): die Live Activity zählt die Satz-Uhr hoch. nil = keine Pause war oder sie läuft noch.
    var satzSeit: Date? = nil
    /// Fertige und alle Übungen des Trainings, für die Zeile "2 von 5 Übungen fertig", wenn kein Satz zu zeigen ist.
    var uebungenFertig: Int? = nil
    var uebungenGesamt: Int? = nil
}

extension TrainingLiveStand {
    /// Lumi in der Live Activity: in der Satzpause trinkt er, sonst feuert er an.
    var lumi: LumiStimmung { pauseEnde == nil ? .anfeuern : .pause }

    /// "60 kg × 8"; ohne Gewicht "8 Wdh."; nil ohne Wiederholungen (Cardio, alter Stand).
    var satzZeile: String? {
        guard let wdh else { return nil }
        guard let kg, kg > 0 else { return String(localized: "\(wdh) Wdh.") }
        return "\(TrainingLogik.kgText(kg)) kg × \(wdh)"
    }
}
