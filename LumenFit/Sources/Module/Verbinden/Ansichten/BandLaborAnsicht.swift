// Quelle: Lovea Health/Tracker/BandLaborAnsicht.swift
import SwiftUI

/// Das Band-Labor: Befehl senden, beim Spüren auf Start und beim Ende auf Vorbei tippen, Ergebnis speichern. Nichts läuft von allein
/// (Akku): jeder Befehl kommt von einem Tipp. Gesendet wird nur der Finden-Befehl, den das Protokoll belegt; sonst wird nur gelesen.
struct BandLaborAnsicht: View {
    let modell: TrackerModell
    @Environment(\.palette) private var palette
    @AppStorage(BandLaborSpeicher.nutzenSchluessel) private var nutzen = false
    @State private var messungen = BandLaborSpeicher.messungen()
    @State private var lauf: Lauf?
    @State private var abstand = BandLaborAuswertung.abstaende[1]
    @State private var sendeAufgabe: Task<Void, Never>?

    /// Eine laufende Messung: was gesendet wurde, wann, und wann der Nutzer den Puls zu spüren begann.
    struct Lauf: Equatable {
        var art: BandLaborMessung.Art
        var abstand: Double?
        var gesendet: Date
        var start: Date?
    }

    private var verbunden: Bool { modell.zustand == .verbunden }

    var body: some View {
        Form {
            verbindungAbschnitt.listRowBackground(palette.flaeche)
            einzelAbschnitt.listRowBackground(palette.flaeche)
            doppelAbschnitt.listRowBackground(palette.flaeche)
            if lauf != nil { stoppuhrAbschnitt.listRowBackground(palette.flaeche) }
            ergebnisAbschnitt.listRowBackground(palette.flaeche)
            messungenAbschnitt.listRowBackground(palette.flaeche)
        }
        .verbindenFormular()
        .navigationTitle("Band-Labor")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { sendeAufgabe?.cancel() }
    }

    // MARK: Verbindung

    private var verbindungAbschnitt: some View {
        Section {
            LabeledContent("Band", value: modell.statusText)
            if let akku = modell.akku {
                LabeledContent("Akku", value: akku.laedt ? "\(akku.prozent) % (lädt)" : "\(akku.prozent) %")
            }
            Button("Akku lesen (nur Lesen)") { modell.abfragen() }
                .frame(minHeight: 44)
                .disabled(!verbunden)
        } header: {
            Text("Verbindung")
        } footer: {
            Text("Trag das Band am Arm. Lesen ändert nichts am Band. Andere Befehle als Finden sendet das Labor nicht, weil das Protokoll sie nicht als Vibration belegt.")
        }
    }

    // MARK: Messen

    private var einzelAbschnitt: some View {
        Section {
            Button("Finden-Befehl senden") { einzelStarten() }
                .frame(minHeight: 44)
                .disabled(!verbunden || lauf != nil)
        } header: {
            Text("Ein Befehl")
        } footer: {
            Text("Nach dem Senden tippst du auf Spüre ich es, sobald das Band vibriert, und auf Vorbei, sobald es aufhört. Mehrmals wiederholen, die Mitte zählt.")
        }
    }

    private var doppelAbschnitt: some View {
        Section {
            Picker("Abstand", selection: $abstand) {
                ForEach(BandLaborAuswertung.abstaende, id: \.self) { Text(Self.sekunden($0)).tag($0) }
            }
            .pickerStyle(.segmented)
            Button("Zwei Befehle senden") { doppelStarten() }
                .frame(minHeight: 44)
                .disabled(!verbunden || lauf != nil)
        } header: {
            Text("Zwei Befehle hintereinander")
        } footer: {
            Text("Der zweite Befehl geht mitten im ersten Puls raus. Tippe auf Spüre ich es beim Beginn und auf Vorbei, wenn das Band ganz still ist. Erst mit einer Einzelmessung gibt es ein Urteil.")
        }
    }

