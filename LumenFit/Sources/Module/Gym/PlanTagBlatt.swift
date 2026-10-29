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

    private var training: TrainingStore? { sitzung.training }
    private var tag: TrainingsTag? { training?.tag(id: tagId) }

    var body: some View {
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
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
            .onAppear { name = tag?.name ?? "" }
            .sheet(isPresented: $suche) {
                UebungsSucheView(titel: "Übung hinzufügen") { k in
                    guard let t = tag else { return }
                    var neu = t
                    neu.uebungen.append(PlanUebung.neu(k))
                    sichern(neu)
                }
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

    private func sichern(_ neu: TrainingsTag) {
        guard let t = training else { return }
        t.planSichern(TrainingLogik.tagSetzen(t.plan, neu))
    }

    private func liste(_ tag: TrainingsTag) -> some View {
        List {
            Section("Name") {
                TextField("Name des Tages", text: $name)
                    .onSubmit { var neu = tag; neu.name = name.trimmingCharacters(in: .whitespacesAndNewlines); sichern(neu) }
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
                ForEach(tag.uebungen.indices, id: \.self) { i in
                    UebungsPlanZeile(tag: tag, index: i, sichern: sichern)
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
            }
            Section {
                Button("Tag löschen", role: .destructive) { loeschen = true }.frame(minHeight: Abstand.tippflaeche)
            }
        }
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }
}

/// Eine Übung im Plantag: Sätze, Wiederholungen, Gewicht, Supersatz und Notiz (Idee 28). Bei Cardio die Dauer.
private struct UebungsPlanZeile: View {
    let tag: TrainingsTag
    let index: Int
    let sichern: (TrainingsTag) -> Void
    @Environment(\.palette) private var palette
    @State private var offen = false
    @State private var notiz = ""

    private var u: PlanUebung { tag.uebungen[index] }

    private func aendere(_ f: (PlanUebung) -> PlanUebung) {
        var neu = tag
        neu.uebungen[index] = f(u)
        sichern(neu)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $offen) {
            if u.istCardio {
                Stepper("Dauer \(u.minuten ?? 20) min", value: Binding(get: { u.minuten ?? 20 }, set: { v in aendere { SplitFrei.dauer($0, v) } }), in: 5...180, step: 5)
            } else {
                Stepper("Sätze \(u.saetze.count)", value: Binding(get: { u.saetze.count }, set: { v in aendere { SplitFrei.saetzeAnzahl($0, v) } }), in: 1...SplitFrei.maxSaetze)
                Stepper("Wiederholungen \(u.saetze.first?.wdh ?? 10)", value: Binding(get: { u.saetze.first?.wdh ?? 10 }, set: { v in aendere { SplitFrei.alleWdh($0, v) } }), in: 1...100)
                Stepper("Gewicht \(u.saetze.first?.kg.map { "\(TrainingLogik.kgText($0)) kg" } ?? "ohne")",
                        value: Binding(get: { u.saetze.first?.kg ?? 0 }, set: { v in aendere { SplitFrei.alleKg($0, v) } }), in: 0...500, step: LetztesMal.kgSchritt(geraet: u.katalog?.geraet))
                if index < tag.uebungen.count - 1 {
                    Toggle("Supersatz mit der nächsten", isOn: Binding(get: { u.supersatz == true }, set: { an in
                        var neu = tag
                        let gekoppelt = SupersatzLogik.koppeln(tag.uebungen, index, an: an)
                        for k in neu.uebungen.indices { neu.uebungen[k].supersatz = gekoppelt[k].supersatz }
                        sichern(neu)
                    }))
                }
            }
            TextField("Notiz, zum Beispiel Sitz auf Stufe 4", text: $notiz, axis: .vertical)
                .onSubmit { let t = notiz.trimmingCharacters(in: .whitespacesAndNewlines); aendere { var x = $0; x.notiz = t.isEmpty ? nil : t; return x } }
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
        .onAppear { notiz = u.notiz ?? "" }
    }
}
