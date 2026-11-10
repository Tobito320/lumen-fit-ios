// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Training beenden ("Fertig?"): Dauer, Sets, Volumen und Rekorde auf einen Blick, dann beenden (weiter zur Seite "Geschafft"), weiter trainieren oder verwerfen.
/// Hat sich der Aufbau geändert, fragt es einmal, ob der Plan so bleiben soll (`WorkoutLogik.neuerTag`).
struct TrainingBeendenView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var planBehalten = true
    @State private var tagName = ""
    @State private var notiz = ""
    @State private var verwerfen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    zusammenfassung
                    cardioDazu
                    fragen
                    TextField("Notiz zum Training (optional)", text: $notiz, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(Abstand.m)
                        .frame(minHeight: Abstand.tippflaeche)
                        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                        .accessibilityLabel("Notiz zum Training")
                    Button {
                        abschliessen()
                    } label: {
                        Label("Training beenden", systemImage: "stop.fill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.lumenHauptknopf)
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
        VStack(alignment: .leading, spacing: Abstand.s) {
            LaufKachelReihe {
                LaufKachel("Dauer") { Text(dauerText) }
                Divider()
                LaufKachel("Sets") { Text(sitzung.saetzeZahl, format: .number) }
                Divider()
                LaufKachel("Volumen") { Text("\(TrainingLogik.kgText(sitzung.volumen)) kg") }
            }
            if rekorde > 0 {
                Label(rekorde == 1 ? "1 Rekord heute" : "\(rekorde) Rekorde heute", systemImage: "trophy.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(palette.akzent)
                    .padding(.horizontal, Abstand.xs)
            }
        }
    }

    /// "Noch Cardio?": ein Tipp nimmt das Gerät ans Ende des Trainings und schließt das Blatt; danach wie jede Cardio-Übung abschließen.
    private var cardioDazu: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Noch Cardio?").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Abstand.s) {
                ForEach(CardioAmEnde.wahl, id: \.id) { g in
                    Button {
                        if let u = UebungsKatalog.nachId[g.id] {
                            sitzung.uebungDazu(u)
                            schliessen()
                        }
                    } label: {
                        Label(g.titel, systemImage: g.symbol).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Nimmt \(g.titel) ans Ende des Trainings")
                }
            }
        }
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    @ViewBuilder
    private var fragen: some View {
        if sitzung.tag != nil, sitzung.neuerTag != nil {
            Toggle("Plan so aktualisieren", isOn: $planBehalten)
                .padding(Abstand.l)
                .lumenKartenFlaeche()
        } else if sitzung.tag == nil, sitzung.liste.contains(where: { $0.fertigZahl > 0 }) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Als Trainingstag speichern?").font(.headline)
                TextField("Name, zum Beispiel Freitag", text: $tagName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: Abstand.tippflaeche)
                Text("Leer lassen, wenn du ihn nicht speichern willst.").font(.footnote).foregroundStyle(palette.text2)
            }
            .padding(Abstand.l)
            .lumenKartenFlaeche()
        }
    }

    private func abschliessen() {
        if sitzung.tag != nil, sitzung.neuerTag != nil, planBehalten { sitzung.planAktualisieren() }
        if sitzung.tag == nil, !tagName.trimmingCharacters(in: .whitespaces).isEmpty { sitzung.alsTagSpeichern(name: tagName) }
        sitzung.beende(notiz: notiz)
        schliessen()
        // Beenden -> Fertig? -> Geschafft (Entwurf): die Seite liegt auf Heute, "Fertig" dort führt zurück zu Heute.
        umgebung.router.oeffne(.gym(.geschafft))
    }
}

/// Die Cardio-Geräte am Ende des Trainings (Katalog-IDs).
enum CardioAmEnde {
    struct Geraet: Sendable {
        let id: String
        let titel: String
        let symbol: String
    }

    static let wahl: [Geraet] = [
        Geraet(id: "rjiM4L3", titel: String(localized: "Laufband"), symbol: "figure.walk.treadmill"),
        Geraet(id: "j9Q5crt", titel: String(localized: "Stepper"), symbol: "figure.stair.stepper"),
        Geraet(id: "rjtuP6X", titel: String(localized: "Crosstrainer"), symbol: "figure.elliptical"),
        Geraet(id: "a8VDgLw", titel: String(localized: "Fahrrad"), symbol: "figure.indoor.cycle"),
    ]
}

/// Einstellungen fürs Training (Idee 30): Training nach Health schreiben (Standard aus) und die Pulsmessung dieses Geräts.
struct GymEinstellungenBlatt: View {
    let sitzung: GymSitzung
    @Environment(\.dismiss) private var schliessen
    @AppStorage(GymPulsMessung.schluessel) private var pulsAn = false
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeit = false
    @AppStorage(GymAnzeige.rpeSpalteSchluessel) private var rpeSpalte = GymAnzeige.rpeSpalteStandard
    @AppStorage(GymAnzeige.pausenTimerSchluessel) private var pausenTimer = false
    @AppStorage(GymAnzeige.pausenTimerGefragtSchluessel) private var pausenTimerGefragt = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Pausen-Timer nach jedem Satz", isOn: $pausenTimer)
                        .onChange(of: pausenTimer) { _, _ in pausenTimerGefragt = true }
                } header: {
                    Text("Präferenzen")
                } footer: {
                    Text("Aus: der Haken setzt nur den Satz. An: nach jedem Satz läuft die Pause der Übung (Standard 2:00), am Ende Haptik und Band.")
                }
                SatzVorhersageAbschnitt()
                Section {
                    Toggle("Training nach Health schreiben", isOn: Binding(
                        get: { sitzung.einstellungen.healthSchreiben },
                        set: { neu in sitzung.daten?.einstellungen.aendere { $0.healthSchreiben = neu } }))
                } footer: {
                    Text("Beim Beenden entsteht ein Krafttraining in Health, mit der Dauer. Energie und Puls kommen nur dazu, wenn dein Sensor sie liefert. Nichts wird geschätzt.")
                }
                Section {
                    Toggle("Satz-Zeit messen", isOn: $satzzeit)
                    Toggle("Anstrengung (RPE) zeigen", isOn: $rpeSpalte)
                } footer: {
                    Text("Satz-Zeit: nach der Pause läuft die Uhr des Satzes; beim Haken wird die Dauer gemerkt. RPE: nach dem Haken erscheint die Anstrengung an der Zeile.")
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
        .presentationDetents([.medium, .large])
    }
}
