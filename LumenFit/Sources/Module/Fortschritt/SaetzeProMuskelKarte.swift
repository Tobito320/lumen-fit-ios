import Charts
import SwiftUI

/// Idee 32: Wochenbalken je Muskelgruppe. Der Wert steht rechts als Zahl ("9 von 12"), das Ziel als Raute im Diagramm; wer das Ziel erreicht hat, bekommt
/// einen Haken in der Zahl. Aufwärmsätze zählen nicht.
struct SaetzeProMuskelKarte: View {
    let zeilen: [SatzZeile]
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        DiagrammKarte(aussage: SaetzeProMuskel.aussage(zeilen), kernzeile: SaetzeProMuskel.kernzeile(zeilen)) {
            if zeilen.isEmpty {
                LeerZustand(stimmung: .bereit, satz: "Lege deine Wochenziele fest, dann zählt Lumi mit.", handlung: "Ziele öffnen") {
                    umgebung.router.oeffne(.profil(.ziele))
                }
            } else {
                diagramm
            }
        }
    }

    private var diagramm: some View {
        let farbe = LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let hoechste = max(zeilen.map { Double($0.ziel) }.max() ?? 1, zeilen.map(\.saetze).max() ?? 1)
        let nachName = Dictionary(zeilen.map { ($0.gruppe.name, $0) }, uniquingKeysWith: { erste, _ in erste })
        return Chart(zeilen) { z in
            BarMark(x: .value("Sätze", z.saetze), y: .value("Gruppe", z.gruppe.name))
                .foregroundStyle(farbe.opacity(z.erreicht ? 1 : 0.6))
                .cornerRadius(3)
            PointMark(x: .value("Ziel", Double(z.ziel)), y: .value("Gruppe", z.gruppe.name))
                .symbol(.diamond)
                .symbolSize(70)
                .foregroundStyle(palette.text)
        }
        .chartXScale(domain: 0...hoechste)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel().foregroundStyle(palette.text)
            }
            AxisMarks(position: .trailing) { wert in
                AxisValueLabel {
                    if let name = wert.as(String.self), let z = nachName[name] {
                        HStack(spacing: Abstand.xs) {
                            if z.erreicht { Image(systemName: "checkmark").accessibilityHidden(true) }
                            Text(z.text).monospacedDigit()
                        }
                        .foregroundStyle(palette.text2)
                    }
                }
            }
        }
        .frame(height: CGFloat(zeilen.count) * 30 + 8)
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "Sätze je Muskel", zusammenfassung: SaetzeProMuskel.aussage(zeilen), xTitel: "Muskelgruppe", yTitel: "Sätze diese Woche", einheit: "Sätze",
            stetig: false, punkte: zeilen.map { .init(x: "\($0.gruppe.name), Ziel \($0.ziel)", y: $0.saetze) }))
    }
}
