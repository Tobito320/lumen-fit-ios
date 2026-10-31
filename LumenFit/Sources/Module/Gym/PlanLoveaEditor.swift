// Quelle: Lovea Health/GymNeu/SplitEditorView.swift (SplitEditorAktionen :9, SplitEditorInhalt :21, SplitEditorView :157),
// Health/TrainingsPlanView.swift (SaetzeEditor :462, VariantenBlatt, SaetzeListe, SatzZeile), GymNeu/GymStartView.swift (GymUebungZeile :255)
import SwiftUI
import UIKit

// Der Plan-Editor im Lovea-Aufbau: Tagesleiste mit Plus, Wochentage, Übungen zum Aufklappen, Menü ⋯. Jede Änderung sichert sofort den
// ganzen Plan (`TrainingStore.planSichern`, `gym.plan`, der neueste gilt). Was Lumen Fit im Plantag mehr kann (Doppeln, Reihenfolge,
// Supersatz, Notiz, Variante, Kopieren von einem anderen Tag), liegt in den Kapseln unter der Übung, im Sätze-Blatt und im Menü ⋯.

struct PlanLoveaEditorAktionen {
    var waehlen: (String) -> Void = { _ in }
    var neuerTag: () -> Void = {}
    var wochentag: (Int) -> Void = { _ in }
    var aufklappen: (String) -> Void = { _ in }
    var bearbeiten: (PlanUebung) -> Void = { _ in }
    /// Schnell geändert (Stepper für Sätze, Wiederholungen, kg, Minuten): die neue Übung.
    var aendern: (PlanUebung) -> Void = { _ in }
    var hinzufuegen: () -> Void = {}
    var doppeln: (String) -> Void = { _ in }
    /// Übung `id` um -1 (nach oben) oder +1 (nach unten) schieben.
    var schieben: (String, Int) -> Void = { _, _ in }
    /// Schritt der kg-Stepper je Übung (Lumen: nach Gerät, `LetztesMal.kgSchritt`).
    var kgSchritt: (PlanUebung) -> Double = { _ in 2.5 }
}

/// Reiner Inhalt: Tagesleiste, Wochentage des gewählten Tags, seine Übungen (Lovea `SplitEditorInhalt`).
struct PlanLoveaEditorInhalt: View {
    let plan: TrainingsPlan
    let tagId: String?
    var offen: String? = nil
    var aktionen = PlanLoveaEditorAktionen()

    private var tag: TrainingsTag? { plan.tage.first { $0.id == tagId } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tage
            if let tag {
                wochentage(tag)
                uebungen(tag).padding(.top, 6)
            } else {
                Text("Noch kein Trainingstag. Tipp auf das Plus.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 14)
            }
        }
    }

