import Accessibility
import Charts
import SwiftUI
import UIKit

/// Muster als kleine Kachel (8 x 8 pt), damit Segmente und Legende ohne Farbe unterscheidbar sind.
enum EssenMusterKachel {
    @MainActor static func bild(_ muster: MakroMuster, farbe: UIColor) -> UIImage? {
        guard muster != .flaeche else { return nil }
        let seite: CGFloat = 8
        return UIGraphicsImageRenderer(size: CGSize(width: seite, height: seite)).image { kontext in
            let c = kontext.cgContext
            c.setStrokeColor(farbe.cgColor)
            c.setFillColor(farbe.cgColor)
            switch muster {
            case .streifen:
                c.setLineWidth(2)
                for versatz in [-seite / 2, 0, seite / 2] {
                    c.move(to: CGPoint(x: 0, y: seite + versatz))
                    c.addLine(to: CGPoint(x: seite, y: versatz))
                }
                c.strokePath()
            case .punkte:
                c.fillEllipse(in: CGRect(x: 2.5, y: 2.5, width: 3, height: 3))
            case .flaeche:
                break
            }
        }
    }
}

/// Wie der Donut für VoiceOver vorgelesen wird: drei Werte in Gramm.
struct EssenDonutBeschreibung: AXChartDescriptorRepresentable {
    let daten: MakroDonutDaten

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: String(localized: "Nährstoff"), categoryOrder: daten.segmente.map { $0.art.name })
        let hoechster = max(1, daten.segmente.map(\.gramm).max() ?? 1)
        let y = AXNumericDataAxisDescriptor(title: String(localized: "Gramm"), range: 0...hoechster, gridlinePositions: []) { wert in String(localized: "\(String(Int(wert.rounded()))) Gramm") }
        let reihe = AXDataSeriesDescriptor(name: String(localized: "Makronährstoffe"), isContinuous: false,
                                           dataPoints: daten.segmente.map { AXDataPoint(x: $0.art.name, y: $0.gramm) })
        return AXChartDescriptor(title: String(localized: "Makronährstoffe"), summary: daten.beschreibung, xAxis: x, yAxis: y, additionalAxes: [], series: [reihe])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

/// Makro-Donut ohne Farbe (Idee 43): Protein, Kohlenhydrate und Fett als Grautöne mit Muster (Streifen, Punkte, Fläche) und Beschriftung.
/// Die Segmente sind ein `SectorMark`; das Muster liegt als zweites, gleich großes Diagramm darüber. Die Farben bleiben für Gym und Schlaf frei.
struct MakroDonut: View {
    let daten: MakroDonutDaten
    let kcal: Double
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: Abstand.l) {
            ring
            legende
        }
        .accessibilityElement(children: .contain)
    }

    private func fuellung(_ art: MakroArt) -> Color { palette.text.opacity(1 - art.grau * 0.75) }

    private func musterStil(_ art: MakroArt) -> AnyShapeStyle {
        guard let bild = EssenMusterKachel.bild(art.muster, farbe: UIColor(palette.flaeche)) else { return AnyShapeStyle(Color.clear) }
        return AnyShapeStyle(ImagePaint(image: Image(uiImage: bild), scale: 1))
    }

    private var ring: some View {
        ZStack {
            if daten.istLeer {
                Chart {
                    SectorMark(angle: .value("leer", 1), innerRadius: .ratio(0.62)).foregroundStyle(palette.haar)
                }
            } else {
                Chart(daten.segmente) { s in
                    SectorMark(angle: .value("Energie", max(s.kcal, 0.001)), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(fuellung(s.art))
                }
                Chart(daten.segmente) { s in
                    SectorMark(angle: .value("Energie", max(s.kcal, 0.001)), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(musterStil(s.art))
                }
                .accessibilityHidden(true)
            }
            VStack(spacing: 0) {
                RollZahl(wert: kcal, format: .number.precision(.fractionLength(0)))
                    .font(.title3.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                Text("kcal").font(.caption).foregroundStyle(palette.text2)
            }
        }
        .chartLegend(.hidden)
        .frame(width: 136, height: 136)
        .accessibilityChartDescriptor(EssenDonutBeschreibung(daten: daten))
    }

    private var legende: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            ForEach(daten.segmente) { s in
                HStack(spacing: Abstand.s) {
                    muster(s.art)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(s.art.name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                        Text(daten.istLeer ? "0 g" : "\(s.grammText) · \(s.prozent) %")
                            .font(.footnote).monospacedDigit().foregroundStyle(palette.text2)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func muster(_ art: MakroArt) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(fuellung(art))
            if let bild = EssenMusterKachel.bild(art.muster, farbe: UIColor(palette.flaeche)) {
                Image(uiImage: bild).resizable(resizingMode: .tile).clipShape(.rect(cornerRadius: 3, style: .continuous))
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
