import Foundation

/// Die einfachen Wahlen beim Teilen mit einer Person: "Wenig" (Schritte und Gym, der Standard), "Crew" (Training, Plan und Gewichte fürs Gym) oder "Alles" (alle Bereiche).
/// Eine eigene Auswahl aus den einzelnen Schaltern passt zu keiner Stufe (`von` liefert nil) und bleibt unverändert.
enum FreigabeStufe: CaseIterable, Sendable {
    case wenig, crew, alles

    var name: String {
        switch self {
        case .wenig: "Wenig"
        case .alles: "Alles"
        case .crew: "Crew"
        }
    }

    /// Ein Satz unter der Auswahl, was die Stufe zeigt (nil: keiner nötig).
    var hilfe: String? { self == .crew ? "Training, Plan und Gewichte der letzten Einheiten. Nie Schlaf, Essen, Körper." : nil }

    var bereiche: Set<VerbindungBereich> {
        switch self {
        case .wenig: VerbindungenLogik.standardZeigt
        case .alles: Set(VerbindungBereich.allCases)
        case .crew: [.gym, .plan, .verlauf]
        }
    }

    static func von(_ gezeigt: Set<VerbindungBereich>) -> FreigabeStufe? { allCases.first { $0.bereiche == gezeigt } }

    /// Die Auswahl, nachdem ein einzelner Schalter umgelegt wurde.
    static func schalte(_ an: Set<VerbindungBereich>, _ bereich: VerbindungBereich, ein: Bool) -> Set<VerbindungBereich> {
        var neu = an
        if ein { neu.insert(bereich) } else { neu.remove(bereich) }
        return neu
    }

    /// Das Feld für den Server (`PATCH /verbindungen/<id>`): die Namen der gezeigten Bereiche, sortiert.
    static func felder(_ gezeigt: Set<VerbindungBereich>) -> [String: Any] { ["zeigt": gezeigt.map(\.rawValue).sorted()] }
}