    private var plus: some View {
        Button(action: aktionen.neuerTag) {
            Image(systemName: "plus")
                .font(.footnote.weight(.bold))
                .frame(width: 44, height: 32)
                .foregroundStyle(Color.secondary)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trainingstag hinzufügen")
    }

    private var tage: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(plan.tage) { t in
                    Button { aktionen.waehlen(t.id) } label: { PlanLoveaChip(text: PlanLoveaLogik.tagName(t), an: t.id == tagId) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(t.id == tagId ? .isSelected : [])
                }
                if PlanLoveaLogik.darfNeuerTag(plan) { plus }
            }
        }
    }

    private func wochentage(_ tag: TrainingsTag) -> some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { w in
                let an = tag.wochentage.contains(w)
                Button { aktionen.wochentag(w) } label: {
                    Text(HabitLogik.wochentagKuerzel[w - 1])
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(an ? Color(uiColor: .systemBackground) : Color.secondary)
                        .background(an ? Color.primary : Color(uiColor: .tertiarySystemFill), in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(TrainingLogik.wochentagName[w - 1])
                .accessibilityAddTraits(an ? .isSelected : [])
            }
        }
    }

    private func uebungen(_ tag: TrainingsTag) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Aus Lumen Fit: die geschätzte Dauer des Tages (`ZeitSchaetzung`).
            if !tag.uebungen.isEmpty {
                Text(ZeitSchaetzung.umfang(tag)).font(.footnote).foregroundStyle(.secondary).frame(minHeight: 28, alignment: .leading)
            }
            ForEach(tag.uebungen) { u in
                Button { aktionen.aufklappen(u.id) } label: {
                    PlanLoveaUebungZeile(name: u.anzeigeName, unter: TrainingLogik.saetzeText(u) + (u.supersatz == true ? " · Supersatz" : "")).contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(offen == u.id ? .isSelected : [])
                .accessibilityHint(offen == u.id ? "Klappt die Sätze zu" : "Klappt die Sätze auf")
                if offen == u.id { saetze(u, in: tag) }
                Divider()
            }
            Button(action: aktionen.hinzufuegen) {
                Label("Übung hinzufügen", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func saetze(_ u: PlanUebung, in tag: TrainingsTag) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            schnell(u)
            if let minuten = u.minuten {
                Text("\(minuten) min").font(.subheadline).foregroundStyle(.secondary).frame(minHeight: 36)
            }
            ForEach(Array(u.saetze.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 10) {
                    Text(s.kuerzel ?? "\(i + 1)").frame(width: 28, alignment: .leading).foregroundStyle(.secondary)
                    Text("\(s.wdh) Wdh.").frame(maxWidth: .infinity, alignment: .leading)
                    Text(s.kg.map { "\(TrainingLogik.kgText($0)) kg" } ?? "ohne Gewicht").frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(s.kg == nil ? Color.secondary : Color.primary)
                }
                .font(.subheadline)
                .monospacedDigit()
                .frame(minHeight: 36)
                .accessibilityElement(children: .combine)
            }
            kapseln(u, in: tag)
        }
        .padding(.bottom, 8)
    }

    /// "Sätze ändern" wie in Lovea; Doppeln und Reihenfolge sind die Wischer und der Reihenfolge-Modus aus dem Lumen-Plantag.
    private func kapseln(_ u: PlanUebung, in tag: TrainingsTag) -> some View {
        let i = tag.uebungen.firstIndex { $0.id == u.id } ?? 0
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button { aktionen.bearbeiten(u) } label: { PlanLoveaChip(text: "Sätze ändern") }.buttonStyle(.plain)
                Button { aktionen.doppeln(u.id) } label: { PlanLoveaChip(text: "Doppeln") }
                    .buttonStyle(.plain)
                    .accessibilityHint("Fügt die Übung direkt dahinter noch einmal ein")
                Button { aktionen.schieben(u.id, -1) } label: { PlanLoveaChip(text: "Nach oben") }
                    .buttonStyle(.plain)
                    .disabled(i == 0)
                Button { aktionen.schieben(u.id, 1) } label: { PlanLoveaChip(text: "Nach unten") }
                    .buttonStyle(.plain)
                    .disabled(i >= tag.uebungen.count - 1)
            }
        }
    }
}

/// Eine Übung als Zeile: Name und Sätze (Lovea `GymUebungZeile`).
struct PlanLoveaUebungZeile: View {
    let name: String
    let unter: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.body.weight(.semibold)).foregroundStyle(Color.primary).lineLimit(2)
            Text(unter).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }
}

extension PlanLoveaEditorInhalt {
    /// Sätze, Wiederholungen und kg für die ganze Übung mit je einem Stepper (Cardio: Minuten).
    @ViewBuilder
    fileprivate func schnell(_ u: PlanUebung) -> some View {
        if let minuten = u.minuten {
            zeile("Dauer", "\(minuten) min", Stepper("", value: Binding(get: { minuten }, set: { aktionen.aendern(SplitFrei.dauer(u, $0)) }), in: 5...180, step: 5))
        } else {
            zeile("Sätze", "\(u.saetze.count)", Stepper("", value: Binding(get: { u.saetze.count }, set: { aktionen.aendern(SplitFrei.saetzeAnzahl(u, $0)) }), in: 1...SplitFrei.maxSaetze))
            zeile("Wiederholungen", PlanLoveaLogik.wdhText(u),
                  Stepper("", value: Binding(get: { u.saetze.first?.wdh ?? 10 }, set: { aktionen.aendern(SplitFrei.alleWdh(u, $0)) }), in: 1...100))
            zeile("Gewicht", PlanLoveaLogik.kgText(u),
                  Stepper("", value: Binding(get: { u.saetze.first?.kg ?? 0 }, set: { aktionen.aendern(SplitFrei.alleKg(u, $0)) }), in: 0...500, step: aktionen.kgSchritt(u)))
        }
    }

