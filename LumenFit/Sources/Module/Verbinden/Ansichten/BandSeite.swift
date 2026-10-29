// Quelle: Lovea Health/Tracker/TrackerSeite.swift
import Accessibility
import Charts
import SwiftUI

/// Die Band-Seite (Idee 85, 87, 88): Verbindung, Akku mit Warnung unter 15 Prozent und Verlauf der letzten Tage, Pausen-Ende-Muster, Regeln und Band-Labor.
/// Neu im Lumen-Design; Verbinden und Trennen laufen über den `BandDienstImpl`, den Stand liest sie aus dessen `TrackerModell`.
struct BandSeite: View {
    @Environment(AppUmgebung.self) private var umgebung

    private var dienst: BandDienstImpl? { umgebung.band as? BandDienstImpl }

    var body: some View {
        Form {
            statusAbschnitt
            if let modell = dienst?.modell { BandMessungen(modell: modell) }
            if let punkte = dienst?.modell?.akkuVerlauf.punkte, punkte.count >= 2 {
                Section { BandAkkuVerlauf(punkte: punkte).listRowInsets(EdgeInsets()) }
                    .listRowBackground(Color.clear)
            }
            BandQuelleAbschnitt(quelle: .gymPause)
            VerbindenAbschnitt {
                NavigationLink { BandRegelnBlatt() } label: { Label("Alle Regeln", systemImage: "slider.horizontal.3") }
                if let modell = dienst?.modell {
                    NavigationLink { BandLaborAnsicht(modell: modell) } label: { Label("Band-Labor", systemImage: "waveform.path") }
                }
            }
        }
        .verbindenFormular()
        .navigationTitle("Band")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Verbindung und Akku

    private var statusAbschnitt: some View {
        let modell = dienst?.modell
        let verbunden = modell?.zustand == .verbunden
        return VerbindenAbschnitt(titel: "Verbindung", fuss: "Das Band kann nur eine App gleichzeitig halten. Hält Lovea es noch, lass es dort verbunden und das hier aus.") {
            LabeledContent("Status", value: modell?.statusText ?? "Nicht verbunden")
            if let name = modell?.name { LabeledContent("Band", value: name) }
            if let akku = modell?.akku {
                LabeledContent("Akku", value: akku.laedt ? "\(akku.prozent) %, lädt" : "\(akku.prozent) %")
            }
            if modell?.akkuNiedrig == true {
                Label("Akku niedrig: bald laden", systemImage: "battery.25percent")
                    .foregroundStyle(.primary)
            }
            if verbunden {
                Button("Trennen") { Task { await dienst?.trenne() } }
                    .frame(minHeight: Abstand.tippflaeche)
            } else {
                Button(modell?.gekoppelt == true ? "Verbinden" : "Band suchen") { Task { await dienst?.verbinde() } }
                    .frame(minHeight: Abstand.tippflaeche)
            }
            if modell?.gekoppelt == true {
                Button("Band vergessen", role: .destructive) { modell?.vergessen() }
                    .frame(minHeight: Abstand.tippflaeche)
            }
        }
    }
}

/// Der Akku-Verlauf der letzten Tage als Linie, mit Kernzeile und Diagramm-Beschreibung für VoiceOver.
struct BandAkkuVerlauf: View {
    let punkte: [TrackerAkkuVerlauf.Punkt]

    var body: some View {
        DiagrammKarte(aussage: "Akku der letzten Tage", kernzeile: kernzeile) {
            Chart(punkte) { punkt in
                LineMark(x: .value("Zeit", punkt.datum), y: .value("Prozent", punkt.prozent))
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis { AxisMarks(values: [0, 50, 100]) }
            .frame(height: 140)
            .accessibilityChartDescriptor(BandAkkuBeschreibung(punkte: punkte))
        }
    }

    /// "Jetzt 82 %, am niedrigsten 41 %."
    private var kernzeile: String {
        guard let letzter = punkte.last, let tiefster = punkte.map(\.prozent).min() else { return "Noch kein Verlauf" }
        return "Jetzt \(letzter.prozent) %, am niedrigsten \(tiefster) %."
    }
}

/// Die Beschreibung des Akku-Diagramms für VoiceOver: Stunden seit dem ersten Wert gegen Prozent.
struct BandAkkuBeschreibung: AXChartDescriptorRepresentable {
    let punkte: [TrackerAkkuVerlauf.Punkt]

