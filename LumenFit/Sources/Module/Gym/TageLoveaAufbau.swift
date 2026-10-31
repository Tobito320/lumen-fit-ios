// Quelle: Lovea Health/GymSession.swift (GymVerlaufView :261, GymMonat :362, WorkoutRueckblick :406, GymVerlaufZeile :560) und WorkoutView.swift (WorkoutUebungView mit nachtrag :562)
import SwiftUI

/// Rein gerechnete Hilfen der Trainingstage im Lovea-Aufbau (`LumenAufbau.lovea`).
enum TageLoveaLogik {
    /// Lovea blättert immer zwölf Monate zurück (`MonatsPager`); Lumen reicht bis zur ältesten Einheit (höchstens 60). Beides bleibt: nie weniger als zwölf.
    static func monate(aeltesterTag: String?, heute: String) -> Int {
        max(12, EinheitZeitenLogik.monateAnzahl(aeltesterTag: aeltesterTag, heute: heute))
    }

    /// "Woche" oder "Wochen" hinter der Serien-Zahl (Lovea `serieText`).
    static func serieEinheit(_ wochen: Int) -> String { wochen == 1 ? "Woche" : "Wochen" }

    /// Rekord-Marke eines abgehakten Satzes gegen frühere Einheiten und die anderen Sätze heute ("Gewicht, 1RM"); nil ohne Rekord.
    static func rekordText(_ saetze: [PlanSatz], _ i: Int, frueher: [UebungTag]) -> String? {
        guard saetze.indices.contains(i), saetze[i].zaehlt, saetze[i].ok == true else { return nil }
        let davor = saetze.enumerated().filter { $0.offset != i && $0.element.zaehlt }.map(\.element)
        let arten = RekordLogik.beimSatz(saetze[i], davor: davor, gegen: frueher)
        return arten.isEmpty ? nil : arten.map(\.kurz).joined(separator: ", ")
    }
}

// MARK: - Trainingstage