    private func zeile(_ titel: String, _ wert: String, _ stepper: some View) -> some View {
        HStack(spacing: 10) {
            Text(titel).font(.subheadline).accessibilityHidden(true)
            Spacer(minLength: 8)
            Text(wert).font(.subheadline.weight(.semibold)).monospacedDigit().accessibilityHidden(true)
            stepper.labelsHidden().fixedSize().accessibilityLabel(titel).accessibilityValue(wert)
        }
        .frame(minHeight: 44)
    }
}

/// Der Editor als Seite (Push aus der Plan-Seite) oder als Blatt (Übungsliste auf der Gym-Startseite). Im Blatt steht oben "Fertig".
struct PlanLoveaEditorView: View {
    let sitzung: GymSitzung
    /// Der Tag, der zuerst gezeigt wird; nil = der erste.
    let start: String?
    var blatt = false

    @Environment(\.dismiss) private var schliessen
    @State private var tagId: String?
    @State private var offen: String?
    @State private var bearbeiten: PlanUebung?
    @State private var sucheOffen = false
    @State private var nameOffen = false
    @State private var name = ""
    @State private var loeschenFrage = false
    @State private var stufe = 0

    private var training: TrainingStore? { sitzung.training }
    private var plan: TrainingsPlan { training?.plan ?? .leer }
    private var gewaehlt: String? { PlanLoveaLogik.gewaehlterTag(plan, gewaehlt: tagId, start: start) }
    private var tag: TrainingsTag? { plan.tage.first { $0.id == gewaehlt } }

    var body: some View {
        ScrollView {
            PlanLoveaEditorInhalt(plan: plan, tagId: gewaehlt, offen: offen, aktionen: aktionen)
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
        }
        .navigationTitle(plan.splitName ?? "Mein Split")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menue }
            if blatt {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() }.fontWeight(.semibold) }
            }
        }
        .sheet(isPresented: $sucheOffen) {
            UebungsSucheView(titel: "Übung hinzufügen", auswahl: { k in aendern { $0.uebungen.append(GymEigeneLogik.planUebung(k)) } }, mehrfach: true)
        }
        .sheet(item: $bearbeiten) { u in
            NavigationStack {
                PlanLoveaSaetzeBlatt(
                    start: u,
                    supersatzMoeglich: supersatzMoeglich(u),
                    speichern: { neu in aendern { t in if let i = t.uebungen.firstIndex(where: { $0.id == neu.id }) { t.uebungen[i] = neu } } },
                    entfernen: { aendern { t in t = PlanEditor.weg(t, id: u.id) } }
                )
            }
        }
        .alert("Tag umbenennen", isPresented: $nameOffen) {
            TextField("z. B. Push", text: $name)
            Button("Abbrechen", role: .cancel) {}
            Button("Sichern") {
                let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sauber.isEmpty { aendern { $0.name = sauber } }
            }
        }
        .confirmationDialog("Diesen Trainingstag löschen?", isPresented: $loeschenFrage, titleVisibility: .visible) {
            Button("Tag löschen", role: .destructive) { tagLoeschen() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Tag und seine Übungen fallen aus dem Plan. Alte Trainings bleiben.")
        }
        .haptik(.auswahl, bei: stufe)
    }

    private var menue: some View {
        Menu {
            Button("Tag umbenennen", systemImage: "pencil") {
                name = tag?.name ?? ""
                nameOffen = true
            }
            if let tag, !quellen(tag).isEmpty {
                Menu("Von anderem Tag kopieren", systemImage: "doc.on.doc") {
                    ForEach(quellen(tag)) { q in
                        Button("\(q.name.isEmpty ? "Training" : q.name) (\(q.uebungen.count))") {
                            aendern { $0 = PlanEditor.vonTagKopieren($0, quelle: q) }
                        }
                    }
                }
            }
            Button("Tag löschen", systemImage: "trash", role: .destructive) { loeschenFrage = true }
        } label: {
            Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
        }
        .disabled(tag == nil)
        .accessibilityLabel("Mehr")
        .loveaTipp(.loveaSplitTagMehr)
    }

    private func quellen(_ tag: TrainingsTag) -> [TrainingsTag] {
        plan.tage.filter { $0.id != tag.id && !$0.uebungen.isEmpty }
    }

    private var aktionen: PlanLoveaEditorAktionen {
        PlanLoveaEditorAktionen(
            waehlen: { id in
                stufe += 1
                withAnimation(Feder.schnell) { tagId = id; offen = nil }
            },
            neuerTag: neuerTag,
            wochentag: { w in
                aendern { t in t = PlanEditor.wochentag(t, w, an: !t.wochentage.contains(w)) }
                stufe += 1
            },
            aufklappen: { id in withAnimation(Feder.schnell) { offen = offen == id ? nil : id } },
            bearbeiten: { bearbeiten = $0 },
            aendern: { neu in
                aendern { t in
                    if let i = t.uebungen.firstIndex(where: { $0.id == neu.id }) { t.uebungen[i] = neu }
                }
            },
            hinzufuegen: { sucheOffen = true },
            doppeln: { id in aendern { $0 = PlanEditor.duplizieren($0, id: id) } },
            schieben: { id, schritt in aendern { $0 = PlanEditor.schieben($0, id: id, um: schritt) } },
            kgSchritt: kgSchritt
        )
    }

    private func kgSchritt(_ u: PlanUebung) -> Double {
        LetztesMal.kgSchritt(geraet: sitzung.katalog(u)?.geraet)
    }

    /// Wie `SupersatzLogik.koppeln`: nicht für die letzte Übung und nicht für Cardio.
    private func supersatzMoeglich(_ u: PlanUebung) -> Bool {
        guard let t = tag, let i = t.uebungen.firstIndex(where: { $0.id == u.id }) else { return false }
        return i + 1 < t.uebungen.count && !t.uebungen[i].istCardio && !t.uebungen[i + 1].istCardio
    }

    /// Ändert den gewählten Tag und sichert den Plan. `tagSetzen` nimmt den Wochentag anderen Tagen weg.
    private func aendern(_ f: (inout TrainingsTag) -> Void) {
        guard var t = tag, let training else { return }
        f(&t)
        training.planSichern(TrainingLogik.tagSetzen(training.plan, t))
    }

    private func neuerTag() {
        guard let training else { return }
        let neu = PlanEditor.neuerTag(training.plan, name: "")
        training.planSichern(neu)
        tagId = neu.tage.last?.id
        offen = nil
        stufe += 1
    }

    private func tagLoeschen() {
        guard let t = tag, let training else { return }
        training.planSichern(PlanEditor.tagWeg(training.plan, id: t.id))
        tagId = nil
        stufe += 1
        if blatt { schliessen() }
    }
}

