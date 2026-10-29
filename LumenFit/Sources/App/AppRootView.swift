import SwiftUI

/// Wurzel der App: ohne Profil das Onboarding, sonst die fünf Tabs. Es gibt nirgends einen Anmeldebildschirm.
/// Setzt Thema, Erscheinung und Haptik aus den Einstellungen des aktiven Profils; Profil und Freunde öffnen als Blatt über den Tabs.
struct AppRootView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var speicherFehler = false

    var body: some View {
        let einstellungen = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        inhalt
            .overlay(alignment: .top) {
                if speicherFehler {
                    // Eine Eingabe ging nicht auf die Platte (Idee 10): sagen, was jetzt hilft. Tippen schließt, nach 8 Sekunden geht sie von selbst.
                    FehlerKarte(titel: FehlerTexte.speichernTitel, hilfe: FehlerTexte.speichernHilfe, stimmung: .muede)
                        .padding(.horizontal, Abstand.l)
                        .padding(.top, Abstand.s)
                        .onTapGesture { speicherFehler = false }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Schließt die Meldung")
                }
            }
            .task(id: speicherFehler) {
                guard speicherFehler else { return }
                try? await Task.sleep(for: .seconds(8))
                if !Task.isCancelled { speicherFehler = false }
            }
            .lumenTheme(einstellungen.thema, erscheinung: einstellungen.erscheinung)
            .toggleStyle(.lumenSchalter)
            .environment(\.haptikAn, einstellungen.haptik)
            .bewegungsSchalter()
            // Die App spricht nur Deutsch: Zahlen und Daten in Text(...) folgen nicht dem Gerät (im Simulator "1,224" statt "1.224").
            .environment(\.locale, Locale(identifier: "de_DE"))
            .task(id: umgebung.profil.aktiv?.id) { await auffrischen() }
            .task {
                for await ereignis in umgebung.ereignisse.strom() {
                    if case .vordergrund = ereignis { await auffrischen() }
                    if case .speichernFehlgeschlagen = ereignis { speicherFehler = true }
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
        } else if let problem = umgebung.profil.ladeProblem {
            // Nicht lesbar heißt nicht leer: kein Onboarding, das ein neues Profil über die alten schriebe (SPEC 5.4).
            ProfilLadeProblemView(problem: problem)
        } else {
            OnboardingView()
        }
    }

    /// Health lesen (erster Aufruf fragt die Rechte) und den Partner-Stand neu lesen.
    private func auffrischen() async {
        guard umgebung.profil.hatProfil else { return }
        umgebung.daten?.verbindung.aktualisiere(jetzt: umgebung.uhr())
        Task { await kontoAbgleichen() }   // Netz darf Health nicht aufhalten
        await umgebung.gesundheit.aktualisiere()
    }

    /// Meldet das Gerät beim Server an, holt Einstellungen und Lovea-Freigabe. Sagt der Server (nicht nur der gemerkte Stand) "nicht freigegeben",
    /// geht ein alter Schalter "Mit Lovea verbinden" einmal aus: die Brücke liest ihn direkt.
    private func kontoAbgleichen() async {
        await umgebung.konto.aktualisiere(profilName: umgebung.profil.aktiv?.name)
        guard umgebung.konto.freigabeAktuell, !umgebung.konto.loveaErlaubt,
              umgebung.daten?.einstellungen.werte.loveaVerbunden == true else { return }
        umgebung.daten?.einstellungen.aendere { $0.loveaVerbunden = false }
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
        // Medaillen aus Gym und Heute zeigen ihren Toast auf jedem Tab (die Seiten im Fortschritt hängen ihn auch an, gezeigt wird er nur einmal).
        .fortschrittToast()
        .sheet(isPresented: Binding(get: { router.blatt != nil }, set: { if !$0 { router.blatt = nil } })) {
            if let blatt = router.blatt {
                NavigationStack {
                    RouteAnsicht(route: blatt)
                        .toggleStyle(.lumenSchalter)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { router.blatt = nil } } }
                }
            }
        }
    }
}
