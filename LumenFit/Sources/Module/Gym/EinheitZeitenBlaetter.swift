// Quelle: Lovea Health/GymSession.swift (ZeitenBlatt, StartzeitBlatt, NachtragenBlatt; neu im Lumen-Design)
import SwiftUI

/// Zeiten einer beendeten Einheit ändern (Löschen steht seit 11.11.2026 im Menü der Einheit). Länger als drei Stunden fragt nach ("Warst du wirklich so lange im Gym?").
struct EinheitZeitenBlatt: View {
    let session: GymSession
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @State private var start: Date
    @State private var ende: Date
    @State private var langeStunden: Double?
    @State private var gesichert = 0

    /// `jetzt` kommt vom Aufrufer (`umgebung.uhr()`), damit das Ende ohne Wert einen Vorschlag hat.
    init(session: GymSession, jetzt: Date) {
        self.session = session
        _start = State(initialValue: session.start)
        _ende = State(initialValue: session.ende ?? EinheitZeitenLogik.endeVorschlag(start: session.start, jetzt: jetzt))
    }

    var body: some View {
        let jetzt = umgebung.uhr()
        NavigationStack {
            Form {
                Section {
                    DatePicker("Eingecheckt", selection: $start, in: ...jetzt)
                    DatePicker("Ausgecheckt", selection: $ende, in: start...max(start, jetzt))
                    LabeledContent("Dauer", value: TrainingLogik.dauerText(max(0, ende.timeIntervalSince(start))))
                }
            }
            .navigationTitle(Datum.anzeige(Datum.text(session.start)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { pruefen(jetzt) } }
            }
            .alert("Wirklich so lange?", isPresented: Binding(get: { langeStunden != nil }, set: { if !$0 { langeStunden = nil } })) {
                Button("Ja, so lange") { sichern() }
                Button("Zeit ändern", role: .cancel) { langeStunden = nil }
            } message: {
                Text(langeStunden.map(EinheitZeitenLogik.langeFrage) ?? "")
            }
        }
        .haptik(.erfolg, bei: gesichert)
    }

    private func pruefen(_ jetzt: Date) {
        switch EinheitZeitenLogik.pruefe(start: start, ende: ende, jetzt: jetzt) {
        case .ok: sichern()
        case .zuLang(let stunden): langeStunden = stunden
        case .ungueltig: break
        }
    }

    private func sichern() {
        umgebung.daten?.training.zeitenAendern(session, start: start, ende: max(ende, start))
        gesichert += 1
        schliessen()
    }
}

/// Nur die Startzeit eines laufenden Trainings ändern ("ich habe schon vor 20 Minuten angefangen").
/// Das Training läuft weiter; es wird nur der Check-in neu gesendet.
struct EinheitStartzeitBlatt: View {
    let session: GymSession
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @State private var start: Date
    @State private var gesichert = 0

    init(session: GymSession) {
        self.session = session
        _start = State(initialValue: session.start)
    }

    var body: some View {
        let jetzt = umgebung.uhr()
        NavigationStack {
            Form {
                Section {
                    DatePicker("Gestartet", selection: $start, in: EinheitZeitenLogik.startBereich(aktuell: session.start, jetzt: jetzt))
                } footer: {
                    Text("Das Training läuft weiter. Nur die Startzeit ändert sich, höchstens drei Stunden zurück.")
                }
            }
            .navigationTitle("Startzeit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        umgebung.daten?.training.zeitenAendern(session, start: start, ende: nil)
                        gesichert += 1
                        schliessen()
                    }
                }
            }
        }
        .haptik(.erfolg, bei: gesichert)
        .presentationDetents([.medium])
    }
}

/// Ein Training von Hand nachtragen: Start, Ende und Trainingstag. Mit `datum` (Tag mit Gym-Häkchen, aber ohne Einheit) liegen Start und Ende
/// schon an diesem Tag. Länger als drei Stunden fragt nach.
struct EinheitNachtragenBlatt: View {
    let datum: String?
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @State private var start: Date
    @State private var ende: Date
    @State private var tag: String?
    @State private var langeStunden: Double?
    @State private var gesichert = 0

    init(datum: String? = nil, jetzt: Date) {
        self.datum = datum
        let vorschlag = datum.map { GymTageLogik.nachtragVorschlag(datum: $0, jetzt: jetzt) } ?? (start: jetzt.addingTimeInterval(-90 * 60), ende: jetzt)
        _start = State(initialValue: vorschlag.start)
        _ende = State(initialValue: vorschlag.ende)
    }

