import Accessibility
import SwiftUI

/// Kleiner offener Bogen (270 Grad, Öffnung unten) für Karten und den Wochenstreifen. Farben sind die Tief-Varianten (Linien auf Flächen), nie die Ring-Originale.
struct HeuteMiniBogen: View {
    let anteil: Double
    let bereich: Datenbereich
    var strich: CGFloat = 5
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let farbe = LumenFarben.tief(bereich, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(farbe.opacity(0.22), style: StrokeStyle(lineWidth: strich, lineCap: .round))
            Circle().trim(from: 0, to: 0.75 * min(max(anteil, 0), 1)).stroke(farbe, style: StrokeStyle(lineWidth: strich, lineCap: .round))
        }
        .rotationEffect(.degrees(135))
        .padding(strich / 2)
        .accessibilityHidden(true)
    }
}

/// Kopfzeile einer Karte: Symbol, Titel, rechts ein Zusatz (zum Beispiel ein Pfeil, der ein Blatt öffnet).
struct HeuteKartenKopf: View {
    let symbol: String
    let titel: String
    var zusatz: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.s) {
            Image(systemName: symbol).foregroundStyle(palette.text2).accessibilityHidden(true)
            Text(titel).font(.headline).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            if let zusatz { Text(zusatz).font(.subheadline).foregroundStyle(palette.text2) }
        }
    }
}

/// Beschreibung eines Diagramms für VoiceOver (`accessibilityChartDescriptor`): Titel, eine Kernzeile und die Werte je Punkt.
struct HeuteDiagrammBeschreibung: AXChartDescriptorRepresentable {
    let titel: String
    let zusammenfassung: String
    let xTitel: String
    let yTitel: String
    let einheit: String
    let punkte: [HeuteDiagrammPunkt]

    func makeChartDescriptor() -> AXChartDescriptor {
        let namen = punkte.map(\.name)
        let x = AXCategoricalDataAxisDescriptor(title: xTitel, categoryOrder: namen.isEmpty ? ["–"] : namen)
        let obergrenze = max(1, punkte.map(\.wert).max() ?? 1)
        let einheitText = self.einheit
        let y = AXNumericDataAxisDescriptor(title: yTitel, range: 0...obergrenze, gridlinesOccurAtValues: []) { wert in
            "\(Int(wert.rounded())) \(einheitText)"
        }
        let serie = AXDataSeriesDescriptor(name: titel, isContinuous: false, dataPoints: punkte.map { AXDataPoint(x: $0.name, y: $0.wert) })
        return AXChartDescriptor(title: titel, summary: zusammenfassung, xAxis: x, yAxis: y, additionalAxes: [], series: [serie])
    }
}

struct HeuteDiagrammPunkt: Equatable, Sendable {
    var name: String
    var wert: Double
}

/// Deutsche Zahlen für Kommazahlen: 78,4.
enum HeuteFormat {
    static func kilo() -> FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(1)).locale(Locale(identifier: "de_DE"))
    }

    static func ganz() -> FloatingPointFormatStyle<Double> {
        .number.precision(.fractionLength(0)).locale(Locale(identifier: "de_DE"))
    }
}
