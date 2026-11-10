import SwiftUI

/// Blatt "Gewichtsziel" an der Gewicht-Karte (neues Design 10.11.2026): −/+ 1 kg, die Ziel-Linie im Diagramm wandert mit, "Fertig" sichert.
/// Schreibt dieselbe Einstellung wie Präferenzen > Ziele (`Ziele.gewichtKg`). "Kein Ziel" entspricht dem Schalter dort.
struct HeuteGewichtZielBlatt: View {
    let gewicht: HeuteGewicht
    let sichern: (Double?) -> Void
    @State private var ziel: Double
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    init(gewicht: HeuteGewicht, sichern: @escaping (Double?) -> Void) {
        self.gewicht = gewicht
        self.sichern = sichern
        _ziel = State(initialValue: gewicht.zielKg ?? (gewicht.aktuellKg ?? 75).rounded())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Abstand.l) {
                    HStack(spacing: Abstand.l) {
                        schritt("minus", -1, "1 kg weniger")
                        HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                            Text(ziel, format: HeuteFormat.zielKilo()).heuteHeldenZahl(44).foregroundStyle(palette.text)
                                .contentTransition(.numericText(value: ziel))
                            Text("kg").font(.headline).foregroundStyle(palette.text2)
                        }
                        .frame(minWidth: 140)
                        .accessibilityElement(children: .combine)
                        schritt("plus", 1, "1 kg mehr")
                    }
                    Text("Die Linie im Diagramm zeigt dein Ziel.").font(.subheadline).foregroundStyle(palette.text2).multilineTextAlignment(.center)
                    if gewicht.punkte.count >= 2 {
                        HeuteGewichtDiagramm(punkte: gewicht.punkte, ziel: ziel).frame(height: 120)
                    }
                    Button {
                        sichern(ziel)
                        dismiss()
                    } label: {
                        Text("Fertig").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.lumenHauptknopf)
                    if gewicht.zielKg != nil {
                        Button("Kein Ziel", role: .destructive) {
                            sichern(nil)
                            dismiss()
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                    }
                }
                .padding(Abstand.l)
            }
            .navigationTitle("Gewichtsziel")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .haptik(.auswahl, bei: ziel)
    }

    private func schritt(_ symbol: String, _ delta: Double, _ name: LocalizedStringKey) -> some View {
        Button {
            let neu = ziel + delta
            guard Koerpermasse.gewichtKg.contains(neu) else { return }
            withAnimation(Feder.schnell) { ziel = neu }
        } label: {
            Image(systemName: symbol).font(.title3.weight(.semibold)).frame(width: 52, height: 52)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(palette.text)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(name)
    }
}
