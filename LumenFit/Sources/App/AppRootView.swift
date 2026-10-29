import SwiftUI

/// Wurzel der App: ohne Profil das Onboarding, sonst die fünf Tabs. Es gibt nirgends einen Anmeldebildschirm.
/// Setzt Thema, Erscheinung und Haptik aus den Einstellungen des aktiven Profils; Profil und Freunde öffnen als Blatt über den Tabs.
struct AppRootView: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let einstellungen = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        inhalt
            .lumenTheme(einstellungen.thema, erscheinung: einstellungen.erscheinung)
            .toggleStyle(.lumenSchalter)
            .environment(\.haptikAn, einstellungen.haptik)
            // Die App spricht nur Deutsch: Zahlen und Daten in Text(...) folgen nicht dem Gerät (im Simulator "1,224" statt "1.224").
            .environment(\.locale, Locale(identifier: "de_DE"))
            .task(id: umgebung.profil.aktiv?.id) { await auffrischen() }
            .task {
                for await ereignis in umgebung.ereignisse.strom() {
                    if case .vordergrund = ereignis { await auffrischen() }
                }
            }
    }

    @ViewBuilder
    private var inhalt: some View {
        #if DEBUG
        if StartArgumente.lies().lumi {
            LumiProbe()
        } else {
            hauptinhalt
        }
        #else
        hauptinhalt
        #endif
    }

    @ViewBuilder
    private var hauptinhalt: some View {
        if umgebung.profil.hatProfil {
            TabsAnsicht()
        } else {
            OnboardingView()
        }
    }

    /// Health lesen (erster Aufruf fragt die Rechte) und den Partner-Stand neu lesen.
    private func auffrischen() async {
        guard umgebung.profil.hatProfil else { return }
        umgebung.daten?.verbindung.aktualisiere(jetzt: umgebung.uhr())
        await umgebung.gesundheit.aktualisiere()
    }
}

private struct TabsAnsicht: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        @Bindable var router = umgebung.router
        TabView(selection: $router.tab) {
            ForEach(LumenFitTab.allCases) { tab in
                Tab(tab.titel, systemImage: tab.symbolName, value: tab) {
                    NavigationStack(path: Binding(get: { router.pfade[tab] ?? [] }, set: { router.pfade[tab] = $0 })) {
                        RouteAnsicht.wurzel(tab)
                            .navigationDestination(for: Route.self) { RouteAnsicht(route: $0) }
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { router.blatt != nil }, set: { if !$0 { router.blatt = nil } })) {
            if let blatt = router.blatt {
                NavigationStack {
                    RouteAnsicht(route: blatt)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { router.blatt = nil } } }
                }
            }
        }
    }
}
