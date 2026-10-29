// Quelle: Lovea Health/GymNeu/GymStartView.swift (neu im Lumen-Design; ohne Partner und Körperwoche)
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
    @State private var cardio = false
    @State private var einstellungen = false
    @State private var fehler: String?

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
        .sheet(isPresented: $cardio) { CardioEingabeView(sitzung: sitzung) }
        .sheet(isPresented: $einstellungen) { GymEinstellungenBlatt(sitzung: sitzung) }
        .alert("Das geht gerade nicht", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
            Button("OK") { fehler = nil }
        } message: {
            Text(fehler ?? "")
        }
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
            tagesKarte(stand, training: training, anderer: anderer)
            if stand.vergessen, let s = training.vergessene(jetzt: jetzt) { vergessenKarte(s, training: training) }
            verlegenKarte(stand, training: training)
            Button { cardio = true } label: {
                Label("Cardio eintragen", systemImage: "figure.run").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            Button { einstellungen = true } label: {
                Label("Einstellungen fürs Training", systemImage: "gearshape").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
            letzte(training, jetzt: jetzt)
            StudioKarte(sitzung: sitzung) { heuteStarten(training) }
        }
    }

    // MARK: Wochenleiste

    private func wochenleiste(_ stand: GymStartStand) -> some View {
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
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
            Button("Freies Training") { sitzung.starte(planTag: nil) }
        } label: {
            Label("Anderer Tag", systemImage: "arrow.left.arrow.right").font(.subheadline.weight(.semibold)).frame(minHeight: Abstand.tippflaeche)
        }
        .tint(.white)
    }

    // MARK: Auschecken vergessen

    private func vergessenKarte(_ s: GymSession, training: TrainingStore) -> some View {
        ListenKarte {
            GymZeile(titel: "Auschecken vergessen?", untertitel: "Die Einheit von \(GymFormat.tag(s.start)) läuft noch. Das Ende wird auf 1,5 Stunden nach dem Start gesetzt.") {
                Button("Auschecken") { training.auschecken(s.id, ende: s.start.addingTimeInterval(TrainingLogik.langNach / 2)) }
                    .buttonStyle(.bordered).controlSize(.large)
            }
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
        if !liste.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                GymAbschnitt(titel: "Letzte Einheiten")
                ListenKarte {
                    ForEach(Array(liste)) { s in
                        let tag = Datum.text(s.start)
                        GymZeile(titel: training.tag(id: s.tag).map { $0.name.isEmpty ? "Training" : $0.name } ?? "Freies Training",
                                 untertitel: GymFormat.tag(s.start)) {
                            Text(GymStartLogik.status([s], datum: tag, heute: Datum.text(jetzt), geplant: nil, jetzt: jetzt))
                                .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                        if s.id != liste.last?.id { Haarlinie() }
                    }
                }
            }
        }
    }
}
