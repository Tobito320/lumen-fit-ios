// Quelle: Lovea Health/Ernaehrung/HinzufuegenTeile.swift (VorschlaegeBlatt) und ErnaehrungHinzufuegen.swift (vorschlaegeAuswahl)
import SwiftUI

/// Regeln zum Mehrtreffer-Blatt: ein gewählter Vorschlag wird als eigenes Lebensmittel mit dem gescannten Code gespeichert.
enum EssenMehrtrefferLogik {
    /// Kopie des Vorschlags als eigenes Lebensmittel mit neuer ID und dem gescannten Barcode, damit der nächste Scan es auch ohne Netz findet.
    static func alsEigenes(_ l: Lebensmittel, code: String, id: String = "eigen-\(UUID().uuidString)") -> Lebensmittel {
        var k = l
        k.id = id
        k.barcode = BarcodeLogik.normal(code)
        k.quelle = nil
        return k
    }
}

/// "Meintest du ...?" bei einem unbekannten Barcode, zu dem es Namens-Vorschläge gibt. Auch für die Zutat-Suche im Rezept nutzbar.
struct EssenMehrtrefferBlatt: View {
    let name: String
    let treffer: [Lebensmittel]
    let auswahl: @MainActor (Lebensmittel) -> Void
    let keinesDavon: @MainActor () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Abstand.m) {
                    ListenKarte {
                        ForEach(Array(treffer.enumerated()), id: \.element.id) { i, l in
                            if i > 0 { Haarlinie() }
                            Button { dismiss(); auswahl(l) } label: {
                                EssenLebensmittelZeile(lebensmittel: l).padding(.horizontal, Abstand.l)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button { dismiss(); keinesDavon() } label: {
                        Text("Nichts davon, Nährwerte fotografieren").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(Abstand.l)
            }
            .navigationTitle("Meintest du \(name)?")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
