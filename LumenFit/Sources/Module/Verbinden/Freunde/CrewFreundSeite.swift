import SwiftUI

/// Eine Person der Crew: Status, Trainingspartner wählen, eure Woche, Zahlen der Woche, Live-Einheit, Rekorde und letzte Trainings, Vergleich
/// gemeinsamer Übungen, Herausfordern und die Einstellungen der Verbindung. Alles nur aus dem, was die Person mir zeigt; ohne Freigabe steht
/// "nicht geteilt", nie eine 0.
struct CrewFreundSeite: View {
    let id: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var herausfordern = false
    /// Nur damit die Seite eine neue Wahl des Trainingspartners sofort zeigt.
    @AppStorage(VerbindungenLogik.partnerSchluessel) private var gewaehlt: String?

    var body: some View {
        let eintrag = GymCrewQuelle.eintraege(umgebung).first { $0.id == id }
        Group {
            if let eintrag {
                inhalt(eintrag)
            } else {
                LeerZustand(stimmung: .denkt, satz: String(localized: "Diese Person ist nicht mehr verbunden."))
            }
        }
        .lumenHintergrund()
        .navigationTitle(eintrag.map(CrewLogik.name) ?? String(localized: "Freund"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $herausfordern) { CrewHerausforderungBlatt(vorauswahl: id) }
        .modifier(CrewFehlerAnzeige(extra: .constant(nil)))
    }

    private func kopf(_ titel: String) -> some View {
        Text(titel).font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
    }

    private func inhalt(_ e: VerbindungEintrag) -> some View {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let zeile = GymCrewLogik.zeilen(eintraege: [e], datum: heute, heute: heute, jetzt: jetzt).first
        return ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                ListenKarte {
                    GymZeile(titel: CrewLogik.name(e), untertitel: zeile?.status ?? VerbindungenLogik.zuletztText(e.zuletzt, jetzt: jetzt))
                    if let satz = zeile?.mitlauf {
                        Text(GymMitlaufLogik.text(satz)).font(.footnote).foregroundStyle(palette.text2)
                            .padding([.horizontal, .bottom], Abstand.l)
                    }
                }
                knoepfe(e)
                if let d = e.daten {
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        kopf(String(localized: "Eure Woche"))
                        ListenKarte { CrewWocheZusammen(name: CrewLogik.name(e), datei: d).padding(Abstand.l) }
                    }
                }
                woche(e, jetzt: jetzt)
                if let d = e.daten { live(e, d, imGym: zeile?.zustand == .imGym, heute: heute) }
                if let d = e.daten { rekorde(e, d, jetzt: jetzt) }
                if let d = e.daten { trainings(e, d, heute: heute) }
                vergleich(e)
                ListenKarte {
                    NavigationLink { VerbindungPersonView(id: e.id) } label: {
                        GymZeile(titel: String(localized: "Einstellungen der Verbindung"), untertitel: String(localized: "Was du zeigst, Pause, Name, Entfernen")) {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
    }

    // MARK: Knöpfe

    private func knoepfe(_ e: VerbindungEintrag) -> some View {
        let istPartner = VerbindungenLogik.partner(CrewLogik.crew(GymCrewQuelle.eintraege(umgebung)), gewaehlt: gewaehlt)?.id == e.id
        return VStack(spacing: Abstand.s) {
            Button { herausfordern = true } label: {
                Label("Herausfordern", systemImage: "flag.checkered").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            Button { umgebung.konto.partnerWaehlen(istPartner ? VerbindungenLogik.keinPartner : e.id) } label: {
                Label(istPartner ? "Dein Trainingspartner" : "Als Trainingspartner wählen", systemImage: istPartner ? "person.2.fill" : "person.2")
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            .accessibilityHint(istPartner ? "Tippen nimmt die Wahl zurück" : "Seine Karte steht dann auf Heute und im Training")
            if !CrewLogik.darfReagieren(e) {
                Text(e.ich.pause ? "Die Verbindung ist pausiert." : "Diese Person teilt Gym nicht mit dir.")
                    .font(.footnote).foregroundStyle(palette.text2).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Woche

    private func woche(_ e: VerbindungEintrag, jetzt: Date) -> some View {
        let w = CrewLogik.woche(e.daten, jetzt: jetzt)
        let serie = e.daten.flatMap { $0.freigaben.contains(.verlauf) ? $0.heute.verlauf?.serieWochen : nil }
        return VStack(alignment: .leading, spacing: Abstand.s) {
            kopf(String(localized: "Diese Woche"))
            ListenKarte {
                ForEach(Array(CrewMass.rangliste.enumerated()), id: \.element) { i, m in
                    if i > 0 { Haarlinie() }
                    GymZeile(titel: m.titel) {
                        Text(w?.wert(m).map { CrewLogik.wertText($0, m) } ?? String(localized: "nicht geteilt"))
                            .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                    }
                    .accessibilityElement(children: .combine)
                }
                Haarlinie()
                GymZeile(titel: String(localized: "Serie")) {
                    Text(serie.map { $0 == 1 ? String(localized: "1 Woche") : String(localized: "\($0) Wochen") } ?? String(localized: "nicht geteilt"))
                        .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Live, Rekorde, Trainings

    @ViewBuilder
    private func live(_ e: VerbindungEintrag, _ d: ZusammenfassungDatei, imGym: Bool, heute: String) -> some View {
        if imGym, let einheit = GymPartnerLogik.einheit(am: heute, in: d) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                kopf(String(localized: "Läuft gerade"))
                ListenKarte {
                    NavigationLink { GymPartnerEinheitView(name: CrewLogik.name(e), einheit: einheit) } label: {
                        GymZeile(titel: einheit.name ?? String(localized: "Training"), untertitel: String(localized: "\(einheit.uebungen.count) Übungen · \(GymPartnerLogik.saetzeZahl(einheit)) Sätze")) {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func rekorde(_ e: VerbindungEintrag, _ d: ZusammenfassungDatei, jetzt: Date) -> some View {
        let heute = Datum.text(jetzt)
        let liste = Array(GymRekordPinnwandLogik.rekorde(d, name: CrewLogik.name(e), jetzt: jetzt).sorted { $0.tag > $1.tag }.prefix(5))
        if !liste.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                kopf(String(localized: "Rekorde"))
                ListenKarte {
                    ForEach(Array(liste.enumerated()), id: \.element) { i, r in
                        if i > 0 { Haarlinie() }
                        GymZeile(titel: r.uebung, untertitel: GymRekordPinnwandLogik.text(r, heute: heute))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trainings(_ e: VerbindungEintrag, _ d: ZusammenfassungDatei, heute: String) -> some View {
        let liste = Array(GymPartnerLogik.einheiten(d).prefix(5))
        if !liste.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                kopf(String(localized: "Letzte Trainings"))
                ListenKarte {
                    ForEach(Array(liste.enumerated()), id: \.element) { i, t in
                        if i > 0 { Haarlinie() }
                        trainingZeile(e, d, t, heute: heute)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trainingZeile(_ e: VerbindungEintrag, _ d: ZusammenfassungDatei, _ t: PartnerTrainingKurz, heute: String) -> some View {
        let titel = t.name ?? Datum.anzeige(t.tag)
        let untertitel = CrewTexte.trainingText(t, heute: heute)
        if let einheit = GymPartnerLogik.einheit(am: t.tag, in: d) {
            NavigationLink { GymPartnerEinheitView(name: CrewLogik.name(e), einheit: einheit) } label: { GymZeile(titel: titel, untertitel: untertitel) }
                .buttonStyle(.plain)
                .accessibilityHint("Zeigt die Sätze")
        } else {
            GymZeile(titel: titel, untertitel: untertitel)
        }
    }

    // MARK: Vergleich

    @ViewBuilder
    private func vergleich(_ e: VerbindungEintrag) -> some View {
        let liste = CrewLogik.vergleich(sessions: umgebung.daten?.training.sessions ?? [], datei: e.daten)
        if !liste.isEmpty {
            let name = CrewLogik.name(e)
            VStack(alignment: .leading, spacing: Abstand.s) {
                kopf(String(localized: "Vergleich: bestes geschätztes 1RM"))
                ListenKarte {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { i, v in
                        if i > 0 { Haarlinie() }
                        GymZeile(titel: v.uebung, untertitel: String(localized: "Du \(TrainingLogik.kgText(v.ich.rounded())) kg · \(name) \(TrainingLogik.kgText(v.person.rounded())) kg")) {
                            Image(systemName: v.ich >= v.person ? "arrow.up.circle.fill" : "arrow.down.circle")
                                .foregroundStyle(v.ich >= v.person ? palette.akzent : palette.text2)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}
