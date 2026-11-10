import Foundation

enum LumenFitTab: String, CaseIterable, Hashable, Sendable, Identifiable {
    /// Aufteilung B (Wunsch vom 09.11.2026): Startseite, Training, Fortschritt, Freunde, Profil ganz rechts. Der Rohwert `heute` bleibt (Nutzungsname, gemerkter Tab).
    case heute, training, fortschritt, freunde, profil

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .heute: "Startseite"
        case .training: "Training"
        case .fortschritt: "Fortschritt"
        case .freunde: "Freunde"
        case .profil: "Profil"
        }
    }

    var symbolName: String {
        switch self {
        case .heute: "house.fill"
        case .training: "dumbbell.fill"
        case .fortschritt: "chart.xyaxis.line"
        case .freunde: "person.2.fill"
        case .profil: "person.crop.circle.fill"
        }
    }

    /// Der Tab, auf dem eine Route liegt. Essen und Schlaf liegen bis zum Umzug im Stapel des Profils.
    static func fuer(_ route: Route) -> LumenFitTab {
        switch route {
        case .heute, .gewichtEintragen: .heute
        case .gym(.training), .gym(.plaene), .uebung: .training
        case .gym(.fortschritt), .verlauf, .einsichten: .fortschritt
        case .freund, .profil(.verbindungen): .freunde
        case .essen, .schlaf, .profil: .profil
        }
    }

    /// Die Mini-Leiste "Training läuft" steht auf allen Tabs außer dem Training selbst.
    static func zeigtMiniLeiste(auf tab: LumenFitTab, trainingLaeuft: Bool) -> Bool { trainingLaeuft && tab != .training }
}

extension Route {
    /// Der Bereich, den die Person abschalten kann; nil für Seiten, die immer da sind.
    var bereich: AppBereich? {
        switch self {
        case .gym, .uebung: .gym
        case .essen: .essen
        case .schlaf: .schlaf
        case .heute, .profil, .verlauf, .einsichten, .gewichtEintragen, .freund: nil
        }
    }
}

extension Einstellungen {
    /// Zeigt die App die Seite dieser Route? Seiten ohne Bereich immer.
    func zeigt(_ route: Route) -> Bool { route.bereich.map(zeigt) ?? true }
}
