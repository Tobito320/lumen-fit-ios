import SwiftUI

/// Die Nacht als Zeitleiste wie in Apple Health: je Phase eine Zeile (Wach oben, Tief unten), die Abschnitte als Muster-Felder über der Zeit.
/// Nur für Nächte mit Phasen (Uhr oder Band); sonst zeigt die Detailansicht den einfachen `PhasenBalken`.
struct SchlafNachtDiagramm: View {
    let nacht: SchlafNacht
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    /// Zeilenhöhe und Breite der Namensspalte wachsen mit der Schriftgröße, sonst ragen die Namen bei großer Schrift aus ihrer Zeile.
    @ScaledMetric(relativeTo: .caption) private var zeilenHoehe: CGFloat = 26
    @ScaledMetric(relativeTo: .caption) private var spaltenBreite: CGFloat = 44

    var body: some View {
        let zeilen = nacht.phasen
        let linie = LumenFarben.tief(.erholen, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        let grund = palette.flaeche
        let haar = palette.haar
        let von = nacht.von
        let spanne = max(nacht.bis.timeIntervalSince(nacht.von), 1)
        let abschnitte = nacht.abschnitte
        let hoehe = zeilenHoehe
        VStack(alignment: .leading, spacing: Abstand.xs) {
            HStack(alignment: .top, spacing: Abstand.s) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(zeilen, id: \.rawValue) { phase in
                        Text(phase.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(palette.text2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: spaltenBreite, height: hoehe, alignment: .trailing)
                    }
                }
                .accessibilityHidden(true)
                Canvas { kontext, groesse in
                    for i in zeilen.indices {
                        let y = CGFloat(i) * hoehe
                        kontext.fill(Path(CGRect(x: 0, y: y + hoehe - 1, width: groesse.width, height: 1)), with: .color(haar))
                    }
                    for a in abschnitte {
                        guard let zeile = zeilen.firstIndex(of: a.phase) else { continue }
                        let x0 = groesse.width * a.von.timeIntervalSince(von) / spanne
                        let x1 = groesse.width * a.bis.timeIntervalSince(von) / spanne
                        let rect = CGRect(x: x0, y: CGFloat(zeile) * hoehe + 4, width: max(x1 - x0, 2), height: hoehe - 9)
                        SchlafPhasenZeichner.fuelle(a.phase, rect: rect, linie: aufbau.farbe(LoveaDaten.schlaf(a.phase), sonst: linie), grund: grund, in: &kontext)
                    }
                }
                .frame(height: hoehe * CGFloat(zeilen.count))
                .accessibilityHidden(true)
            }
            HStack {
                Text(Datum.uhrzeit(nacht.von))
                Spacer(minLength: Abstand.s)
                Text(Datum.uhrzeit(nacht.bis))
            }
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(palette.text2)
            .padding(.leading, spaltenBreite + Abstand.s)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nacht.beschreibung)
        .accessibilityChartDescriptor(SchlafDiagrammBeschreibung(
            titel: "Schlaf in der Nacht", zusammenfassung: nacht.beschreibung, achseX: "Phase", reihe: "Minuten je Phase",
            punkte: zeilen.map { SchlafDiagrammBeschreibung.Punkt(name: $0.name, minuten: Double(nacht.minuten($0))) }))
    }
}
