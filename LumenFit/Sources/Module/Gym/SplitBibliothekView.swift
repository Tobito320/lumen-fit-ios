// Quelle: Lovea Health/GymNeu/SplitBibliothekView (neu im Lumen-Design)
import SwiftUI

/// Die Split-Bibliothek (Idee 27): Suche und Filter nach Ziel und Tagen, Vorschau jeder Einheit, "Als Plan übernehmen" oder
/// "Nur diese Woche testen". Die Splits stehen in `splits.json` (Grundgerüst), nichts davon ist hier fest verdrahtet.
struct SplitBibliothekView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var suche = ""
    @State private var art: String? = "fuerdich"
    @State private var tage: Int?

    var body: some View {
        NavigationStack {
            let geschlecht = umgebung.daten?.ziele.koerper.geschlecht
            let treffer = SplitLogik.treffer(SplitLogik.fuer(geschlecht), art: art, tage: tage, suche: suche)
            List {
                Section { filter }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                Section(treffer.isEmpty ? "Nichts gefunden" : "\(treffer.count) \(treffer.count == 1 ? "Split" : "Splits")") {
                    if treffer.isEmpty {
                        Text("Stell den Filter auf Alle oder such ein anderes Wort, zum Beispiel einen Muskel.").font(.subheadline).foregroundStyle(palette.text2)
                    }
                    ForEach(treffer) { v in
                        NavigationLink { SplitDetailView(sitzung: sitzung, vorlage: v, fertig: { schliessen() }) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.name).font(.body.weight(.medium)).foregroundStyle(palette.text)
                                Text(SplitLogik.unterzeile(v)).font(.footnote).foregroundStyle(palette.text2)
                            }
                            .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle("Split-Bibliothek")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $suche, prompt: "Name, Muskel oder Übung")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { schliessen() } } }
        }
    }

    private var filter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Abstand.s) {
                chip("Alle", aktiv: art == nil) { art = nil }
                ForEach(Array(SplitLogik.artWahl.enumerated()), id: \.offset) { _, a in chip(a.text, aktiv: art == a.id) { art = a.id } }
                Divider().frame(height: 24)
                chip("Alle Tage", aktiv: tage == nil) { tage = nil }
                ForEach(SplitLogik.tageWahl, id: \.self) { n in chip("\(n) Tage", aktiv: tage == n) { tage = n } }
            }
            .padding(.horizontal, Abstand.l)
        }
    }

    private func chip(_ text: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Text(text).font(.footnote.weight(.semibold))
                .foregroundStyle(aktiv ? palette.aufAkzent : palette.text)
                .padding(.horizontal, Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
                .background(aktiv ? palette.akzent : palette.flaeche, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}

/// Ein Split im Detail: die Wochenübersicht, jede Einheit mit ihren Übungen, darunter die beiden Wege ihn zu nutzen.
struct SplitDetailView: View {
    let sitzung: GymSitzung
    let vorlage: SplitVorlage
    let fertig: () -> Void
    @Environment(\.palette) private var palette
    @State private var ersetzen = false
    @State private var meldung: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: Abstand.xs) {
                    ForEach(Array(SplitLogik.wochenbild(vorlage).enumerated()), id: \.offset) { i, an in
                        VStack(spacing: 2) {
                            Text(HabitLogik.wochentagKuerzel[i]).font(.caption.weight(.semibold))
                            Image(systemName: an ? "checkmark.circle.fill" : "minus").accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(an ? palette.text : palette.text2)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(TrainingLogik.wochentagName[i]): \(an ? "Training" : "frei")")
                    }
                }
            } footer: {
                Text(SplitLogik.unterzeile(vorlage))
            }
            ForEach(vorlage.einheiten.indices, id: \.self) { i in
                let e = vorlage.einheiten[i]
                Section("\(e.name) · \(TrainingLogik.wochentageText(e.wochentage))") {
                    ForEach(e.uebungen.indices, id: \.self) { k in
                        let z = e.uebungen[k]
                        HStack {
                            Text(UebungsKatalog.nachId[z.uebung]?.name ?? "Übung").foregroundStyle(palette.text)
                            if z.supersatz == true { Image(systemName: "link").accessibilityLabel("Supersatz").foregroundStyle(palette.text2) }
                            Spacer(minLength: Abstand.s)
                            Text(SplitLogik.wdhText(z)).font(.footnote).foregroundStyle(palette.text2).monospacedDigit()
                        }
                    }
                }
            }
            Section {
                Button("Als meinen Plan übernehmen") {
                    if (sitzung.training?.plan.tage.isEmpty ?? true) { uebernehmen() } else { ersetzen = true }
                }
                .frame(minHeight: Abstand.tippflaeche)
                Button("Nur diese Woche testen") {
                    if sitzung.training?.testwocheStarten(vorlage) == true { fertig() } else { meldung = "In dieser Woche ist kein Tag mehr übrig. Probier es am Montag." }
                }
                .frame(minHeight: Abstand.tippflaeche)
            } footer: {
                Text("Testen ändert nur die laufende Woche, ab Montag gilt wieder dein Plan.")
            }
        }
        .scrollContentBackground(.hidden)
        .lumenHintergrund()
        .navigationTitle(vorlage.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Deinen Plan ersetzen?", isPresented: $ersetzen, titleVisibility: .visible) {
            Button("Ersetzen", role: .destructive) { uebernehmen() }
        } message: {
            Text("Dein jetziger Plan wird durch diesen Split ersetzt. Alte Trainings bleiben.")
        }
        .alert("Das geht gerade nicht", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK") { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
    }

    private func uebernehmen() {
        sitzung.training?.planSichern(SplitLogik.alsPlan(vorlage))
        fertig()
    }
}

/// Ein eigener Split ohne Vorlage (Idee 27): Name, 1 bis 6 Tage, jeder Tag mit eigenem Namen. Die Übungen kommen danach im Plan.
struct SplitFreiBlatt: View {
    let sitzung: GymSitzung
    @Environment(\.dismiss) private var schliessen
    @State private var name = ""
    @State private var anzahl = 3
    @State private var namen = Array(repeating: "", count: SplitFrei.tageBereich.upperBound)
    @State private var ersetzen = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Mein Split", text: $name) }
                Section {
                    Stepper("\(anzahl) \(anzahl == 1 ? "Tag" : "Tage") pro Woche", value: $anzahl, in: SplitFrei.tageBereich)
                    ForEach(0..<anzahl, id: \.self) { i in
                        TextField(SplitFrei.standardName(i + 1), text: $namen[i])
                    }
                } header: {
                    Text("Tage")
                } footer: {
                    Text("Die Wochentage verteilt Lumi gleichmäßig. Du änderst sie danach im Plan.")
                }
            }
            .navigationTitle("Eigener Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        if sitzung.training?.plan.tage.isEmpty ?? true { anlegen() } else { ersetzen = true }
                    }
                }
            }
            .confirmationDialog("Deinen Plan ersetzen?", isPresented: $ersetzen, titleVisibility: .visible) {
                Button("Ersetzen", role: .destructive) { anlegen() }
            } message: {
                Text("Dein jetziger Plan wird durch den neuen Split ersetzt. Alte Trainings bleiben.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func anlegen() {
        sitzung.training?.planSichern(SplitFrei.anlegen(name: name, tage: Array(namen.prefix(anzahl))))
        schliessen()
    }
}
