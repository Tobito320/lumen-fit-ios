// Quelle: Lovea Health/Heute/HeuteView.swift (SchlafLeistung, SchlafPunkt), Lovea Health/SchlafCard.swift (leistung)
import Accessibility
import Charts
import SwiftUI

/// Ein Punkt je Einheit: Schlaf der Nacht davor gegen die Leistung.
struct SchlafPunkt: Identifiable, Equatable, Sendable {
    var id: String
    var stunden: Double
    /// Prozent des eigenen Bestwerts, Mittel über die Übungen der Einheit.
    var leistung: Double
}

enum SchlafLeistung {
    /// Ein Punkt je Einheit mit Schlafdaten (wie die Regel "Schlaf bremst dich" in `HeuteHinweisLogik`). Eigene Übungen und Sätze ohne kg zählen nicht.
    static func punkte(_ sessions: [GymSession], schlafMinuten: [String: Int]) -> [SchlafPunkt] {
        let werte = sessions.map { HeuteHinweisLogik.bestwerte($0) }
        var bestwert: [String: Double] = [:]
        for w in werte { bestwert.merge(w, uniquingKeysWith: max) }
        var punkte: [SchlafPunkt] = []
        for (s, w) in zip(sessions, werte) where !w.isEmpty {
            guard let minuten = schlafMinuten[Datum.text(s.start)] else { continue }
            let mittel = w.map { $0.value / (bestwert[$0.key] ?? $0.value) }.reduce(0, +) / Double(w.count)
            punkte.append(SchlafPunkt(id: s.id, stunden: Double(minuten) / 60, leistung: mittel * 100))
        }
        return punkte
    }

    /// Ein Satz zur Kernzeile: mehr oder weniger Leistung nach langen Nächten; unter 2 kurzen und 2 langen Nächten nur die Zahl der Einheiten.
    static func kernzeile(_ punkte: [SchlafPunkt]) -> String {
        let kurz = punkte.filter { $0.stunden < 6 }.map(\.leistung), gut = punkte.filter { $0.stunden >= 7 }.map(\.leistung)
        guard kurz.count >= 2, gut.count >= 2 else { return String(localized: "\(punkte.count) Einheiten mit Schlafdaten") }
        let mittelGut: Double = gut.reduce(0, +) / Double(gut.count)
        let mittelKurz: Double = kurz.reduce(0, +) / Double(kurz.count)
        let unterschied = Int((mittelGut - mittelKurz).rounded())
        if abs(unterschied) < 2 { return String(localized: "Kein Unterschied zwischen kurzen und langen Nächten") }
        return unterschied > 0 ? String(localized: "Nach langen Nächten im Schnitt \(unterschied) Prozentpunkte mehr Leistung") : String(localized: "Nach kurzen Nächten im Schnitt \(-unterschied) Prozentpunkte mehr Leistung")
    }
}

/// Streudiagramm Schlaf gegen Leistung: jeder Punkt eine Einheit, Schlaf der Nacht davor (Stunden) gegen die Leistung in Prozent des eigenen Bestwerts.
struct SchlafLeistungKarte: View {
    let punkte: [SchlafPunkt]
    @Environment(\.palette) private var palette

    var body: some View {
        DiagrammKarte(aussage: String(localized: "Schlaf und Training"), kernzeile: SchlafLeistung.kernzeile(punkte)) {
            Chart {
                ForEach(punkte) { p in
                    PointMark(x: .value("Schlaf in Stunden", p.stunden), y: .value("Leistung in Prozent", p.leistung))
                        .foregroundStyle(palette.text)
                        .symbolSize(60)
                }
            }
            .chartXScale(domain: 3...10)
            .chartYScale(domain: 40...105)
            .chartXAxisLabel("Stunden Schlaf", alignment: .center)
            .chartYAxisLabel("Leistung in Prozent", position: .leading)
            .frame(height: 190)
            .environment(\.locale, Datum.anzeigeLocale)
            .accessibilityChartDescriptor(SchlafLeistungBeschreibung(punkte: punkte, zusammenfassung: SchlafLeistung.kernzeile(punkte)))
        }
    }
}

private struct SchlafLeistungBeschreibung: AXChartDescriptorRepresentable {
    let punkte: [SchlafPunkt]
    let zusammenfassung: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXNumericDataAxisDescriptor(title: String(localized: "Schlaf"), range: 3...10, gridlinePositions: []) { String(localized: "\(SchlafFormat.zahl($0, stellen: 1)) Stunden") }
        let y = AXNumericDataAxisDescriptor(title: String(localized: "Leistung"), range: 40...105, gridlinePositions: []) { String(localized: "\(Int($0.rounded())) Prozent") }
        let serie = AXDataSeriesDescriptor(name: String(localized: "Einheiten"), isContinuous: false, dataPoints: punkte.map { AXDataPoint(x: $0.stunden, y: $0.leistung) })
        return AXChartDescriptor(title: String(localized: "Schlaf gegen Leistung"), summary: zusammenfassung, xAxis: x, yAxis: y, additionalAxes: [], series: [serie])
    }
}
