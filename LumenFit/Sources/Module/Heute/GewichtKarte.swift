import Charts
import SwiftUI

/// Karte "Gewicht" (neues Design 10.11.2026): Waage lila, oben rechts "+ Eintragen" (Blatt), die Zahl groß mit "kg" und rechts die Änderung zur Vorwoche,
/// die Kurve mit gestrichelter Ziel-Linie, unten "Ziel" (Blatt Gewichtsziel) und "Alle Einträge" (Körper und Gewicht). Ein Tipp auf Zahl und Kurve öffnet
/// ebenfalls alle Einträge. Ohne Aktionen (vergangener Tag im Tag-Blatt) nur zum Ansehen.
struct GewichtKarte: View {
    let gewicht: HeuteGewicht
    /// Öffnet das Blatt "Gewicht eintragen"; nil = nur ansehen.
    var eintragen: (() -> Void)?
    var ziel: (() -> Void)?
    var alleEintraege: (() -> Void)?
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack(spacing: Abstand.s) {
                    Image(systemName: "scalemass.fill").foregroundStyle(Bereichsfarbe.gewicht).accessibilityHidden(true)
                    Text("Gewicht").font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    if let eintragen { HeutePillKnopf(titel: "Eintragen", symbol: "plus", aktion: eintragen) }
                }
                if let alleEintraege {
                    Button(action: alleEintraege) { werte.contentShape(.rect) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Zeigt alle Einträge")
                } else {
                    werte
                }
                if ziel != nil || alleEintraege != nil {
                    Haarlinie()
                    HStack {
                        if let ziel { HeutePillKnopf(titel: "Ziel", symbol: "target", aktion: ziel).accessibilityValue(zielWert) }
                        Spacer(minLength: Abstand.s)
                        if let alleEintraege { HeutePillKnopf(titel: "Alle Einträge", symbol: "list.bullet", aktion: alleEintraege) }
                    }
                }
            }
            .padding(Abstand.l)
        }
    }

    private var zielWert: String {
        gewicht.zielKg.map { String(localized: "\($0.formatted(HeuteFormat.kilo())) kg") } ?? String(localized: "kein Ziel")
    }

    @ViewBuilder
    private var werte: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Kleiner Knopf als gefüllte Kapsel ("+ Eintragen", "Ziel", "Alle Einträge"); Tippfläche mindestens 44 pt hoch.
struct HeutePillKnopf: View {
    let titel: LocalizedStringKey
    let symbol: String
    let aktion: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.text)
                .padding(.horizontal, Abstand.m)
                .padding(.vertical, 7)
                .background(palette.haar, in: .capsule)
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
                        Text("Ziel \(ziel, format: HeuteFormat.zielKilo()) kg").font(.caption.weight(.medium)).foregroundStyle(palette.text2)
                    }
            }
        }
        .foregroundStyle(palette.text)
        .chartYScale(domain: unten...oben)
        .environment(\.locale, Locale(identifier: "de_DE"))
        .accessibilityChartDescriptor(HeuteDiagrammBeschreibung(
            titel: String(localized: "Gewichtsverlauf"), zusammenfassung: zusammenfassung, xTitel: String(localized: "Tag"), yTitel: String(localized: "Gewicht"), einheit: "kg",
            punkte: punkte.map { HeuteDiagrammPunkt(name: SchritteDetailLogik.kurz($0.tag), wert: $0.kg) }))
    }

    private var zusammenfassung: String {
        guard let erster = punkte.first, let letzter = punkte.last else { return String(localized: "Keine Werte") }
        let text = String(localized: "\(String(format: "%.1f", letzter.kg).replacingOccurrences(of: ".", with: ",")) kg am \(SchritteDetailLogik.kurz(letzter.tag)), davor \(String(format: "%.1f", erster.kg).replacingOccurrences(of: ".", with: ",")) kg")
        return ziel.map { String(localized: "\(text), Ziel \(String(format: "%.1f", $0).replacingOccurrences(of: ".", with: ",")) kg") } ?? text
    }
}
