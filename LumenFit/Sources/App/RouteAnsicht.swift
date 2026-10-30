import SwiftUI

/// Bildet jede `Route` auf genau eine Ansicht ab. `AppRootView` benutzt es in `.navigationDestination(for: Route.self)` und für Blätter.
struct RouteAnsicht: View {
    let route: Route

    var body: some View {
        switch route {
        case .heute: HeuteTabView()
        case .gym(let bereich): GymTabView(bereich: bereich)
        case .essen(let bereich): EssenTabView(bereich: bereich)
        case .schlaf(let bereich): SchlafTabView(bereich: bereich)
        case .coach(let frage): CoachTabView(frage: frage)
        case .profil(let bereich): profil(bereich)
        case .verlauf: VerlaufView()
        case .gewichtEintragen: GewichtEintragenView()
        case .uebung(let id): UebungDetailView(id: id)
        case .freund(let daten): FreundeView(daten: daten)
        }
    }

    @ViewBuilder
    private func profil(_ bereich: ProfilBereich) -> some View {
        switch bereich {
        case .uebersicht, .einstellungen: ProfilBlattView()
        case .aussehen: AussehenView()
        case .ziele: ZieleView()
        case .verbindungen: VerbindungenView()
        case .datensicherung: DatensicherungView()
        case .quellen: QuellenView()
        case .meilensteine: MeilensteineView()
        case .lumi: LumiSeiteView()
        case .zyklus: ZyklusRouteSeite()
        }
    }

    /// Die Wurzel eines Tabs.
    @ViewBuilder
    static func wurzel(_ tab: LumenFitTab) -> some View {
        switch tab {
        case .heute: HeuteTabView()
        case .gym: GymTabView()
        case .essen: EssenTabView()
        case .schlaf: SchlafTabView()
        case .coach: CoachTabView()
        }
    }
}
