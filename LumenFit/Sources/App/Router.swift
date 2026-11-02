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
    /// Vom Server pro Konto (`coachSichtbar`); ohne wird jede Coach-Seite zu Heute.
    var coachSichtbar = false
    /// Von den Einstellungen des Profils (`AppBereich`): ausgeschaltete Bereiche haben keinen Tab und keine Seite.
    var einstellungen = Einstellungen()

    /// Stellt die Sichtbarkeit ein; wird sie weggenommen, verlässt ein offener oder gemerkter Coach-Tab die Seite.
    func setzeCoachSichtbar(_ sichtbar: Bool) {
        coachSichtbar = sichtbar
        guard !sichtbar else { return }
        pfade[.coach] = nil
        if tab == .coach { tab = .heute }
    }

    /// Nimmt neue Einstellungen an; zeigt der offene oder gemerkte Tab einen ausgeschalteten Bereich, landet er auf Heute (die Daten bleiben).
    func setze(einstellungen neu: Einstellungen) {
        einstellungen = neu
        for tab in LumenFitTab.allCases where !neu.zeigt(tab) { pfade[tab] = nil }
        if !neu.zeigt(tab) { tab = .heute }
    }

    func oeffne(_ route: Route) {
        if !coachSichtbar, case .coach = route { return wechsle(.heute, []) }
        if !einstellungen.zeigt(route) { return wechsle(.heute, []) }
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

    /// Lovea-Aufbau: legt eine Seite auf den Stapel des Heute-Tabs (wie `pfad.append` im Health-Tab von Lovea), ohne den Tab zu wechseln.
    func schiebe(_ route: Route) {
        if !coachSichtbar, case .coach = route { return }
        if !einstellungen.zeigt(route) { return }
        blatt = nil
        pfade[.heute, default: []].append(route)
    }

    /// Öffnet einen `lumenfit://`-Link. false, wenn er keine Seite der App ist.
    /// Ein fremder Link darf dem Coach keine Frage stellen: ohne `vertraut` wird `coach?frage=` zum Entwurf im Eingabefeld. Nur der Demo-Start ist vertraut.
    @discardableResult
    func oeffne(url: URL, vertraut: Bool = false) -> Bool {
        guard let route = RouteURL.route(aus: url) else { return false }
        if !vertraut, coachSichtbar, case .coach(let frage?) = route {
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
