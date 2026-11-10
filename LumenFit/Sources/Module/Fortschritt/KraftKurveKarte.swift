import Charts
import SwiftUI

/// Was die Kraftkurve zeigt: bestes Gewicht, geschätztes Einer-Maximum oder Volumen je Woche.
enum KraftMesswert: String, CaseIterable, Identifiable, Sendable {
    case gewicht, e1rm, volumen

    var id: String { rawValue }

    var name: String {
        switch self {
        case .gewicht: String(localized: "Gewicht")
        case .e1rm: "1RM"
        case .volumen: String(localized: "Volumen")
        }
    }

    var einheit: String { "kg" }

    func wert(_ p: KraftPunkt) -> Double {
        switch self {
        case .gewicht: p.gewicht
        case .e1rm: p.e1rm
        case .volumen: p.volumen
        }
    }
}

/// Idee 31: Linie mit Fläche und Endpunkt je Übung. Der Titel ist die Aussage ("Bankdrücken: 70 kg, plus 10"), darunter die Kernzeile.
struct KraftKurveKarte: View {
    let sessions: [GymSession]
    let heute: String
    @State private var gewaehlt: String?
    @State private var messwert = KraftMesswert.gewicht
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let uebungen = KraftKurve.uebungen(sessions)
        let aktuell = uebungen.first { $0.id == gewaehlt } ?? uebungen.first
        if let aktuell {
            let punkte = KraftKurve.punkte(sessions, uebung: aktuell.id, heute: heute)
            DiagrammKarte(aussage: KraftKurve.aussage(name: aktuell.name, punkte), kernzeile: KraftKurve.kernzeile(punkte)) {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    auswahl(uebungen, aktuell: aktuell)
                    Picker("Wert", selection: $messwert) {
                        ForEach(KraftMesswert.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    diagramm(punkte)
                }
            }
            .haptik(.auswahl, bei: messwert)
            .haptik(.auswahl, bei: aktuell.id)
        } else {
            LeerZustand(stimmung: .bereit, satz: String(localized: "Noch keine Kraftkurve. Hake Sätze mit Gewicht ab, Lumi zeichnet mit."), handlung: String(localized: "Training starten")) {
                umgebung.router.oeffne(.gym(.training))
            }
                .lumenKartenFlaeche()
        }
    }

    private func auswahl(_ uebungen: [KraftUebung], aktuell: KraftUebung) -> some View {
        Picker("Übung", selection: Binding(get: { aktuell.id }, set: { gewaehlt = $0 })) {
            ForEach(uebungen) { Text($0.name).tag($0.id) }
        }
        .pickerStyle(.menu)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityLabel("Übung wählen")
    }

    private func diagramm(_ punkte: [KraftPunkt]) -> some View {
        let farbe = LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let letzter = punkte.last
        let wert = messwert
        return Chart(punkte) { p in
            AreaMark(x: .value("Woche", Datum.datum(p.woche)), y: .value(wert.name, wert.wert(p)))
                .foregroundStyle(farbe.opacity(0.15))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Woche", Datum.datum(p.woche)), y: .value(wert.name, wert.wert(p)))
                .foregroundStyle(farbe)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            if p.id == letzter?.id {
                PointMark(x: .value("Woche", Datum.datum(p.woche)), y: .value(wert.name, wert.wert(p)))
                    .foregroundStyle(farbe)
                    .symbolSize(90)
                    .annotation(position: .top) {
                        Text("\(VerlaufLogik.zahl(wert.wert(p).rounded())) kg")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(palette.text)
                    }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
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
        .frame(height: 180)
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: String(localized: "Kraftkurve"), zusammenfassung: KraftKurve.kernzeile(punkte), xTitel: String(localized: "Woche ab"), yTitel: wert.name, einheit: wert.einheit, stetig: true,
            punkte: punkte.map { .init(x: KoerperLogik.tagMonat($0.woche), y: wert.wert($0)) }))
    }
}
