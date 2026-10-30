import Accessibility
import Charts
import SwiftUI

/// Kurzer Wochentag für die Achse: "Mo" bis "So".
enum EssenTagText {
    static func kurz(_ tag: String) -> String { ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][min(max(Datum.wochentag(tag), 1), 7) - 1] }
}

struct EssenProteinBeschreibung: AXChartDescriptorRepresentable {
    let analyse: Wochenanalyse

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXCategoricalDataAxisDescriptor(title: "Tag", categoryOrder: analyse.tage.map { EssenTagText.kurz($0.tag) })
        let hoechster = max(1, analyse.tage.map(\.protein).max() ?? 1, Double(analyse.proteinZiel))
        let y = AXNumericDataAxisDescriptor(title: "Protein in Gramm", range: 0...hoechster, gridlinePositions: [Double(analyse.proteinZiel)]) { wert in "\(Int(wert.rounded())) Gramm" }
        let reihe = AXDataSeriesDescriptor(name: "Protein je Tag", isContinuous: false,
                                           dataPoints: analyse.tage.map { AXDataPoint(x: EssenTagText.kurz($0.tag), y: $0.hatEintraege ? $0.protein : nil) })
        return AXChartDescriptor(title: "Protein je Tag", summary: analyse.klartext.first, xAxis: x, yAxis: y, additionalAxes: [], series: [reihe])
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}

/// Protein je Tag als Balken, die gestrichelte Linie ist das Ziel. Tage ohne Eintrag bleiben leer, sie sind keine Null.
struct EssenProteinDiagramm: View {
    let analyse: Wochenanalyse
    @Environment(\.palette) private var palette

    var body: some View {
        Chart {
            ForEach(analyse.tage) { t in
                if t.hatEintraege {
                    BarMark(x: .value("Tag", EssenTagText.kurz(t.tag)), y: .value("Protein", t.protein))
                        .foregroundStyle(palette.text.opacity(t.protein >= Double(t.proteinZiel) ? 0.85 : 0.45))
                        .cornerRadius(4)
                }
            }
            RuleMark(y: .value("Ziel", Double(analyse.proteinZiel)))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(palette.text2)
                .annotation(position: .top, alignment: .trailing) {
                    Text("Ziel \(analyse.proteinZiel) g").font(.caption).foregroundStyle(palette.text2)
                }
        }
        .chartXScale(domain: analyse.tage.map { EssenTagText.kurz($0.tag) })
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel().font(.caption).foregroundStyle(palette.text2)
            }
        }
        .frame(height: 160)
        .accessibilityChartDescriptor(EssenProteinBeschreibung(analyse: analyse))
    }
}

/// Wochenanalyse Essen (Idee 50): Protein je Tag gegen die Ziellinie, dazu Zucker, Ballaststoffe und Mikronährstoff-Lücken in Klartext.
/// Richtwerte: DGE (Ballaststoffe mindestens 30 g), WHO (freier Zucker höchstens 10 % der Energie), EU-Tagesreferenz (Anhang XIII der Verordnung 1169/2011).
struct WochenanalyseView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            if let essen = umgebung.daten?.essen {
                let bis = Datum.text(umgebung.uhr())
                let analyse = WochenanalyseLogik.berechne(bis: bis, eintraege: { essen.eintraege($0) }, ziele: { essen.ernaehrungsZiele(tag: $0) })
                VStack(spacing: Abstand.l) {
                    if analyse.istLeer {
                        LeerZustand(stimmung: .bereit, satz: "In den letzten sieben Tagen ist noch nichts eingetragen. Sobald du isst, rechne ich dir die Woche vor.")
                    } else {
                        DiagrammKarte(aussage: proteinAussage(analyse), kernzeile: analyse.klartext.first ?? "") {
                            EssenProteinDiagramm(analyse: analyse)
                        }
                        klartextKarte(analyse)
                        if !analyse.luecken.isEmpty { lueckenKarte(analyse) }
                    }
                }
                .padding(Abstand.l)
            }
        }
        .navigationTitle("Wochenanalyse")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }

    private func proteinAussage(_ a: Wochenanalyse) -> String {
        let ziel = a.proteinZiel
        guard let schnitt = a.proteinSchnitt else { return "Protein je Tag" }
        return Int(schnitt.rounded()) >= ziel ? "Protein: Ziel im Schnitt erreicht" : "Protein: im Schnitt \(ziel - Int(schnitt.rounded())) g unter dem Ziel"
    }

    private func klartextKarte(_ a: Wochenanalyse) -> some View {
        ListenKarte {
            ForEach(Array(a.klartext.dropFirst().enumerated()), id: \.offset) { i, zeile in
                if i > 0 { Haarlinie() }
                Text(zeile).font(.body).foregroundStyle(palette.text)
                    .padding(Abstand.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func lueckenKarte(_ a: Wochenanalyse) -> some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Mikronährstoff-Lücken").font(.headline).foregroundStyle(palette.text)
            ForEach(a.luecken, id: \.mikro) { l in
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    HStack {
                        Text(l.mikro.name).font(.subheadline).foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        Text("\(Int(l.prozent.rounded())) % der Referenz").font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                    }
                    EssenBalken(anteil: l.prozent / 100)
                }
                .accessibilityElement(children: .combine)
            }
            Text("Es zählen nur Lebensmittel mit Angaben. Fehlende Angaben sind keine Lücke.")
                .font(.footnote).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }
}