/// Sätze einer Plan-Übung (oder Minuten bei Cardio), oben das Bild (Lovea `SaetzeEditor`). Änderungen gelten erst mit "Fertig",
/// "Abbrechen" verwirft sie. Dazu aus Lumen Fit: Notiz, Supersatz, Variante.
struct PlanLoveaSaetzeBlatt: View {
    let start: PlanUebung
    let supersatzMoeglich: Bool
    let speichern: (PlanUebung) -> Void
    let entfernen: () -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var entwurf: PlanUebung
    @State private var variantenOffen = false
    @State private var erfolg = 0

    init(start: PlanUebung, supersatzMoeglich: Bool, speichern: @escaping (PlanUebung) -> Void, entfernen: @escaping () -> Void) {
        self.start = start
        self.supersatzMoeglich = supersatzMoeglich
        self.speichern = speichern
        self.entfernen = entfernen
        _entwurf = State(initialValue: start)
    }

    var body: some View {
        Form {
            if entwurf.katalog != nil {
                Section {
                    UebungsBild(id: entwurf.uebung, koerper: entwurf.katalog?.koerper)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                }
            }
            if entwurf.istCardio {
                Section("Dauer") {
                    Stepper(value: minuten, in: 5...180, step: 5) { Text("\(entwurf.minuten ?? 20) min").monospacedDigit() }
                }
            } else {
                Section {
                    PlanLoveaSaetzeListe(saetze: $entwurf.saetze)
                } header: {
                    Text("Sätze")
                } footer: {
                    Text("Failure heißt: bis nichts mehr geht.")
                }
            }
            Section("Notiz") {
                TextField("Zum Beispiel Sitz auf Stufe 4", text: notiz, axis: .vertical)
            }
            if supersatzMoeglich, !entwurf.istCardio {
                Section {
                    Toggle("Supersatz mit der nächsten", isOn: Binding(get: { entwurf.supersatz == true }, set: { entwurf.supersatz = $0 ? true : nil }))
                        .frame(minHeight: 44)
                } footer: {
                    Text("Beide Übungen wechseln sich satzweise ab, die Pause kommt einmal je Runde.")
                }
            }
            Section {
                if !entwurf.istCardio, let u = entwurf.katalog, !AusweichLogik.alternativen(fuer: u).isEmpty {
                    Button("Andere Variante wählen", systemImage: "arrow.triangle.2.circlepath") { variantenOffen = true }
                        .frame(minHeight: 44)
                }
                Button("Übung entfernen", systemImage: "trash", role: .destructive) {
                    entfernen()
                    schliessen()
                }
                .frame(minHeight: 44)
            }
        }
        .navigationTitle(entwurf.anzeigeName)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") {
                    var neu = entwurf
                    let t = (neu.notiz ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    neu.notiz = t.isEmpty ? nil : t
                    speichern(neu)
                    erfolg += 1
                    schliessen()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $variantenOffen) {
            if let u = entwurf.katalog {
                PlanLoveaVarianteBlatt(uebung: u) { neu in
                    entwurf.uebung = neu.id
                    entwurf.name = nil
                }
            }
        }
        .haptik(.erfolg, bei: erfolg)
    }

