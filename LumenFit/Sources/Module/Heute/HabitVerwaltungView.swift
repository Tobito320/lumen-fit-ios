import SwiftUI

/// Alle Gewohnheiten im Blatt: antippen öffnet die Seite der Gewohnheit (Serie, Raster, Bearbeiten), wischen blendet aus oder löscht (außer die eingebauten),
/// unten legt eine neue an.
struct HabitVerwaltungView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var neu = false
    @State private var geaendert = 0

    var body: some View {
        NavigationStack {
            List {
                if let daten = umgebung.daten {
                    ForEach(alle(daten)) { habit in
                        zeile(habit, daten)
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
            .haptik(.auswahl, bei: geaendert)
        }
    }

    private func zeile(_ habit: Habit, _ daten: DatenSatz) -> some View {
        let aus = habit.ausgeblendet
        return NavigationLink {
            HabitDetailView(habitId: habit.id)
        } label: {
            HStack(spacing: Abstand.m) {
                Image(systemName: habit.symbol).foregroundStyle(habit.tint).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name).font(.body).foregroundStyle(palette.text)
                    Text(HabitLogik.haeufigkeitText(habit, ziel: daten.habits.habitZiel(habit.id))).font(.footnote).foregroundStyle(palette.text2)
                }
                Spacer(minLength: Abstand.s)
                if aus { Pille(text: "ausgeblendet", symbolName: "eye.slash") }
            }
            .frame(minHeight: Abstand.tippflaeche)
        }
        .swipeActions(edge: .leading) {
            Button(aus ? "Einblenden" : "Ausblenden", systemImage: aus ? "eye" : "eye.slash") {
                daten.habits.ausblenden(habit.id, !aus)
                geaendert += 1
            }
            .tint(palette.text2)
        }
        .swipeActions(edge: .trailing) {
            if !habit.istEingebaut {
                Button("Löschen", systemImage: "trash", role: .destructive) { daten.habits.loeschen(habit.id) }
            }
        }
        .accessibilityHint("Öffnet die Seite der Gewohnheit")
    }

    private func alle(_ daten: DatenSatz) -> [Habit] {
        daten.habits.habits.values.filter { !Habit.nurHeute.contains($0.id) }.sorted { a, b in
            let ia = Habit.eingebaut.firstIndex { $0.id == a.id } ?? Int.max
            let ib = Habit.eingebaut.firstIndex { $0.id == b.id } ?? Int.max
            return ia != ib ? ia < ib : a.name < b.name
        }
    }
}
