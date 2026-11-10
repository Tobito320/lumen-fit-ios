import SwiftUI

/// Der Tab Freunde (Aufteilung B, 10.11.2026): Für dich (Reaktionen, Einladungen), Trainingspartner mit eurer Woche, Rangliste der Woche,
/// Herausforderungen, Rekorde der Freunde, Freunde mit Status und Einladen mit einem Tipp. Kein Feed (Design 09.11.2026); die Trainings einer Person
/// stehen auf ihrer Seite. Ohne Freunde steht das Einladen oben. Wurzel des Tabs ohne eigenen NavigationStack (den gibt das Tab-Gerüst).
/// Neues kommt beim Öffnen und beim Ziehen nach unten (kein Push).
struct FreundeTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @AppStorage(CrewDienst.gesehenSchluessel) private var gesehen: Double = 0
    @State private var mass: CrewMass = .tage
    @State private var herausfordern = false
    /// Der Stand von "gesehen" beim Öffnen: alles danach ist für diesen Besuch "neu" markiert.
    @State private var gesehenBeimOeffnen: Double?
    @State private var aktionFehler: String?

    private var dienst: CrewDienst { CrewDienst.von(umgebung) }
    private var eintraege: [VerbindungEintrag] { GymCrewQuelle.eintraege(umgebung) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                if !dienst.ausstehend.isEmpty {
                    Label("Ohne Netz gemacht: geht raus, sobald Netz da ist.", systemImage: "icloud.slash")
                        .font(.footnote).foregroundStyle(palette.text2)
                }
                if eintraege.isEmpty { freunde }
                fuerDich
                CrewPartnerAbschnitt()
                // Bis Build 20: Heute des Lovea-Partners (Schritte-Vergleich, Energie, Ansichten), seit die Startseite ohne Freunde ist.
                if umgebung.daten?.einstellungen.werte.loveaVerbunden == true { PartnerKarte(bereich: .heute) }
                rangliste
                herausforderungen
                GymRekordPinnwandView()
                if !eintraege.isEmpty { freunde }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .lumenHintergrund()
        .navigationTitle("Freunde")
        .refreshable {
            await umgebung.konto.verbindungenNeuLaden()
            await dienst.laden(erzwingen: true)
        }
        .task { await dienst.laden(erzwingen: true) }
        .onAppear { if gesehenBeimOeffnen == nil { gesehenBeimOeffnen = gesehen } }
        .onDisappear { gesehen = umgebung.uhr().timeIntervalSince1970 }
        .sheet(isPresented: $herausfordern) { CrewHerausforderungBlatt() }
        .modifier(CrewFehlerAnzeige(extra: $aktionFehler))
        .gymCrewAbruf()
    }

    private func kopf(_ titel: String) -> some View {
        Text(titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
    }

    // MARK: Für dich

    @ViewBuilder
    private var fuerDich: some View {
        let einladungen = dienst.einladungen
        let reaktionen = Array(dienst.neue(seit: nil).prefix(6))
        if !einladungen.isEmpty || !reaktionen.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                kopf("Für dich")
                ForEach(einladungen) { einladungKarte($0) }
                if !reaktionen.isEmpty {
                    ListenKarte {
                        ForEach(Array(reaktionen.enumerated()), id: \.element.id) { i, r in
                            if i > 0 { Haarlinie() }
                            reaktionZeile(r)
                        }
                    }
                }
            }
        }
    }

    private func reaktionZeile(_ r: CrewReaktion) -> some View {
        let neu = r.zeit.timeIntervalSince1970 > (gesehenBeimOeffnen ?? gesehen)
        return HStack(spacing: Abstand.m) {
            Image(systemName: r.art.symbol).foregroundStyle(neu ? palette.akzent : palette.text2).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(CrewLogik.reaktionText(r)).font(.subheadline).foregroundStyle(palette.text)
                Text(r.zeit.formatted(.relative(presentation: .named))).font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            if neu {
                Circle().fill(palette.akzent).frame(width: 8, height: 8).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
        .accessibilityValue(neu ? "neu" : "")
    }

    private func einladungKarte(_ h: CrewHerausforderung) -> some View {
        let andere = h.teilnehmer.filter { !$0.ich }.map(\.name).joined(separator: ", ")
        return ListenKarte {
            GymZeile(titel: "Einladung: \(CrewLogik.titel(h))", untertitel: "Mit \(andere) · \(CrewLogik.restText(h, jetzt: umgebung.uhr()))")
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

    // MARK: Herausforderungen

    private var herausforderungen: some View {
        let jetzt = umgebung.uhr()
        let liste = (dienst.antwort?.herausforderungen ?? []).filter(\.dabei)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            HStack {
                kopf("Herausforderungen")
                Spacer()
                Button { herausfordern = true } label: {
                    Label("Herausfordern", systemImage: "flag.checkered").font(.footnote.weight(.semibold)).frame(minHeight: Abstand.tippflaeche)
                }
            }
            ListenKarte {
                if liste.isEmpty {
                    GymZeile(titel: "Noch keine Herausforderung", untertitel: "Duell, Gruppe oder ein gemeinsames Ziel mit deinen Freunden.")
                } else {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { i, h in
                        if i > 0 { Haarlinie() }
                        NavigationLink { CrewHerausforderungSeite(id: h.id) } label: {
                            GymZeile(titel: CrewLogik.titel(h), untertitel: "\(CrewLogik.text(CrewLogik.stand(h, jetzt: jetzt))) · \(CrewLogik.restText(h, jetzt: jetzt))") {
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Rangliste

    private var rangliste: some View {
        let jetzt = umgebung.uhr()
        let ich = CrewLogik.woche(sessions: umgebung.daten?.training.sessions ?? [], jetzt: jetzt)
        let zeilen = CrewLogik.rangliste(mass, ich: ich, eintraege: eintraege, jetzt: jetzt)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            kopf("Rangliste der Woche")
            Picker("Maß", selection: $mass) {
                ForEach(CrewMass.rangliste) { Text($0.titel).tag($0) }
            }
            .pickerStyle(.segmented)
            ListenKarte {
                ForEach(Array(zeilen.enumerated()), id: \.element.id) { i, z in
                    if i > 0 { Haarlinie() }
                    if z.ich {
                        rangZeile(z)
                    } else {
                        NavigationLink { CrewFreundSeite(id: z.id) } label: { rangZeile(z) }.buttonStyle(.plain)
                    }
                }
                if zeilen.count < 2 {
                    Text("Sobald deine Freunde Gym und Training teilen, stehen sie hier.")
                        .font(.footnote).foregroundStyle(palette.text2).padding(Abstand.l)
                }
            }
        }
    }

    private func rangZeile(_ z: CrewRang) -> some View {
        HStack(spacing: Abstand.m) {
            Text("\(z.rang).").font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(palette.text2).frame(minWidth: 28, alignment: .leading)
            Text(z.name).font(.body.weight(z.ich ? .bold : .regular)).foregroundStyle(palette.text).lineLimit(1)
            Spacer(minLength: Abstand.s)
            Text(CrewLogik.wertText(z.wert, mass)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(z.ich ? palette.akzent : palette.text)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Platz \(z.rang), \(z.name), \(CrewLogik.wertText(z.wert, mass))")
    }

    // MARK: Freunde

    /// Wer gerade trainiert oder zuletzt trainiert hat (antippbar), Einladen mit einem Tipp (Link teilen); Code, Scan und Einstellungen je Person
    /// wohnen in "Freunde hinzufügen und verwalten".
    private var freunde: some View {
        let zeilen = GymCrewQuelle.zeilen(umgebung)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            kopf("Freunde")
            if !zeilen.isEmpty { GymCrewZeilen(zeilen: zeilen, grenze: .max) }
            ListenKarte {
                CrewLinkTeilen(imHub: true)
                Haarlinie()
                NavigationLink { VerbindungenView() } label: {
                    GymZeile(titel: "Freunde hinzufügen und verwalten", untertitel: "Code zeigen oder scannen, was jede Person sieht") {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Texte der Crew, die mehrere Ansichten brauchen.
enum CrewTexte {
    nonisolated static let sichtbar = "Alle in dieser Herausforderung sehen deinen Namen und deinen Wert."

    /// "heute · 54 min · 27 Sätze"
    static func trainingText(_ t: PartnerTrainingKurz, heute: String) -> String {
        let n = Datum.tageZwischen(t.tag, heute)
        var teile = [n <= 0 ? "heute" : n == 1 ? "gestern" : "vor \(n) Tagen"]
        if let m = t.minuten { teile.append(TrainingLogik.dauerText(TimeInterval(m * 60))) }
        if t.saetze > 0 { teile.append(t.saetze == 1 ? "1 Satz" : "\(t.saetze) Sätze") }
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
