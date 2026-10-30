import SwiftUI

/// Idee 51, letzte Nacht groß: die Schlafzeit als Heldenzahl mit von bis und Ziel. Die eine mutige Karte des Tabs. Lumi schläft nachts.
struct SchlafCard: View {
    let nacht: SchlafGewaehlteNacht
    let titel: String
    let zielMinuten: Int
    let lumi: LumiStimmung
    @ScaledMetric(relativeTo: .largeTitle) private var heldenGroesse: CGFloat = 56
    @Environment(\.dynamicTypeSize) private var schriftGroesse

    private var minuten: Int { nacht.nacht.schlafMinuten }

    private var zeiten: String { "\(Datum.uhrzeit(nacht.nacht.von)) bis \(Datum.uhrzeit(nacht.nacht.bis))" }

    /// Symbol und Text zum Ziel: nie nur Farbe.
    private var zielZeile: (symbol: String, text: String) {
        guard zielMinuten > 0 else { return ("moon.zzz.fill", "Kein Ziel gesetzt") }
        if minuten >= zielMinuten { return ("checkmark", "Ziel erreicht") }
        return ("arrow.down", "\(SchlafFormat.dauer(zielMinuten - minuten)) unter deinem Ziel")
    }

    /// "02:10–02:40, 04:05–04:20": Wach in der Nacht und Nickerchen aus den Schlafphasen (Lovea `SchlafCard`).
    private func zeitText(_ liste: [SchlafAbschnitt]) -> String {
        liste.map { "\(Datum.uhrzeit($0.von))–\(Datum.uhrzeit($0.bis))" }.joined(separator: ", ")
    }

    private var sprechText: String {
        var teile = ["\(titel): \(SchlafFormat.sprechDauer(minuten)) geschlafen", "von \(zeiten)"]
        if zielMinuten > 0 { teile.append("Ziel \(SchlafFormat.sprechDauer(zielMinuten))") }
        teile.append(zielZeile.text)
        teile.append(lumi.beschreibung)
        if !nacht.nacht.wachPhasen.isEmpty { teile.append("Wach in der Nacht: " + zeitText(nacht.nacht.wachPhasen)) }
        if let n = nacht.nacht.nickerchen, !n.isEmpty { teile.append("Nickerchen: " + zeitText(n)) }
        return teile.joined(separator: ", ")
    }

    var body: some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(titel.uppercased())
                    .font(.footnote.weight(.semibold))
                    .tracking(0.5)
                HStack(alignment: .center, spacing: Abstand.m) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                            Text(SchlafFormat.stundenMinuten(minuten))
                                .font(.system(size: heldenGroesse, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Text("h").font(.title3.weight(.semibold))
                        }
                        Text(zeiten + (zielMinuten > 0 ? " · Ziel \(SchlafFormat.stundenMinuten(zielMinuten))" : ""))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                    Spacer(minLength: Abstand.s)
                    if !schriftGroesse.isAccessibilitySize {
                        VStack(spacing: Abstand.xs) {
                            LumiView(stimmung: lumi, groesse: 64)
                            Text(lumi.beschreibung).font(.caption.weight(.medium)).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: 96)
                    }
                }
                Label(zielZeile.text, systemImage: zielZeile.symbol)
                    .font(.subheadline.weight(.semibold))
                if !nacht.nacht.wachPhasen.isEmpty {
                    Label("Wach in der Nacht: " + zeitText(nacht.nacht.wachPhasen), systemImage: "eye")
                        .font(.footnote.weight(.medium)).monospacedDigit()
                }
                if let n = nacht.nacht.nickerchen, !n.isEmpty {
                    Label("Nickerchen: " + zeitText(n), systemImage: "powersleep")
                        .font(.footnote.weight(.medium)).monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechText)
    }
}
