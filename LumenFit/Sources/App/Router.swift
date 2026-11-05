import Foundation
import Observation

/// Navigation der App: der aktive Tab, je Tab ein Pfad tieferer Seiten und ein Blatt über allem (Profil, Freunde).
/// Jede Seite hat eine `Route` und einen Link (`RouteURL`); Widgets, Spotlight und Mitteilungen öffnen sie über `oeffne(url:)`.
@MainActor @Observable
final class Router {
    var tab: LumenFitTab = .heute
    var pfade: [LumenFitTab: [Route]] = [:]
    var blatt: Route?
    /// Von den Einstellungen des Profils (`AppBereich`): ausgeschaltete Bereiche haben keinen Tab und keine Seite.
    var einstellungen = Einstellungen()

    /// Nimmt neue Einstellungen an; zeigt der offene oder gemerkte Tab einen ausgeschalteten Bereich, landet er auf Heute (die Daten bleiben).
    func setze(einstellungen neu: Einstellungen) {
        einstellungen = neu
        for tab in LumenFitTab.allCases where !neu.zeigt(tab) { pfade[tab] = nil }
        if !neu.zeigt(tab) { tab = .heute }
    }

    func oeffne(_ route: Route) {
        if !einstellungen.zeigt(route) { return wechsle(.heute, []) }
        switch route {
        case .profil, .freund:
            blatt = route
        case .heute: wechsle(.heute, [])
        case .gym(.training): wechsle(.gym, [])
        case .essen(.heute): wechsle(.essen, [])
        case .schlaf(.letzteNacht): wechsle(.schlaf, [])
        default:
            if let tab = LumenFitTab.fuer(route) { wechsle(tab, [route]) }
        }
    }

    /// Lovea-Aufbau: legt eine Seite auf den Stapel des Heute-Tabs (wie `pfad.append` im Health-Tab von Lovea), ohne den Tab zu wechseln.
    func schiebe(_ route: Route) {
        if !einstellungen.zeigt(route) { return }
        blatt = nil
        pfade[.heute, default: []].append(route)
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
