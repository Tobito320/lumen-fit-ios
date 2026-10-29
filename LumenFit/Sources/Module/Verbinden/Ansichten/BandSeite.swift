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
