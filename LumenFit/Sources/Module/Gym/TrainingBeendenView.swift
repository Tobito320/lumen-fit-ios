// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Training beenden: Dauer, Sätze, Volumen und Rekorde auf einen Blick, dann beenden, weiter trainieren oder verwerfen.
/// Hat sich der Aufbau geändert, fragt es einmal, ob der Plan so bleiben soll (`WorkoutLogik.neuerTag`).
struct TrainingBeendenView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var planBehalten = true
    @State private var tagName = ""
    @State private var verwerfen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    zusammenfassung
                    fragen
                    Button {
                        abschliessen()
                    } label: {
                        Label("Training beenden", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { schliessen() } label: { Text("Weiter trainieren").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                    Button(role: .destructive) { verwerfen = true } label: { Text("Training verwerfen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle("Fertig?")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Das Training wird nicht gespeichert.", isPresented: $verwerfen, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) {
                    sitzung.verwerfen()
                    schliessen()
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Teile

    private var dauerText: String {
        guard let s = sitzung.laufende else { return "–" }
        return TrainingLogik.dauerText(umgebung.uhr().timeIntervalSince(s.start))
    }

    private var rekorde: Int {
        guard let s = sitzung.laufende else { return 0 }
        let frueher = (sitzung.training?.sessions ?? []).filter { $0.id != s.id && $0.start < s.start }
        return RekordLogik.anzahl(sitzung.liste, frueher: frueher)
    }

    private var zusammenfassung: some View {
        HeroKarte(platte: true) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                HStack(alignment: .top) {
                    kennzahl("Dauer", dauerText)
                    Spacer()
                    kennzahl("Sätze", "\(sitzung.saetzeZahl)")
                    Spacer()
                    kennzahl("Volumen", "\(TrainingLogik.kgText(sitzung.volumen)) kg")
                }
                if rekorde > 0 {
                    Label("\(rekorde) \(rekorde == 1 ? "Rekord" : "Rekorde") heute", systemImage: "medal.fill").font(.subheadline.weight(.semibold))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func kennzahl(_ titel: String, _ wert: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.footnote.weight(.semibold)).textCase(.uppercase)
            Text(wert).font(.title2.weight(.bold)).fontDesign(.rounded).monospacedDigit()
        }
    }

    @ViewBuilder
    private var fragen: some View {
        if sitzung.tag != nil, sitzung.neuerTag != nil {
            Toggle("Plan so aktualisieren", isOn: $planBehalten)
                .padding(Abstand.l)
                .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        } else if sitzung.tag == nil, sitzung.liste.contains(where: { $0.fertigZahl > 0 }) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Als Trainingstag speichern?").font(.headline)
                TextField("Name, zum Beispiel Freitag", text: $tagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: Abstand.tippflaeche)
                Text("Leer lassen, wenn du ihn nicht speichern willst.").font(.footnote).foregroundStyle(palette.text2)
            }
            .padding(Abstand.l)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        }
    }

    private func abschliessen() {
        if sitzung.tag != nil, sitzung.neuerTag != nil, planBehalten { sitzung.planAktualisieren() }
        if sitzung.tag == nil, !tagName.trimmingCharacters(in: .whitespaces).isEmpty { sitzung.alsTagSpeichern(name: tagName) }
        sitzung.beende()
        schliessen()
    }
}

/// Einstellungen fürs Training (Idee 30): Training nach Health schreiben (Standard aus) und die Pulsmessung dieses Geräts.
struct GymEinstellungenBlatt: View {
    let sitzung: GymSitzung
    @Environment(\.dismiss) private var schliessen
    @AppStorage(GymPulsMessung.schluessel) private var pulsAn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Training nach Health schreiben", isOn: Binding(
                        get: { sitzung.einstellungen.healthSchreiben },
                        set: { neu in sitzung.daten?.einstellungen.aendere { $0.healthSchreiben = neu } }))
                } footer: {
                    Text("Beim Beenden entsteht ein Krafttraining in Health, mit der Dauer. Energie und Puls kommen nur dazu, wenn dein Sensor sie liefert. Nichts wird geschätzt.")
                }
                Section {
                    Toggle("Puls und Energie messen", isOn: $pulsAn)
                } footer: {
                    Text("Nur mit AirPods Pro 3, Pulsgurt oder Uhr. Ohne Sensor gibt es keinen Puls. Die Messung kostet Akku und läuft nur während des Trainings.")
                }
            }
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
            // Mitten im Training eingeschaltet: die Messung startet gleich, nicht erst beim nächsten Training.
            .onChange(of: pulsAn) { _, an in if an, sitzung.sessionId != nil { sitzung.puls.starten() } }
        }
        .presentationDetents([.medium])
    }
}
