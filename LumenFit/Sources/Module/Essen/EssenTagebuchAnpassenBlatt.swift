// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (TagebuchAnpassenBlatt), ohne Live-Aktivität (eigenes Paket)
import SwiftUI

/// "Tagebuch anpassen": Abschnitte des Essen-Tabs sortieren und ausblenden, Mahlzeiten umbenennen.
/// Gespeichert über `EssenStore.anpassungSichern`; das Modell bildet Reihenfolge, Ausblenden und Namen schon ab.
struct EssenTagebuchAnpassenBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var reihenfolge = TagebuchAnpassung.alleAbschnitte
    @State private var ausgeblendet: Set<String> = []
    @State private var namen: [String: String] = [:]
    @State private var geladen = false
    @State private var gesichert = 0

    init() {}

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(reihenfolge, id: \.self) { id in
                        Toggle(EssenMahlzeitenLogik.abschnittTitel(id), isOn: Binding(
                            get: { !ausgeblendet.contains(id) },
                            set: { an in
                                if an { ausgeblendet.remove(id) } else { ausgeblendet.insert(id) }
                            }))
                            .frame(minHeight: Abstand.tippflaeche)
                            .listRowBackground(palette.flaeche)
                    }
                    .onMove { reihenfolge.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("Abschnitte")
                } footer: {
                    Text("Ziehen zum Sortieren, Schalter zum Ausblenden.")
                }
                Section("Mahlzeiten") {
                    ForEach(Mahlzeit.allCases) { m in
                        HStack(spacing: Abstand.m) {
                            Image(systemName: m.symbol).foregroundStyle(palette.text2).frame(width: 28).accessibilityHidden(true)
                            TextField(m.name, text: Binding(
                                get: { namen[m.rawValue] ?? "" },
                                set: { namen[m.rawValue] = $0 }))
                                .accessibilityLabel("Name für \(m.name)")
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                        .listRowBackground(palette.flaeche)
                    }
                }
                Section {
                    Toggle("Intervallfasten zeigen", isOn: Binding(
                        get: { umgebung.daten?.einstellungen.werte.fastenAn ?? false },
                        set: { neu in umgebung.daten?.einstellungen.aendere { $0.fastenAn = neu } }))
                        .frame(minHeight: Abstand.tippflaeche)
                        .listRowBackground(palette.flaeche)
                } header: {
                    Text("Fasten")
                } footer: {
                    Text("Aus blendet nur aus, deine Fasten-Daten bleiben.")
                }
                EssenLiveSchalter()
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .fontDesign(.rounded)
            .lumenHintergrund()
            .navigationTitle("Tagebuch anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
            }
            .haptik(.erfolg, bei: gesichert)
            .task { laden() }
        }
    }

    private func laden() {
        guard !geladen, let a = umgebung.daten?.essen.anpassung else { return }
        geladen = true
        reihenfolge = EssenMahlzeitenLogik.startReihenfolge(a)
        ausgeblendet = Set(a.ausgeblendet)
        namen = a.mahlzeitNamen
    }

    private func speichern() {
        umgebung.daten?.essen.anpassungSichern(
            EssenMahlzeitenLogik.anpassung(reihenfolge: reihenfolge, ausgeblendet: ausgeblendet, namen: namen))
        gesichert += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            dismiss()
        }
    }
}
