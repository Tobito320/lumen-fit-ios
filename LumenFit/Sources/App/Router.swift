import Foundation
import Observation

/// Navigation der App: der aktive Tab, je Tab ein Pfad tieferer Seiten und ein Blatt über allem (Profil, Freunde).
/// Jede Seite hat eine `Route` und einen Link (`RouteURL`); Widgets, Spotlight und Mitteilungen öffnen sie über `oeffne(url:)`.
@MainActor @Observable
final class Router {
    var tab: LumenFitTab = .heute
    var pfade: [LumenFitTab: [Route]] = [:]
    var blatt: Route?

    func oeffne(_ route: Route) {
        switch route {
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

    /// Öffnet einen `lumenfit://`-Link. false, wenn er keine Seite der App ist.
    @discardableResult
    func oeffne(url: URL) -> Bool {
        guard let route = RouteURL.route(aus: url) else { return false }
        oeffne(route)
        return true
    }

    private func wechsle(_ neuerTab: LumenFitTab, _ pfad: [Route]) {
        blatt = nil
        tab = neuerTab
        pfade[neuerTab] = pfad
    }
}
