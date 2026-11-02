import SwiftUI

/// Eine Person in der Liste "Verbindungen": Name und darunter ihre Schritte und ihr Gym von heute (sofern geteilt), sonst wann sie zuletzt Daten geschickt hat.
struct VerbindungZeile: View {
    let eintrag: VerbindungEintrag
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: eintrag.ich.favorit ? "star.fill" : "person.fill")
                .frame(width: 28)
                .foregroundStyle(palette.text2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.anzeigeName).foregroundStyle(palette.text)
                Text(untertitel).font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.m)
        }
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
    }

    private var untertitel: String {
        if eintrag.ich.pause { return "Pausiert" }
        return VerbindungenLogik.kurzInfo(eintrag, jetzt: umgebung.uhr()) ?? VerbindungenLogik.zuletztText(eintrag.zuletzt, jetzt: umgebung.uhr())
    }
}

/// Alles zu einer Person: was du zeigst (mit Vorschau), was du von ihr sehen willst, Pause, Mitteilungen, Favorit, eigener Name, Entfernen.
struct VerbindungPersonView: View {
    let id: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fragen = false
    @State private var einzelnOffen = false
    @State private var fehler: String?
    @State private var zeigtLokal: Set<VerbindungBereich>?
    @State private var ausblendenLokal: Set<VerbindungBereich>?

    private var eintrag: VerbindungEintrag? { umgebung.konto.verbindungen.eintraege.first { $0.id == id && $0.aktiv } }

    var body: some View {
        Group {
            if let e = eintrag {
                Form {
                    zeigstAbschnitt(e)
                    vorschauAbschnitt(e)
                    kopf(e)
                    siehstAbschnitt(e)
                    optionen(e)
                    entfernen(e)
                }
                .verbindenFormular()
                .onAppear {
                    name = e.ich.name
                    einzelnOffen = FreigabeStufe.von(e.ich.zeigtBereiche) == nil && !e.ich.zeigtBereiche.isEmpty
                }
                .onChange(of: e.ich) { _, neu in
                    zeigtLokal = nil
                    ausblendenLokal = nil
                    name = neu.name
                }
            } else {
                LeerZustand(stimmung: .bereit, satz: "Diese Verbindung gibt es nicht mehr.")
            }
        }
        .navigationTitle(eintrag?.anzeigeName ?? "Verbindung")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .alert("Das hat nicht geklappt", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(fehler ?? "") }
    }

    // MARK: Abschnitte

    private func kopf(_ e: VerbindungEintrag) -> some View {
        VerbindenAbschnitt(titel: nil, fuss: e.lovea ? "Das ist deine Verbindung über Lovea. Sie bleibt, bis du sie entfernst oder ausschaltest." : nil) {
            LabeledContent("Zuletzt") { Text(VerbindungenLogik.zuletztText(e.zuletzt, jetzt: umgebung.uhr())).foregroundStyle(palette.text2) }
        }
    }

    private func zeigstAbschnitt(_ e: VerbindungEintrag) -> some View {
        let an = zeigtLokal ?? e.ich.zeigtBereiche
        return VerbindenAbschnitt(titel: "Das zeigst du \(e.anzeigeName)",
                                  fuss: "Wenig: Schritte und Gym. Alles: alle Bereiche. Es gehen nur Zusammenfassungen von heute hinaus.") {
            FreigabeAuswahl(an: an, einklappbar: $einzelnOffen) { neu in
                zeigtLokal = neu
                senden(FreigabeStufe.felder(neu))
            }
        }
    }

