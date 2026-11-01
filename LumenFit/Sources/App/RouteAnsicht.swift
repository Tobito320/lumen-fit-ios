import SwiftUI

/// Bildet jede `Route` auf genau eine Ansicht ab. `AppRootView` benutzt es in `.navigationDestination(for: Route.self)` und für Blätter.
struct RouteAnsicht: View {
    let route: Route

    var body: some View {
        switch route {
        case .heute: HeuteTabView()
        case .gym(let bereich): GymTabView(bereich: bereich).kartenTint(HabitFarbe.mint.farbe)
        case .essen(let bereich): EssenTabView(bereich: bereich).kartenTint(LumenFarben.loveaEssen)
        case .schlaf(let bereich): SchlafTabView(bereich: bereich).kartenTint(HabitFarbe.indigo.farbe)
        case .coach(let frage): CoachTabView(frage: frage).kartenTint(HabitFarbe.himmel.farbe)
        case .profil(let bereich): profil(bereich)
        case .verlauf: VerlaufView()
        case .gewichtEintragen: GewichtEintragenView()
        case .uebung(let id): UebungDetailView(id: id)
        case .freund(let daten):
            if let t = VerbindungenLogik.token(aus: daten) { VerbindungScanBlatt(token: t) } else { FreundeView(daten: daten) }
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
        // Zyklus gehört nur in Lovea: ein alter Link landet auf Heute.
        case .zyklus: HeuteTabView()
        }
    }

    /// Die Wurzel eines Tabs.
    @ViewBuilder
    static func wurzel(_ tab: LumenFitTab) -> some View {
        switch tab {
        case .heute: HeuteTabView()
        case .gym: GymTabView().kartenTint(HabitFarbe.mint.farbe)
        case .essen: EssenTabView().kartenTint(LumenFarben.loveaEssen)
        case .schlaf: SchlafTabView().kartenTint(HabitFarbe.indigo.farbe)
        case .coach: CoachTabView().kartenTint(HabitFarbe.himmel.farbe)
        }
    }
}
