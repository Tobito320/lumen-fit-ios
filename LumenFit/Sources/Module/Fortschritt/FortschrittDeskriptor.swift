import Accessibility
import SwiftUI

/// Der Audiodiagramm-Beschreiber für VoiceOver (`accessibilityChartDescriptor`): ein Diagramm mit Rubriken auf der X-Achse und einer Reihe Zahlen.
/// Alle Diagramme des Moduls nutzen ihn; der Typ `AXChartDescriptorRepresentable` ist die einzige Stelle, die der Compiler in CI prüfen muss.
struct FortschrittDeskriptor: AXChartDescriptorRepresentable {
    struct Punkt: Sendable {
        let x: String
        let y: Double
    }

    let titel: String
    let zusammenfassung: String
    let xTitel: String
    let yTitel: String
    let einheit: String
    /// Linie (true) oder einzelne Balken (false).
    let stetig: Bool
    let punkte: [Punkt]

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: xTitel, categoryOrder: punkte.map(\.x))
        let niedrig = punkte.map(\.y).min() ?? 0
        let hoch = max(punkte.map(\.y).max() ?? 1, niedrig + 1)
        let einheit = self.einheit
        let y = AXNumericDataAxisDescriptor(title: yTitel, range: niedrig...hoch, gridlinePositions: []) { wert in
            "\(wert.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE")))) \(einheit)"
        }
        let serie = AXDataSeriesDescriptor(name: yTitel, isContinuous: stetig, dataPoints: punkte.map { AXDataPoint(x: $0.x, y: $0.y) })
        return AXChartDescriptor(title: titel, summary: zusammenfassung, xAxis: x, yAxis: y, additionalAxes: [], series: [serie])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}
