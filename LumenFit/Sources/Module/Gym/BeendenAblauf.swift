// Quelle: Lovea Health/WorkoutView.swift (GymSessionView.beenden :346, abschliessen :350, Alerts :151-190)
import Foundation

/// Welche Rückfrage beim Beenden im Lovea-Aufbau als Nächstes kommt.
enum BeendenSchritt: Equatable, Sendable {
    /// "Warst du wirklich so lange im Gym?"
    case zeitFrage
    /// "Plan aktualisieren?"
    case planFrage
    /// "Als Trainingstag speichern?"
    case freiFrage
    /// Keine Frage mehr: das Training wird beendet.
    case beenden
}

/// Die Reihenfolge der Rückfragen beim Beenden (Lovea): erst die Zeit, dann der Plan oder der freie Tag, dann ist das Training beendet.
/// Lovea checkt zuerst aus und fragt danach. Lumen fragt zuerst und beendet zuletzt: `GymSitzung.beende` leert die Liste, und der Gym-Tab
/// wechselt dann zur Startseite, ein Alert auf der laufenden Seite wäre weg. Für die Person ist die Abfolge dieselbe.
enum BeendenAblauf {
    static func ersterSchritt(zuLang: Bool, planFrage: Bool, freiFrage: Bool) -> BeendenSchritt {
        zuLang ? .zeitFrage : weiter(planFrage: planFrage, freiFrage: freiFrage)
    }

    /// Nach "Ja, stimmt" oder gleich, wenn die Zeit nicht zu lang ist.
    static func weiter(planFrage: Bool, freiFrage: Bool) -> BeendenSchritt {
        planFrage ? .planFrage : freiFrage ? .freiFrage : .beenden
    }
}
