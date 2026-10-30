// Quelle: Lovea Health/Tracker/TrackerSeite.swift
import Accessibility
import Charts
import SwiftUI

/// Die Seite "Fitness-Tracker" unter Profil > Geräte (Idee 85, 87, 88), alles aus Loveas Tracker-Seite im Lumen-Design: Kopf mit Status und Akku, Verbindung,
/// Am Arm, Modus, Verlauf-Karten, Messungen am Band, Schritte, Funktionen (Finden, Abfragen, Puls messen), Band-Vibration, Akku-Warnung und Hilfe.
/// Der Schalter `bandAktiv` bleibt das Tor: ohne ihn entsteht kein Modell und kein Bluetooth-Objekt; die Seite liest `dienst?.modell` nur und legt es nie an.
/// Verbinden und Trennen laufen über den `BandDienstImpl`, den Stand liest sie aus dessen `TrackerModell`.
struct BandSeite: View {
    @Environment(AppUmgebung.self) private var umgebung

    private var dienst: BandDienstImpl? { umgebung.band as? BandDienstImpl }
    private var einstellungen: EinstellungenStore? { umgebung.daten?.einstellungen }
    private var an: Bool { einstellungen?.werte.bandAktiv ?? false }

    var body: some View {
        Form {
            schalterAbschnitt
            weckerAbschnitt
            if an {
                if let modell = dienst?.modell {
                    BandInhalt(modell: modell, dienst: dienst)
                } else {
                    VerbindenAbschnitt {
                        Button("Band suchen") { Task { await dienst?.verbinde() } }
                            .frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
        }
        .verbindenFormular()
        .navigationTitle("Fitness-Tracker")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var schalterAbschnitt: some View {
        VerbindenAbschnitt(fuss: fuss) {
            Toggle("Band in Lumen Fit nutzen", isOn: Binding(
                get: { an },
                set: { neu in einstellungen?.aendere { $0.bandAktiv = neu } }))
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    /// Lumen Alarm legt Weck-Wünsche ab, Lumen Fit vibriert das Band dazu. Der Ton von Lumen Alarm klingelt immer, auch ohne Band.
    private var weckerAbschnitt: some View {
        VerbindenAbschnitt(fuss: "Standard an. Wirkt nur mit dem Band-Schalter oben und nur, wenn Lumen Alarm das Band mitwecken lässt. Der Ton klingelt immer.") {
            Toggle("Lumen Alarm darf das Band wecken", isOn: Binding(
                get: { einstellungen?.werte.alarmWeckt ?? true },
                set: { neu in einstellungen?.aendere { $0.alarmWeckt = neu } }))
                .frame(minHeight: Abstand.tippflaeche)
        }
    }

    /// Ohne Freigabe steht hier kein Wort von Lovea.
    private var fuss: String {
        let basis = "Standard aus. Erst mit dem Schalter fragt Lumen Fit nach Bluetooth."
        return umgebung.konto.loveaErlaubt ? "Standard aus. Solange Lovea das Band selbst hält, lass es aus: nur eine App kann das Band halten. Erst mit dem Schalter fragt Lumen Fit nach Bluetooth." : basis
    }
}

/// Alle Abschnitte bei eingeschaltetem Band. Zehn Kinder sind die Grenze des ViewBuilders: die letzten stehen in einer Gruppe.
private struct BandInhalt: View {
    let modell: TrackerModell
    let dienst: BandDienstImpl?

    var body: some View {
        BandKopfAbschnitt(modell: modell)
        BandVerbindungAbschnitt(modell: modell, dienst: dienst)
        BandArmAbschnitt(modell: modell)
        BandModusAbschnitt(modell: modell)
        BandVerlaufAbschnitt(modell: modell)
        BandMessungenAbschnitt(modell: modell)
        BandSchritteAbschnitt(modell: modell)
        BandFunktionenAbschnitt(modell: modell)
        BandVibrationAbschnitt(modell: modell)
        Group {
            BandAkkuWarnAbschnitt()
            BandHilfeAbschnitt(modell: modell)
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