    var body: some View {
        let jetzt = umgebung.uhr()
        let tage = umgebung.daten.map { WochenLogik.waehlbar($0.training.plan, heute: Datum.text(jetzt)) } ?? []
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $start, in: ...jetzt)
                    DatePicker("Ende", selection: $ende, in: start...max(start, jetzt))
                    LabeledContent("Dauer", value: TrainingLogik.dauerText(max(0, ende.timeIntervalSince(start))))
                } footer: {
                    if datum != nil {
                        Text("Gym abgehakt, keine Einheit gespeichert. Start und Ende sind nur ein Vorschlag, stell die echten Zeiten ein. Danach trägst du die Sätze in der Einheit nach.")
                    }
                }
                if !tage.isEmpty {
                    Section {
                        Picker("Trainingstag", selection: $tag) {
                            Text("Ohne Tag").tag(String?.none)
                            ForEach(tage) { t in Text(t.name.isEmpty ? String(localized: "Ohne Namen") : t.name).tag(String?.some(t.id)) }
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
            .navigationTitle("Training nachtragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { pruefen(jetzt) } }
            }
            .alert("Wirklich so lange?", isPresented: Binding(get: { langeStunden != nil }, set: { if !$0 { langeStunden = nil } })) {
                Button("Ja, so lange") { sichern() }
                Button("Zeit ändern", role: .cancel) { langeStunden = nil }
            } message: {
                Text(langeStunden.map(EinheitZeitenLogik.langeFrage) ?? "")
            }
        }
        .haptik(.erfolg, bei: gesichert)
        .presentationDetents([.medium])
    }

    private func pruefen(_ jetzt: Date) {
        switch EinheitZeitenLogik.pruefe(start: start, ende: ende, jetzt: jetzt) {
        case .ok: sichern()
        case .zuLang(let stunden): langeStunden = stunden
        case .ungueltig: break
        }
    }

    private func sichern() {
        umgebung.daten?.training.nachtragen(tag: tag, start: start, ende: max(ende, start))
        gesichert += 1
        schliessen()
    }
}

/// "Endzeit eintragen" bei vergessenem Auschecken: das Ende wählen statt eines festen Werts. Länger als drei Stunden fragt nach.
struct EinheitEndzeitBlatt: View {
    let session: GymSession
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @State private var ende: Date
    @State private var langeStunden: Double?
    @State private var gesichert = 0

    init(session: GymSession, jetzt: Date) {
        self.session = session
        _ende = State(initialValue: EinheitZeitenLogik.endeVorschlag(start: session.start, jetzt: jetzt))
    }

    var body: some View {
        let jetzt = umgebung.uhr()
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Eingecheckt", value: "\(Datum.anzeige(Datum.text(session.start))), \(Datum.uhrzeit(session.start))")
                    DatePicker("Ausgecheckt", selection: $ende, in: session.start...max(session.start, jetzt))
                    LabeledContent("Dauer", value: TrainingLogik.dauerText(max(0, ende.timeIntervalSince(session.start))))
                } footer: {
                    Text("Wann warst du fertig? Der Vorschlag ist anderthalb Stunden nach dem Start.")
                }
            }
            .navigationTitle("Endzeit eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Auschecken") { pruefen(jetzt) } }
            }
            .alert("Wirklich so lange?", isPresented: Binding(get: { langeStunden != nil }, set: { if !$0 { langeStunden = nil } })) {
                Button("Ja, so lange") { sichern() }
                Button("Zeit ändern", role: .cancel) { langeStunden = nil }
            } message: {
                Text(langeStunden.map(EinheitZeitenLogik.langeFrage) ?? "")
            }
        }
        .haptik(.erfolg, bei: gesichert)
        .presentationDetents([.medium])
    }

    private func pruefen(_ jetzt: Date) {
        switch EinheitZeitenLogik.pruefe(start: session.start, ende: ende, jetzt: jetzt) {
        case .ok: sichern()
        case .zuLang(let stunden): langeStunden = stunden
        case .ungueltig: break
        }
    }

    private func sichern() {
        umgebung.daten?.training.auschecken(session.id, ende: ende)
        gesichert += 1
        schliessen()
    }
}
