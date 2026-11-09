// Quelle: Lovea Health/Ernaehrung/FastenView.swift
import Charts
import SwiftUI

/// Reine Entscheidungen der Fasten-Seite, ohne Oberfläche testbar.
enum EssenFastenAnzeige {
    /// Die letzten `anzahl` beendeten Fenster, ältestes zuerst (Balken laufen von links nach rechts). `beendete` ist neuester Start zuerst.
    static func letzte(_ beendete: [FastenEintrag], anzahl: Int = 7) -> [FastenEintrag] {
        Array(beendete.prefix(anzahl).reversed())
    }

    /// Plan, nach dem der Ring gerade rechnet: beim laufenden Fenster der zum Start gewählte, sonst der aktuelle.
    static func ringPlan(laufend: FastenEintrag?, aktuell: FastenPlan) -> FastenPlan {
        laufend.map(FastenLogik.planVon) ?? aktuell
    }

    /// Eintrag, dessen Start und Ende oben stehen: das laufende Fenster, sonst das zuletzt gestartete.
    static func anzeigeEintrag(laufend: FastenEintrag?, alle: [FastenEintrag]) -> FastenEintrag? { laufend ?? alle.first }

    /// Beim laufenden Fenster das geplante Ende (Start plus Stunden), sonst das tatsächliche; "–" ohne Eintrag.
    static func endeText(_ eintrag: FastenEintrag?, plan: FastenPlan) -> String {
        guard let eintrag else { return "–" }
        if let ende = eintrag.ende { return FastenLogik.zeitpunktText(ende) }
        return "\(FastenLogik.zeitpunktText(FastenLogik.geplantesEnde(start: eintrag.start, plan: plan))) (geplant)"
    }

    /// "16 von 16 Stunden, geschafft": Dauer gegen das Ziel, für VoiceOver.
    static func zielText(_ e: FastenEintrag) -> String {
        let stunden = FastenLogik.dauerStunden(e) ?? 0
        return "\(ErnaehrungLogik.zahl(stunden)) von \(FastenLogik.planVon(e).stunden) Stunden, \(FastenLogik.geschafft(e) ? "geschafft" : "nicht ganz")"
    }
}

