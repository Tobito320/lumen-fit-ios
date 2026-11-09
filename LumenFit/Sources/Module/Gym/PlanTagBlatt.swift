// Quelle: Lovea Health/GymNeu/SplitEditorView (neu im Lumen-Design)
import SwiftUI

/// Ein Plantag bearbeiten (Idee 27 und 28): Name, Wochentage, Übungen mit Sätzen, Wiederholungen und Gewicht, Supersatz, Notiz,
/// Reihenfolge. Jede Änderung geht sofort in den Plan.
struct PlanTagBlatt: View {
    let sitzung: GymSitzung
    let tagId: String
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var suche = false
    @State private var name = ""
    @State private var loeschen = false
    @State private var bearbeiten: EditMode = .inactive

    private var training: TrainingStore? { sitzung.training }
    private var tag: TrainingsTag? { training?.tag(id: tagId) }

    @ViewBuilder
    var body: some View {
        lumenBody
    }

    private var lumenBody: some View {
        NavigationStack {
            Group {
                if let tag {
                    liste(tag)
                } else {
                    LeerZustand(stimmung: .denkt, satz: "Diesen Tag gibt es nicht mehr.")
                }
            }
            .lumenHintergrund()
            .navigationTitle(tag?.name ?? "Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { nameSichern(); schliessen() } }
                ToolbarItem(placement: .cancellationAction) { EditButton() }
            }
            .environment(\.editMode, $bearbeiten)
            .onAppear { name = tag?.name ?? "" }
            .onDisappear { nameSichern() }
            .sheet(isPresented: $suche) {
                UebungsSucheView(titel: "Übung hinzufügen", auswahl: { k in
                    guard let t = tag else { return }
                    var neu = t
                    neu.uebungen.append(GymEigeneLogik.planUebung(k))
                    sichern(neu)
                }, mehrfach: true)
            }
            .confirmationDialog("Tag löschen?", isPresented: $loeschen, titleVisibility: .visible) {
                Button("Tag löschen", role: .destructive) {
                    if let t = training { t.planSichern(PlanEditor.tagWeg(t.plan, id: tagId)) }
                    schliessen()
                }
            } message: {
                Text("Der Tag und seine Übungen fallen aus dem Plan. Alte Trainings bleiben.")
            }
        }
    }

    /// Name speichern, wenn er sich geändert hat und nicht leer ist. Läuft bei Return, bei "Fertig" und beim Schließen.
    private func nameSichern() {
        guard let t = tag else { return }
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty, sauber != t.name else { return }
        var neu = t
        neu.name = sauber
        sichern(neu)
    }

    private func sichern(_ neu: TrainingsTag) {
        guard let t = training else { return }
        t.planSichern(TrainingLogik.tagSetzen(t.plan, neu))
    }

