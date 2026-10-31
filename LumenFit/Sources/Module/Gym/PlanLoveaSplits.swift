// Quelle: Lovea Health/GymNeu/SplitAnsichten.swift (SplitVorschauInhalt :217, SplitVorschauView :269, SplitGefuehrtView :348),
// GymNeu/SplitFreiAnsichten.swift (SplitFreiInhalt :43, SplitFreiView :73)
import SwiftUI
import UIKit

// Vorschau, geführtes Erstellen und eigener Split im Lovea-Aufbau. Wählen schreibt den Plan über `TrainingStore.planSichern`
// (`gym.plan`), genau wie der Lumen-Aufbau; die Ansichten hier ändern nur die Darstellung.

/// Reiner Inhalt der Vorschau: Wochenbild, Kürzel, dann jede Einheit mit ihren Übungen (Lovea `SplitVorschauInhalt`).
struct PlanLoveaVorschauInhalt: View {
    let vorlage: SplitVorlage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(SplitLogik.unterzeile(vorlage)).font(.subheadline).foregroundStyle(.secondary)
            PlanLoveaWochenbild(tage: SplitLogik.wochenbild(vorlage)).padding(.top, 12)
            HStack(spacing: 4) {
                ForEach(HabitLogik.wochentagKuerzel, id: \.self) { Text($0).frame(maxWidth: .infinity) }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .accessibilityHidden(true)
            ForEach(Array(vorlage.einheiten.enumerated()), id: \.offset) { _, e in einheit(e) }
        }
    }

    private func zeile(_ name: String, _ z: SplitVorlage.Zeile, video: Bool) -> some View {
        HStack {
            if video { Image(systemName: "play.circle").foregroundStyle(.secondary).accessibilityHidden(true) }
            Text(name).font(.body)
            // Lumen Fit zeigt Supersätze mit dem Kettensymbol.
            if z.supersatz == true { Image(systemName: "link").foregroundStyle(.secondary).accessibilityLabel("Supersatz") }
            Spacer(minLength: 12)
            Text(SplitLogik.wdhText(z)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityHint(video ? "Zeigt, wie die Übung geht" : "")
    }

    private func einheit(_ e: SplitVorlage.Einheit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(e.name).font(.title3.bold())
                Spacer()
                Text(TrainingLogik.wochentageText(e.wochentage)).font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 4)
            ForEach(Array(e.uebungen.enumerated()), id: \.offset) { i, z in
                if i > 0 { Divider() }
                if let u = UebungsKatalog.nachId[z.uebung] {
                    // Tipp öffnet die Übung mit Animation, damit man sieht, wie sie geht.
                    NavigationLink { UebungDetailView(id: u.id) } label: { zeile(u.name, z, video: true) }
                        .buttonStyle(.plain)
                } else {
                    zeile("Übung", z, video: false)
                }
            }
        }
    }
}

/// Ein Split ansehen und übernehmen oder nur diese Woche testen (Lovea `SplitVorschauView`): Übernehmen in der Leiste, Testen unter der Liste.
struct PlanLoveaVorschauView: View {
    let sitzung: GymSitzung
    let vorlage: SplitVorlage
    /// Nach dem Übernehmen oder Testen: zurück zur Plan-Seite.
    var fertig: () -> Void = {}

    @State private var frage = false
    @State private var keinTag = false
    @State private var erfolg = 0
    @State private var warnung = 0

    private var training: TrainingStore? { sitzung.training }
    private var planLeer: Bool { training?.plan.tage.isEmpty ?? true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PlanLoveaVorschauInhalt(vorlage: vorlage)
                if !planLeer { testKnopf }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle(vorlage.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Übernehmen") {
                    if planLeer { uebernehmen() } else { frage = true }
                }
                .fontWeight(.semibold)
                .frame(minHeight: 44)
            }
        }
        .confirmationDialog("Dein jetziger Plan wird ersetzt.", isPresented: $frage, titleVisibility: .visible) {
            Button("Plan ersetzen", role: .destructive) { uebernehmen() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Deine bisherigen Trainingstage und Gewichte im Plan gehen verloren. Der Verlauf bleibt.")
        }
        .alert("Diese Woche ist vorbei", isPresented: $keinTag) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Es ist kein Trainingstag mehr übrig. Probier das Split ab Montag.")
        }
        .haptik(.erfolg, bei: erfolg)
        .haptik(.warnung, bei: warnung)
    }

    /// Nur diese Woche: der feste Plan bleibt, ab Montag gilt er wieder (`WochenLogik.testStarten`).
    private var testKnopf: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: testen) {
                Text("Nur diese Woche testen")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .foregroundStyle(Color.primary)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(.federnd)
            .accessibilityHint("Dein fester Plan bleibt, ab Montag gilt er wieder")
            Text("Dein Plan und deine Gewichte bleiben. Ab Montag gilt er wieder.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 28)
    }

    private func testen() {
        guard training?.testwocheStarten(vorlage) == true else {
            warnung += 1
            keinTag = true
            return
        }
        erfolg += 1
        fertig()
    }

    private func uebernehmen() {
        training?.planSichern(SplitLogik.alsPlan(vorlage))
        erfolg += 1
        fertig()
    }
}

