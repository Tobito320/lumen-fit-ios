// Quelle: Lovea Health/Ernaehrung/ErnaehrungHinzufuegen.swift (SchnellEintragenBlatt)
import SwiftUI

/// Schnell eintragen: Kalorien (Pflicht), Name und Makros freiwillig, ohne ein Lebensmittel anzulegen.
enum EssenSchnellLogik {
    /// nil, solange die Kalorien fehlen oder keine Zahl sind. Der Eintrag zählt als eine "Portion" zu 100 g, damit 1 Portion = die eingegebenen Werte.
    static func lebensmittel(name: String, kcal: String, protein: String, kohlenhydrate: String, fett: String,
                             id: String = "schnell-\(UUID().uuidString)") -> Lebensmittel? {
        guard let k = ErnaehrungLogik.eingabe(kcal) else { return nil }
        let werte = Naehrwerte(kcal: k, protein: ErnaehrungLogik.eingabe(protein) ?? 0,
                               kohlenhydrate: ErnaehrungLogik.eingabe(kohlenhydrate) ?? 0, fett: ErnaehrungLogik.eingabe(fett) ?? 0)
        let titel = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Lebensmittel(id: id, name: titel.isEmpty ? "Schnell eingetragen" : titel, pro100: werte, portionMenge: 100, portionName: "Eintrag")
    }
}

/// Blatt "Schnell eintragen": trägt sofort als eine Portion in die Mahlzeit ein.
struct EssenSchnellEintragenBlatt: View {
    let mahlzeit: Mahlzeit
    let tag: String
    let fertig: @MainActor (Lebensmittel) -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var kohlenhydrate = ""
    @State private var fett = ""
    @State private var gesichert = 0

    private var ergebnis: Lebensmittel? {
        EssenSchnellLogik.lebensmittel(name: name, kcal: kcal, protein: protein, kohlenhydrate: kohlenhydrate, fett: fett)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (freiwillig)", text: $name).accessibilityLabel("Name, freiwillig")
                    EssenZahlFeld(titel: String(localized: "Kalorien"), einheit: "kcal", text: $kcal)
                }
                Section("Freiwillig") {
                    EssenZahlFeld(titel: String(localized: "Eiweiß"), einheit: "g", text: $protein)
                    EssenZahlFeld(titel: String(localized: "Kohlenhydrate"), einheit: "g", text: $kohlenhydrate)
                    EssenZahlFeld(titel: String(localized: "Fett"), einheit: "g", text: $fett)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Schnell eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .haptik(.erfolg, bei: gesichert)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Eintragen") { eintragen() }.disabled(ergebnis == nil || gesichert > 0) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { EssenTastatur.schliessen() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func eintragen() {
        guard let l = ergebnis, gesichert == 0, let essen = umgebung.daten?.essen else { return }
        essen.eintragen(l, menge: 1, einheit: .portion, mahlzeit: mahlzeit, datum: tag)
        gesichert += 1
        // Kurz warten, damit die Haptik noch auf der sichtbaren Ansicht ausgelöst wird.
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            dismiss()
            fertig(l)
        }
    }
}
