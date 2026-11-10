import Foundation
import Observation

/// Navigation der App: der aktive Tab, je Tab ein Pfad tieferer Seiten und ein Blatt über allem (Freundeskarte bestätigen).
/// Jede Seite hat eine `Route` und einen Link (`RouteURL`); Widgets, Spotlight und Mitteilungen öffnen sie über `oeffne(url:)`.
@MainActor @Observable
final class Router {
    var tab: LumenFitTab = .heute
    var pfade: [LumenFitTab: [Route]] = [:]
    var blatt: Route?
    /// Vom Server pro Konto (`schlafSichtbar`); ohne wird jede Schlaf-Seite zu Heute.
    var schlafSichtbar = false
    /// Von den Einstellungen des Profils (`AppBereich`): ausgeschaltete Bereiche haben keine Seiten.
    var einstellungen = Einstellungen()

    /// Stellt die Erlaubnis ein; wird sie weggenommen, verlässt jede offene oder gemerkte Schlaf-Seite den Stapel.
    func setzeSchlafSichtbar(_ sichtbar: Bool) {
        schlafSichtbar = sichtbar
        if !sichtbar { raeumeStapelAuf() }
    }

    /// Alle fünf Tabs sind immer da (Wunsch vom 09.11.2026); nur einzelne Seiten hängen an den Bereichen.
    func zeigt(_ tab: LumenFitTab) -> Bool { true }

    /// Zeigt die App die Seite dieser Route: Bereich an (Profil) und, beim Schlaf, vom Server erlaubt.
    func zeigt(_ route: Route) -> Bool { einstellungen.wirksam(schlafSichtbar: schlafSichtbar).zeigt(route) }

    /// Nimmt neue Einstellungen an; Seiten eines ausgeschalteten Bereichs verlassen die Stapel (die Daten bleiben).
    func setze(einstellungen neu: Einstellungen) {
        einstellungen = neu
        raeumeStapelAuf()
    }

    private func raeumeStapelAuf() {
        for (tab, pfad) in pfade {
            let bleibt = pfad.filter { zeigt($0) }
            if bleibt.count != pfad.count { pfade[tab] = bleibt.isEmpty ? nil : bleibt }
        }
    }

    func oeffne(_ route: Route) {
        if !zeigt(route) { return wechsle(.heute, []) }
        switch route {
        // Wurzeln ihres Tabs: nichts obendrauf.
        case .heute, .gym(.training), .gym(.fortschritt), .profil(.uebersicht), .profil(.einstellungen), .freund(daten: nil):
            wechsle(LumenFitTab.fuer(route), [])
        case .freund:
            // Das Bestätigen nach dem Scannen bleibt ein Blatt über dem Freunde-Tab.
            wechsle(.freunde, [])
            blatt = route
        default:
            wechsle(LumenFitTab.fuer(route), [route])
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
