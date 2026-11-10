import Accessibility
import SwiftUI

/// Beschreibung für VoiceOver und Audio Graphs: Kategorien auf der X-Achse, Minuten auf der Y-Achse. Der einzige Ort im Modul, der die
/// Accessibility-Typen für Diagramme benutzt (Namen nach der Apple-Doku `AXChartDescriptorRepresentable`; Compiler und Gerät prüfen sie erst in CI).
struct SchlafDiagrammBeschreibung: AXChartDescriptorRepresentable {
    struct Punkt: Sendable {
        let name: String
        let minuten: Double
    }

    let titel: String
    let zusammenfassung: String
    let achseX: String
    let reihe: String
    let punkte: [Punkt]

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: achseX, categoryOrder: punkte.map(\.name))
        let hoechster = max(punkte.map(\.minuten).max() ?? 0, 60)
        let y = AXNumericDataAxisDescriptor(title: String(localized: "Dauer"), range: 0...hoechster, gridlinePositions: []) { wert in
            SchlafFormat.sprechDauer(Int(wert.rounded()))
        }
        let serie = AXDataSeriesDescriptor(name: reihe, isContinuous: false, dataPoints: punkte.map { AXDataPoint(x: $0.name, y: $0.minuten) })
        return AXChartDescriptor(title: titel, summary: zusammenfassung, xAxis: x, yAxis: y, additionalAxes: [], series: [serie])
    }
}
