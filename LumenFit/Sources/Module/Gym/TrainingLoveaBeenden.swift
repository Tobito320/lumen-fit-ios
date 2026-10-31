// Quelle: Lovea Health/WorkoutView.swift (Alerts :151-190, "Als Trainingstag speichern?" :178) und GymSession.swift (ZeitenBlatt :165)
import SwiftUI

/// Die Rückfragen beim Beenden im Lovea-Aufbau, Wort für Wort wie in Lovea: "Warst du wirklich so lange im Gym?" (Ja, stimmt / Endzeit ändern /
/// Abbrechen), dann "Plan aktualisieren?" oder "Als Trainingstag speichern?". `ausloeser` wird `true`, wenn jemand "Beenden" tippt; der Ablauf steht in
/// `BeendenAblauf`. Beendet wird erst nach der letzten Antwort (siehe dort, warum nicht davor wie in Lovea).
struct LoveaBeendenFragen: ViewModifier {
    let sitzung: GymSitzung
    @Binding var ausloeser: Bool
    @Environment(AppUmgebung.self) private var umgebung
    @State private var zeitFrage = false
    @State private var planFrage: TrainingsTag?
    @State private var freiFrage = false
    @State private var freiName = ""
    @State private var zeiten: GymSession?

    func body(content: Content) -> some View {
        content
            .onChange(of: ausloeser) { _, neu in
                guard neu else { return }
                ausloeser = false
                weiter(sitzung.ersterBeendenSchritt())
            }
            .alert("Warst du wirklich so lange im Gym?", isPresented: $zeitFrage) {
                Button("Ja, stimmt") { weiter(sitzung.naechsterBeendenSchritt()) }
                Button("Endzeit ändern") { zeiten = sitzung.laufende }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text(zeitText)
            }
            .alert("Plan aktualisieren?", isPresented: Binding(get: { planFrage != nil }, set: { if !$0 { planFrage = nil } }), presenting: planFrage) { _ in
                Button("Plan aktualisieren") {
                    sitzung.planAktualisieren()
                    sitzung.beende()
                }
                Button("So lassen", role: .cancel) { sitzung.beende() }
            } message: { neu in
                Text("Du hast Sätze oder Übungen geändert. Soll \(neu.name.isEmpty ? "der Tag" : neu.name) beim nächsten Mal so aussehen?")
            }
            .alert("Als Trainingstag speichern?", isPresented: $freiFrage) {
                TextField("Name", text: $freiName)
                Button("Speichern") {
                    sitzung.alsTagSpeichern(name: freiName, einheitZuordnen: true)
                    sitzung.beende()
                }
                Button("Nein", role: .cancel) { sitzung.beende() }
            } message: {
                Text("Du hast ohne Trainingstag trainiert. Beim nächsten Mal steht es als Vorlage bereit.")
            }
            .sheet(item: $zeiten) { LoveaEndzeitBlatt(sitzung: sitzung, session: $0, jetzt: umgebung.uhr()) }
    }

    private func weiter(_ schritt: BeendenSchritt) {
        switch schritt {
        case .zeitFrage: zeitFrage = true
        case .planFrage: planFrage = sitzung.neuerTag
        case .freiFrage:
            freiName = ""
            freiFrage = true
        case .beenden: sitzung.beende()
        }
    }

    private var zeitText: String {
        guard let s = sitzung.laufende else { return "" }
        return "Gestartet um \(Datum.uhrzeit(s.start)), das sind \(TrainingLogik.dauerText(umgebung.uhr().timeIntervalSince(s.start)))."
    }
}

extension View {
    /// Hängt die Beenden-Rückfragen des Lovea-Aufbaus an (`LoveaBeendenFragen`).
    func loveaBeendenFragen(sitzung: GymSitzung, ausloeser: Binding<Bool>) -> some View {
        modifier(LoveaBeendenFragen(sitzung: sitzung, ausloeser: ausloeser))
    }
}

/// "Endzeit ändern" im laufenden Training (Lovea `ZeitenBlatt` auf der laufenden Einheit): Start und Ende wählen, Sichern beendet das Training mit diesen
/// Zeiten, "Einheit löschen" verwirft es. Das Training endet über `GymSitzung`, damit Pause, Puls und Live-Anzeige mit aufgeräumt werden.
struct LoveaEndzeitBlatt: View {
    let sitzung: GymSitzung
    let session: GymSession
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @State private var start: Date
    @State private var ende: Date
    @State private var loeschenFrage = false
    @State private var gesichert = 0
    @State private var geloescht = 0

    init(sitzung: GymSitzung, session: GymSession, jetzt: Date) {
        self.sitzung = sitzung
        self.session = session
        _start = State(initialValue: session.start)
        _ende = State(initialValue: EinheitZeitenLogik.endeVorschlag(start: session.start, jetzt: jetzt))
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
                Section {
                    Button("Einheit löschen", role: .destructive) { loeschenFrage = true }
                        .frame(minHeight: Abstand.tippflaeche)
                }
            }
            .navigationTitle(Datum.anzeige(Datum.text(session.start)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        sitzung.beendeMitZeiten(start: start, ende: ende)
                        gesichert += 1
                        schliessen()
                    }
                }
            }
            .confirmationDialog("Einheit löschen?", isPresented: $loeschenFrage, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    sitzung.verwerfen()
                    geloescht += 1
                    schliessen()
                }
            }
        }
        .haptik(.erfolg, bei: gesichert)
        .haptik(.warnung, bei: geloescht)
    }
}
