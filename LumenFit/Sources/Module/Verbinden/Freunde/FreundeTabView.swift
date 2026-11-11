import SwiftUI

/// Der Tab Stats (neues Design 10.11.2026, vorher Freunde; Rohwert bleibt `freunde`): Freunde | Alle (Standard Freunde), Chips Schritte (Standard, Heute | Monat), Punkte, Trainings,
/// Sets, Serie, Platz-Karte mit Lumi und Liste. Standard privat: die eigenen Zahlen bleiben auf dem Gerät (`StatsDienst`). Unter Freunde wohnt
/// alles von vorher: Für dich, Trainingspartner, Herausforderungen, Rekorde der Freunde, Freunde mit Code eingeben und Verwalten, Einladen
/// (nichts fällt weg, es ist umsortiert). Wurzel des Tabs ohne eigenen NavigationStack (den gibt das Tab-Gerüst).
struct FreundeTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @AppStorage(CrewDienst.gesehenSchluessel) private var gesehen: Double = 0
    @State private var alle = false
    @State private var mass: StatsMass = .schritteHeute
    /// Der Stand von "gesehen" beim Öffnen: alles danach ist für diesen Besuch "neu" markiert.
    @State private var gesehenBeimOeffnen: Double?
    @State private var aktionFehler: String?
    @State private var einladenOffen = false
    @State private var codeOffen = false
    @State private var mitmachenOffen = false
    @State private var entfernen: VerbindungEintrag?

    private var dienst: CrewDienst { CrewDienst.von(umgebung) }
    private var stats: StatsDienst { StatsDienst.von(umgebung) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                if !dienst.ausstehend.isEmpty {
                    Label("Ohne Netz gemacht: geht raus, sobald Netz da ist.", systemImage: "icloud.slash")
                        .font(.footnote).foregroundStyle(palette.text2)
                }
                Picker("Vergleich", selection: $alle) {
                    Text("Freunde").tag(false)
                    Text("Alle").tag(true)
                }
                .pickerStyle(.segmented)
                StatsChips(mass: $mass)
                if alle {
                    StatsAlleAbschnitt(mass: mass, mitmachen: { mitmachenOffen = true })
                } else {
                    fuerDich
                    StatsFreundeAbschnitt(mass: mass, einladen: { einladenOffen = true }, codeEingeben: { codeOffen = true })
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle("Stats")
        .refreshable {
            await umgebung.konto.verbindungenNeuLaden()
            await dienst.laden(erzwingen: true)
            await stats.laden(erzwingen: true)
        }
        // Beim Erscheinen höchstens einmal je Minute; Ziehen zum Aktualisieren holt immer. Spart Funk bei jedem Tab-Wechsel.
        .task {
            await dienst.laden()
            await stats.laden()
        }
        .onAppear {
            if gesehenBeimOeffnen == nil { gesehenBeimOeffnen = gesehen }
            stats.eigeneRechnen()
        }
        .onDisappear { gesehen = umgebung.uhr().timeIntervalSince1970 }
        .sheet(isPresented: $einladenOffen) { VerbindungCodeBlatt() }
        .sheet(isPresented: $codeOffen) { VerbindungScanBlatt() }
        .sheet(isPresented: $mitmachenOffen) { StatsMitmachenBlatt() }
        .confirmationDialog("Verbindung mit \(entfernen?.anzeigeName ?? "") entfernen?",
                            isPresented: Binding(get: { entfernen != nil }, set: { if !$0 { entfernen = nil } }),
                            titleVisibility: .visible, presenting: entfernen) { e in
            Button("Entfernen", role: .destructive) {
                Task {
                    if !(await umgebung.konto.verbindungEntfernen(e.id)) {
                        aktionFehler = String(localized: "Die Verbindung ließ sich nicht entfernen. Prüfe das Netz und versuche es nochmal.")
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .modifier(CrewFehlerAnzeige(extra: $aktionFehler))
        .gymCrewAbruf()
    }

    private func kopf(_ titel: String) -> some View {
        Text(titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
    }

    // MARK: Für dich

    /// Wer über meine Einladung neu verbunden ist (seit dem letzten Blick, höchstens sieben Tage), mit Entfernen; darunter Einladungen zu Herausforderungen.
    @ViewBuilder
    private var fuerDich: some View {
        let einladungen = dienst.einladungen
        let stand = gesehenBeimOeffnen ?? gesehen
        let neu = dienst.neue(seit: stand > 0 ? Date(timeIntervalSince1970: stand) : nil)
        if !einladungen.isEmpty || !neu.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                kopf(String(localized: "Für dich"))
                if !neu.isEmpty {
                    ListenKarte {
                        ForEach(Array(neu.enumerated()), id: \.element.id) { i, e in
                            if i > 0 { Haarlinie() }
                            neuZeile(e)
                        }
                    }
                }
                ForEach(einladungen) { einladungKarte($0) }
            }
        }
    }

    private func neuZeile(_ e: VerbindungEintrag) -> some View {
        GymZeile(titel: String(localized: "\(e.anzeigeName) ist jetzt mit dir verbunden"), untertitel: e.erstellt?.formatted(.relative(presentation: .named))) {
            Button("Entfernen", role: .destructive) { entfernen = e }
                .font(.footnote.weight(.semibold))
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func einladungKarte(_ h: CrewHerausforderung) -> some View {
        let andere = h.teilnehmer.filter { !$0.ich }.map(\.name).joined(separator: ", ")
        return ListenKarte {
            GymZeile(titel: String(localized: "Einladung: \(CrewLogik.titel(h))"), untertitel: String(localized: "Mit \(andere) · \(CrewLogik.restText(h, jetzt: umgebung.uhr()))"))
            HStack(spacing: Abstand.s) {
                Button {
                    Task { aktionFehler = await dienst.annehmen(h.id) }
                } label: { Text("Annehmen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                .buttonStyle(.lumenHauptknopf)
                Button {
                    Task { aktionFehler = await dienst.ablehnen(h.id) }
                } label: { Text("Ablehnen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                .buttonStyle(.bordered)
            }
            .padding([.horizontal, .bottom], Abstand.l)
            Text(CrewTexte.sichtbar).font(.footnote).foregroundStyle(palette.text2).padding([.horizontal, .bottom], Abstand.l)
        }
    }
}

/// Texte der Crew, die mehrere Ansichten brauchen.
enum CrewTexte {
    nonisolated static let sichtbar = String(localized: "Alle in dieser Herausforderung sehen deinen Namen und deinen Wert.")

    /// "heute · 54 min · 27 Sätze"
    static func trainingText(_ t: PartnerTrainingKurz, heute: String) -> String {
        let n = Datum.tageZwischen(t.tag, heute)
        var teile = [n <= 0 ? String(localized: "heute") : n == 1 ? String(localized: "gestern") : String(localized: "vor \(n) Tagen")]
        if let m = t.minuten { teile.append(TrainingLogik.dauerText(TimeInterval(m * 60))) }
        if t.saetze > 0 { teile.append(t.saetze == 1 ? String(localized: "1 Satz") : String(localized: "\(t.saetze) Sätze")) }
        return teile.joined(separator: " · ")
    }
}

/// Zeigt den Fehler der letzten Crew-Aktion (Reaktion, Annehmen, Link) als Hinweis.
struct CrewFehlerAnzeige: ViewModifier {
    @Binding var extra: String?
    @Environment(AppUmgebung.self) private var umgebung

    func body(content: Content) -> some View {
        let dienst = CrewDienst.von(umgebung)
        let text = extra ?? dienst.fehler
        content.alert("Das hat nicht geklappt", isPresented: Binding(get: { text != nil }, set: { if !$0 { extra = nil; dienst.fehler = nil } })) {
            Button("Verstanden", role: .cancel) {}
        } message: {
            Text(text ?? "")
        }
    }
}
