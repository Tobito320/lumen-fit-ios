import Charts
import SwiftUI

/// Gewicht in drei Sekunden (Idee 17), Teil 1: die Karte mit dem aktuellen Gewicht, dem Verlauf und der Ziellinie. Der Knopf öffnet das Blatt mit dem Zahlenrad.
struct GewichtKarte: View {
    let gewicht: HeuteGewicht
    let wiege: () -> Void
    /// false bei einem vergangenen Tag der Tagwahl: nur ansehen, der Knopf fehlt.
    var eintragbar = true
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HeuteKartenKopf(symbol: "scalemass.fill", titel: "Gewicht", zusatz: gewicht.heuteEingetragen ? (eintragbar ? "heute eingetragen" : "an diesem Tag eingetragen") : nil)
                if let kg = gewicht.aktuellKg {
                    HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                        RollZahl(wert: kg, format: HeuteFormat.kilo())
                            .heuteHeldenZahl(40).foregroundStyle(palette.text)
                        Text("kg").font(.headline).foregroundStyle(palette.text2)
                        Spacer(minLength: Abstand.s)
                        if let aenderung = gewicht.aenderung { Text(aenderung).font(.footnote.weight(.medium)).foregroundStyle(palette.text2) }
                    }
                    .accessibilityElement(children: .combine)
                    if gewicht.punkte.count >= 2 { HeuteGewichtDiagramm(punkte: gewicht.punkte, ziel: gewicht.zielKg).frame(height: 96) }
                } else {
                    Text("Noch kein Gewicht. Trag es einmal ein, dann siehst du hier den Verlauf.").font(.subheadline).foregroundStyle(palette.text2)
                }
                if eintragbar {
                    Button(action: wiege) {
                        Text(gewicht.heuteEingetragen ? "Gewicht ändern" : "Gewicht eintragen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.text)
                }
            }
            .padding(Abstand.l)
        }
    }
}

/// Verlauf der letzten Tage als Linie, mit der Ziellinie, wenn ein Ziel gesetzt ist.
struct HeuteGewichtDiagramm: View {
    let punkte: [HeuteGewichtPunkt]
    let ziel: Double?
    @Environment(\.palette) private var palette

    var body: some View {
        let alle = punkte.map(\.kg) + (ziel.map { [$0] } ?? [])
        let unten = (alle.min() ?? 0) - 1
        let oben = (alle.max() ?? 1) + 1
        Chart {
            ForEach(punkte) { p in
                LineMark(x: .value("Tag", Datum.datum(p.tag)), y: .value("Gewicht in kg", p.kg)).interpolationMethod(.monotone)
                PointMark(x: .value("Tag", Datum.datum(p.tag)), y: .value("Gewicht in kg", p.kg)).symbolSize(20)
            }
            if let ziel {
                RuleMark(y: .value("Ziel", ziel))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(palette.text2)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("Ziel \(ziel, format: HeuteFormat.kilo()) kg").font(.caption.weight(.medium)).foregroundStyle(palette.text2)
                    }
            }
        }
        .foregroundStyle(palette.text)
        .chartYScale(domain: unten...oben)
        .environment(\.locale, Locale(identifier: "de_DE"))
        .accessibilityChartDescriptor(HeuteDiagrammBeschreibung(
            titel: "Gewichtsverlauf", zusammenfassung: zusammenfassung, xTitel: "Tag", yTitel: "Gewicht", einheit: "kg",
            punkte: punkte.map { HeuteDiagrammPunkt(name: SchritteDetailLogik.kurz($0.tag), wert: $0.kg) }))
    }

    private var zusammenfassung: String {
        guard let erster = punkte.first, let letzter = punkte.last else { return "Keine Werte" }
        let text = "\(String(format: "%.1f", letzter.kg).replacingOccurrences(of: ".", with: ",")) kg am \(SchritteDetailLogik.kurz(letzter.tag)), davor \(String(format: "%.1f", erster.kg).replacingOccurrences(of: ".", with: ",")) kg"
        return ziel.map { text + ", Ziel \(String(format: "%.1f", $0).replacingOccurrences(of: ".", with: ",")) kg" } ?? text
    }
}