    private var stoppuhrAbschnitt: some View {
        Section {
            if let lauf {
                if let start = lauf.start {
                    TimelineView(.periodic(from: .now, by: 0.1)) { zeit in
                        Text(Self.sekunden(zeit.date.timeIntervalSince(start)))
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)
                    }
                    Button("Vorbei") { beenden() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                } else {
                    Button("Spüre ich es") { spuerenStarten() }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }
            }
            Button("Abbrechen", role: .cancel) { abbrechen() }
                .frame(minHeight: 44)
        } header: {
            Text("Stoppuhr")
        }
    }

    // MARK: Ergebnis

    private var ergebnisAbschnitt: some View {
        Section {
            let puls = BandLaborAuswertung.pulsLaenge(messungen)
            LabeledContent("Gemessene Pulslänge", value: puls.map(Self.sekunden) ?? "noch keine")
            LabeledContent("Lumen Fit rechnet mit", value: Self.sekunden(TrackerProtokoll.findenPulsDauer))
            if let puls {
                Button("Gemessene Länge übernehmen") {
                    BandLaborSpeicher.pulsDauerSetzen(puls)
                }
                .frame(minHeight: 44)
            }
            Toggle("Gemessene Länge nutzen", isOn: $nutzen)
                .frame(minHeight: 44)
            if let urteil = BandLaborAuswertung.gesamtUrteil(messungen) {
                LabeledContent("Zweiter Befehl", value: urteil.text)
            }
        } header: {
            Text("Ergebnis")
        } footer: {
            Text("Aus: Lumen Fit rechnet mit der Annahme von \(Self.sekunden(TrackerProtokoll.findenPulsDauerAnnahme)). An: mit der übernommenen Messung (nach einem Neustart der App).")
        }
    }

    private var messungenAbschnitt: some View {
        Section {
            if messungen.isEmpty {
                Text("Noch keine Messung").foregroundStyle(.secondary)
            }
            ForEach(messungen.reversed()) { zeile($0) }
            if !messungen.isEmpty {
                Button("Messungen löschen", role: .destructive) {
                    BandLaborSpeicher.loeschen()
                    messungen = []
                }
                .frame(minHeight: 44)
            }
        } header: {
            Text("Messungen")
        }
    }

    private func zeile(_ m: BandLaborMessung) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            switch m.art {
            case .einzel:
                Text("Ein Befehl: Puls \(Self.sekunden(m.dauer))")
            case .doppel:
                Text("Zwei Befehle, Abstand \(Self.sekunden(m.abstand ?? 0)): \(Self.sekunden(m.dauer))")
                Text(m.urteil?.text ?? "Ohne Einzelmessung kein Urteil")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Ablauf

    private func einzelStarten() {
        lauf = Lauf(art: .einzel, abstand: nil, gesendet: Date(), start: nil)
        modell.finden()
    }

    private func doppelStarten() {
        let wahl = abstand
        lauf = Lauf(art: .doppel, abstand: wahl, gesendet: Date(), start: nil)
        modell.finden()
        sendeAufgabe = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wahl))
            guard !Task.isCancelled else { return }
            modell.finden()
        }
    }

    private func spuerenStarten() {
        lauf?.start = Date()
    }

    private func beenden() {
        guard let aktuell = lauf, let start = aktuell.start else { return }
        let dauer = Date().timeIntervalSince(start)
        let urteil: BandLaborAuswertung.Doppel?
        if aktuell.art == .doppel, let abstand = aktuell.abstand, let puls = BandLaborAuswertung.pulsLaenge(messungen) {
            urteil = BandLaborAuswertung.beurteile(puls: puls, abstand: abstand, gesamt: dauer)
        } else {
            urteil = nil
        }
        let messung = BandLaborMessung(datum: Date(), art: aktuell.art, abstand: aktuell.abstand, dauer: dauer,
                                       verzoegerung: start.timeIntervalSince(aktuell.gesendet), urteil: urteil)
        BandLaborSpeicher.anhaengen(messung)
        messungen = BandLaborSpeicher.messungen()
        lauf = nil
    }

    private func abbrechen() {
        sendeAufgabe?.cancel()
        lauf = nil
    }

    /// "7,8 s" (eine Nachkommastelle, deutsches Komma).
    private static func sekunden(_ wert: Double) -> String {
        String(format: "%.1f", wert).replacingOccurrences(of: ".", with: ",") + " s"
    }
}
