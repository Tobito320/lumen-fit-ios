import SwiftUI

/// Gewicht in drei Sekunden (Idee 17), Teil 2: das Blatt mit dem Zahlenrad. Es startet bei der letzten Messung, ein Tipp auf "Speichern" genügt.
/// Auf Wunsch (Schalter, Einstellung `healthSchreiben`) geht der Wert zurück nach Health. Erreichbar über die Route `gewichtEintragen` und als Blatt im Heute-Tab.
struct GewichtEintragenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var modell: HeuteModell?
    @State private var kilo = 75
    @State private var zehntel = 0
    @State private var gespeichert = 0
    @State private var fehler = false

    var body: some View {
        ScrollView {
            VStack(spacing: Abstand.l) {
                rad
                Button { speichern() } label: {
                    Text("Speichern").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.akzent)
                .foregroundStyle(palette.aufAkzent)
                if fehler {
                    Text("Das Gewicht muss zwischen 30 und 249,9 kg liegen.").font(.footnote.weight(.medium)).foregroundStyle(palette.text2)
                }
                healthSchalter
                if let g = modell?.stand?.gewicht, g.punkte.count >= 2 {
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        Text("Verlauf").font(.headline).foregroundStyle(palette.text)
                        HeuteGewichtDiagramm(punkte: g.punkte, ziel: g.zielKg).frame(height: 160)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Gewicht")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.erfolg, bei: gespeichert)
        .task {
            guard modell == nil else { return }
            let m = HeuteModell(umgebung: umgebung)
            m.berechne()
            modell = m
            let start = m.stand?.gewicht.startZehntel ?? 750
            kilo = min(max(start / 10, 30), 249)
            zehntel = start % 10
        }
    }

    private var rad: some View {
        HStack(spacing: 0) {
            Picker("Kilogramm", selection: $kilo) {
                ForEach(30...249, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 110)
            Text(",").font(.title.weight(.bold)).foregroundStyle(palette.text).accessibilityHidden(true)
            Picker("Zehntel", selection: $zehntel) {
                ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)
            Text("kg").font(.title3).foregroundStyle(palette.text2).padding(.leading, Abstand.s).accessibilityHidden(true)
        }
        .frame(height: 160)
        .accessibilityElement(children: .contain)
    }

    private var healthSchalter: some View {
        let daten = umgebung.daten
        return Toggle("Auch in Health speichern", isOn: Binding(
            get: { daten?.einstellungen.werte.healthSchreiben ?? false },
            set: { neu in daten?.einstellungen.aendere { $0.healthSchreiben = neu } }))
            .font(.subheadline)
            .foregroundStyle(palette.text)
            .frame(minHeight: Abstand.tippflaeche)
    }

    private func speichern() {
        guard let modell else { return }
        Task {
            if await modell.speichereGewicht(zehntel: kilo * 10 + zehntel) {
                gespeichert += 1
                dismiss()
            } else {
                fehler = true
            }
        }
    }
}