    private func vorschauAbschnitt(_ e: VerbindungEintrag) -> some View {
        let an = zeigtLokal ?? e.ich.zeigtBereiche
        let frei = VerbindungenLogik.erlaubt(Set(an.compactMap(\.freigabe)), einstellungen: umgebung.daten?.einstellungen.werte ?? Einstellungen())
        let zeilen = VerbindenDienste.geteilt?.bruecke.vorschau(freigaben: frei).map(FreigabenVorschau.zeilen) ?? []
        return VerbindenAbschnitt(titel: "Das sieht \(e.anzeigeName)", fuss: "Genau diese Zeilen bekommt diese Person, nicht mehr.") {
            if an.isEmpty || e.ich.pause {
                Text(e.ich.pause ? "Nichts, die Pause ist an." : "Nichts. Du zeigst dieser Person noch nichts.").foregroundStyle(palette.text2)
            } else if zeilen.isEmpty {
                Text("Heute gibt es noch keine Werte.").foregroundStyle(palette.text2)
            }
            if !e.ich.pause {
                ForEach(zeilen) { z in
                    LabeledContent { Text(z.wert).monospacedDigit() } label: { Label(z.titel, systemImage: z.symbol) }
                        .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private func siehstAbschnitt(_ e: VerbindungEintrag) -> some View {
        let aus = ausblendenLokal ?? e.ich.ausgeblendet
        let liste = VerbindungBereich.allCases.filter { e.sichtbareBereiche.contains($0) || aus.contains($0) }
        if liste.isEmpty {
            VerbindenAbschnitt(titel: "Das siehst du von \(e.anzeigeName)", fuss: "\(e.anzeigeName) teilt mit dir noch nichts.") { EmptyView() }
        } else {
            VerbindenAbschnitt(titel: "Das siehst du von \(e.anzeigeName)", fuss: "Ausgeschaltetes verschwindet bei dir. Es ändert nicht, was die andere Person teilt.") {
                ForEach(liste, id: \.self) { b in
                    Toggle(isOn: Binding(get: { !aus.contains(b) }, set: { neu in
                        var n = aus
                        if neu { n.remove(b) } else { n.insert(b) }
                        ausblendenLokal = n
                        senden(["ausblenden": n.map(\.rawValue).sorted()])
                    })) { BereichZeile(b, erklaerung: false) }
                    .frame(minHeight: Abstand.tippflaeche)
                }
                let zeilen = e.daten.map(FreigabenVorschau.zeilen) ?? []
                ForEach(zeilen) { z in
                    LabeledContent { Text(z.wert).monospacedDigit() } label: { Label(z.titel, systemImage: z.symbol) }
                        .accessibilityElement(children: .combine)
                }
                let fehlt = VerbindungenLogik.nichtGeteilt(e)
                if !fehlt.isEmpty {
                    Text("Wird nicht geteilt: \(fehlt.map(\.name).joined(separator: ", "))").font(.footnote).foregroundStyle(palette.text2)
                }
                // Plan, Verlauf, Tagebuch und Körperwerte öffnen als eigene Ansichten: für den Lovea-Partner mit seinem Stand, für alle anderen mit dem der Person.
                let stand = e.lovea ? PartnerAnsichtLogik.aktuellerStand(umgebung) : e.stand(jetzt: umgebung.uhr())
                if let datei = PartnerAnsichtLogik.datei(stand) {
                    PartnerEinstiegZeilen(einstiege: PartnerAnsichtLogik.einstiege(datei, jetzt: umgebung.uhr()), imFormular: true, stand: e.lovea ? nil : stand)
                }
            }
        }
    }

    private func optionen(_ e: VerbindungEintrag) -> some View {
        VerbindenAbschnitt(titel: "Optionen", fuss: "Pause: ihr seht euch beide nichts, bis du sie ausschaltest. Mitteilungen: Meldungen wie \"im Gym\" von dieser Person.") {
            Toggle("Pause", isOn: Binding(get: { e.ich.pause }, set: { senden(["pause": $0]) })).frame(minHeight: Abstand.tippflaeche)
            Toggle("Mitteilungen", isOn: Binding(get: { e.ich.mitteilungen }, set: { senden(["mitteilungen": $0]) })).frame(minHeight: Abstand.tippflaeche)
            Toggle("Favorit", isOn: Binding(get: { e.ich.favorit }, set: { senden(["favorit": $0]) })).frame(minHeight: Abstand.tippflaeche)
            TextField("Eigener Name (nur bei dir)", text: $name)
                .submitLabel(.done)
                .onSubmit { senden(["name": name.trimmingCharacters(in: .whitespacesAndNewlines)]) }
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func entfernen(_ e: VerbindungEintrag) -> some View {
        VerbindenAbschnitt(fuss: "Beide Seiten sehen sich sofort nicht mehr. Gespeicherte Daten dieser Person werden von diesem Gerät gelöscht. Wieder verbinden geht nur mit einem neuen Code.") {
            Button("Verbindung entfernen", role: .destructive) { fragen = true }
                .frame(minHeight: Abstand.tippflaeche)
                .confirmationDialog("Verbindung mit \(e.anzeigeName) entfernen?", isPresented: $fragen, titleVisibility: .visible) {
                    Button("Entfernen", role: .destructive) {
                        Task {
                            if await umgebung.konto.verbindungEntfernen(e.id) { dismiss() } else { fehler = "Die Verbindung ließ sich nicht entfernen. Prüfe das Netz und versuche es nochmal." }
                        }
                    }
                    Button("Abbrechen", role: .cancel) {}
                }
        }
    }

    // MARK: Hilfen

    private func senden(_ felder: [String: Any]) {
        Task {
            if !(await umgebung.konto.verbindungAendern(id, felder)) {
                zeigtLokal = nil
                ausblendenLokal = nil
                fehler = "Das ließ sich nicht speichern. Prüfe das Netz und versuche es nochmal."
            }
        }
    }
}