/// Intervallfasten-Seite: großer Status mit Ring und laufender Zeit, Start und Ende zum Bearbeiten, Statistik der letzten 7 beendeten Fenster
/// und ein Verlauf zum Wischen (Bearbeiten, Löschen). Wird in einen bestehenden NavigationStack gepusht.
struct EssenFastenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var planOffen = false
    @State private var bearbeiten: FastenEintrag?
    @State private var gezeichnet = false
    @State private var aktionZaehler = 0
    @State private var planZaehler = 0
    @State private var loeschZaehler = 0

    init() {}

    var body: some View {
        Group {
            if let essen = umgebung.daten?.essen {
                liste(essen)
            } else {
                LeerZustand(stimmung: .bereit, satz: "Lege zuerst ein Profil an, dann zähle ich dein Fasten mit.")
            }
        }
        .navigationTitle("Intervallfasten")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.erfolg, bei: aktionZaehler)
        .haptik(.auswahl, bei: planZaehler)
        .haptik(.stopp, bei: loeschZaehler)
        .onAppear {
            if bewegungAus { gezeichnet = true } else { withAnimation(Feder.weich) { gezeichnet = true } }
        }
    }

    private func liste(_ essen: EssenStore) -> some View {
        let beendete = FastenLogik.beendete(essen.fastenEintraege)
        let aktuellerPlan = essen.fastenPlan
        return List {
            Section {
                statusKarte(essen, aktuellerPlan: aktuellerPlan)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Abstand.s, leading: Abstand.l, bottom: Abstand.s, trailing: Abstand.l))
            }
            Section {
                statistikKarte(essen, beendete: beendete, aktuellerPlan: aktuellerPlan)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Abstand.s, leading: Abstand.l, bottom: Abstand.s, trailing: Abstand.l))
            }
            if !beendete.isEmpty {
                Section {
                    ForEach(beendete) { e in
                        verlaufZeile(e)
                            .listRowBackground(palette.flaeche)
                            .listRowSeparatorTint(palette.haar)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    essen.fastenLoeschen(e)
                                    loeschZaehler += 1
                                }
                                Button("Bearbeiten", systemImage: "pencil") { bearbeiten = e }
                                    .tint(palette.text2)
                            }
                            .accessibilityAction(named: "Bearbeiten") { bearbeiten = e }
                            .accessibilityAction(named: "Löschen") {
                                essen.fastenLoeschen(e)
                                loeschZaehler += 1
                            }
                    }
                } header: {
                    Text("Verlauf").font(.headline).foregroundStyle(palette.text).textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .fontDesign(.rounded)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(aktuellerPlan.name) { planOffen = true }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: Abstand.tippflaeche)
                    .accessibilityLabel("Plan: \(aktuellerPlan.name), ändern")
            }
        }
        .sheet(isPresented: $planOffen) { planBlatt(essen, aktuell: aktuellerPlan) }
        .sheet(item: $bearbeiten) { e in
            EssenFastenBearbeitenBlatt(eintrag: e) { neu in
                essen.fastenAendern(neu)
                aktionZaehler += 1
            }
        }
    }

    // MARK: - Status

    private func statusKarte(_ essen: EssenStore, aktuellerPlan: FastenPlan) -> some View {
        let laufend = essen.fastenLaufend
        let ringPlan = EssenFastenAnzeige.ringPlan(laufend: laufend, aktuell: aktuellerPlan)
        let anzeige = EssenFastenAnzeige.anzeigeEintrag(laufend: laufend, alle: essen.fastenEintraege)
        return VStack(spacing: Abstand.xl) {
            if let laufend {
                TimelineView(.periodic(from: .now, by: 1)) { kontext in
                    ring(laufend: laufend, plan: ringPlan, jetzt: kontext.date)
                }
            } else {
                ring(laufend: nil, plan: ringPlan, jetzt: Date())
            }
            startEndeZeile(anzeige: anzeige, plan: ringPlan)
            aktionsKnopf(essen, laufend: laufend)
        }
        .padding(Abstand.xl)
        .frame(maxWidth: .infinity)
        .lumenKartenFlaeche()
    }

    private func ring(laufend: FastenEintrag?, plan: FastenPlan, jetzt: Date) -> some View {
        let anteil = laufend.map { FastenLogik.fortschritt(start: $0.start, plan: plan, jetzt: jetzt) } ?? 0
        let vergangen = laufend.map { FastenLogik.vergangen(start: $0.start, jetzt: jetzt) } ?? 0
        return VStack(spacing: Abstand.m) {
            Text(laufend != nil ? "Du fastest" : "Essenszeit").font(.title2.weight(.heavy)).foregroundStyle(palette.text)
            ZStack {
                Circle().stroke(palette.haar, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                Circle()
                    .trim(from: 0, to: CGFloat(anteil))
                    .stroke(palette.akzent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: Abstand.xs) {
                    Text(FastenLogik.zeitText(vergangen))
                        .font(.title.weight(.heavy)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                        .foregroundStyle(palette.text)
                    Text(laufend != nil ? "von \(plan.stunden) h" : "Bereit?")
                        .font(.footnote).foregroundStyle(palette.text2)
                }
                .padding(.horizontal, Abstand.xl)
            }
            .frame(width: 180, height: 180)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(laufend != nil
                ? "\(FastenLogik.zeitText(vergangen)) von \(plan.stunden) Stunden gefastet"
                : "Kein Fasten läuft")
        }
    }

    private func startEndeZeile(anzeige: FastenEintrag?, plan: FastenPlan) -> some View {
        HStack(alignment: .top, spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                zeitFeld("Fasten Start", anzeige.map { FastenLogik.zeitpunktText($0.start) } ?? "–")
                zeitFeld("Fasten Ende", EssenFastenAnzeige.endeText(anzeige, plan: plan))
            }
            Spacer(minLength: Abstand.s)
            if let anzeige {
                Button("Bearbeiten") { bearbeiten = anzeige }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                    .accessibilityHint("Ändert Start und Ende des Fensters")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func zeitFeld(_ titel: String, _ wert: String) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(titel).font(.footnote).foregroundStyle(palette.text2)
            Text(wert).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
        }
        .accessibilityElement(children: .combine)
    }

    private func aktionsKnopf(_ essen: EssenStore, laufend: FastenEintrag?) -> some View {
        Button {
            if let laufend { essen.fastenFensterBeenden(laufend) } else { essen.fastenFensterStarten() }
            aktionZaehler += 1
        } label: {
            Text(laufend != nil ? "Fasten beenden" : "Fasten starten")
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.lumenHauptknopf)
        .accessibilityHint(laufend != nil ? "Beendet das laufende Fenster jetzt" : "Startet das \(essen.fastenPlan.name)-Fenster jetzt")
    }

    // MARK: - Statistik

    private func statistikKarte(_ essen: EssenStore, beendete: [FastenEintrag], aktuellerPlan: FastenPlan) -> some View {
        let letzte = EssenFastenAnzeige.letzte(beendete)
        return VStack(alignment: .leading, spacing: Abstand.l) {
            Text("Deine Statistik").font(.title2.weight(.heavy)).foregroundStyle(palette.text)
            if letzte.isEmpty {
                Text("Noch kein beendetes Fasten.").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                statistikChart(letzte, plan: aktuellerPlan)
                HStack(spacing: 0) {
                    EssenKennzahlSpalte(wert: "\(ErnaehrungLogik.zahl(FastenLogik.durchschnittStunden(beendete))) h", titel: "Schnitt", mittig: true)
                    EssenKennzahlSpalte(wert: "\(ErnaehrungLogik.zahl(FastenLogik.laengstesStunden(beendete))) h", titel: "Längstes", mittig: true)
                    EssenKennzahlSpalte(wert: "\(FastenLogik.serie(essen.fastenEintraege))", titel: "Serie", mittig: true)
                }
            }
        }
        .padding(Abstand.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
    }

    private func statistikChart(_ letzte: [FastenEintrag], plan: FastenPlan) -> some View {
        let wachstum = gezeichnet || bewegungAus ? 1.0 : 0.0
        let beschreibung = EssenReiheBeschreibung(
            titel: "Fastendauer der letzten Fenster",
            zusammenfassung: "Ziel \(plan.stunden) Stunden, \(letzte.filter(FastenLogik.geschafft).count) von \(letzte.count) geschafft",
            xTitel: "Start", yTitel: "Stunden", einheit: "h",
            kategorien: letzte.map { FastenLogik.zeitpunktText($0.start) },
            werte: letzte.map { FastenLogik.dauerStunden($0) },
            ziel: Double(plan.stunden))
        return Chart {
            ForEach(letzte) { e in
                BarMark(x: .value("Tag", e.start, unit: .day), y: .value("Stunden", (FastenLogik.dauerStunden(e) ?? 0) * wachstum))
                    .foregroundStyle(FastenLogik.geschafft(e) ? palette.akzent : palette.text2.opacity(0.6))
                    .cornerRadius(4)
            }
            RuleMark(y: .value("Ziel", plan.stunden))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(palette.text2)
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel().font(.caption).foregroundStyle(palette.text2) } }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel().font(.caption).foregroundStyle(palette.text2)
            }
        }
        .frame(height: 160)
        .accessibilityChartDescriptor(beschreibung)
    }

    // MARK: - Verlauf

    private func verlaufZeile(_ e: FastenEintrag) -> some View {
        let geschafft = FastenLogik.geschafft(e)
        return HStack(spacing: Abstand.m) {
            Image(systemName: geschafft ? "checkmark.circle.fill" : "xmark.circle")
                .font(.title3)
                .foregroundStyle(geschafft ? palette.akzent : palette.text2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Text(FastenLogik.planVon(e).name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text("\(FastenLogik.zeitpunktText(e.start)) – \(e.ende.map(FastenLogik.zeitpunktText) ?? "–")")
                    .font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            if let dauer = FastenLogik.dauerStunden(e) {
                Text("\(ErnaehrungLogik.zahl(dauer)) h").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
            }
        }
        .padding(.vertical, Abstand.xs)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(FastenLogik.planVon(e).name), \(FastenLogik.zeitpunktText(e.start)), \(EssenFastenAnzeige.zielText(e))")
    }

    // MARK: - Plan-Blatt

    private func planBlatt(_ essen: EssenStore, aktuell: FastenPlan) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Abstand.m) {
                    ForEach(FastenPlan.allCases) { p in planZeile(p, essen: essen, aktuell: aktuell) }
                }
                .padding(Abstand.l)
            }
            .fontDesign(.rounded)
            .navigationTitle("Plan wählen")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { planOffen = false } }
            }
        }
        .presentationDetents([.large])
    }

    private func planZeile(_ p: FastenPlan, essen: EssenStore, aktuell: FastenPlan) -> some View {
        let ausgewaehlt = p == aktuell
        return Button {
            essen.fastenPlanSetzen(p)
            planZaehler += 1
            planOffen = false
        } label: {
            HStack(alignment: .top, spacing: Abstand.m) {
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text(p.name).font(.headline.weight(.bold)).foregroundStyle(palette.text)
                    Text(p.beschreibung).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: Abstand.s)
                if ausgewaehlt {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.akzent).accessibilityHidden(true)
                }
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .lumenKartenFlaeche()
        .accessibilityAddTraits(ausgewaehlt ? [.isSelected] : [])
    }
}

// MARK: - Bearbeiten-Blatt

/// Start ändern (laufendes Fasten) oder Start und Ende (beendetes).
private struct EssenFastenBearbeitenBlatt: View {
    let eintrag: FastenEintrag
    let sichern: (FastenEintrag) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var ende: Date

    private var laeuftNoch: Bool { eintrag.ende == nil }

    init(eintrag: FastenEintrag, sichern: @escaping (FastenEintrag) -> Void) {
        self.eintrag = eintrag
        self.sichern = sichern
        _start = State(initialValue: eintrag.start)
        _ende = State(initialValue: eintrag.ende ?? eintrag.start)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $start)
                if !laeuftNoch {
                    DatePicker("Ende", selection: $ende, in: start...)
                }
            }
            .fontDesign(.rounded)
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle("Fasten bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        var neu = eintrag
                        neu.start = start
                        if !laeuftNoch { neu.ende = max(ende, start) }
                        sichern(neu)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
