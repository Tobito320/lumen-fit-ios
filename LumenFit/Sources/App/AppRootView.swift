import SwiftUI

/// Wurzel der App: ohne Profil das Onboarding, sonst die fünf Tabs. Es gibt nirgends einen Anmeldebildschirm.
/// Setzt Thema, Erscheinung und Haptik aus den Einstellungen des aktiven Profils; die Freundeskarte (Scan-Link) bestätigt ein Blatt über den Tabs.
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
            .overlay(alignment: .top) { if !speicherFehler { LoveaEinmalKarte() } }
            .task(id: speicherFehler) {
                guard speicherFehler else { return }
                try? await Task.sleep(for: .seconds(8))
                if !Task.isCancelled { speicherFehler = false }
            }
            .bewegungsSchalter()
            .lumenTheme(ProfilThemaWahl.wirksam(einstellungen.thema, loveaErlaubt: umgebung.konto.loveaErlaubt), erscheinung: einstellungen.erscheinung)
            .toggleStyle(.lumenSchalter)
            .environment(\.haptikAn, einstellungen.haptik)
            // Auf Deutsch feste deutsche Zahlen und Daten (im Simulator sonst "1,224" statt "1.224"); sonst folgt alles dem Gerät, auch die Texte.
            .environment(\.locale, Bundle.main.preferredLocalizations.first == "de" ? Locale(identifier: "de_DE") : .current)
            .task(id: umgebung.profil.aktiv?.id) {
                nutzungAbgleichen()
                if umgebung.profil.hatProfil {
                    umgebung.konto.nutzung.bereich(NutzungName.tab(umgebung.router.tab))
                    umgebung.konto.nutzung.startdauer(NutzungMass.sekunden(ContinuousClock.now - NutzungStart.beginn))
                }
                await auffrischen()
            }
            // Nutzung: nur nach einem "Ja" und nur Zähler mit festen Namen (nie Inhalte); gesendet wird gebündelt einmal je Start und beim Wechsel in den Hintergrund.
            .onChange(of: einstellungen.nutzungAntwort, initial: true) { _, _ in nutzungAbgleichen() }
            .onChange(of: umgebung.router.tab) { _, neu in umgebung.konto.nutzung.bereich(NutzungName.tab(neu)) }
            .onChange(of: umgebung.router.blatt) { _, neu in if let neu { umgebung.konto.nutzung.bereich(NutzungName.blatt(neu)) } }
            .onChange(of: umgebung.router.pfade[umgebung.router.tab]?.last) { _, neu in if let neu { umgebung.konto.nutzung.bereich(NutzungName.seite(neu)) } }
            .task {
                for await ereignis in umgebung.ereignisse.strom() {
                    if let funktion = NutzungName.funktion(ereignis) { umgebung.konto.nutzung.funktion(funktion) }
                    if case .vordergrund = ereignis { umgebung.konto.nutzung.vordergrund(); await auffrischen() }
                    if case .mahlzeitGespeichert = ereignis { umgebung.konto.nutzung.ablaufFertig(.essen) }
                    if case .speichernFehlgeschlagen = ereignis { speicherFehler = true; umgebung.konto.nutzung.fehler(.speichern) }
                }
            }
            // Die Frage nach der Nutzungsmeldung für Konten, die schon vor dem Update da waren (neue Konten fragt das Onboarding). Nur mit Antwort zu schließen.
            .sheet(isPresented: Binding(get: { nutzungFrageOffen }, set: { _ in })) { NutzungFrageBlatt() }
    }

    private var nutzungFrageOffen: Bool {
        umgebung.profil.hatProfil && !LoveaFreigabe.demoAktiv && umgebung.daten?.einstellungen.werte.nutzungAntwort == .offen
    }

    /// Hängt den Zähler an die Antwort der Person: nur "Ja" zählt und sendet; bei "Nein" und ohne Antwort ist alles Offene weg, auch eine alte Datei.
    private func nutzungAbgleichen() {
        let werte = umgebung.daten?.einstellungen.werte
        let erlaubt = umgebung.profil.hatProfil && werte?.nutzungErlaubt == true
        umgebung.konto.nutzung.an = erlaubt
        NutzungMetrik.schalte(erlaubt, seit: werte?.nutzungJaSeit, nutzung: umgebung.konto.nutzung)
        if erlaubt, let werte {
            umgebung.konto.nutzung.einstellungen(werte)
            umgebung.konto.nutzung.vordergrund()
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
        umgebung.beobachteHealth()
        await umgebung.gesundheit.aktualisiere()
        if umgebung.gesundheit.zugriff == .nichtVerfuegbar, umgebung.daten?.einstellungen.werte.healthGefragt == true {
            umgebung.konto.nutzung.fehler(.healthNichtVerfuegbar)
        }
    }

    /// Meldet das Gerät beim Server an, holt Einstellungen, Lovea-Freigabe und den Partner. Gibt der Server das Konto für Lovea frei, ist die Partner-Verbindung
    /// ohne Schalter an und der einmalige Import startet von selbst; sagt er (nicht nur der gemerkte Stand) "nicht freigegeben", geht ein alter Schalter einmal aus.
    private func kontoAbgleichen() async {
        let konto = umgebung.konto
        if let aktiv = umgebung.profil.aktiv { konto.profilZuordnen(aktiv: aktiv.id, vorhanden: umgebung.profil.profile.map(\.id)) }   // das Konto merkt sich sein Profil
        await konto.aktualisiere(profilName: umgebung.profil.aktiv?.name)
        if let einstellungen = umgebung.daten?.einstellungen {
            let verbunden = einstellungen.werte.loveaVerbunden
            if konto.loveaErlaubt, !LoveaFreigabe.demoAktiv, !verbunden {
                einstellungen.aendere { $0.loveaVerbunden = true }   // Mitteilungsrechte holt der Mitteiler bei der ersten Mitteilung
            } else if konto.freigabeAktuell, !konto.loveaErlaubt, verbunden {
                einstellungen.aendere { $0.loveaVerbunden = false }
            }
        }
        await umgebung.loveaImport.starteWennOffen(konto: konto, daten: umgebung.daten, lader: umgebung.http)
        umgebung.daten?.verbindung.aktualisiere(jetzt: umgebung.uhr())   // der Partner-Stand vom Server liegt jetzt da
        await LoveaEssenExport.starteWennOffen(konto: konto, daten: umgebung.daten, jetzt: umgebung.uhr())   // Essen zurück zu Lovea, nur mit Server-Schalter
        if let training = umgebung.daten?.training { await konto.postfachAbgleichen(training: training) }   // Pläne, die ein Agent abgelegt hat
    }
}

