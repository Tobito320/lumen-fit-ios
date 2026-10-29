import CoreSpotlight
import SwiftUI

@main
struct LumenFitApp: App {
    private let umgebung: AppUmgebung
    @Environment(\.scenePhase) private var phase

    /// `ModulStart.starteAlle` läuft synchron hier (BGTask-Kennungen müssen vor Ende des Starts registriert sein); im Test-Host startet nichts.
    init() {
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
            if neu == .active { umgebung.ereignisse.senden(.vordergrund) }
        }
    }
}
