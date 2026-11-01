import Foundation
import Observation

/// Navigation der App: der aktive Tab, je Tab ein Pfad tieferer Seiten und ein Blatt über allem (Profil, Freunde).
/// Jede Seite hat eine `Route` und einen Link (`RouteURL`); Widgets, Spotlight und Mitteilungen öffnen sie über `oeffne(url:)`.
@MainActor @Observable
final class Router {
    var tab: LumenFitTab = .heute
    var pfade: [LumenFitTab: [Route]] = [:]
    var blatt: Route?
    /// Ein Coach-Text aus einem Link von außen (Annahme 34): landet im Eingabefeld und wird nie von selbst gesendet.
    var coachEntwurf: String?

    func oeffne(_ route: Route) {
        switch route {
        case .profil(.zyklus):
            // Zyklus gehört nur in Lovea: ein alter Link oder ein gespeicherter Stand landet auf Heute.
            wechsle(.heute, [])
        case .profil, .freund:
            blatt = route
        case .heute: wechsle(.heute, [])
        case .gym(.training): wechsle(.gym, [])
        case .essen(.heute): wechsle(.essen, [])
        case .schlaf(.letzteNacht): wechsle(.schlaf, [])
        case .coach(nil): wechsle(.coach, [])
        default:
            if let tab = LumenFitTab.fuer(route) { wechsle(tab, [route]) }
        }
    }

    /// Lovea-Aufbau: legt eine Seite auf den Stapel des Heute-Tabs (wie `pfad.append` im Health-Tab von Lovea), ohne den Tab zu wechseln.
    func schiebe(_ route: Route) {
        blatt = nil
        pfade[.heute, default: []].append(route)
    }

    /// Öffnet einen `lumenfit://`-Link. false, wenn er keine Seite der App ist.
    /// Ein fremder Link darf dem Coach keine Frage stellen: ohne `vertraut` wird `coach?frage=` zum Entwurf im Eingabefeld. Nur der Demo-Start ist vertraut.
    @discardableResult
    func oeffne(url: URL, vertraut: Bool = false) -> Bool {
        guard let route = RouteURL.route(aus: url) else { return false }
        if !vertraut, case .coach(let frage?) = route {
            coachEntwurf = frage
            oeffne(.coach(frage: nil))
        } else {
            oeffne(route)
        }
        return true
    }

    private func wechsle(_ neuerTab: LumenFitTab, _ pfad: [Route]) {
        blatt = nil
        tab = neuerTab
        pfade[neuerTab] = pfad
    }
}
