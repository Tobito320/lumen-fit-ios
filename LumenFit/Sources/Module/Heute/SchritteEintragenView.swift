// Quelle: Lovea Health/HealthTab.swift (SchritteEintragenBlatt)
import SwiftUI

/// Schritte für einen Tag von Hand, wenn kein Tracker zählt. Gilt mit Health und Band je Tag der größte Wert (Op `fit.schritte.hand`).
struct SchritteEintragenView: View {
    let gespeichert: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @State private var datum = Date()
    @State private var text = ""
    @State private var fertig = 0
    @FocusState private var fokus: Bool

    private var anzahl: Int? { SchritteHandLogik.anzahl(text) }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Tag", selection: $datum, in: ...umgebung.uhr(), displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                    .environment(\.timeZone, Datum.zone)
                    .frame(minHeight: Abstand.tippflaeche)
                TextField("Schritte", text: $text)
                    .keyboardType(.numberPad)
                    .focused($fokus)
                    .frame(minHeight: Abstand.tippflaeche)
                    .onAppear { fokus = true }
                Section { Text("Zählt Health oder das Band an diesem Tag mehr, gilt der größere Wert.").font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle("Schritte eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() }.disabled(anzahl == nil) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { fokus = false }
                }
            }
            .haptik(.erfolg, bei: fertig)
        }
        .presentationDetents([.medium])
    }

    private func speichern() {
        guard let anzahl, let daten = umgebung.daten else { return }
        let tag = Datum.text(datum)
        daten.raum.senden(SchritteHandLogik.art, SchritteHandD(tag: tag, anzahl: anzahl))
        umgebung.ereignisse.senden(.healthAktualisiert)
        fertig += 1
        gespeichert()
        dismiss()
    }
}
