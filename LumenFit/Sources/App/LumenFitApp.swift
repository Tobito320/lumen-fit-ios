import CoreSpotlight
import SwiftUI

@main
struct LumenFitApp: App {
    private let umgebung: AppUmgebung
    @Environment(\.scenePhase) private var phase
    /// `.vordergrund` nur nach echtem Hintergrund (oder beim ersten Aktivwerden), nicht nach Kontrollzentrum, Mitteilungen oder Face ID
    /// (inaktiv zu aktiv): jede Meldung startet Health-Abruf, Konto-Abgleich und Brücke (Akku, Tempo-Prüfung 10.11.2026).
    @State private var warImHintergrund = true

    /// `ModulStart.starteAlle` läuft synchron hier (BGTask-Kennungen müssen vor Ende des Starts registriert sein); im Test-Host startet nichts.
    init() {
        _ = NutzungStart.beginn   // startet die Uhr für die Startzeit
        let umgebung = AppUmgebung.geteilt
        self.umgebung = umgebung
        ModulStart.starteAlle(umgebung)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(umgebung)
                .onOpenURL { umgebung.router.oeffne(url: $0) }
                .onContinueUserActivity(CSSearchableItemActionType) { aktivitaet in
                    if let kennung = aktivitaet.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                       let route = RouteURL.route(ausSpotlightKennung: kennung) {
                        umgebung.router.oeffne(route)
                    }
                }
        }
        .onChange(of: phase) { _, neu in
            if neu == .active, warImHintergrund {
                warImHintergrund = false
                umgebung.ereignisse.senden(.vordergrund)
            }
            if neu == .background {
                warImHintergrund = true
                umgebung.konto.nutzung.hintergrund()
                Task { await umgebung.konto.nutzungHochladen() }
            }
        }
    }
}
