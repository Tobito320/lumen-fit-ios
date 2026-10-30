// Quelle: Lovea Health/Cardio.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Zahl-Binding aus einem optionalen Wert: 0 heißt "ohne" (nil).
enum CardioBindung {
    static func zahl(_ b: Binding<Int?>) -> Binding<Int> {
        Binding(get: { b.wrappedValue ?? 0 }, set: { b.wrappedValue = $0 > 0 ? $0 : nil })
    }

    static func kommazahl(_ b: Binding<Double?>) -> Binding<Double> {
        Binding(get: { b.wrappedValue ?? 0 }, set: { b.wrappedValue = $0 > 0 ? $0 : nil })
    }
}

/// Die Felder einer Cardio-Einheit (Idee 29): Dauer, Energie, Puls und je Gerät die Werte, die es anzeigt (Laufband: Entfernung, Höhe;
/// Stairmaster: Stufen, Etagen) und was eingestellt war (Steigung, Geschwindigkeit, Stufe). Mit Plus und Minus statt Tippen.
/// Die Schritte sind geschätzt (`CardioEintrag.schritteCa`).
struct GymCardioFelder: View {
    @Binding var eintrag: CardioEintrag
    @Binding var puls: Int

    private var laufband: Bool { eintrag.geraet != "stairmaster" }

    var body: some View {
        Section("Was dein Gerät anzeigt") {
            Stepper(value: $eintrag.minuten, in: 1...300, step: 5) {
                LabeledContent("Dauer", value: "\(eintrag.minuten) min")
            }
            Stepper(value: CardioBindung.zahl($eintrag.kcal), in: 0...3000, step: 10) {
                LabeledContent("Energie", value: (eintrag.kcal ?? 0) > 0 ? "\(eintrag.kcal ?? 0) kcal" : "ohne")
            }
            if laufband {
                Stepper(value: CardioBindung.kommazahl($eintrag.km), in: 0...100, step: 0.5) {
                    LabeledContent("Entfernung", value: (eintrag.km ?? 0) > 0 ? "\(TrainingLogik.kgText(eintrag.km ?? 0)) km" : "ohne")
                }
                Stepper(value: CardioBindung.zahl($eintrag.hoehe), in: 0...2000, step: 10) {
                    LabeledContent("Höhe", value: (eintrag.hoehe ?? 0) > 0 ? "\(eintrag.hoehe ?? 0) m" : "ohne")
                }
            } else {
                Stepper(value: CardioBindung.zahl($eintrag.stufen), in: 0...5000, step: 10) {
                    LabeledContent("Stufen", value: (eintrag.stufen ?? 0) > 0 ? "\(eintrag.stufen ?? 0)" : "ohne")
                }
                Stepper(value: CardioBindung.zahl($eintrag.etagen), in: 0...500) {
                    LabeledContent("Etagen", value: (eintrag.etagen ?? 0) > 0 ? "\(eintrag.etagen ?? 0)" : "ohne")
                }
            }
            Stepper(value: $puls, in: 0...220, step: 5) {
                LabeledContent("Puls im Schnitt", value: puls > 0 ? "\(puls)" : "ohne")
            }
        }
        Section("Eingestellt") {
            if laufband {
                Stepper(value: CardioBindung.kommazahl($eintrag.steigung), in: 0...30, step: 0.5) {
                    LabeledContent("Steigung", value: (eintrag.steigung ?? 0) > 0 ? "\(TrainingLogik.kgText(eintrag.steigung ?? 0)) %" : "ohne")
                }
                Stepper(value: CardioBindung.kommazahl($eintrag.kmh), in: 0...25, step: 0.5) {
                    LabeledContent("Geschwindigkeit", value: (eintrag.kmh ?? 0) > 0 ? "\(TrainingLogik.kgText(eintrag.kmh ?? 0)) km/h" : "ohne")
                }
            } else {
                Stepper(value: CardioBindung.zahl($eintrag.stufe), in: 0...30) {
                    LabeledContent("Stufe", value: (eintrag.stufe ?? 0) > 0 ? "\(eintrag.stufe ?? 0)" : "ohne")
                }
            }
        }
        if let s = eintrag.schritteCa {
            Section {
                LabeledContent("Schritte", value: "ca. \(s.formatted())")
            } footer: {
                Text(laufband ? "Geschätzt aus der Entfernung." : "Eine Stufe zählt als ein Schritt.")
            }
        }
    }
}

/// Cardio-Übung im Training abschließen.
struct CardioAbschlussBlatt: View {
    let sitzung: GymSitzung
    let index: Int
    @State private var eintrag: CardioEintrag
    @State private var puls = 0
    @State private var gesichert = 0
    @Environment(\.dismiss) private var schliessen

    init(sitzung: GymSitzung, index: Int) {
        self.sitzung = sitzung
        self.index = index
        let u = sitzung.liste.indices.contains(index) ? sitzung.liste[index].planUebung : nil
        _eintrag = State(initialValue: CardioEintrag(datum: "", geraet: TrainingLogik.cardioGeraet(u?.katalog) ?? "laufband", minuten: u?.minuten ?? 20))
    }

    var body: some View {
        NavigationStack {
            Form {
                GymCardioFelder(eintrag: $eintrag, puls: $puls)
            }
            .navigationTitle("Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        sitzung.cardioAbschliessen(index, eintrag: eintrag, puls: puls > 0 ? puls : nil)
                        gesichert += 1
                        schliessen()
                    }
                }
            }
            .haptik(.erfolg, bei: gesichert)
        }
        .presentationDetents([.medium, .large])
    }
}

/// Cardio ohne Training eintragen (Laufband oder Stairmaster): Dauer, Distanz, Energie und Puls; darunter die Einträge von heute.
struct CardioEingabeView: View {
    let sitzung: GymSitzung
    @State private var eintrag: CardioEintrag
    @State private var puls = 0
    @State private var gesichert = 0
    @Environment(\.dismiss) private var schliessen
    @Environment(AppUmgebung.self) private var umgebung

    /// `geraet`: "laufband" oder "stairmaster" (die Schnellknöpfe der Startseite); die Dauer startet mit 30 beziehungsweise 20 min.
    init(sitzung: GymSitzung, geraet: String = "laufband") {
        self.sitzung = sitzung
        _eintrag = State(initialValue: CardioEintrag(datum: "", geraet: geraet, minuten: geraet == "stairmaster" ? 20 : 30))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gerät") {
                    Picker("Gerät", selection: $eintrag.geraet) {
                        Text("Laufband").tag("laufband")
                        Text("Stairmaster").tag("stairmaster")
                    }
                    .pickerStyle(.segmented)
                }
                GymCardioFelder(eintrag: $eintrag, puls: $puls)
                heutige
            }
            .navigationTitle("Cardio eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Schließen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() } }
            }
            .haptik(.erfolg, bei: gesichert)
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
        var neu = eintrag
        neu.datum = Datum.text(umgebung.uhr())
        sitzung.training?.cardioSichern(neu)
        sitzung.cardioPuls?.setze(neu.id, puls: puls > 0 ? puls : nil)
        gesichert += 1
        schliessen()
    }
}
