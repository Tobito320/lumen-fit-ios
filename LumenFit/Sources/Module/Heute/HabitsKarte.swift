import SwiftUI

/// Gewohnheiten (Idee 16): ein Haken per Tipp, Zähl-Gewohnheiten wie Wasser mit Plus und Minus, die Serie in Tagen oder Wochen.
/// Die Verwaltung (ausblenden, anlegen, löschen) steht in einer Zeile unten.
struct HabitsKarte: View {
    let habits: [HeuteHabitZeile]
    let tippe: (HeuteHabitZeile) -> Void
    let weniger: (HeuteHabitZeile) -> Void
    let verwalte: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            HeuteKartenKopf(symbol: "checkmark.circle", titel: "Gewohnheiten").padding(Abstand.l)
            ForEach(habits) { zeile in
                Haarlinie()
                HeuteHabitReihe(zeile: zeile, tippe: { tippe(zeile) }, weniger: { weniger(zeile) })
            }
            Haarlinie()
            Button(action: verwalte) {
                HStack {
                    Text("Gewohnheiten verwalten").font(.subheadline).foregroundStyle(palette.text)
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.medium)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HeuteHabitReihe: View {
    let zeile: HeuteHabitZeile
    let tippe: () -> Void
    let weniger: () -> Void
    @State private var zaehler = 0
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: zeile.habit.symbol).foregroundStyle(palette.text2).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(zeile.habit.name).font(.body).foregroundStyle(palette.text)
                if let unter = unterzeile { Text(unter).font(.footnote.weight(.medium)).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: Abstand.s)
            steuerung
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.xs)
        .frame(minHeight: 56)
        .haptik(zeile.habit.zaehlen ? .mehr : .auswahl, bei: zaehler)
        .accessibilityElement(children: .contain)
    }

    private var unterzeile: String? {
        [zeile.zaehlerText, zeile.serieText].compactMap { $0 }.joined(separator: " · ").nilWennLeer
    }

    @ViewBuilder
    private var steuerung: some View {
        if zeile.habit.zaehlen {
            HStack(spacing: 0) {
                Button { zaehler += 1; weniger() } label: { Image(systemName: "minus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .disabled(zeile.wert == 0)
                    .accessibilityLabel("\(zeile.habit.name) eins weniger")
                Button { zaehler += 1; tippe() } label: { Image(systemName: "plus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .accessibilityLabel("\(zeile.habit.name) eins mehr")
            }
            .foregroundStyle(palette.text)
            .accessibilityValue(zeile.zaehlerText ?? "")
        } else {
            Button { zaehler += 1; tippe() } label: {
                Image(systemName: zeile.erledigt ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(zeile.erledigt ? palette.text : palette.text2)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel(zeile.habit.name)
            .accessibilityValue(zeile.erledigt ? "erledigt" : "offen")
            .accessibilityHint(zeile.erledigt ? "Nimmt den Haken weg" : "Hakt ab")
        }
    }
}

private extension String {
    var nilWennLeer: String? { isEmpty ? nil : self }
}

/// Alle Gewohnheiten im Blatt: ausblenden, löschen (außer den eingebauten) und eine neue anlegen.
struct HabitVerwaltungView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var neu = false

    var body: some View {
        NavigationStack {
            List {
                if let daten = umgebung.daten {
                    ForEach(alle(daten)) { habit in
                        Toggle(isOn: Binding(get: { !(daten.habits.habits[habit.id]?.ausgeblendet ?? false) },
                                             set: { daten.habits.ausblenden(habit.id, !$0) })) {
                            Label(habit.name, systemImage: habit.symbol)
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                        .swipeActions {
                            if !habit.istEingebaut {
                                Button("Löschen", role: .destructive) { daten.habits.loeschen(habit.id) }
                            }
                        }
                    }
                }
                Button { neu = true } label: { Label("Neue Gewohnheit", systemImage: "plus") }
                    .frame(minHeight: Abstand.tippflaeche)
            }
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle("Gewohnheiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sheet(isPresented: $neu) { HabitFormularView() }
        }
    }

    private func alle(_ daten: DatenSatz) -> [Habit] {
        daten.habits.habits.values.filter { !Habit.nurHeute.contains($0.id) }.sorted { a, b in
            let ia = Habit.eingebaut.firstIndex { $0.id == a.id } ?? Int.max
            let ib = Habit.eingebaut.firstIndex { $0.id == b.id } ?? Int.max
            return ia != ib ? ia < ib : a.name < b.name
        }
    }
}

/// Neue Gewohnheit: Name, Symbol, Haken oder Zähler, Häufigkeit.
struct HabitFormularView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = HabitSymbole.alle[0]
    @State private var zaehlen = false
    @State private var tagesziel = 3
    @State private var proWoche = false
    @State private var wochenziel = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Zum Beispiel Dehnen", text: $name).frame(minHeight: Abstand.tippflaeche) }
                Section("Symbol") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: Abstand.tippflaeche), spacing: Abstand.s)], spacing: Abstand.s) {
                        ForEach(HabitSymbole.alle, id: \.self) { s in
                            Button { symbol = s } label: {
                                Image(systemName: s).frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                                    .foregroundStyle(symbol == s ? palette.aufAkzent : palette.text)
                                    .background(symbol == s ? palette.akzent : Color.clear, in: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(s)
                            .accessibilityAddTraits(symbol == s ? .isSelected : [])
                        }
                    }
                }
                Section("Wie oft") {
                    Toggle("Mehrmals am Tag zählen", isOn: $zaehlen)
                    if zaehlen { Stepper("Ziel: \(tagesziel) am Tag", value: $tagesziel, in: 1...20) }
                    Toggle("Nur einige Tage pro Woche", isOn: $proWoche)
                    if proWoche { Stepper("\(wochenziel) Tage pro Woche", value: $wochenziel, in: 1...7) }
                }
            }
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle("Neue Gewohnheit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }

    private func sichern() {
        guard let daten = umgebung.daten else { return }
        let habit = Habit(id: UUID().uuidString, name: name.trimmingCharacters(in: .whitespaces), symbol: symbol, farbe: HabitFarbe.grau.rawValue, zaehlen: zaehlen,
                          tagesziel: zaehlen ? tagesziel : nil, haeufigkeit: proWoche ? .proWoche(wochenziel) : .taeglich, fuer: "ich")
        daten.habits.anlegen(habit)
        dismiss()
    }
}