    func makeChartDescriptor() -> AXChartDescriptor {
        let start = punkte.first?.zeit ?? 0
        let stunden = punkte.map { Double($0.zeit - start) / 3600 }
        let x = AXNumericDataAxisDescriptor(title: "Stunden seit dem ersten Wert", range: 0...max(1, stunden.last ?? 1), gridlinePositions: []) {
            "\(Int($0.rounded())) Stunden"
        }
        let y = AXNumericDataAxisDescriptor(title: "Akku in Prozent", range: 0...100, gridlinePositions: []) { "\(Int($0.rounded())) Prozent" }
        let reihe = AXDataSeriesDescriptor(name: "Akku", isContinuous: true,
                                           dataPoints: zip(stunden, punkte).map { AXDataPoint(x: $0, y: Double($1.prozent)) })
        return AXChartDescriptor(title: "Akku des Bands", summary: nil, xAxis: x, yAxis: y, additionalAxes: [], series: [reihe])
    }
}

/// Was das Band misst (Idee 85): Schritte zählen, Puls (letzter Wert, Messung auf Knopfdruck) und der Modus (Sparen oder Viele Daten). Der Puls speist die Regel
/// "Gym: Ziel-Puls erreicht"; Schritte und Schlaf vom Band gehen als Ops in den Raum, `GesundheitsStand` nimmt je Tag den höheren Wert von Health und Band.
struct BandMessungen: View {
    let modell: TrackerModell
    @AppStorage(TrackerModell.schritteSchluessel) private var schritteZaehlen = true
    @Environment(\.palette) private var palette

    var body: some View {
        VerbindenAbschnitt(titel: "Messungen", fuss: "Schritte: es zählt je Tag der höhere Wert von Band und Apple Health, nie die Summe. Bereits gemeldete Tage bleiben, wenn du das hier ausschaltest. Sparen misst seltener und schont den Akku.") {
            Toggle(isOn: $schritteZaehlen) { Label("Schritte vom Band zählen", systemImage: "figure.walk") }
            if let heute = modell.heute {
                LabeledContent("Schritte heute (Band)", value: heute.schritte.formatted())
            }
            LabeledContent("Letzter Puls", value: pulsText)
            Button("Puls jetzt messen") { modell.pulsMessen() }
                .frame(minHeight: Abstand.tippflaeche)
                .disabled(modell.zustand != .verbunden || messtGerade)
            Picker("Modus", selection: Binding(get: { modell.modus }, set: { neu in if let neu { modell.modusWaehlen(neu) } })) {
                ForEach(TrackerModus.allCases) { Text($0.name).tag(Optional($0)) }
            }
            .pickerStyle(.segmented)
            Text(modusZeile).font(.footnote).foregroundStyle(palette.text2)
        }
    }

    private var messtGerade: Bool {
        if case .misst = modell.pulsMessung { true } else { false }
    }

    private var pulsText: String {
        switch modell.pulsMessung {
        case .misst: return "Misst, bis zu 45 Sekunden"
        case .fehler(let text): return text
        case .fertig(let wert, _): return "\(wert) Schläge/Min."
        case .aus: break
        }
        guard let puls = modell.letzterPuls else { return "Noch keiner" }
        return "\(puls.wert) Schläge/Min."
    }

    private var modusZeile: String {
        let status = TrackerModus.status(modus: modell.modus, offen: modell.modusOffen, verbunden: modell.zustand == .verbunden,
                                         gelesen: modell.pulsEinstellung != nil, abweichungen: modell.modusAbweichungen)
        guard let akku = modell.modus?.akkuSatz else { return status }
        return status + " " + akku
    }
}
