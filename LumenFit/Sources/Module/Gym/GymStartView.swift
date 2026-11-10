// Quelle: Lovea Health/GymNeu/GymStartView.swift (neu im Lumen-Design)
import SwiftUI

/// Die Startseite des Trainings (Idee 27 und 29): Wochenleiste, der Plantag mit Zeitschätzung und Start, "Heute Beine statt Push",
/// Verlegen, Cardio ohne Training, die letzten Einheiten und das Studio.
struct GymStartView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @State private var gewaehlt: String?
    /// Ein anderer Plantag statt des geplanten, nur für heute ("Heute Beine statt Push").
    @State private var andererTag: String?
    @State private var cardioGeraet: CardioWahl?
    @State private var einstellungen = false
    @State private var fehler: String?
    /// Die vergessene Einheit, deren Endzeit gerade eingetragen wird.
    @State private var endzeitFuer: GymSession?
    @State private var nachtragen = false
    /// "Mehr" unten ist zu, bis man es öffnet.
    @State private var mehrOffen = false

    var body: some View {
        ScrollView {
            if let training = sitzung.training {
                inhalt(training)
                    .padding(.horizontal, Abstand.l)
                    .padding(.bottom, Abstand.xl)
            } else {
                LeerZustand(stimmung: .denkt, satz: "Das Training lädt noch.")
            }
        }
        .sheet(item: $cardioGeraet) { CardioEingabeView(sitzung: sitzung, geraet: $0.rawValue) }
        .sheet(isPresented: $einstellungen) { GymEinstellungenBlatt(sitzung: sitzung) }
        .alert("Das geht gerade nicht", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
            Button("Verstanden") { fehler = nil }
        } message: {
            Text(fehler ?? "")
        }
        .sheet(item: $endzeitFuer) { EinheitEndzeitBlatt(session: $0, jetzt: umgebung.uhr()) }
        .sheet(isPresented: $nachtragen) { EinheitNachtragenBlatt(jetzt: umgebung.uhr()) }
        .task { sitzung.ladeWennNoetig() }
    }

    private func inhalt(_ training: TrainingStore) -> some View {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let datum = gewaehlt ?? heute
        // Ohne Studio kein Zeitfenster: ein aus Lovea übernommenes ließe sich nicht mehr ändern.
        let stand = GymStartStand.bauen(sessions: training.sessions, plan: training.plan, gewaehlt: datum, jetzt: jetzt)
        let anderer = datum == heute ? andererTag.flatMap { training.tag(id: $0) } : nil
        return VStack(alignment: .leading, spacing: Abstand.l) {
            // Der große Start ganz oben, dann Woche und Tag, Letzte Einheiten; alles Seltene unter "Mehr".
            if let knopf = stand.knopf { startKnopf(knopf, training: training).frame(maxWidth: .infinity) }
            wochenleiste(stand)
            tagesKarte(stand, training: training, anderer: anderer)
            if stand.vergessen, let s = training.vergessene(jetzt: jetzt) { vergessenKarte(s, training: training) }
            letzte(training, jetzt: jetzt)
            planZeile
            mehrBereich(stand, training: training)
        }
    }

    // MARK: Plan

    /// Der Plan ist eine Unterseite des Trainings (Task 7 ordnet die Zeilen Plan, Kalender, Übungen neu).
    private var planZeile: some View {
        NavigationLink(value: Route.gym(.plaene)) {
            ListenKarte {
                GymZeile(titel: "Plan", untertitel: "Tage, Übungen und Split-Bibliothek") {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Mehr

    private var cardioKnoepfe: some View {
        HStack(spacing: Abstand.s) {
            Button { cardioGeraet = .laufband } label: {
                Label("Laufband", systemImage: "figure.walk.treadmill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            Button { cardioGeraet = .stairmaster } label: {
                Label("Stairmaster", systemImage: "figure.stair.stepper").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Cardio eintragen")
    }

    private var einstellungenKnopf: some View {
        Button { einstellungen = true } label: {
            Label("Einstellungen fürs Training", systemImage: "gearshape").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.bordered)
    }

    /// Eine Zeile "Mehr", darunter (aufgeklappt) Diese Woche mit Verlegen und Testwoche, Cardio, Einstellungen und Nachtragen.
    @ViewBuilder
    private func mehrBereich(_ stand: GymStartStand, training: TrainingStore) -> some View {
        ListenKarte {
            Button { mehrOffen.toggle() } label: {
                GymZeile(titel: "Cardio, Nachtragen, Einstellungen", untertitel: "Auch: diesen Tag verlegen") {
                    Image(systemName: mehrOffen ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(mehrOffen ? "Klappt zu" : "Klappt auf")
        }
        if mehrOffen {
            verlegenKarte(stand, training: training)
            cardioKnoepfe
            einstellungenKnopf
            Button { nachtragen = true } label: {
                Label("Training nachtragen", systemImage: "plus").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Wochenleiste

    private func wochenleiste(_ stand: GymStartStand) -> some View {
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            // W-003: der Tag steht schon als Titel der Karte darunter.
            HStack(spacing: Abstand.xs) {
                ForEach(stand.woche) { t in
                    Button {
                        gewaehlt = t.datum == stand.heute ? nil : t.datum
                        andererTag = nil
                    } label: {
                        VStack(spacing: 2) {
                            Text(t.kuerzel).font(.caption.weight(.semibold))
                            Image(systemName: t.gemacht ? "checkmark.circle.fill" : t.geplant != nil ? "circle" : "minus")
                                .foregroundStyle(t.gemacht ? gruen : palette.text2)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(palette.text)
                        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche + 8)
                        .background(t.gewaehlt ? gruen.opacity(0.16) : Color.clear, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).stroke(t.heute ? gruen : Color.clear, lineWidth: 1.5))
                    }
                    .buttonStyle(.federnd)
                    .accessibilityLabel(t.sprechtext)
                    .accessibilityAddTraits(t.gewaehlt ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Plantag

    private func tagesKarte(_ stand: GymStartStand, training: TrainingStore, anderer: TrainingsTag?) -> some View {
        let tag = anderer ?? stand.tag
        let abweichung = anderer.flatMap { GymStartStand.abweichung(geplant: stand.tag, gewaehlt: $0) }
        return HeroKarte(platte: true) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                // W-003: "noch nicht" sagt nichts Neues, nur Abweichung oder Erledigtes steht oben.
                if abweichung != nil || stand.status != "noch nicht" {
                    Text(abweichung ?? stand.status).font(.footnote.weight(.semibold)).textCase(.uppercase)
                }
                if let tag {
                    Text(tag.name.isEmpty ? "Training" : tag.name).font(.title2.weight(.bold)).fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                    Text(ZeitSchaetzung.umfang(tag)).font(.subheadline)
                    // Ohne Zeitfenster wiederholt das Urteil nur die Dauer ("ca. 24 min" unter "etwa 25 min").
                    if stand.slotMinuten != nil {
                        let urteil = ZeitSchaetzung.urteil(tag, slotMinuten: stand.slotMinuten)
                        Label(urteil.titel, systemImage: urteil.warnt ? "exclamationmark.triangle.fill" : "timer").font(.subheadline)
                        if let tipp = urteil.tipp { Text(tipp.text).font(.footnote) }
                    }
                } else {
                    Text("Ruhetag").font(.title2.weight(.bold)).fontDesign(.rounded)
                    Text("Erholung gehört zum Plan. Du kannst trotzdem trainieren.").font(.subheadline)
                }
                if stand.knopf != nil {
                    HStack(spacing: Abstand.s) {
                        andereTageMenue(training: training, aktuell: tag)
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Der Start von heute: nach kurzem Beenden fortsetzen, sonst der gewählte (oder geplante) Tag. Hero-Knopf und Studio-Karte teilen das.
    private func heuteStarten(_ training: TrainingStore) {
        if training.fortsetzbare() != nil { sitzung.fortsetzen() } else { sitzung.starte(planTag: andererTag ?? training.heutigerTag()?.id) }
    }

    private func startKnopf(_ knopf: GymStartKnopf, training: TrainingStore) -> some View {
        Button {
            if knopf == .weiter { sitzung.ladeWennNoetig() } else { heuteStarten(training) }
        } label: {
            Label(knopf.titel, systemImage: knopf.symbolName).font(.headline).frame(minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.borderedProminent)
        .tint(.white)
        .foregroundStyle(.black)
    }

    /// "Heute Beine statt Push": einen anderen Tag des Plans oder ein freies Training wählen.
    private func andereTageMenue(training: TrainingStore, aktuell: TrainingsTag?) -> some View {
        Menu {
            ForEach(training.plan.tage.filter { $0.id != aktuell?.id }) { t in
                Button(t.name.isEmpty ? "Training" : t.name) { andererTag = t.id }
            }
            if andererTag != nil { Button("Zurück zum Plan") { andererTag = nil } }
            Button("Freies Training") { sitzung.starte(planTag: nil) }
        } label: {
            Label("Anderer Tag", systemImage: "arrow.left.arrow.right").font(.subheadline.weight(.semibold)).frame(minHeight: Abstand.tippflaeche)
        }
        .tint(.white)
    }

    // MARK: Auschecken vergessen

    private func vergessenKarte(_ s: GymSession, training: TrainingStore) -> some View {
        ListenKarte {
            GymZeile(titel: "Auschecken vergessen?", untertitel: "Die Einheit von \(GymFormat.tag(s.start)) läuft noch. Trag ein, wann du fertig warst, oder setz das Ende auf 1,5 Stunden nach dem Start.") {
                EmptyView()
            }
            HStack(spacing: Abstand.s) {
                Button("Endzeit eintragen") { endzeitFuer = s }
                    .buttonStyle(.bordered).controlSize(.large)
                Button("Nach 1,5 Stunden") { training.auschecken(s.id, ende: EinheitZeitenLogik.endeVorschlag(start: s.start, jetzt: umgebung.uhr())) }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.m)
        }
    }

    // MARK: Verlegen und Testwoche

    @ViewBuilder
    private func verlegenKarte(_ stand: GymStartStand, training: TrainingStore) -> some View {
        if !stand.ziele.isEmpty || stand.verlegt || stand.testHinweis != nil {
            VStack(alignment: .leading, spacing: Abstand.s) {
                GymAbschnitt(titel: "Diese Woche")
                ListenKarte {
                    if let hinweis = stand.testHinweis {
                        GymZeile(titel: hinweis) {
                            Button("Beenden") { training.testwocheAbbrechen() }.buttonStyle(.bordered).controlSize(.large)
                        }
                    }
                    if !stand.ziele.isEmpty {
                        if stand.testHinweis != nil { Haarlinie() }
                        GymZeile(titel: "Tag verlegen", untertitel: "Nur diese Woche, der Plan bleibt.") {
                            Menu("Verlegen") {
                                ForEach(stand.ziele, id: \.datum) { z in
                                    Button(z.text) { if !training.verlegen(von: stand.gewaehlt, auf: z.datum) { fehler = "Dieser Tag lässt sich nicht verlegen." } }
                                }
                            }
                            .buttonStyle(.bordered).controlSize(.large)
                        }
                    }
                    if stand.verlegt {
                        Haarlinie()
                        GymZeile(titel: "Zurück auf Plan", untertitel: "Verlegte Tage gelten wieder wie im Plan.") {
                            Button("Zurücksetzen") { training.verlegungenLoeschen() }.buttonStyle(.bordered).controlSize(.large)
                        }
                    }
                }
            }
        }
    }

    // MARK: Letzte Einheiten

    @ViewBuilder
    private func letzte(_ training: TrainingStore, jetzt: Date) -> some View {
        let liste = training.sessions.sorted { $0.start > $1.start }.prefix(5)
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: "Letzte Einheiten")
            ListenKarte {
                ForEach(Array(liste)) { s in
                    let tag = Datum.text(s.start)
                    NavigationLink {
                        EinheitNachlesenView(sessionId: s.id)
                    } label: {
                        GymZeile(titel: training.tag(id: s.tag).map { $0.name.isEmpty ? "Training" : $0.name } ?? "Freies Training",
                                 untertitel: GymFormat.tag(s.start) + (s.notiz.map { " · \($0.prefix(60))" } ?? "")) {
                            HStack(spacing: Abstand.xs) {
                                Text(GymStartLogik.status([s], datum: tag, heute: Datum.text(jetzt), geplant: nil, jetzt: jetzt))
                                    .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.trailing)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Öffnet die Einheit zum Nachlesen")
                    .accessibilityElement(children: .combine)
                    Haarlinie()
                }
                NavigationLink {
                    TrainingVerlaufView()
                } label: {
                    GymZeile(titel: "Alle Trainingstage", untertitel: "Monatsraster, Serie und alle Einheiten") {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Die zwei Schnellknöpfe für Cardio ohne Training.
enum CardioWahl: String, Identifiable { case laufband, stairmaster; var id: String { rawValue } }
