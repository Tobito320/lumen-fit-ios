// Quelle: Lovea Health/WorkoutView.swift (WorkoutLeiste :31, GymSessionView :129, WorkoutInhalt :347, WorkoutUebungView :562, WorkoutSatzZeile :973)
import SwiftUI
import UIKit

/// Das laufende Training im Lovea-Aufbau (`LumenAufbau.lovea`): erst die Übersicht aller Übungen mit ihrem Stand, ein Tipp öffnet eine einzelne
/// mit Tabelle (Satz, Vorher, kg, Wdh, RPE, Haken), unten die Leiste für den nächsten Schritt. Alle Daten und Handlungen kommen aus
/// `GymSitzung` (dieselbe wie im Lumen-Aufbau): Live Activity, Widgets, Kurzbefehle und Pause laufen unverändert, ein Theme-Wechsel
/// tauscht nur die Darstellung und bricht nichts ab. Die Farben sind die von Lovea (`Color.blue`, `.green`, `.red`, Systemfüllung).
enum LoveaTraining {
    static var feld: Color { Color(uiColor: .tertiarySystemFill) }
    static let kachel = RoundedRectangle(cornerRadius: 9, style: .continuous)

    /// Cardio-Kurzknöpfe unter "Übung hinzufügen" (Lovea `WorkoutView.swift:539`, `cardioSchnell`): dieselben Katalog-ids wie in Lovea
    /// (Laufband `rjiM4L3`, Stairmaster `j9Q5crt`), damit Verlauf und Rekorde zu den Lovea-Daten passen; sonst die erste Übung des Geräts.
    static func cardio(_ geraet: String) -> Uebung? {
        let id = geraet == "stairmaster" ? "j9Q5crt" : "rjiM4L3"
        return UebungsKatalog.nachId[id] ?? UebungsKatalog.alle.first { TrainingLogik.cardioGeraet($0) == geraet }
    }

    /// Lovea `WorkoutView.swift:387`: Farbe der Anstrengung.
    static func farbe(_ a: Anstrengung) -> Color {
        switch a {
        case .versagen: .purple
        case .fastVersagen: .red
        case .eineNoch: .orange
        case .zweiNoch: .yellow
        case .dreiNoch: .green
        case .leicht: .gray
        }
    }
}

/// Rundes Bild der Übung (Lovea `UebungBild`, `WorkoutView.swift:9`).
struct LoveaUebungBild: View {
    let sitzung: GymSitzung
    let uebung: PlanUebung
    var groesse: CGFloat = 48

    var body: some View {
        UebungsBild(id: uebung.uebung, koerper: sitzung.katalog(uebung)?.koerper)
            .frame(width: groesse, height: groesse)
            .clipShape(.circle)
    }
}

/// Die Leiste unten (Lovea `WorkoutLeiste`): was dran ist, die Satz- oder Pausenzeit, ein Knopf; bei laufender Pause ±15 s und Überspringen.
struct LoveaTrainingLeiste: View {
    let sitzung: GymSitzung
    let titel: String
    let unter: String
    let knopf: String
    let aktion: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeit = false
    @State private var mehr = 0
    @State private var weniger = 0

