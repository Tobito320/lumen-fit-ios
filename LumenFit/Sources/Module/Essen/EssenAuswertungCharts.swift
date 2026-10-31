// Quelle: Lovea Health/Ernaehrung/ErnaehrungAnalyse.swift:140-484 (Diagramme der Auswertung, im Lumen-Design neu gezeichnet)
import Accessibility
import Charts
import SwiftUI

/// VoiceOver-Beschreibung für jedes Diagramm der Auswertung: Rubriken auf der x-Achse, eine Reihe, optional eine Ziellinie.
/// Tage ohne Wert bleiben `nil` (keine Null).
struct EssenReiheBeschreibung: AXChartDescriptorRepresentable {
    let titel: String
    let zusammenfassung: String
    let xTitel: String
    let yTitel: String
    let einheit: String
    let kategorien: [String]
    let werte: [Double?]
    var ziel: Double?
    /// Untergrenze der y-Achse; Gewicht und Körperwerte beginnen nicht bei 0.
    var von: Double = 0

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: xTitel, categoryOrder: kategorien)
        let hoechster = max(von + 1, werte.compactMap { $0 }.max() ?? 0, ziel ?? 0)
        let einheit = einheit
        let y = AXNumericDataAxisDescriptor(title: yTitel, range: von...hoechster, gridlinePositions: ziel.map { [$0] } ?? []) { wert in
            "\(Int(wert.rounded())) \(einheit)"
        }
        let punkte = zip(kategorien, werte).map { AXDataPoint(x: $0, y: $1) }
        let reihe = AXDataSeriesDescriptor(name: titel, isContinuous: false, dataPoints: punkte)
        return AXChartDescriptor(title: titel, summary: zusammenfassung, xAxis: x, yAxis: y, additionalAxes: [], series: [reihe])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

/// Zahl über Beschriftung, für Statistik und Fasten-Kennzahlen.
struct EssenKennzahlSpalte: View {
    let wert: String
    let titel: String
    var mittig = false
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        VStack(alignment: mittig ? .center : .leading, spacing: Abstand.xs) {
            Text(wert).font(.title3.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text)
            Text(titel).font(.footnote).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: mittig ? .infinity : nil, alignment: mittig ? .center : .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Balkendiagramm Kalorien je Tag, Woche oder Monat mit gestrichelter Ziellinie.
struct EssenKalorienDiagramm: View {
    let buckets: [AnalyseBucket]
    let gruppierung: AnalyseGruppierung
    let werte: [String: Double]
    let ziel: Int
    /// 0 bis 1: wie weit die Balken schon gewachsen sind (Reduce Motion: sofort 1).
    let wachstum: Double
    let beschreibung: EssenReiheBeschreibung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        Chart {
            ForEach(buckets) { bucket in
                if let wert = AnalyseLogik.bucketSchnitt(bucket, werte) {
                    BarMark(x: .value("Zeit", AnalyseLogik.label(bucket, gruppierung)), y: .value("kcal", wert * wachstum))
                        .foregroundStyle(aufbau.farbe(LoveaDaten.essen, sonst: palette.text.opacity(0.85)))
                        .cornerRadius(3)
                }
            }
            RuleMark(y: .value("Ziel", ziel))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(palette.text2)
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) { _ in AxisValueLabel().font(.caption).foregroundStyle(palette.text2) } }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel().font(.caption).foregroundStyle(palette.text2)
            }
        }
        .frame(height: 180)
        .accessibilityChartDescriptor(beschreibung)
    }
}

/// Ringdiagramm der Energieanteile von Kohlenhydraten, Eiweiß und Fett.
struct EssenMakroSektor: View {
    let schnitte: [EssenMakroSchnitt]
    let sichtbar: Bool
    let beschreibung: EssenReiheBeschreibung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        Chart(schnitte) { m in
            SectorMark(angle: .value(m.name, m.energie), innerRadius: .ratio(0.62), angularInset: 1.5)
                .foregroundStyle(aufbau.farbe(LoveaDaten.essen.opacity(m.deckkraft), sonst: palette.text.opacity(m.deckkraft)))
                .cornerRadius(3)
        }
        .opacity(sichtbar ? 1 : 0)
        .frame(width: 96, height: 96)
        .accessibilityChartDescriptor(beschreibung)
    }
}

/// Verlauf einer Messreihe (Gewicht, Körperwert) als Linie mit Punkten.
struct EssenMessLinie: View {
    let reihe: [EssenMesspunkt]
    let einheit: String
    let hoehe: CGFloat
    let achsenWerte: Int
    let wachstum: Double
    let beschreibung: EssenReiheBeschreibung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        let untergrenze = (reihe.map(\.wert).min() ?? 0)
        Chart(reihe) { punkt in
            // Die Linie wächst aus dem Tiefpunkt der Reihe, nicht aus 0: sonst staucht die Achse die Kurve beim Zeichnen.
            LineMark(x: .value("Tag", Datum.datum(punkt.tag)), y: .value(einheit, untergrenze + (punkt.wert - untergrenze) * wachstum))
                .foregroundStyle(aufbau.farbe(LoveaDaten.essen, sonst: palette.text))
            PointMark(x: .value("Tag", Datum.datum(punkt.tag)), y: .value(einheit, untergrenze + (punkt.wert - untergrenze) * wachstum))
                .foregroundStyle(aufbau.farbe(LoveaDaten.essen, sonst: palette.text))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: achsenWerte)) { _ in AxisValueLabel().font(.caption).foregroundStyle(palette.text2) } }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel().font(.caption).foregroundStyle(palette.text2)
            }
        }
        .frame(height: hoehe)
        .accessibilityChartDescriptor(beschreibung)
    }
}