    private var minuten: Binding<Int> {
        Binding { entwurf.minuten ?? 20 } set: { entwurf.minuten = $0 }
    }

    private var notiz: Binding<String> {
        Binding { entwurf.notiz ?? "" } set: { entwurf.notiz = $0 }
    }
}

/// "Gefällt mir nicht": andere Übungen für denselben Muskel (Lovea `VariantenBlatt`, mit den Alternativen aus `AusweichLogik`).
struct PlanLoveaVarianteBlatt: View {
    let uebung: Uebung
    let waehlen: (Uebung) -> Void
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List(AusweichLogik.alternativen(fuer: uebung)) { u in
                Button {
                    waehlen(u)
                    schliessen()
                } label: {
                    HStack(spacing: 12) {
                        UebungsBild(id: u.id, koerper: u.koerper).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u.name).foregroundStyle(Color.primary)
                            Text("\(u.muskel) · \(u.geraet)").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .frame(minHeight: 52)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Statt \(uebung.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Die Satzzeilen mit Hinzufügen und Wischen zum Löschen (Lovea `SaetzeListe`). Die Bindungen sind indexsicher: eine Zeile, die gerade
/// wegfällt, fragt noch einmal nach ihrem Index.
struct PlanLoveaSaetzeListe: View {
    @Binding var saetze: [PlanSatz]

    var body: some View {
        ForEach(saetze.indices, id: \.self) { i in PlanLoveaSatzZeile(nummer: i + 1, satz: satz(i)) }
            .onDelete { saetze.remove(atOffsets: $0) }
        Button("Satz hinzufügen", systemImage: "plus") {
            saetze.append(saetze.last ?? PlanSatz(wdh: 10, kg: nil, failure: false))
        }
        .frame(minHeight: 44)
    }

    private func satz(_ i: Int) -> Binding<PlanSatz> {
        Binding {
            saetze.indices.contains(i) ? saetze[i] : PlanSatz(wdh: 0, kg: nil, failure: false)
        } set: {
            if saetze.indices.contains(i) { saetze[i] = $0 }
        }
    }
}

/// "Satz 1", Wiederholungen mit Stepper, kg-Feld, Failure-Schalter (Lovea `SatzZeile`).
struct PlanLoveaSatzZeile: View {
    let nummer: Int
    @Binding var satz: PlanSatz

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Satz \(nummer)").font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("Failure", isOn: $satz.failure)
                    .toggleStyle(.button)
                    .font(.caption.weight(.semibold))
                    .tint(.orange)
                    .frame(minHeight: 44)
            }
            HStack(spacing: 8) {
                Stepper(value: $satz.wdh, in: 1...100) { Text("\(satz.wdh) Wdh.").monospacedDigit() }
                TextField("kg", value: $satz.kg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64, height: 44)
                    .accessibilityLabel("Gewicht in Kilogramm")
                Text("kg").foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }
}
