import Foundation
import Observation

/// Navigation der App: der aktive Tab, je Tab ein Pfad tieferer Seiten und ein Blatt über allem (Profil, Freunde).
/// Jede Seite hat eine `Route` und einen Link (`RouteURL`); Widgets, Spotlight und Mitteilungen öffnen sie über `oeffne(url:)`.
@MainActor @Observable
final class Router {
    var tab: LumenFitTab = .heute
    var pfade: [LumenFitTab: [Route]] = [:]
    var blatt: Route?
    /// Vom Server pro Konto (`schlafSichtbar`); ohne wird jede Schlaf-Seite zu Heute.
    var schlafSichtbar = false
    /// Von den Einstellungen des Profils (`AppBereich`): ausgeschaltete Bereiche haben keinen Tab und keine Seite.
    var einstellungen = Einstellungen()

    /// Stellt die Erlaubnis ein; wird sie weggenommen, verlässt ein offener oder gemerkter Schlaf-Tab die Seite.
    func setzeSchlafSichtbar(_ sichtbar: Bool) {
        schlafSichtbar = sichtbar
        guard !sichtbar else { return }
        pfade[.schlaf] = nil
        if tab == .schlaf { tab = .heute }
    }

    /// Zeigt die App diesen Tab: Bereich an (Profil) und, beim Schlaf, vom Server erlaubt.
    func zeigt(_ tab: LumenFitTab) -> Bool { einstellungen.wirksam(schlafSichtbar: schlafSichtbar).zeigt(tab) }

    /// Zeigt die App die Seite dieser Route? Blätter (Profil, Freunde) immer.
    func zeigt(_ route: Route) -> Bool { LumenFitTab.fuer(route).map { zeigt($0) } ?? true }

    /// Nimmt neue Einstellungen an; zeigt der offene oder gemerkte Tab einen ausgeschalteten Bereich, landet er auf Heute (die Daten bleiben).
    func setze(einstellungen neu: Einstellungen) {
        einstellungen = neu
        for tab in LumenFitTab.allCases where !zeigt(tab) { pfade[tab] = nil }
        if !zeigt(tab) { tab = .heute }
    }

    func oeffne(_ route: Route) {
        if !zeigt(route) { return wechsle(.heute, []) }
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
        if !zeigt(route) { return }
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