    private func liste(_ tag: TrainingsTag) -> some View {
        List {
            Section("Name") {
                TextField("Name des Tages", text: $name)
                    .onSubmit { nameSichern() }
                    .submitLabel(.done)
            }
            Section {
                HStack(spacing: Abstand.xs) {
                    ForEach(1...7, id: \.self) { w in
                        let an = tag.wochentage.contains(w)
                        Button { sichern(PlanEditor.wochentag(tag, w, an: !an)) } label: {
                            Text(HabitLogik.wochentagKuerzel[w - 1])
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                                .foregroundStyle(an ? palette.aufAkzent : palette.text)
                                .background(an ? palette.akzent : palette.flaeche, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(TrainingLogik.wochentagName[w - 1])
                        .accessibilityAddTraits(an ? .isSelected : [])
                    }
                }
                .listRowInsets(EdgeInsets(top: Abstand.xs, leading: Abstand.m, bottom: Abstand.xs, trailing: Abstand.m))
            } header: {
                Text("Wochentage")
            } footer: {
                Text("Ohne Wochentag ist der Tag flexibel und passt an jedem Tag.")
            }
            Section("Übungen · \(ZeitSchaetzung.umfang(tag))") {
                if tag.uebungen.isEmpty { Text("Noch keine Übungen.").foregroundStyle(palette.text2) }
                GymTippZeile(art: .planZeile, kontext: GymTippKontext(planUebungen: tag.uebungen.count))
                ForEach(tag.uebungen) { u in
                    UebungsPlanZeile(tag: tag, uebungId: u.id, sichern: sichern)
                        .swipeActions(edge: .leading) {
                            Button { sichern(PlanEditor.duplizieren(tag, id: u.id)) } label: { Label("Doppeln", systemImage: "plus.square.on.square") }
                                .tint(palette.akzent)
                        }
                }
                .onDelete { weg in
                    var neu = tag
                    for i in weg.sorted(by: >) { neu = PlanEditor.weg(neu, id: tag.uebungen[i].id) }
                    sichern(neu)
                }
                .onMove { von, nach in
                    guard let v = von.first else { return }
                    sichern(PlanEditor.verschieben(tag, von: v, nach: nach > v ? nach - 1 : nach))
                }
                Button { suche = true } label: { Label("Übung hinzufügen", systemImage: "plus").frame(minHeight: Abstand.tippflaeche) }
                if let plan = training?.plan, plan.tage.contains(where: { $0.id != tag.id && !$0.uebungen.isEmpty }) {
                    Menu {
                        ForEach(plan.tage.filter { $0.id != tag.id && !$0.uebungen.isEmpty }) { quelle in
                            Button("\(quelle.name.isEmpty ? "Training" : quelle.name) (\(quelle.uebungen.count))") {
                                sichern(PlanEditor.vonTagKopieren(tag, quelle: quelle))
                            }
                        }
                    } label: {
                        Label("Von anderem Tag kopieren", systemImage: "doc.on.doc").frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
            Section {
                Button("Tag löschen", role: .destructive) { loeschen = true }.frame(minHeight: Abstand.tippflaeche)
            }
        }
        .scrollContentBackground(.hidden)
        .animation(Feder.schnell, value: tag.uebungen.map(\.id))
        .haptik(.stufe, bei: tag.uebungen.map(\.id))
        .haptik(.auswahl, bei: tag.wochentage)
    }
}

/// Eine Übung im Plantag: Sätze, Wiederholungen, Gewicht, Supersatz und Notiz (Idee 28). Bei Cardio die Dauer.
private struct UebungsPlanZeile: View {
    let tag: TrainingsTag
    /// Die Zeile hängt an der Übung, nicht an der Stelle: nach Löschen oder Verschieben bleibt die Notiz bei ihrer Übung.
    let uebungId: String
    let sichern: (TrainingsTag) -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var offen = false
    @State private var notiz = ""
    @State private var variante = false

    private var index: Int? { tag.uebungen.firstIndex { $0.id == uebungId } }

    var body: some View {
        if let index { zeile(index, tag.uebungen[index]) }
    }

    private func aendere(_ index: Int, _ f: (PlanUebung) -> PlanUebung) {
        var neu = tag
        neu.uebungen[index] = f(tag.uebungen[index])
        sichern(neu)
    }

    /// Die Notiz speichern, wenn sie sich geändert hat: bei Return, beim Zuklappen und beim Verschwinden der Zeile.
    private func notizSichern(_ index: Int) {
        let t = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        let wert: String? = t.isEmpty ? nil : t
        guard wert != tag.uebungen[index].notiz else { return }
        aendere(index) { var x = $0; x.notiz = wert; return x }
    }

    /// Ein Satz der Übung: Wiederholungen, Gewicht und der Schalter "bis zum Versagen".
    private func satzZeile(_ index: Int, _ u: PlanUebung, _ i: Int) -> some View {
        let satz = u.saetze[i]
        return VStack(alignment: .leading, spacing: Abstand.xs) {
            Stepper("Satz \(i + 1): \(satz.wdh) Wdh.", value: Binding(get: { satz.wdh }, set: { v in aendere(index) { PlanEditor.satzAendern($0, i, wdh: v) } }), in: 1...100)
            Stepper("Gewicht \(satz.kg.map { "\(TrainingLogik.kgText($0)) kg" } ?? "ohne")",
                    value: Binding(get: { satz.kg ?? 0 }, set: { v in aendere(index) { PlanEditor.satzAendern($0, i, kg: .some(v)) } }),
                    in: 0...500, step: LetztesMal.kgSchritt(geraet: GymSitzung.von(umgebung).katalog(u)?.geraet))
            Toggle("Bis zum Versagen", isOn: Binding(get: { satz.failure }, set: { v in aendere(index) { PlanEditor.satzAendern($0, i, versagen: v) } }))
        }
        .font(.subheadline)
        .accessibilityElement(children: .contain)
    }

    private func zeile(_ index: Int, _ u: PlanUebung) -> some View {
        DisclosureGroup(isExpanded: $offen) {
            if u.istCardio {
                Stepper("Dauer \(u.minuten ?? 20) min", value: Binding(get: { u.minuten ?? 20 }, set: { v in aendere(index) { SplitFrei.dauer($0, v) } }), in: 5...180, step: 5)
            } else {
                Stepper("Sätze \(u.saetze.count)", value: Binding(get: { u.saetze.count }, set: { v in aendere(index) { SplitFrei.saetzeAnzahl($0, v) } }), in: 1...SplitFrei.maxSaetze)
                Stepper("Wiederholungen \(u.saetze.first?.wdh ?? 10)", value: Binding(get: { u.saetze.first?.wdh ?? 10 }, set: { v in aendere(index) { SplitFrei.alleWdh($0, v) } }), in: 1...100)
                Stepper("Gewicht \(u.saetze.first?.kg.map { "\(TrainingLogik.kgText($0)) kg" } ?? "ohne")",
                        value: Binding(get: { u.saetze.first?.kg ?? 0 }, set: { v in aendere(index) { SplitFrei.alleKg($0, v) } }), in: 0...500, step: LetztesMal.kgSchritt(geraet: GymSitzung.von(umgebung).katalog(u)?.geraet))
                DisclosureGroup("Satz für Satz") {
                    ForEach(u.saetze.indices, id: \.self) { i in satzZeile(index, u, i) }
                }
                if index < tag.uebungen.count - 1 {
                    Toggle("Supersatz mit der nächsten", isOn: Binding(get: { u.supersatz == true }, set: { an in
                        var neu = tag
                        let gekoppelt = SupersatzLogik.koppeln(tag.uebungen, index, an: an)
                        for k in neu.uebungen.indices { neu.uebungen[k].supersatz = gekoppelt[k].supersatz }
                        sichern(neu)
                    }))
                }
            }
            if !u.istCardio, u.katalog != nil {
                Button { variante = true } label: { Label("Variante wählen", systemImage: "arrow.triangle.swap").frame(minHeight: Abstand.tippflaeche) }
            }
            TextField("Notiz, zum Beispiel Sitz auf Stufe 4", text: $notiz, axis: .vertical)
                .onSubmit { notizSichern(index) }
        } label: {
            HStack(spacing: Abstand.m) {
                UebungsBild(id: u.uebung, koerper: u.katalog?.koerper).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.anzeigeName).font(.body.weight(.medium)).foregroundStyle(palette.text)
                    Text(TrainingLogik.saetzeText(u) + (u.supersatz == true ? " · Supersatz" : "")).font(.footnote).foregroundStyle(palette.text2)
                }
            }
            .frame(minHeight: Abstand.tippflaeche)
        }
        .sheet(isPresented: $variante) { VarianteBlatt(uebung: u) { sichern(PlanEditor.variante(tag, id: u.id, zu: $0)) } }
        .onAppear { notiz = u.notiz ?? "" }
        .onChange(of: offen) { _, neu in if !neu { notizSichern(index) } }
        .onDisappear { if let i = self.index { notizSichern(i) } }
    }
}

/// Variante für eine Plan-Übung: andere Übungen für denselben Muskel (`AusweichLogik`), Sätze bleiben.
private struct VarianteBlatt: View {
    let uebung: PlanUebung
    let waehle: (Uebung) -> Void
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            List {
                let alternativen = uebung.katalog.map { AusweichLogik.alternativen(fuer: $0) } ?? []
                if alternativen.isEmpty { Text("Keine passende Variante gefunden.").foregroundStyle(palette.text2) }
                ForEach(alternativen) { alt in
                    Button { waehle(alt); schliessen() } label: {
                        HStack(spacing: Abstand.m) {
                            UebungsBild(id: alt.id, koerper: alt.koerper).frame(width: 48, height: 48)
                            VStack(alignment: .leading) {
                                Text(alt.name).font(.body.weight(.medium)).foregroundStyle(palette.text)
                                Text("\(alt.muskel) · \(alt.geraet)").font(.footnote).foregroundStyle(palette.text2)
                            }
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
            .navigationTitle("Variante")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