private struct TabsAnsicht: View {
    @Environment(AppUmgebung.self) private var umgebung
    /// Für die Mini-Leiste: dieselbe Sitzung wie im Training-Tab (`von` gibt immer die gesetzte zurück).
    @State private var sitzung: GymSitzung?
    @AppStorage(CrewDienst.gesehenSchluessel) private var crewGesehen: Double = 0

    /// Zahl am Tab Freunde: neu über meine Einladung Verbundene seit dem letzten Blick plus offene Einladungen zu Herausforderungen.
    private var freundeNeu: Int {
        let dienst = CrewDienst.von(umgebung)
        return dienst.neue(seit: crewGesehen > 0 ? Date(timeIntervalSince1970: crewGesehen) : nil).count + dienst.einladungen.count
    }

    var body: some View {
        @Bindable var router = umgebung.router
        TabView(selection: $router.tab) {
            ForEach(LumenFitTab.allCases.filter { router.zeigt($0) }) { tab in
                Tab(tab.titel, systemImage: tab.symbolName, value: tab) {
                    NavigationStack(path: Binding(get: { router.pfade[tab] ?? [] }, set: { router.pfade[tab] = $0 })) {
                        RouteAnsicht.wurzel(tab)
                            .navigationDestination(for: Route.self) { RouteAnsicht(route: $0) }
                    }
                    .safeAreaInset(edge: .bottom) { miniLeiste }
                }
                .badge(tab == .freunde ? freundeNeu : 0)
            }
        }
        .lumenTabLeiste()
        // Die Sitzung entsteht hier, nicht im Körper (`von` setzt den Port); das laufende Training wird gleich geladen, damit die Mini-Leiste es auch ohne Besuch im Training kennt.
        .task(id: umgebung.profil.aktiv?.id) {
            sitzung = GymSitzung.von(umgebung)
            sitzung?.ladeWennNoetig()
        }
        .onChange(of: umgebung.konto.schlafSichtbar, initial: true) { _, neu in router.setzeSchlafSichtbar(neu) }
        .onChange(of: umgebung.daten?.einstellungen.werte ?? Einstellungen(), initial: true) { _, neu in router.setze(einstellungen: neu) }
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

extension TabsAnsicht {
    /// "Training läuft · 23:14 · Weiter" über der Tab-Leiste, solange ein Training läuft und der Tab nicht das Training ist.
    @ViewBuilder
    fileprivate var miniLeiste: some View {
        if let sitzung, let start = sitzung.laufende?.start, LumenFitTab.zeigtMiniLeiste(auf: umgebung.router.tab, trainingLaeuft: sitzung.sessionId != nil) {
            TrainingMiniLeiste(start: start) { umgebung.router.oeffne(.gym(.training)) }
        }
    }
}

private struct TrainingMiniLeiste: View {
    let start: Date
    let weiter: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: weiter) {
            HStack(spacing: Abstand.s) {
                Image(systemName: "dumbbell.fill").accessibilityHidden(true)
                Text("Training läuft").fontWeight(.semibold)
                Text("·").accessibilityHidden(true)
                Text(start, style: .timer).monospacedDigit()
                Spacer(minLength: Abstand.s)
                Text("Weiter").fontWeight(.semibold)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.l)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.flaeche, in: .capsule)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Abstand.l)
        .padding(.bottom, Abstand.xs)
        .accessibilityLabel("Training läuft")
        .accessibilityHint("Öffnet das laufende Training")
    }
}