    var body: some View {
        let _ = sitzung.pauseEndeZaehler // nach dem Pausenende springt die Zeit auf rotes Hochzählen
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(unter).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 4)
                zeit
                Button(action: aktion) {
                    Text(knopf).font(.subheadline.weight(.semibold)).lineLimit(1).fixedSize().frame(minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            if let pause = sitzung.pause, pause.ende != nil {
                HStack(spacing: 8) {
                    Button { weniger += 1; sitzung.pauseAendern(sekunden: -PauseLogik.schritt) } label: {
                        Text("−15 s").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .accessibilityLabel("15 Sekunden weniger")
                    Button { mehr += 1; sitzung.pauseAendern(sekunden: PauseLogik.schritt) } label: {
                        Text("+15 s").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .accessibilityLabel("15 Sekunden mehr")
                    Button { sitzung.pauseUeberspringen() } label: {
                        Text("Überspringen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                }
                .buttonStyle(.bordered)
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .haptik(.mehr, bei: mehr)
        .haptik(.weniger, bei: weniger)
    }

    /// Pause mit Ziel zählt rückwärts, danach rot hoch; ohne Ziel zählt sie hoch. Ohne Pause zählt die Satzzeit, wenn der Schalter an ist.
    @ViewBuilder
    private var zeit: some View {
        Group {
            if let pause = sitzung.pause {
                if let ende = pause.ende {
                    if let bereich = PauseLogik.zeitraum(pause, jetzt: umgebung.uhr()) {
                        Text(timerInterval: bereich, countsDown: true, showsHours: false)
                    } else {
                        Text(ende, style: .timer).foregroundStyle(Color.red)
                    }
                } else {
                    Text(pause.seit, style: .timer)
                }
            } else if satzzeit, let seit = sitzung.satzSeit {
                Text(seit, style: .timer)
            }
        }
        .font(.title2.bold().monospacedDigit())
        .multilineTextAlignment(.trailing)
        .fixedSize()
    }
}

// MARK: - Übersicht

/// Das laufende Training als Übersicht (Lovea `GymSessionView` und `WorkoutInhalt`): Titel, Werte, Übungszeilen, "Hinzufügen", die Leiste.
struct TrainingLoveaView: View {
    @Bindable var sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @State private var offen: String?
    @State private var beenden = false
    @State private var suche = false
    @State private var startzeit: GymSession?
    @State private var verwerfenFrage = false
    @State private var einstellungen = false
    @State private var cardioOffen = false
    @State private var cardioIndex = 0

    var body: some View {
        let _ = sitzung.pauseEndeZaehler
        ScrollView { inhalt }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !sitzung.liste.isEmpty { leiste }
            }
            .navigationDestination(item: $offen) { id in
                TrainingLoveaUebungView(sitzung: sitzung, planId: id, wechseln: { offen = $0 }).id(id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let s = sitzung.laufende {
                            Button("Startzeit ändern", systemImage: "clock") { startzeit = s }
                        }
                        Button("Einstellungen fürs Training", systemImage: "gearshape") { einstellungen = true }
                        Button("Training verwerfen", systemImage: "trash", role: .destructive) { verwerfenFrage = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Mehr")
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Auch mit offenen Übungen: was fertig ist, zählt, der Rest bleibt im Plan.
                    Button("Beenden") { beenden = true }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $beenden) { TrainingBeendenView(sitzung: sitzung) }
            .sheet(isPresented: $suche) {
                UebungsSucheView(titel: "Übung hinzufügen", auswahl: { sitzung.uebungDazu($0) }, mehrfach: true)
            }
            .sheet(isPresented: $einstellungen) { GymEinstellungenBlatt(sitzung: sitzung) }
            .sheet(isPresented: $cardioOffen) { CardioAbschlussBlatt(sitzung: sitzung, index: cardioIndex) }
            .sheet(item: $startzeit) { EinheitStartzeitBlatt(session: $0) }
            .confirmationDialog("Training verwerfen?", isPresented: $verwerfenFrage, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) { sitzung.verwerfen() }
            } message: {
                Text("Die Einheit und alle Sätze darin werden gelöscht.")
            }
            .lumenToast($sitzung.toast)
            .haptik(.satzFertig, bei: sitzung.hakenZaehler)
            .haptik(.pauseEnde, bei: sitzung.pauseEndeZaehler)
            .haptik(.auswahl, bei: sitzung.hakenZurueckZaehler)
            .alert("Hinweis zum Studio", isPresented: Binding(get: { sitzung.studioHinweis != nil }, set: { if !$0 { sitzung.hinweisGelesen() } })) {
                Button("OK") { sitzung.hinweisGelesen() }
            } message: {
                Text(sitzung.studioHinweis ?? "")
            }
            .task { sitzung.ladeWennNoetig() }
    }

    private var tage: [TrainingsTag] { sitzung.training?.plan.tage ?? [] }

    private var inhalt: some View {
        let dran = sitzung.dran?.uebung
        return VStack(alignment: .leading, spacing: 16) {
            werte
            if sitzung.liste.isEmpty {
                leer
            } else {
                VStack(spacing: 2) {
                    ForEach(sitzung.liste.indices, id: \.self) { i in zeile(i, dran: i == dran) }
                }
                Text("Halte eine Übung gedrückt, um sie auszulassen.").font(.footnote).foregroundStyle(.secondary)
            }
            schluss
        }
        .padding(16)
    }

    // MARK: Werte

    private var werte: some View {
        VStack(alignment: .leading, spacing: 12) {
            titel
            TimelineView(.periodic(from: .now, by: 10)) { _ in
                HStack(alignment: .top, spacing: 22) {
                    wert("Dauer") { dauer.foregroundStyle(Color.blue) }
                    wert("Volumen") { Text("\(TrainingLogik.kgText(sitzung.volumen.rounded())) kg") }
                    wert("Sätze") { Text("\(sitzung.saetzeZahl)") }
                    if let puls = sitzung.puls.puls { wert("Puls") { Text("\(puls)").foregroundStyle(Color.red) } }
                    if let kcal = sitzung.puls.kcal { wert("kcal") { Text("\(kcal)") } }
                }
            }
            Divider()
        }
    }

    /// Der Name des Tages. Solange nichts abgehakt ist, öffnet ein Tipp die anderen Tage (Lovea `WorkoutView.swift:394`).
    @ViewBuilder
    private var titel: some View {
        let name = sitzung.tag.map { $0.name.isEmpty ? "Training" : $0.name } ?? "Training"
        if sitzung.tag != nil, tage.count > 1, WorkoutLogik.tagWechselbar(sitzung.liste) {
            Menu {
                ForEach(tage) { t in
                    Button { sitzung.tagWechseln(zu: t) } label: {
                        if t.id == sitzung.tag?.id {
                            Label(t.name.isEmpty ? "Ohne Namen" : t.name, systemImage: "checkmark")
                        } else {
                            Text(t.name.isEmpty ? "Ohne Namen" : t.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(name).font(.largeTitle.bold())
                    Image(systemName: "chevron.down.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
            }
            .accessibilityHint("Anderen Trainingstag wählen")
        } else {
            Text(name).font(.largeTitle.bold())
        }
    }

    /// Die Dauer; ein Tipp ändert die Startzeit (Lumen-Funktion, bleibt).
    private var dauer: some View {
        Button {
            startzeit = sitzung.laufende
        } label: {
            if let s = sitzung.laufende { Text(s.start, style: .timer) } else { Text("–") }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dauer des Trainings")
        .accessibilityHint("Ändert die Startzeit")
    }

    private func wert(_ titel: String, @ViewBuilder _ inhalt: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption).foregroundStyle(.secondary)
            inhalt().font(.title3.weight(.semibold).monospacedDigit())
        }
    }

    // MARK: Zeilen

    private func zeile(_ i: Int, dran: Bool) -> some View {
        let u = sitzung.liste[i]
        return Button { oeffnen(i) } label: {
            HStack(spacing: 12) {
                LoveaUebungBild(sitzung: sitzung, uebung: u.planUebung)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.planUebung.anzeigeName)
                        .font(.headline)
                        .foregroundStyle(dran ? Color.blue : Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(untertitel(u, dran: dran)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    if u.fertig { Image(systemName: "checkmark") }
                    Text(u.ausgelassen ? "–" : "\(u.fertigZahl)/\(u.gesamt)")
                }
                .font(.headline.monospacedDigit())
                .foregroundStyle(u.fertig ? Color.green : Color.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 68)
            .background(dran ? LoveaTraining.feld : Color.clear, in: .rect(cornerRadius: 14, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(u.fertig ? "fertig" : u.ausgelassen ? "ausgelassen" : dran ? "jetzt dran" : "")
        .contextMenu { kontext(i, u) }
    }

    private func untertitel(_ u: WorkoutUebung, dran: Bool) -> String {
        if u.ausgelassen { return "Ausgelassen" }
        if dran { return "Jetzt dran" }
        if let minuten = u.planUebung.minuten { return "\(minuten) min" }
        return sitzung.katalog(u.planUebung).map { "\($0.muskel) · \($0.geraet)" } ?? "Eigene Übung"
    }

    /// Cardio hat keine Sätze: ein Tipp öffnet die Eingabe, ein zweiter nimmt es zurück (Lovea `cardioTipp`); sonst öffnet die Übung.
    private func oeffnen(_ i: Int) {
        let u = sitzung.liste[i]
        if u.planUebung.istCardio {
            if u.cardioFertig { sitzung.cardioZurueck(i) } else { cardioIndex = i; cardioOffen = true }
        } else {
            offen = u.id
        }
    }

    /// Lang drücken: Übung auslassen (Gerät besetzt) oder wieder aufnehmen. Nur Plan-Übungen ohne abgehakten Satz.
    @ViewBuilder
    private func kontext(_ i: Int, _ u: WorkoutUebung) -> some View {
        if !u.extra {
            if u.ausgelassen {
                Button("Wieder aufnehmen", systemImage: "arrow.uturn.backward") { sitzung.wiederAufnehmen(i) }
            } else if u.fertigZahl == 0 {
                Button("Auslassen", systemImage: "forward.end") { sitzung.auslassen(i) }
            }
        }
    }

    // MARK: Leer und Schluss

    @ViewBuilder
    private var leer: some View {
        if sitzung.tag == nil, !tage.isEmpty {
            Text("Welcher Trainingstag?").font(.headline)
            gruppe(tage.map { (t: TrainingsTag) -> ListenZeile in
                (id: t.id, titel: t.name.isEmpty ? "Ohne Namen" : t.name, bild: "dumbbell", aktion: { sitzung.tagWechseln(zu: t) })
            })
        } else {
            Text("Noch keine Übung. Füg unten eine hinzu.").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    typealias ListenZeile = (id: String, titel: String, bild: String, aktion: () -> Void)

    /// Ruhige Inset-Gruppe: Zeilen mit Symbol und Chevron, getrennt durch Linien (Lovea `WorkoutView.swift:496`).
    private func gruppe(_ zeilen: [ListenZeile]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(zeilen.enumerated()), id: \.element.id) { i, z in
                if i > 0 { Divider().padding(.leading, 52) }
                Button(action: z.aktion) {
                    HStack(spacing: 12) {
                        Image(systemName: z.bild).frame(width: 28).foregroundStyle(Color.accentColor)
                        Text(z.titel).font(.body).foregroundStyle(Color.primary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .background(LoveaTraining.feld, in: .rect(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var schluss: some View {
        let leerStart = sitzung.tag == nil && sitzung.liste.isEmpty
        Text(leerStart ? "Oder frei trainieren" : "Hinzufügen").font(.footnote).foregroundStyle(.secondary)
        let neu: ListenZeile = (id: "neu", titel: leerStart ? "Leeres Training" : "Übung hinzufügen", bild: "plus", aktion: { suche = true })
        let laufband: ListenZeile = (id: "laufband", titel: "Laufband", bild: "figure.run", aktion: { cardioDazu("laufband") })
        let stairmaster: ListenZeile = (id: "stairmaster", titel: "Stairmaster", bild: "figure.stair.stepper", aktion: { cardioDazu("stairmaster") })
        gruppe([neu, laufband, stairmaster])
    }

    private func cardioDazu(_ geraet: String) {
        if let u = LoveaTraining.cardio(geraet) { sitzung.uebungDazu(u) }
    }

    // MARK: Leiste

    @ViewBuilder
    private var leiste: some View {
        if let dran = sitzung.dran, sitzung.liste.indices.contains(dran.uebung) {
            let u = sitzung.liste[dran.uebung]
            if u.planUebung.istCardio {
                LoveaTrainingLeiste(sitzung: sitzung, titel: u.planUebung.anzeigeName, unter: "\(u.planUebung.minuten ?? 20) min", knopf: "Fertig") {
                    cardioIndex = dran.uebung
                    cardioOffen = true
                }
            } else {
                let unter = "Satz \(dran.satz + 1) von \(u.saetze.count) · \(WorkoutLogik.satzText(u.saetze[dran.satz]))"
                LoveaTrainingLeiste(sitzung: sitzung, titel: u.planUebung.anzeigeName, unter: unter, knopf: "Öffnen") { offen = u.id }
            }
        } else {
            LoveaTrainingLeiste(sitzung: sitzung, titel: "Alle Sätze fertig", unter: "Beenden schließt das Training ab", knopf: "Beenden") { beenden = true }
        }
    }
}

// MARK: - Eine Übung

/// Nur diese eine Übung (Lovea `WorkoutUebungView`): Notiz, Pausenzeit, Defekt, Einstellung, Tabelle der Sätze, Leiste. Die Zeilen leben in
/// `GymSitzung`; gesendet wird beim Haken, bei Satz dazu oder löschen und beim Verlassen der Seite.
struct TrainingLoveaUebungView: View {
    @Bindable var sitzung: GymSitzung
    let planId: String
    /// Zur nächsten Übung wechseln, nil = zurück zur Übersicht.
    var wechseln: (String?) -> Void = { _ in }

    @State private var notiz = ""
    @State private var geladen = false
    @State private var detail: String?
    @State private var rechnerOffen = false
    @State private var tauschOffen = false
    @State private var anstrengungSatz: Int?
    @AppStorage(GymAnzeige.rpeSpalteSchluessel) private var rpeAn = true
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeitAn = false
    @FocusState private var fokus: Bool
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        if let i = sitzung.liste.firstIndex(where: { $0.id == planId }) {
            seite(i, sitzung.liste[i])
        } else {
            ContentUnavailableView("Übung nicht gefunden", systemImage: "dumbbell")
        }
    }

    private func seite(_ i: Int, _ u: WorkoutUebung) -> some View {
        List {
            Section {
                kopf(u)
                if !u.extra {
                    TextField("Notizen hier hinzufügen", text: $notiz, axis: .vertical).font(.subheadline)
                    pausenMenue(i, u)
                    Toggle("Satz-Zeit", isOn: $satzzeitAn).font(.subheadline.weight(.medium))
                }
            }
            .listRowSeparator(.hidden)
            if !u.ausgelassen {
                Section {
                    DefektAbschnitt(sitzung: sitzung, index: i)
                    GeraeteAbschnitt(sitzung: sitzung, index: i)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            Section {
                if u.ausgelassen {
                    GymZeile(titel: "Ausgelassen", untertitel: "Zählt nicht für Volumen und Rekorde") {
                        Button("Wieder dazu") { sitzung.wiederAufnehmen(i) }.buttonStyle(.bordered).controlSize(.large)
                    }
                    .listRowSeparator(.hidden)
                } else {
                    tabellenKopf.listRowSeparator(.hidden)
                    ForEach(u.saetze.indices, id: \.self) { s in zeile(i, u, s) }
                    Button { sitzung.satzDazu(i) } label: {
                        Label("Satz hinzufügen", systemImage: "plus").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .focused($fokus)
        .lumenToast($sitzung.toast)
        .navigationTitle(u.planUebung.anzeigeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menue(i, u) }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { fokus = false }
            }
        }
        .overlay(alignment: .bottom) { toast }
        .animation(.snappy, value: sitzung.rueckgaengig)
        .safeAreaInset(edge: .bottom, spacing: 0) { leiste(i, u) }
        .sheet(isPresented: Binding(get: { anstrengungSatz != nil }, set: { if !$0 { anstrengungSatz = nil } })) {
            AnstrengungBlatt(aktuell: anstrengungSatz.flatMap { u.saetze.indices.contains($0) ? u.saetze[$0].rpe : nil }) { stufe in
                if let s = anstrengungSatz { sitzung.rpe(i, s, stufe) }
            }
        }
        .sheet(isPresented: Binding(get: { detail != nil }, set: { if !$0 { detail = nil } })) {
            NavigationStack { UebungDetailView(id: detail ?? u.planUebung.uebung) }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $rechnerOffen) { RechnerBlatt(sitzung: sitzung, index: i) }
        .sheet(isPresented: $tauschOffen) { AusweichBlatt(sitzung: sitzung, index: i) }
        .haptik(.satzFertig, bei: sitzung.hakenZaehler)
        .haptik(.auswahl, bei: sitzung.hakenZurueckZaehler)
        .onAppear { laden(u) }
        .onDisappear { sichern() }
        .onChange(of: phase) { _, neu in if neu == .background { sichern() } }
    }

    private func kopf(_ u: WorkoutUebung) -> some View {
        Button { detail = u.planUebung.uebung } label: {
            HStack(spacing: 12) {
                LoveaUebungBild(sitzung: sitzung, uebung: u.planUebung, groesse: 56)
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

    private func pausenMenue(_ i: Int, _ u: WorkoutUebung) -> some View {
        let aktuell = u.planUebung.pause ?? WorkoutLogik.standardPause
        return Menu {
            Picker("Pause", selection: Binding(get: { aktuell }, set: { sitzung.pauseZiel(i, $0) })) {
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

    private func zeile(_ i: Int, _ u: WorkoutUebung, _ s: Int) -> some View {
        let satz = u.saetze[s]
        let istDran = sitzung.dran.map { $0.uebung == i && $0.satz == s } ?? false
        return LoveaSatzZeile(
            nummer: WorkoutLogik.nummer(u.saetze, s),
            satz: satz,
            vorher: LetztesMal.text(zeile: s, in: u.saetze, vorher: u.vorher),
            rpe: rpeAn,
            satzzeit: satzzeitAn,
            laeuft: istDran,
            rekord: satz.ok == true ? sitzung.rekordLabel["\(u.id)|\(s)"] : nil,
            typ: { sitzung.typ(i, s, $0) },
            haken: { sitzung.haken(i, s) },
            kopieren: { sitzung.satzKopieren(i, s) },
            loeschen: { sitzung.satzLoeschen(i, s) },
            anstrengung: { anstrengungSatz = s },
            vorherUebernehmen: { sitzung.letztesMalUebernehmen(i, s) },
            werte: { kg, wdh in sitzung.werteSetzen(i, s, kg: kg, wdh: wdh) }
        )
        .listRowInsets(EdgeInsets(top: 3, leading: 12, bottom: 3, trailing: 12))
        .listRowSeparator(.hidden)
        .listRowBackground(satz.ok == true ? Color.green.opacity(0.2) : Color.clear)
        .swipeActions(edge: .leading) {
            Button("Kopieren", systemImage: "plus.square.on.square") { sitzung.satzKopieren(i, s) }.tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Löschen", role: .destructive) { sitzung.satzLoeschen(i, s) }
        }
    }

    /// Das erste Gewicht, das kein Aufwärmsatz ist.
    private func arbeitsgewicht(_ u: WorkoutUebung) -> Double? {
        u.saetze.first { $0.typ != "w" && $0.kg != nil }?.kg
    }

    private func menue(_ i: Int, _ u: WorkoutUebung) -> some View {
        Menu {
            Button("Übung ansehen", systemImage: "play.rectangle") { detail = u.planUebung.uebung }
            Button("Aufwärmsätze einfügen", systemImage: "flame") {
                if let kg = arbeitsgewicht(u) { sitzung.aufwaermen(i, arbeit: kg) }
            }
            .disabled(arbeitsgewicht(u) == nil)
            Button("Scheiben und Aufwärmen", systemImage: "circle.circle") { rechnerOffen = true }
            Toggle("RPE-Spalte", isOn: $rpeAn)
            Button(u.planUebung.supersatz == true ? "Supersatz lösen" : "Supersatz mit der nächsten", systemImage: "link") {
                sitzung.supersatz(i, an: u.planUebung.supersatz != true)
            }
            if AusweichLogik.tauschbar(u, saetze: u.saetze) {
                Button("Gerät besetzt: tauschen", systemImage: "arrow.left.arrow.right") { tauschOffen = true }
            }
            NavigationLink(value: Route.uebung(id: u.planUebung.uebung)) { Label("Rekorde und Verlauf", systemImage: "medal.fill") }
            if u.extra {
                Button("Übung entfernen", systemImage: "trash", role: .destructive) { entfernen(i) }
            } else if u.ausgelassen {
                Button("Übung wieder aufnehmen", systemImage: "arrow.uturn.backward") { sitzung.wiederAufnehmen(i) }
            } else {
                Button("Übung auslassen", systemImage: "forward.end") { auslassen(i) }
                    .disabled(u.saetze.contains { $0.ok == true })
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Mehr")
    }

    // MARK: Leiste

    @ViewBuilder
    private func leiste(_ i: Int, _ u: WorkoutUebung) -> some View {
        if let offener = u.saetze.firstIndex(where: { $0.ok != true }), !u.ausgelassen {
            LoveaTrainingLeiste(sitzung: sitzung, titel: "Satz \(offener + 1) von \(u.saetze.count)", unter: WorkoutLogik.satzText(u.saetze[offener]), knopf: "Satz fertig") {
                sitzung.haken(i, offener)
            }
        } else {
            let liste = sitzung.liste
            let kraft = liste.filter { $0.id != u.id && !$0.fertig && !$0.ausgelassen && !$0.planUebung.istCardio }
            let danach = liste.drop { $0.id != u.id }.dropFirst().first { !$0.fertig && !$0.ausgelassen && !$0.planUebung.istCardio }
            let naechste = danach ?? kraft.first
            LoveaTrainingLeiste(
                sitzung: sitzung,
                titel: u.ausgelassen ? "Übung ausgelassen" : "Übung fertig",
                unter: naechste.map { "Weiter mit \($0.planUebung.anzeigeName)" } ?? "Zurück zur Übersicht",
                knopf: naechste == nil ? "Übersicht" : "Nächste Übung"
            ) {
                wechseln(naechste?.id)
            }
        }
    }

    // MARK: Rückgängig

    /// "Satz 2 gelöscht" mit "Rückgängig": fünf Sekunden, dann gleitet der Toast weg (Lovea `WorkoutView.swift:212`).
    @ViewBuilder
    private var toast: some View {
        if let r = sitzung.rueckgaengig {
            HStack {
                Text(r.text).font(.subheadline)
                Spacer(minLength: 8)
                Button("Rückgängig") { sitzung.satzRueckgaengigMachen() }.font(.subheadline.weight(.semibold)).frame(minHeight: Abstand.tippflaeche)
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
                if !Task.isCancelled { sitzung.rueckgaengigVergessen() }
            }
        }
    }

    // MARK: Laden und Sichern

    private func laden(_ u: WorkoutUebung) {
        guard !geladen else { return }
        notiz = u.planUebung.notiz ?? ""
        geladen = true
    }

    /// Beim Verlassen: getippte Werte senden und die Notiz in den Plan schreiben, falls geändert.
    private func sichern() {
        guard geladen, let i = sitzung.liste.firstIndex(where: { $0.id == planId }) else { return }
        sitzung.uebungSichern(i)
        let u = sitzung.liste[i]
        let neu = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        if !u.extra, neu != (u.planUebung.notiz ?? "") { sitzung.notiz(i, neu) }
    }

    private func entfernen(_ i: Int) {
        geladen = false // nichts mehr nachsenden
        sitzung.uebungWeg(i)
        wechseln(nil)
    }

    private func auslassen(_ i: Int) {
        sitzung.auslassen(i)
        wechseln(nil)
    }
}

// MARK: - Satzzeile

/// Eine Satzzeile wie in Hevy (Lovea `WorkoutSatzZeile`): Nummer (Tipp wählt den Typ), Vorher, kg, Wdh, RPE, Haken; darunter Satz- und
/// Pausenzeit und der Rekord. Gewicht und Wiederholungen sind Zahlenfelder.
struct LoveaSatzZeile: View {
    let nummer: String
    let satz: PlanSatz
    let vorher: String?
    var rpe = true
    var satzzeit = false
    var laeuft = false
    var rekord: String?
    var typ: (String) -> Void = { _ in }
    var haken: () -> Void = {}
    var kopieren: () -> Void = {}
    var loeschen: () -> Void = {}
    var anstrengung: () -> Void = {}
    var vorherUebernehmen: () -> Void = {}
    var werte: (Double?, Int) -> Void = { _, _ in }

    @Environment(\.dynamicTypeSize) private var schriftGroesse
    private var fertig: Bool { satz.ok == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Ab Accessibility-Größe passt die Tabelle nicht mehr in eine Zeile: die Felder stehen dann untereinander (wie im Lumen-Aufbau).
            if schriftGroesse.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { felder }
            } else {
                HStack(spacing: 6) { felder }
            }
            if fertig, let zeiten = WorkoutLogik.zeitenText(sek: satz.sek, pause: satz.pause, satzzeit: satzzeit) {
                Text(zeiten).font(.caption).foregroundStyle(Color.primary.opacity(0.75)).padding(.leading, schriftGroesse.isAccessibilitySize ? 0 : 50)
            }
            if fertig, let rekord {
                Label("Rekord: \(rekord)", systemImage: "medal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
                    .padding(.leading, schriftGroesse.isAccessibilitySize ? 0 : 50)
            }
        }
    }

    @ViewBuilder
    private var felder: some View {
                typMenue
                Button(action: vorherUebernehmen) {
                    Text(vorher ?? "–")
                        .font(.subheadline)
                        .foregroundStyle(fertig ? Color.primary.opacity(0.75) : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(vorher == nil)
                .accessibilityLabel(vorher.map { "Letztes Mal: \($0)" } ?? "Kein früherer Wert")
                .accessibilityHint("Übernimmt Gewicht und Wiederholungen")
                feld(TextField("0", value: Binding(get: { satz.kg }, set: { werte($0, satz.wdh) }), format: .number).keyboardType(.decimalPad), 62)
                    .accessibilityLabel("Kilo")
                feld(TextField("0", value: Binding(get: { satz.wdh }, set: { werte(satz.kg, $0) }), format: .number).keyboardType(.numberPad), 50)
                    .accessibilityLabel("Wiederholungen")
                if rpe {
                    feld(
                        Button(action: anstrengung) {
                            Text(satz.rpe.map(TrainingLogik.kgText) ?? "–")
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background((satz.rpe.map { LoveaTraining.farbe(Anstrengung.stufe(rpe: $0)) } ?? .clear).opacity(0.3), in: LoveaTraining.kachel)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.primary),
                        44
                    )
                    .accessibilityLabel("RPE")
                    .accessibilityHint("Anstrengung wählen")
                }
                Button(action: haken) {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(fertig ? Color.white : Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(fertig ? Color.green : LoveaTraining.feld, in: LoveaTraining.kachel)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(fertig ? "Haken entfernen" : "Satz abhaken")
    }

    private var typMenue: some View {
        Menu {
            Button("Normal") { typ("") }
            Button("Aufwärmen (W)") { typ("w") }
            Button("Dropsatz (D)") { typ("d") }
            Button("Bis zum Versagen (F)") { typ("f") }
            Divider()
            Button("Satz kopieren", systemImage: "plus.square.on.square", action: kopieren)
            Button("Satz löschen", systemImage: "trash", role: .destructive, action: loeschen)
        } label: {
            Text(nummer)
                .font(.headline)
                .foregroundStyle(satz.kuerzel == nil ? Color.primary : Color.orange)
                .frame(width: 44, height: 44)
                .background(LoveaTraining.feld, in: LoveaTraining.kachel)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Satztyp, jetzt \(nummer)")
    }

    private func feld(_ eingabe: some View, _ breite: CGFloat) -> some View {
        eingabe
            .multilineTextAlignment(.center)
            .font(.headline.monospacedDigit())
            .frame(minWidth: breite, maxWidth: schriftGroesse.isAccessibilitySize ? .infinity : breite, minHeight: 44)
            .frame(height: schriftGroesse.isAccessibilitySize ? nil : 44)
            .overlay {
                LoveaTraining.kachel.strokeBorder(fertig ? Color.clear : laeuft ? Color.blue : Color(uiColor: .separator), lineWidth: 1)
            }
    }
}
