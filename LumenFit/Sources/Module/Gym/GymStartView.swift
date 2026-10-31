// Quelle: Lovea Health/GymNeu/GymStartView.swift (neu im Lumen-Design; im Lovea-Aufbau mit Partner-Zeile und Menü ⋯, ohne Körperwoche)
import SwiftUI

/// Die Startseite des Trainings (Idee 27 und 29): Wochenleiste, der Plantag mit Zeitschätzung und Start, "Heute Beine statt Push",
/// Verlegen, Cardio ohne Training, die letzten Einheiten und das Studio.
struct GymStartView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.lumenAufbau) private var aufbau
    @State private var gewaehlt: String?
    /// Ein anderer Plantag statt des geplanten, nur für heute ("Heute Beine statt Push").
    @State private var andererTag: String?
    @State private var cardioGeraet: CardioWahl?
    @State private var einstellungen = false
    @State private var fehler: String?
    /// Die vergessene Einheit, deren Endzeit gerade eingetragen wird.
    @State private var endzeitFuer: GymSession?
    @State private var nachtragen = false
    @State private var uebungenTag: PlanView.IdentifiableText?
    /// Lovea-Aufbau: wohin das Menü ⋯ oder "Diese Woche anderes Split testen" führt (Push, wie Lovea `GymMenuZiel`).
    @State private var menueZiel: GymMenueZiel?
    @State private var freiGestartet = 0

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
            Button("OK") { fehler = nil }
        } message: {
            Text(fehler ?? "")
        }
        .sheet(item: $endzeitFuer) { EinheitEndzeitBlatt(session: $0, jetzt: umgebung.uhr()) }
        .sheet(isPresented: $nachtragen) { EinheitNachtragenBlatt(jetzt: umgebung.uhr()) }
        .sheet(item: $uebungenTag) { PlanTagBlatt(sitzung: sitzung, tagId: $0.id) }
        .toolbar {
            if aufbau == .lovea {
                ToolbarItem(placement: .topBarTrailing) { loveaMenue }
            }
        }
        .navigationDestination(item: $menueZiel) { menueSeite($0) }
        .haptik(.erfolg, bei: freiGestartet)
        .task { sitzung.ladeWennNoetig() }
    }

    private func inhalt(_ training: TrainingStore) -> some View {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let datum = gewaehlt ?? heute
        let profil = sitzung.studio?.profil ?? .standard
        let stand = GymStartStand.bauen(sessions: training.sessions, plan: training.plan, gewaehlt: datum, jetzt: jetzt, slotMinuten: ZeitSchaetzung.slot(profil))
        let anderer = datum == heute ? andererTag.flatMap { training.tag(id: $0) } : nil
        return VStack(alignment: .leading, spacing: Abstand.l) {
            wochenleiste(stand)
            if aufbau == .lovea { werZeile(stand, jetzt: jetzt) }
            // Lovea-Aufbau (`GymStartView.swift:89-95`): Wochenleiste, "Auschecken vergessen?", dann Kopf mit Start, dann die Abweichung (Testwoche, Verlegen).
            if aufbau == .lovea, stand.vergessen, let s = training.vergessene(jetzt: jetzt) { vergessenKarte(s, training: training) }
            tagesKarte(stand, training: training, anderer: anderer)
            if aufbau == .lumen, stand.vergessen, let s = training.vergessene(jetzt: jetzt) { vergessenKarte(s, training: training) }
            verlegenKarte(stand, training: training)
            if aufbau == .lovea { uebungenUndSplit(stand, tag: anderer ?? stand.tag) }
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
            .gymTipp(.cardioSchnell, GymTippKontext())
            Button { einstellungen = true } label: {
                Label("Einstellungen fürs Training", systemImage: "gearshape").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            letzte(training, jetzt: jetzt)
            StudioKarte(sitzung: sitzung) { heuteStarten(training) }
            PartnerKarte(bereich: .gym)
        }
    }

    // MARK: Wochenleiste

    private func wochenleiste(_ stand: GymStartStand) -> some View {
        let gruen = aufbau.farbe(LoveaDaten.gymGruen, sonst: GymFarbe.gruen(schema: schema, kontrast: kontrast))
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Text(GymStartLogik.titel(datum: stand.gewaehlt, heute: stand.heute, tag: stand.tag))
                .font(.title3.weight(.bold)).foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
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

    // MARK: Übungsliste und Split (Lovea `GymStartView.swift:97-99`)

    @ViewBuilder
    private func uebungenUndSplit(_ stand: GymStartStand, tag: TrainingsTag?) -> some View {
        if let tag, !tag.uebungen.isEmpty {
            ListenKarte {
                ForEach(Array(tag.uebungen.enumerated()), id: \.element.id) { i, u in
                    if i > 0 { Haarlinie() }
                    Button { uebungenTag = PlanView.IdentifiableText(id: tag.id) } label: {
                        HStack {
                            Text(u.anzeigeName).font(.headline).foregroundStyle(palette.text)
                            Spacer(minLength: Abstand.s)
                            Text(u.istCardio ? "\(u.minuten ?? 20) min" : "\(u.saetze.count) × \(u.saetze.first?.wdh ?? 10)")
                                .font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                        }
                        .padding(Abstand.l)
                        .frame(minHeight: Abstand.tippflaeche)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        Text("Split").font(.footnote.weight(.semibold)).textCase(.uppercase).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
        ListenKarte {
            Button { umgebung.router.oeffne(.gym(.plaene)) } label: {
                HStack {
                    Text(stand.splitName ?? "Dein Plan").font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    Text("\(stand.planTage) Tage").font(.subheadline).foregroundStyle(palette.text2)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .padding(Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            // Lovea `GymStartView.swift:100-105`: nicht während einer Testwoche.
            if stand.planTage > 0, stand.testHinweis == nil {
                Haarlinie()
                Button { menueZiel = .splits } label: {
                    PlanLoveaPfeilZeile(titel: "Diese Woche anderes Split testen", unter: "Nur diese Woche, danach gilt dein Plan wieder")
                        .padding(.horizontal, Abstand.l)
                }
                .buttonStyle(.federnd)
            }
        }
    }

    // MARK: Partner-Zeile und Menü ⋯ (Lovea `GymStartView.swift:110`, `:361`)

    /// "Partner 54 min · 27 Sätze   Du geplant: Push": zuerst der Partner (nur wenn verbunden), dann du. Der Punkt davor wie im Wochenstreifen (dunkel = du, hell = Partner).
    private func werZeile(_ stand: GymStartStand, jetzt: Date) -> some View {
        let partner = GymPartnerLogik.partner(PartnerAnsichtLogik.aktuellerStand(umgebung))
        return HStack(spacing: 14) {
            if let partner {
                person(partner.profilName, GymPartnerLogik.status(partner, datum: stand.gewaehlt, heute: stand.heute, jetzt: jetzt), punkt: palette.text2)
            }
            person("Du", stand.status, punkt: palette.text)
        }
        .font(.footnote)
    }

    private func person(_ name: String, _ status: String, punkt: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(punkt).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(name).fontWeight(.semibold).foregroundStyle(palette.text)
            Text(status).foregroundStyle(palette.text2).monospacedDigit()
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private var loveaMenue: some View {
        let partner = GymPartnerLogik.partner(PartnerAnsichtLogik.aktuellerStand(umgebung))
        return Menu {
            if let partner { Button("Plan von \(partner.profilName)", systemImage: "person.2") { menueZiel = .partnerPlan } }
            Button("Verlauf", systemImage: "clock.arrow.circlepath") { menueZiel = .verlauf }
            Button("Messungen", systemImage: "ruler") { menueZiel = .messungen }
            Button("Übungen", systemImage: "list.bullet") { menueZiel = .uebungen }
            Button("Split wechseln", systemImage: "square.grid.2x2") { menueZiel = .splits }
            // Eigenes Ding ohne Plan: leer starten, Übungen und Cardio im Training dazu (nur ohne laufende Einheit).
            if sitzung.training?.laufende() == nil {
                Button("Freies Training", systemImage: "figure.strengthtraining.traditional") {
                    sitzung.starteFrei()
                    freiGestartet += 1
                }
            }
        } label: {
            Image(systemName: "ellipsis").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .accessibilityLabel("Mehr")
        .loveaTipp(.loveaStartMehr)
    }

    @ViewBuilder
    private func menueSeite(_ ziel: GymMenueZiel) -> some View {
        switch ziel {
        case .partnerPlan: PartnerPlanAnsicht()
        case .verlauf: TrainingVerlaufView()
        case .messungen: MessungenView()
        case .uebungen: UebungsSucheView()
        case .splits: PlanLoveaView(sitzung: sitzung)
        }
    }

    // MARK: Plantag

    private func tagesKarte(_ stand: GymStartStand, training: TrainingStore, anderer: TrainingsTag?) -> some View {
        let tag = anderer ?? stand.tag
        let abweichung = anderer.flatMap { GymStartStand.abweichung(geplant: stand.tag, gewaehlt: $0) }
        return HeroKarte(platte: true) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(abweichung ?? stand.status).font(.footnote.weight(.semibold)).textCase(.uppercase)
                if let tag {
                    Text(tag.name.isEmpty ? "Training" : tag.name).font(.title2.weight(.bold)).fontDesign(.rounded)
                    Text(ZeitSchaetzung.umfang(tag)).font(.subheadline)
                    let urteil = ZeitSchaetzung.urteil(tag, slotMinuten: stand.slotMinuten)
                    Label(urteil.titel, systemImage: urteil.warnt ? "exclamationmark.triangle.fill" : "timer").font(.subheadline)
                    if let tipp = urteil.tipp { Text(tipp.text).font(.footnote) }
                } else {
                    Text("Ruhetag").font(.title2.weight(.bold)).fontDesign(.rounded)
                    Text("Erholung gehört zum Plan. Du kannst trotzdem trainieren.").font(.subheadline)
                }
                if stand.knopf != nil {
                    HStack(spacing: Abstand.s) {
                        if let knopf = stand.knopf { startKnopf(knopf, training: training) }
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
            // Lovea-Aufbau: wirklich frei, ohne den Tag von heute (Lumen-Aufbau nimmt ihn wie bisher).
            Button("Freies Training") { if aufbau == .lovea { sitzung.starteFrei() } else { sitzung.starte(planTag: nil) } }
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
                Haarlinie()
                Button { nachtragen = true } label: {
                    GymZeile(titel: "Training nachtragen", untertitel: "Start, Ende und Trainingstag von Hand eintragen") {
                        Image(systemName: "plus").accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wohin das Menü ⋯ der Startseite im Lovea-Aufbau führt (Lovea `GymMenuZiel`; der Editor kommt in Lumen über die Übungsliste).
enum GymMenueZiel: Hashable { case partnerPlan, verlauf, messungen, uebungen, splits }

/// Die zwei Schnellknöpfe für Cardio ohne Training.
enum CardioWahl: String, Identifiable { case laufband, stairmaster; var id: String { rawValue } }