/// Die Trainingstage wie Lovea (`GymVerlaufView`): Wechsel Ich / Partner, Kennzahlen, Monat zum Wischen, die Einheiten, Plus für "Training nachtragen".
/// Daten und Blätter sind dieselben wie im Lumen-Aufbau (`TrainingStore`, `EinheitNachtragenBlatt`). Der Partner erscheint nur, wenn er verbunden ist; von
/// ihm kennt Lumen die Zusammenfassung: mit den Freigaben verlauf und gym alle Trainingstage (Raster) und die letzten 30 Einheiten mit Sätzen zum Nachlesen
/// (`GymPartnerEinheitView`), sonst nur Dauer, Sätze und Übungen der letzten zehn. Ältere Apps des Partners schicken nur die zehn.
struct TageLoveaVerlauf: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var offen: String?
    @State private var nachtragenOffen = false
    /// Der Tag, für den das Blatt geöffnet wurde; nil beim Plus (freie Wahl).
    @State private var nachtragenDatum: String?
    @State private var tipp = 0
    /// Wessen Verlauf: false = Ich, true = der Partner (Lovea `person`).
    @State private var partnerWahl = false
    /// Die Einheit des Partners, die gerade zum Nachlesen offen ist.
    @State private var partnerOffen: PartnerEinheit?

    var body: some View {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let partner = GymPartnerLogik.partner(PartnerAnsichtLogik.aktuellerStand(umgebung))
        let sessions = umgebung.daten?.training.sessions ?? []
        let gym = umgebung.daten?.habits.werte(Habit.gym.id) ?? [:]
        // Häkchen ohne Einheit: ein Ring im Monat, Tipp trägt für diesen Tag nach.
        let nurAbgehakt = GymTageLogik.nurAbgehakt(sessions: sessions, gym: gym)
        List {
            if let partner {
                Picker("Wessen Verlauf", selection: $partnerWahl) {
                    Text("Ich").tag(false)
                    Text(partner.profilName).tag(true)
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
            }
            if partnerWahl, let partner {
                partnerInhalt(partner, heute: heute)
            } else {
                if !sessions.isEmpty || !nurAbgehakt.isEmpty {
                    kennzahlen(sessions, heute: heute)
                        .listRowSeparator(.hidden)
                    let trainingstage = Set(sessions.map { Datum.text($0.start) })
                    let aeltester = trainingstage.union(nurAbgehakt).min()
                    EinheitMonatsPager(anzahl: TageLoveaLogik.monate(aeltesterTag: aeltester, heute: heute)) { zurueck in
                        TageLoveaMonat(tage: trainingstage, heute: heute, monateZurueck: zurueck, nurAbgehakt: nurAbgehakt) { tag in
                            tipp += 1
                            tagTippen(tag, sessions)
                        }
                        .padding(.horizontal, 4)
                    }
                    .listRowSeparator(.hidden)
                }
                if sessions.isEmpty {
                    Text("Noch keine Einheit. Starte ein Training, dann steht es hier.")
                        .foregroundStyle(.secondary)
                    Button("Training starten") { umgebung.router.oeffne(.gym(.training)) }
                        .frame(minHeight: Abstand.tippflaeche)
                }
                ForEach(sessions) { s in
                    Button { offen = s.id } label: { zeile(s) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Verlauf")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    nachtragenDatum = nil
                    nachtragenOffen = true
                } label: {
                    Image(systemName: "plus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .accessibilityLabel("Training nachtragen")
            }
        }
        .navigationDestination(item: $offen) { EinheitNachlesenView(sessionId: $0) }
        .navigationDestination(item: $partnerOffen) { GymPartnerEinheitView(name: partner?.profilName ?? "", einheit: $0) }
        .sheet(isPresented: $nachtragenOffen) { EinheitNachtragenBlatt(datum: nachtragenDatum, jetzt: umgebung.uhr()) }
        .haptik(.auswahl, bei: tipp)
    }

    /// Der Verlauf des Partners (Lovea: dieselbe Seite mit seinen Einheiten): Kennzahlen, Monat, Liste, aus der Zusammenfassung.
    @ViewBuilder
    private func partnerInhalt(_ datei: ZusammenfassungDatei, heute: String) -> some View {
        let einheiten = GymPartnerLogik.einheiten(datei)
        if let v = datei.heute.verlauf, datei.freigaben.contains(.verlauf) {
            HStack(spacing: 28) {
                kennzahl("Diese Woche") { RollZahl(wert: Double(v.woche ?? 0), format: .number.precision(.fractionLength(0))) }
                kennzahl("Serie") {
                    HStack(spacing: 4) {
                        RollZahl(wert: Double(v.serieWochen ?? 0), format: .number.precision(.fractionLength(0)))
                        Text(TageLoveaLogik.serieEinheit(v.serieWochen ?? 0))
                    }
                }
                kennzahl("Gesamt") { RollZahl(wert: Double(v.gesamt ?? einheiten.count), format: .number.precision(.fractionLength(0))) }
            }
            .listRowSeparator(.hidden)
            let tage = GymPartnerLogik.trainingstage(datei)
            if let aeltester = tage.min() {
                EinheitMonatsPager(anzahl: TageLoveaLogik.monate(aeltesterTag: aeltester, heute: heute)) { zurueck in
                    TageLoveaMonat(tage: tage, heute: heute, monateZurueck: zurueck) { tag in
                        tipp += 1
                        partnerOffen = GymPartnerLogik.einheit(am: tag, in: datei)
                    }
                    .padding(.horizontal, 4)
                }
                .listRowSeparator(.hidden)
            }
            if einheiten.isEmpty { Text("\(datei.profilName) hat noch kein Training.").foregroundStyle(.secondary) }
            ForEach(einheiten, id: \.self) { t in
                let z = PartnerAnsichtLogik.trainingZeile(t)
                let detail = GymPartnerLogik.einheit(am: t.tag, in: datei)
                let zeile = VStack(alignment: .leading, spacing: 4) {
                    Text(z.titel).font(.headline)
                    Text(z.detail).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                .contentShape(.rect)
                if let detail {
                    Button { partnerOffen = detail } label: { zeile }
                        .buttonStyle(.plain)
                        .accessibilityHint("Öffnet die Einheit")
                } else {
                    zeile.accessibilityElement(children: .combine)
                }
            }
        } else {
            Text("\(datei.profilName) hat das nicht freigegeben.").foregroundStyle(.secondary)
        }
    }

    private func kennzahlen(_ sessions: [GymSession], heute: String) -> some View {
        let serie = TrainingLogik.serieWochen(sessions, heute: heute)
        return HStack(spacing: 28) {
            kennzahl("Diese Woche") {
                RollZahl(wert: Double(TrainingLogik.dieseWoche(sessions, heute: heute)), format: .number.precision(.fractionLength(0)))
            }
            kennzahl("Serie") {
                HStack(spacing: 4) {
                    RollZahl(wert: Double(serie), format: .number.precision(.fractionLength(0)))
                    Text(TageLoveaLogik.serieEinheit(serie))
                }
            }
            kennzahl("Gesamt") {
                RollZahl(wert: Double(sessions.count), format: .number.precision(.fractionLength(0)))
            }
        }
    }

    private func kennzahl<W: View>(_ titel: String, @ViewBuilder _ wert: () -> W) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption).foregroundStyle(.secondary)
            wert().font(.title3.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    /// Tipp auf einen Tag im Monat: die Einheit öffnen, sonst (nur Häkchen) das Nachtragen für genau diesen Tag.
    private func tagTippen(_ tag: String, _ sessions: [GymSession]) {
        if let s = GymTageLogik.einheit(am: tag, in: sessions) {
            offen = s.id
        } else {
            nachtragenDatum = tag
            nachtragenOffen = true
        }
    }

    private func zeile(_ s: GymSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Datum.anzeige(Datum.text(s.start))).font(.headline)
            Text(EinheitZeitenLogik.zeitText(s)).font(.subheadline).foregroundStyle(s.ende == nil ? Color.orange : Color.secondary)
            if let tag = umgebung.daten?.training.tag(id: s.tag) {
                Text(EinheitZeitenLogik.untertitel(s, tag: tag)).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Einheit")
    }
}

/// Ein Monat als Gitter wie Lovea (`GymMonat`): Trainingstage blau gefüllt, Tage mit Gym-Häkchen ohne Einheit nur ein blauer Ring.
struct TageLoveaMonat: View {
    let tage: Set<String>
    let heute: String
    let monateZurueck: Int
    var nurAbgehakt: Set<String> = []
    var tippen: ((String) -> Void)?

    private static let spalten = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let gitter = HealthLogik.monatsGitter(heute: heute, monateZurueck: monateZurueck)
        VStack(alignment: .leading, spacing: 8) {
            Text(EinheitZeitenLogik.monatTitel(gitter)).font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 0) {
                ForEach(HabitLogik.wochentagKuerzel, id: \.self) { k in
                    Text(k).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Self.spalten, spacing: 4) {
                ForEach(gitter.indices, id: \.self) { i in zelle(gitter[i]) }
            }
        }
    }

    @ViewBuilder
    private func zelle(_ tag: String?) -> some View {
        if let tag {
            let an = tage.contains(tag)
            let ring = !an && nurAbgehakt.contains(tag)
            let text = EinheitZeitenLogik.tagSprechtext(tag, training: an, nurHaken: ring)
            if let tippen, an || ring {
                Button { tippen(tag) } label: { nummer(tag, an: an, ring: ring) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(text)
                    .accessibilityHint(an ? "Öffnet die Einheit" : "Training für diesen Tag nachtragen")
            } else {
                nummer(tag, an: an, ring: ring).accessibilityLabel(text)
            }
        } else {
            Color.clear.frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func nummer(_ tag: String, an: Bool, ring: Bool) -> some View {
        Text(HabitRaster.tagesnummer(tag))
            .font(.footnote.weight(an ? .bold : .regular).monospacedDigit())
            .foregroundStyle(an ? Color.white : tag == heute ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            .background(an ? Color.blue : Color.clear, in: .circle)
            .overlay { if ring { Circle().strokeBorder(Color.blue, lineWidth: 2) } }
            .contentShape(.circle)
    }
}

// MARK: - Einheit nachlesen

/// Eine Einheit zum Nachlesen wie Lovea (`WorkoutRueckblick`): Liste mit Zeit, Volumen, Sätzen, Kalorien, Puls, dann je Übung ein Abschnitt mit
/// "Sätze bearbeiten" (Push) und "Übung hinzufügen". Oben rechts "Zeiten". Lumen-Zusatz: die Notiz zum Training als Zeile im ersten Abschnitt.
struct TageLoveaRueckblick: View {
    let sessionId: String
    @Environment(AppUmgebung.self) private var umgebung
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeit = false
    @State private var zeiten: GymSession?
    @State private var sucheOffen = false
    @State private var notizOffen = false
    @State private var notizText = ""
    @State private var hinzugefuegt = 0

    var body: some View {
        if let training = umgebung.daten?.training, let s = training.sessions.first(where: { $0.id == sessionId }) {
            inhalt(s, training: training)
        } else {
            ContentUnavailableView("Einheit nicht gefunden", systemImage: "dumbbell")
        }
    }

    private func inhalt(_ s: GymSession, training: TrainingStore) -> some View {
        let tag = training.tag(id: s.tag)
        let liste = WorkoutLogik.uebungen(s, tag: tag, frueher: training.sessions.filter { $0.start < s.start })
        // Die beendete Einheit lässt sich korrigieren und mit Sätzen nachtragen.
        let bearbeitbar = s.ende != nil
        let volumen = WorkoutLogik.volumen(liste).rounded()
        return List {
            Section {
                LabeledContent("Zeit", value: EinheitZeitenLogik.kopfZeit(s))
                LabeledContent("Volumen") {
                    HStack(spacing: 2) {
                        RollZahl(wert: volumen, format: .number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE")))
                        Text("kg")
                    }
                    .foregroundStyle(.secondary)
                }
                LabeledContent("Sätze") {
                    RollZahl(wert: Double(WorkoutLogik.saetzeZahl(liste)), format: .number.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                }
                if let kcal = s.kcal { LabeledContent("Aktive Kalorien", value: "\(kcal) kcal") }
                if let puls = s.puls { LabeledContent("Puls im Schnitt", value: "\(puls)") }
                Button {
                    notizText = s.notiz ?? ""
                    notizOffen = true
                } label: {
                    LabeledContent("Notiz", value: s.notiz ?? "Hinzufügen")
                }
                .buttonStyle(.plain)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityHint("Notiz zum Training ändern")
            } footer: {
                if let hinweis = GymTageLogik.leerHinweis(s, eigene: true, jetzt: umgebung.uhr()) { Text(hinweis) }
            }
            ForEach(liste) { u in
                Section(u.planUebung.anzeigeName) {
                    saetze(u)
                    if bearbeitbar, !u.planUebung.istCardio {
                        NavigationLink {
                            TageLoveaSaetzeView(sessionId: sessionId, planId: u.id)
                        } label: {
                            Label("Sätze bearbeiten", systemImage: "pencil")
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
            if bearbeitbar {
                Section {
                    Button("Übung hinzufügen", systemImage: "plus") { sucheOffen = true }
                        .frame(minHeight: Abstand.tippflaeche)
                }
            }
        }
        .sheet(isPresented: $sucheOffen) {
            UebungsSucheView(titel: "Übung hinzufügen", auswahl: { hinzufuegen($0, s, training: training) })
        }
        .navigationTitle(tag.map { $0.name.isEmpty ? "Training" : $0.name } ?? Datum.anzeige(Datum.text(s.start)))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Zeiten") { zeiten = s }
                    .frame(minHeight: Abstand.tippflaeche)
            }
        }
        .sheet(item: $zeiten) { EinheitZeitenBlatt(session: $0, jetzt: umgebung.uhr()) }
        .alert("Notiz zum Training", isPresented: $notizOffen) {
            TextField("Notiz", text: $notizText)
            Button("Speichern") { training.notizAendern(s, notizText) }
            Button("Abbrechen", role: .cancel) {}
        }
        .haptik(.erfolg, bei: hinzugefuegt)
    }

    /// Eine Übung nachtragen: Kraft mit ihren Plan-Sätzen (ohne Haken), Cardio gleich als gemacht.
    private func hinzufuegen(_ k: Uebung, _ s: GymSession, training: TrainingStore) {
        let p = GymEigeneLogik.planUebung(k)
        if p.istCardio { training.fertig(s.id, p, saetze: []) } else { training.saetzeSenden(s.id, p, p.saetze) }
        hinzugefuegt += 1
    }

    @ViewBuilder
    private func saetze(_ u: WorkoutUebung) -> some View {
        if u.planUebung.istCardio {
            Text(u.cardioFertig ? "\(u.planUebung.minuten ?? 20) min" : "nicht gemacht").foregroundStyle(u.cardioFertig ? Color.primary : Color.secondary)
        } else if u.fertigZahl == 0 {
            Text("nicht gemacht").foregroundStyle(.secondary)
        } else {
            ForEach(u.saetze.indices, id: \.self) { i in
                if u.saetze[i].ok == true { zeile(u, i) }
            }
        }
    }

    private func zeile(_ u: WorkoutUebung, _ i: Int) -> some View {
        let s = u.saetze[i]
        let zeiten = WorkoutLogik.zeitenText(sek: s.sek, pause: s.pause, satzzeit: satzzeit)
        return HStack(spacing: 12) {
            Text(WorkoutLogik.nummer(u.saetze, i))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(s.kuerzel == nil ? Color.secondary : Color.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(WorkoutLogik.satzText(s)).monospacedDigit()
                if let zeiten { Text(zeiten).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            if let rpe = s.rpe { Text("RPE \(TrainingLogik.kgText(rpe))").font(.subheadline).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sätze bearbeiten

/// "Sätze bearbeiten" wie Lovea (`WorkoutUebungView(nachtrag: true)`): eine Übung einer beendeten Einheit, Tabelle Satz, Vorher, kg, Wdh, RPE, Haken,
/// ohne Uhr und ohne untere Leiste. Haken, Löschen und Kopieren senden gleich, getippte Werte beim Verlassen. Aus dem Lumen-Blatt
/// (`EinheitSaetzeBlatt`) bleiben alle Handlungen: Satztyp, Satz dazu, löschen (mindestens ein Satz bleibt), Haken, Gewicht und Wiederholungen.
struct TageLoveaSaetzeView: View {
    let sessionId: String
    let planId: String

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var schliessen
    @State private var saetze: [PlanSatz] = []
    @State private var notiz = ""
    @State private var geladen = false
    @State private var detail: String?
    @State private var anstrengungSatz: Int?
    @State private var rueckgaengig: SatzRueckgaengig?
    @State private var geaendert = 0
    @AppStorage(GymAnzeige.rpeSpalteSchluessel) private var rpeAn = true
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeitAn = false
    @FocusState private var fokus: Bool

    private var training: TrainingStore? { umgebung.daten?.training }

    /// Die Übung in dieser Einheit, wie der Speicher sie gerade hält.
    private func uebung() -> WorkoutUebung? {
        guard let t = training, let s = t.sessions.first(where: { $0.id == sessionId }) else { return nil }
        let liste = WorkoutLogik.uebungen(s, tag: t.tag(id: s.tag), frueher: t.sessions.filter { $0.start < s.start })
        return liste.first { $0.id == planId }
    }

    var body: some View {
        if let u = uebung() {
            seite(u)
        } else {
            ContentUnavailableView("Übung nicht gefunden", systemImage: "dumbbell")
        }
    }

    private func seite(_ u: WorkoutUebung) -> some View {
        let frueher = fruehereTage(u)
        return List {
            Section {
                kopf(u)
                if !u.extra {
                    TextField("Notizen hier hinzufügen", text: $notiz, axis: .vertical).font(.subheadline).focused($fokus)
                    pausenMenue(u)
                    Toggle("Satz-Zeit", isOn: $satzzeitAn).font(.subheadline.weight(.medium))
                }
            }
            .listRowSeparator(.hidden)
            Section {
                tabellenKopf.listRowSeparator(.hidden)
                ForEach(saetze.indices, id: \.self) { i in zeile(u, i, frueher) }
                Button { satzDazu() } label: {
                    Label("Satz hinzufügen", systemImage: "plus").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(u.planUebung.anzeigeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menue(u) }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { fokus = false }
            }
        }
        .overlay(alignment: .bottom) { toast(u) }
        .animation(.snappy, value: rueckgaengig)
        .sheet(isPresented: Binding(get: { anstrengungSatz != nil }, set: { if !$0 { anstrengungSatz = nil } })) {
            AnstrengungBlatt(aktuell: anstrengungSatz.flatMap { saetze.indices.contains($0) ? saetze[$0].rpe : nil }) { stufe in
                if let i = anstrengungSatz, saetze.indices.contains(i) {
                    saetze[i].rpe = stufe?.rpe
                    senden(u)
                }
            }
        }
        .sheet(isPresented: Binding(get: { detail != nil }, set: { if !$0 { detail = nil } })) {
            NavigationStack { UebungDetailView(id: detail ?? u.planUebung.uebung) }.presentationDetents([.medium, .large])
        }
        .haptik(.auswahl, bei: geaendert)
        .onAppear { laden(u) }
        .onDisappear { sichern() }
        .onChange(of: phase) { _, neu in if neu == .background { sichern() } }
    }

    private func kopf(_ u: WorkoutUebung) -> some View {
        Button { detail = u.planUebung.uebung } label: {
            HStack(spacing: 12) {
                UebungsBild(id: u.planUebung.uebung, koerper: (umgebung.trainingSteuerung as? GymSitzung).flatMap { $0.katalog(u.planUebung) }?.koerper)   // nur lesen: `von` setzt beim Zeichnen den Port
                    .frame(width: 56, height: 56)
                    .clipShape(.circle)
                Text(u.planUebung.anzeigeName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.blue)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Zeigt die Übung")
    }

    private func pausenMenue(_ u: WorkoutUebung) -> some View {
        let aktuell = u.planUebung.pause ?? WorkoutLogik.standardPause
        return Menu {
            Picker("Pause", selection: Binding(get: { aktuell }, set: { pauseSetzen($0) })) {
                ForEach(WorkoutLogik.pausen, id: \.self) { sek in Text(WorkoutLogik.pauseText(sek)).tag(sek) }
            }
        } label: {
            Label("Pausentimer: \(WorkoutLogik.pauseText(aktuell))", systemImage: "timer")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.blue)
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    private var tabellenKopf: some View {
        HStack(spacing: 6) {
            Text("SATZ").frame(width: 44)
            Text("VORHER").frame(maxWidth: .infinity, alignment: .leading)
            Text("KG").frame(width: 62)
            Text("WDH").frame(width: 50)
            if rpeAn { Text("RPE").frame(width: 44) }
            Image(systemName: "checkmark").frame(width: 44)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 12))
        .accessibilityHidden(true)
    }

    private func zeile(_ u: WorkoutUebung, _ i: Int, _ frueher: [UebungTag]) -> some View {
        let satz = saetze.indices.contains(i) ? saetze[i] : PlanSatz(wdh: 0, kg: nil, failure: false)
        return LoveaSatzZeile(
            nummer: WorkoutLogik.nummer(saetze, i),
            satz: satz,
            vorher: LetztesMal.text(zeile: i, in: saetze, vorher: u.vorher),
            rpe: rpeAn,
            satzzeit: satzzeitAn,
            laeuft: false,
            rekord: TageLoveaLogik.rekordText(saetze, i, frueher: frueher),
            typ: { t in
                if saetze.indices.contains(i) { saetze[i].setzeTyp(t) }
                geaendert += 1
            },
            haken: { haken(u, i) },
            kopieren: { kopieren(u, i) },
            loeschen: { loeschen(u, i) },
            anstrengung: { anstrengungSatz = i },
            vorherUebernehmen: { saetze = LetztesMal.uebernehmen(zeile: i, in: saetze, vorher: u.vorher) },
            werte: { kg, wdh in
                if saetze.indices.contains(i) {
                    saetze[i].kg = kg
                    saetze[i].wdh = wdh
                }
            }
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(satz.ok == true ? Color.green.opacity(0.2) : Color.clear)
        .swipeActions(edge: .leading) {
            Button("Kopieren", systemImage: "plus.square.on.square") { kopieren(u, i) }.tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Löschen", role: .destructive) { loeschen(u, i) }
        }
    }

    private func menue(_ u: WorkoutUebung) -> some View {
        Menu {
            Button("Übung ansehen", systemImage: "play.rectangle") { detail = u.planUebung.uebung }
            Button("Aufwärmsätze einfügen", systemImage: "flame") {
                if let kg = arbeitsgewicht { saetze = AufwaermRechner.einfuegen(in: saetze, arbeit: kg) }
            }
            .disabled(arbeitsgewicht == nil)
            Toggle("RPE-Spalte", isOn: $rpeAn)
            if u.extra {
                Button("Übung entfernen", systemImage: "trash", role: .destructive) { entfernen(u) }
            }
        } label: {
            Image(systemName: "ellipsis.circle").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .accessibilityLabel("Mehr")
    }

    /// "Satz 2 gelöscht" mit "Rückgängig": fünf Sekunden, dann gleitet der Hinweis weg.
    @ViewBuilder
    private func toast(_ u: WorkoutUebung) -> some View {
        if let r = rueckgaengig {
            HStack {
                Text(r.text).font(.subheadline)
                Spacer(minLength: 8)
                Button("Rückgängig") {
                    saetze = r.vorher
                    rueckgaengig = nil
                    senden(u)
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: Abstand.tippflaeche)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: r.id) {
                try? await Task.sleep(for: .seconds(SatzRueckgaengigLogik.sekunden))
                if !Task.isCancelled { rueckgaengig = nil }
            }
        }
    }

    // MARK: Handlungen

    /// Das erste Gewicht, das kein Aufwärmsatz ist.
    private var arbeitsgewicht: Double? {
        saetze.first { $0.typ != "w" && $0.kg != nil }?.kg
    }

    /// Diese Übung in allen Einheiten vor dieser (für die Rekord-Marke).
    private func fruehereTage(_ u: WorkoutUebung) -> [UebungTag] {
        guard let t = training, let s = t.sessions.first(where: { $0.id == sessionId }) else { return [] }
        return RekordLogik.tage(katalogId: u.planUebung.uebung, planId: planId, in: t.sessions.filter { $0.start < s.start })
    }

    private func laden(_ u: WorkoutUebung) {
        guard !geladen else { return }
        saetze = u.saetze
        notiz = u.planUebung.notiz ?? ""
        geladen = true
    }

    private func senden(_ u: WorkoutUebung) {
        training?.saetzeSenden(sessionId, u.planUebung, saetze)
    }

    /// Beim Verlassen: getippte Werte senden und die Notiz in den Plan schreiben, falls geändert.
    private func sichern() {
        guard geladen, let u = uebung(), let t = training else { return }
        if saetze != u.saetze { t.saetzeSenden(sessionId, u.planUebung, saetze) }
        let neu = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        if !u.extra, neu != (u.planUebung.notiz ?? "") {
            t.planSichern(TrainingLogik.aendern(t.plan, planUebung: planId) { $0.notiz = neu.isEmpty ? nil : neu })
        }
    }

    private func pauseSetzen(_ sek: Int) {
        guard let t = training else { return }
        t.planSichern(TrainingLogik.aendern(t.plan, planUebung: planId) { $0.pause = sek })
    }

    private func haken(_ u: WorkoutUebung, _ i: Int) {
        saetze = WorkoutLogik.hakenNachtrag(saetze, i)
        senden(u)
        geaendert += 1
    }

    private func satzDazu() {
        saetze.append((saetze.last(where: { $0.typ != "w" }) ?? PlanSatz(wdh: 10, kg: nil, failure: false)).alsPlan)
        geaendert += 1
    }

    private func loeschen(_ u: WorkoutUebung, _ i: Int) {
        guard saetze.indices.contains(i), saetze.count > 1 else { return }
        rueckgaengig = SatzRueckgaengig(text: SatzRueckgaengigLogik.text(.geloescht, nummer: WorkoutLogik.nummer(saetze, i)), plan: planId, vorher: saetze)
        saetze.remove(at: i)
        senden(u)
        geaendert += 1
    }

    private func kopieren(_ u: WorkoutUebung, _ i: Int) {
        guard saetze.indices.contains(i) else { return }
        rueckgaengig = SatzRueckgaengig(text: SatzRueckgaengigLogik.text(.kopiert, nummer: WorkoutLogik.nummer(saetze, i)), plan: planId, vorher: saetze)
        saetze = WorkoutLogik.kopieren(saetze, i)
        senden(u)
        geaendert += 1
    }

    private func entfernen(_ u: WorkoutUebung) {
        geladen = false // nichts mehr nachsenden
        training?.entfernen(sessionId, u.planUebung)
        schliessen()
    }
}
