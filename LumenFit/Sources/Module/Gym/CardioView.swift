import SwiftUI

/// Die Felder einer Cardio-Einheit (Idee 29): Dauer, Distanz, Energie, Puls. Mit Plus und Minus statt Tippen.
struct GymCardioFelder: View {
    @Binding var minuten: Int
    @Binding var km: Double
    @Binding var kcal: Int
    @Binding var puls: Int

    var body: some View {
        Section("Was dein Gerät anzeigt") {
            Stepper(value: $minuten, in: 1...300, step: 5) {
                LabeledContent("Dauer", value: "\(minuten) min")
            }
            Stepper(value: $km, in: 0...100, step: 0.5) {
                LabeledContent("Distanz", value: km > 0 ? "\(TrainingLogik.kgText(km)) km" : "ohne")
            }
            Stepper(value: $kcal, in: 0...3000, step: 10) {
                LabeledContent("Energie", value: kcal > 0 ? "\(kcal) kcal" : "ohne")
            }
            Stepper(value: $puls, in: 0...220, step: 5) {
                LabeledContent("Puls im Schnitt", value: puls > 0 ? "\(puls)" : "ohne")
            }
        }
    }
}

/// Cardio-Übung im Training abschließen.
struct CardioAbschlussBlatt: View {
    let sitzung: GymSitzung
    let index: Int
    @State private var minuten = 20
    @State private var km = 0.0
    @State private var kcal = 0
    @State private var puls = 0
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                GymCardioFelder(minuten: $minuten, km: $km, kcal: $kcal, puls: $puls)
            }
            .navigationTitle("Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        sitzung.cardioAbschliessen(index, minuten: minuten, km: km > 0 ? km : nil, kcal: kcal > 0 ? kcal : nil, puls: puls > 0 ? puls : nil)
                        schliessen()
                    }
                }
            }
            .onAppear {
                if sitzung.liste.indices.contains(index) { minuten = sitzung.liste[index].planUebung.minuten ?? 20 }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Cardio ohne Training eintragen (Laufband oder Stairmaster): Dauer, Distanz, Energie und Puls; darunter die Einträge von heute.
struct CardioEingabeView: View {
    let sitzung: GymSitzung
    @State private var geraet = "laufband"
    @State private var minuten = 30
    @State private var km = 0.0
    @State private var kcal = 0
    @State private var puls = 0
    @Environment(\.dismiss) private var schliessen
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        NavigationStack {
            Form {
                Section("Gerät") {
                    Picker("Gerät", selection: $geraet) {
                        Text("Laufband").tag("laufband")
                        Text("Stairmaster").tag("stairmaster")
                    }
                    .pickerStyle(.segmented)
                }
                GymCardioFelder(minuten: $minuten, km: $km, kcal: $kcal, puls: $puls)
                heutige
            }
            .navigationTitle("Cardio eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
            }
        }
    }

    @ViewBuilder
    private var heutige: some View {
        let tag = Datum.text(umgebung.uhr())
        let eintraege = sitzung.training?.cardio(am: tag) ?? []
        if !eintraege.isEmpty {
            Section("Heute") {
                ForEach(eintraege) { e in
                    HStack {
                        Label(e.titel, systemImage: e.symbol)
                        Spacer()
                        Text(zeile(e)).font(.footnote).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Löschen", role: .destructive) { sitzung.training?.cardioLoeschen(e) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func zeile(_ e: CardioEintrag) -> String {
        var teile = ["\(e.minuten) min"]
        if let km = e.km { teile.append("\(TrainingLogik.kgText(km)) km") }
        if let p = sitzung.cardioPuls?.puls(e.id) { teile.append("Puls \(p)") }
        return teile.joined(separator: " · ")
    }

    private func sichern() {
        let eintrag = CardioEintrag(datum: Datum.text(umgebung.uhr()), geraet: geraet, minuten: minuten, kcal: kcal > 0 ? kcal : nil, km: km > 0 ? km : nil)
        sitzung.training?.cardioSichern(eintrag)
        sitzung.cardioPuls?.setze(eintrag.id, puls: puls > 0 ? puls : nil)
        schliessen()
    }
}
