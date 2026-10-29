import Charts
import SwiftUI

/// Idee 36: Gewichtsverlauf mit Punkten, gleitendem Mittel, Ziellinie und der Prognose als Titel ("In 9 Wochen am Ziel").
/// Ohne Eintrag: Lumi, ein Satz, eine Handlung (Gewicht eintragen).
struct GewichtVerlaufKarte: View {
    let trend: GewichtTrend
    let beiEintragen: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        if trend.reihe.isEmpty {
            LeerZustand(stimmung: .bereit, satz: "Noch kein Gewicht eingetragen. Ein Wert, dann zeichnet Lumi die Kurve.", handlung: "Gewicht eintragen", aktion: beiEintragen)
                .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        } else {
            DiagrammKarte(aussage: GewichtVerlauf.aussage(trend), kernzeile: GewichtVerlauf.kernzeile(trend)) {
                diagramm
            }
        }
    }

    private var diagramm: some View {
        let farbe = LumenFarben.tief(.bewegen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let letzter = trend.reihe.last
        let alleKg = (trend.reihe.map(\.kg) + trend.punkte.map(\.kg) + [trend.zielKg].compactMap { $0 })
        let niedrig = (alleKg.min() ?? 0) - 1, hoch = (alleKg.max() ?? 1) + 1
        return Chart {
            ForEach(trend.punkte, id: \.tag) { p in
                PointMark(x: .value("Tag", Datum.datum(p.tag)), y: .value("Gewicht", p.kg))
                    .foregroundStyle(palette.text2.opacity(0.55))
                    .symbolSize(24)
            }
            ForEach(trend.reihe, id: \.tag) { p in
                LineMark(x: .value("Tag", Datum.datum(p.tag)), y: .value("Mittel", p.kg))
                    .foregroundStyle(farbe)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            if let ziel = trend.zielKg {
                RuleMark(y: .value("Ziel", ziel))
                    .foregroundStyle(palette.text)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Ziel \(GewichtVerlauf.kg(ziel)) kg").font(.caption2.weight(.semibold)).foregroundStyle(palette.text)
                    }
            }
            if let letzter {
                PointMark(x: .value("Tag", Datum.datum(letzter.tag)), y: .value("Mittel", letzter.kg))
                    .foregroundStyle(farbe)
                    .symbolSize(90)
                    .annotation(position: .bottom) {
                        Text("\(GewichtVerlauf.kg(letzter.kg)) kg").font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                    }
            }
        }
        .chartYScale(domain: niedrig...hoch)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(palette.text2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel().foregroundStyle(palette.text2)
            }
        }
        .frame(height: 200)
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "Gewichtsverlauf", zusammenfassung: "\(GewichtVerlauf.aussage(trend)). \(GewichtVerlauf.kernzeile(trend))", xTitel: "Tag", yTitel: "Gewicht (Mittel)", einheit: "kg",
            stetig: true, punkte: trend.reihe.map { .init(x: KoerperLogik.tagMonat($0.tag), y: $0.kg) }))
    }
}
