import SwiftUI

/// Eine neue Herausforderung: Duell (1:1), Gruppe (gegeneinander) oder gemeinsames Ziel; Maß, bei "Übung" eine der eigenen Übungen; Dauer; Personen
/// (nur aktive, nicht pausierte Verbindungen); bei gemeinsam das Ziel mit Vorschlag. Die Eingeladenen müssen annehmen.
struct CrewHerausforderungBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var art: Art = .duell
    @State private var mass: CrewMass = .saetze
    @State private var uebung = ""
    /// 0 = bis Sonntag, sonst Tage.
    @State private var dauer = 0
    @State private var personen: Set<String> = []
    /// nil = der Vorschlag gilt.
    @State private var ziel: Int?
    @State private var sendet = false
    @State private var fehler: String?

    private enum Art: String, CaseIterable, Identifiable {
        case duell, gruppe, gemeinsam
        var id: String { rawValue }
        var titel: String {
            switch self {
            case .duell: "Duell"
            case .gruppe: "Gruppe"
            case .gemeinsam: "Gemeinsam"
            }
        }
    }

    /// `vorauswahl`: diese Person ist schon gewählt (von ihrer Seite aus).
    init(vorauswahl: String? = nil) {
        _personen = State(initialValue: vorauswahl.map { Set([$0]) } ?? [])
    }

    private var crew: [VerbindungEintrag] { CrewLogik.crew(GymCrewQuelle.eintraege(umgebung)) }
    private var sessions: [GymSession] { umgebung.daten?.training.sessions ?? [] }

    /// Die eigenen Übungen mit Gewicht, nach Name (für das Maß Übung).
    private var eigeneUebungen: [String] {
        var namen: [String: String] = [:]
        for l in sessions.flatMap(\.laeufe) where CrewLogik.saetze(l).contains(where: { ($0.kg ?? 0) > 0 }) {
            let n = CrewLogik.anzeige(CrewLogik.uebungsName(l))
            namen[n.lowercased()] = namen[n.lowercased()] ?? n
        }
        return namen.values.sorted { $0.lowercased() < $1.lowercased() }
    }

    private var tage: Int {
        guard dauer == 0 else { return dauer }
        let jetzt = umgebung.uhr()
        return max(1, Int((CrewLogik.endeBisSonntag(jetzt: jetzt).timeIntervalSince(jetzt) / 86_400).rounded(.up)))
    }

    private var vorschlag: Int {
        let jetzt = umgebung.uhr()
        let ich = CrewLogik.woche(sessions: sessions, jetzt: jetzt).wert(mass)
        let andere = crew.filter { personen.contains($0.id) }.map { CrewLogik.woche($0.daten, jetzt: jetzt)?.wert(mass) }
        return CrewLogik.zielVorschlag(wochenwerte: [ich] + andere, tage: tage)
    }

    private var gueltig: Bool {
        let anzahl = personen.count
        let passt = switch art {
        case .duell: anzahl == 1
        case .gruppe: anzahl >= 2 && anzahl <= 9
        case .gemeinsam: anzahl >= 1 && anzahl <= 9
        }
        return passt && (mass != .uebung || !uebung.isEmpty) && !sendet
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $art) {
                        ForEach(Art.allCases) { Text($0.titel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: art) { _, neu in
                        if neu == .duell, personen.count > 1 { personen = [] }
                    }
                } footer: {
                    Text(art == .gemeinsam ? "Ihr arbeitet zusammen auf ein Ziel hin." : art == .duell ? "Du gegen eine Person." : "Alle gegeneinander, bis zu neun Personen.")
                }
                massAbschnitt
                Section("Dauer") {
                    Picker("Dauer", selection: $dauer) {
                        Text("Bis Sonntag").tag(0)
                        Text("7 Tage").tag(7)
                        Text("14 Tage").tag(14)
                        Text("28 Tage").tag(28)
                    }
                    .pickerStyle(.segmented)
                }
                personenAbschnitt
                if art == .gemeinsam { zielAbschnitt }
                Section {
                    Text(CrewTexte.sichtbar).font(.footnote).foregroundStyle(palette.text2)
                }
            }
            .navigationTitle("Herausfordern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") { Task { await senden() } }.disabled(!gueltig)
                }
            }
            .alert("Das hat nicht geklappt", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
                Button("Verstanden", role: .cancel) {}
            } message: { Text(fehler ?? "") }
        }
    }

    private var massAbschnitt: some View {
        Section {
            Picker("Woran", selection: $mass) {
                ForEach(CrewMass.allCases) { Label($0.titel, systemImage: $0.symbol).tag($0) }
            }
            if mass == .uebung {
                let liste = eigeneUebungen
                if liste.isEmpty {
                    Text("Trainiere zuerst eine Übung mit Gewicht.").foregroundStyle(palette.text2)
                } else {
                    Picker("Übung", selection: $uebung) {
                        Text("Wählen").tag("")
                        ForEach(liste, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
        } footer: {
            if mass == .uebung {
                Text("Zählt die Steigerung deines geschätzten 1RM gegen deinen Stand vor dem Start, in Promille (10 ‰ = 1 %). So ist es für jedes Niveau fair.")
            }
        }
    }

    private var personenAbschnitt: some View {
        Section("Mit wem") {
            if crew.isEmpty {
                Text("Lade zuerst Freunde ein: Crew, Freunde hinzufügen und verwalten.").foregroundStyle(palette.text2)
            }
            ForEach(crew) { e in
                let an = personen.contains(e.id)
                Button {
                    if an {
                        personen.remove(e.id)
                    } else if art == .duell {
                        personen = [e.id]
                    } else if personen.count < 9 {
                        personen.insert(e.id)
                    }
                } label: {
                    HStack {
                        Text(CrewLogik.name(e)).foregroundStyle(palette.text)
                        Spacer()
                        Image(systemName: an ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(an ? palette.akzent : palette.text2)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: Abstand.tippflaeche)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(an ? .isSelected : [])
            }
        }
    }

    private var zielAbschnitt: some View {
        let wert = ziel ?? vorschlag
        let schritt = mass == .volumen ? 100 : 1
        return Section {
            Stepper(value: Binding(get: { wert }, set: { ziel = $0 }), in: 1...10_000_000, step: schritt) {
                Text("Ziel: \(CrewLogik.wertText(wert, mass))").monospacedDigit()
            }
            if ziel != nil {
                Button("Vorschlag nehmen: \(CrewLogik.wertText(vorschlag, mass))") { ziel = nil }
            }
        } header: {
            Text("Gemeinsames Ziel")
        } footer: {
            Text("Der Vorschlag ist eure Woche zusammen, hochgerechnet auf die Dauer.")
        }
    }

    private func senden() async {
        sendet = true
        defer { sendet = false }
        let modus: CrewModus = art == .gemeinsam ? .gemeinsam : .gegen
        let neu = CrewNeueHerausforderung(art: mass, modus: modus, tage: dauer == 0 ? nil : dauer, ziel: ziel ?? vorschlag,
                                          uebung: uebung, einladen: Array(personen), jetzt: umgebung.uhr())
        if let f = await CrewDienst.von(umgebung).erstellen(neu) {
            fehler = f
        } else {
            dismiss()
        }
    }
}