/// Drei Fragen, dann ein Vorschlag aus der Bibliothek (Lovea `SplitGefuehrtView`).
struct PlanLoveaGefuehrtView: View {
    let sitzung: GymSitzung
    var fertig: () -> Void = {}

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.bewegungAus) private var ruhig
    @State private var schritt = 0
    @State private var tage = 4
    @State private var ziel = "muskeln"
    @State private var geraet = "studio"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                fortschritt
                inhalt
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle(schritt < 3 ? "Geführt erstellen" : "Dein Vorschlag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if schritt > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zurück") { withAnimation(ruhig ? nil : Feder.schnell) { schritt -= 1 } }
                        .frame(minHeight: 44)
                }
            }
        }
        .haptik(.auswahl, bei: schritt)
    }

    private var fortschritt: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(i <= schritt ? Color.primary : Color(uiColor: .tertiarySystemFill)).frame(height: 3)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
        .accessibilityElement()
        .accessibilityLabel("Schritt \(schritt + 1) von 4")
    }

    @ViewBuilder
    private var inhalt: some View {
        switch schritt {
        case 0:
            frage("Wie oft pro Woche?", SplitLogik.tageWahl.map { "\($0) Tage" }, gewaehlt: SplitLogik.tageWahl.firstIndex(of: tage)) { tage = SplitLogik.tageWahl[$0] }
        case 1:
            frage("Was ist dein Ziel?", SplitLogik.ziele.map { $0.text }, gewaehlt: SplitLogik.ziele.firstIndex { $0.id == ziel }) { ziel = SplitLogik.ziele[$0].id }
        case 2:
            frage("Was steht dir zur Verfügung?", SplitLogik.geraete.map { $0.text }, gewaehlt: SplitLogik.geraete.firstIndex { $0.id == geraet }) { geraet = SplitLogik.geraete[$0].id }
        default:
            vorschlag
        }
    }

    private func frage(_ titel: String, _ texte: [String], gewaehlt: Int?, _ setzen: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titel).font(.title2.bold()).padding(.bottom, 10).accessibilityAddTraits(.isHeader)
            ForEach(Array(texte.enumerated()), id: \.offset) { i, text in
                if i > 0 { Divider() }
                Button {
                    setzen(i)
                    withAnimation(ruhig ? nil : Feder.schnell) { schritt += 1 }
                } label: {
                    frageZeile(text, an: i == gewaehlt)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(i == gewaehlt ? .isSelected : [])
            }
        }
    }

    private func frageZeile(_ text: String, an: Bool) -> some View {
        HStack {
            Text(text).font(.body.weight(.semibold)).foregroundStyle(Color.primary)
            Spacer()
            Image(systemName: an ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(an ? Color.primary : Color.secondary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 52)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var vorschlag: some View {
        if let v = SplitLogik.vorschlag(umgebung.daten?.ziele.koerper.geschlecht, tage: tage, ziel: ziel, geraet: geraet) {
            Text("Passt zu deinen Antworten").font(.footnote).foregroundStyle(.secondary)
            Text(v.name).font(.largeTitle.bold()).padding(.bottom, 6)
            PlanLoveaVorschauInhalt(vorlage: v)
            NavigationLink {
                PlanLoveaVorschauView(sitzung: sitzung, vorlage: v, fertig: fertig)
            } label: {
                Text("Ansehen und übernehmen")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .background(Color.primary, in: Capsule())
            }
            .buttonStyle(.federnd)
            .padding(.top, 24)
        } else {
            Text("Dafür gibt es noch keinen fertigen Split. Leg ihn selbst an.").font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

/// Frischer eigener Split. Ersetzt den jetzigen Plan (nach Rückfrage, wenn er Tage hat). Lovea `SplitFreiView` samt `SplitFreiInhalt`.
struct PlanLoveaFreiView: View {
    let sitzung: GymSitzung
    /// Nach dem Anlegen, hier weiter in den Editor.
    var angelegt: () -> Void = {}

    @State private var name = ""
    @State private var tage = 3
    @State private var namen = Array(repeating: "", count: SplitFrei.tageBereich.upperBound)
    @State private var frage = false
    @State private var erfolg = 0

    private var training: TrainingStore? { sitzung.training }

    var body: some View {
        Form {
            Section("Split") {
                TextField("Name, z. B. Mein Split", text: $name)
            }
            Section {
                Stepper(value: $tage, in: SplitFrei.tageBereich) {
                    Text("\(tage) \(tage == 1 ? "Tag" : "Tage") pro Woche").monospacedDigit()
                }
            }
            Section {
                ForEach(0..<tage, id: \.self) { i in
                    TextField(SplitFrei.standardName(i + 1), text: $namen[i])
                        .submitLabel(.next)
                }
            } header: {
                Text("Namen der Tage")
            } footer: {
                Text("Die Wochentage und Übungen stellst du danach pro Tag ein.")
            }
        }
        .navigationTitle("Neuer Split")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Anlegen") {
                    if training?.plan.tage.isEmpty ?? true { anlegen() } else { frage = true }
                }
                .fontWeight(.semibold)
                .frame(minHeight: 44)
            }
        }
        .confirmationDialog("Dein jetziger Plan wird ersetzt.", isPresented: $frage, titleVisibility: .visible) {
            Button("Plan ersetzen", role: .destructive) { anlegen() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Deine bisherigen Trainingstage und Gewichte im Plan gehen verloren. Der Verlauf bleibt.")
        }
        .haptik(.erfolg, bei: erfolg)
    }

    private func anlegen() {
        training?.planSichern(SplitFrei.anlegen(name: name, tage: Array(namen.prefix(tage))))
        erfolg += 1
        angelegt()
    }
}
