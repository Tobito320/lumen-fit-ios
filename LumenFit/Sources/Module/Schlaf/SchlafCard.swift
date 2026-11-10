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

    private var zeiten: String { String(localized: "\(Datum.uhrzeit(nacht.nacht.von)) bis \(Datum.uhrzeit(nacht.nacht.bis))") }

    /// Symbol und Text zum Ziel: nie nur Farbe.
    private var zielZeile: (symbol: String, text: String) {
        guard zielMinuten > 0 else { return ("moon.zzz.fill", String(localized: "Kein Ziel gesetzt")) }
        if minuten >= zielMinuten { return ("checkmark", String(localized: "Ziel erreicht")) }
        return ("arrow.down", String(localized: "\(SchlafFormat.dauer(zielMinuten - minuten)) unter deinem Ziel"))
    }

    /// "02:10–02:40, 04:05–04:20": Wach in der Nacht und Nickerchen aus den Schlafphasen (Lovea `SchlafCard`).
    private func zeitText(_ liste: [SchlafAbschnitt]) -> String {
        liste.map { "\(Datum.uhrzeit($0.von))–\(Datum.uhrzeit($0.bis))" }.joined(separator: ", ")
    }

    private var sprechText: String {
        var teile = [String(localized: "\(titel): \(SchlafFormat.sprechDauer(minuten)) geschlafen"), String(localized: "von \(zeiten)")]
        if zielMinuten > 0 { teile.append(String(localized: "Ziel \(SchlafFormat.sprechDauer(zielMinuten))")) }
        teile.append(zielZeile.text)
        teile.append(lumi.beschreibung)
        if !nacht.nacht.wachPhasen.isEmpty { teile.append(String(localized: "Wach in der Nacht: \(zeitText(nacht.nacht.wachPhasen))")) }
        if let n = nacht.nacht.nickerchen, !n.isEmpty { teile.append(String(localized: "Nickerchen: \(zeitText(n))")) }
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
                        Text(zielMinuten > 0 ? String(localized: "\(zeiten) · Ziel \(SchlafFormat.stundenMinuten(zielMinuten))") : zeiten)
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
                    Label(String(localized: "Wach in der Nacht: \(zeitText(nacht.nacht.wachPhasen))"), systemImage: "eye")
                        .font(.footnote.weight(.medium)).monospacedDigit()
                }
                if let n = nacht.nacht.nickerchen, !n.isEmpty {
                    Label(String(localized: "Nickerchen: \(zeitText(n))"), systemImage: "powersleep")
                        .font(.footnote.weight(.medium)).monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechText)
    }
}
