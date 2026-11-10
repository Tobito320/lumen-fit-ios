// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (TagebuchAnsicht.uebersicht, ring, makro)
import SwiftUI

/// Die eine Hero-Karte des Tabs: Gegessen | offener Bogen "Übrig" oder "Drüber" | Verbrannt, darunter drei Makro-Balken (Ist/Ziel).
/// Tipp öffnet die Nährwerte des Tages. Verbrannt kommt aus Apple Health (nur Anzeige, zählt nicht zum Ziel).
struct EssenUebersichtKarte: View {
    let summe: Naehrwerte
    let ziele: ErnaehrungsZiele
    let verbrannt: Int?
    let oeffnen: @MainActor () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus

    private var gegessen: Int { Int(summe.kcal.rounded()) }

    var body: some View {
        Button { oeffnen() } label: {
            karte {
                VStack(spacing: Abstand.l) {
                    HStack(alignment: .center, spacing: 0) {
                        kennzahl(Double(gegessen), String(localized: "Gegessen"))
                        bogen
                        kennzahl(Double(verbrannt ?? 0), String(localized: "Verbrannt"))
                    }
                    HStack(alignment: .top, spacing: Abstand.l) {
                        makro(String(localized: "Kohlenhydrate"), ist: summe.kohlenhydrate, ziel: ziele.kohlenhydrate)
                        makro(String(localized: "Eiweiß"), ist: summe.protein, ziel: ziele.protein)
                        makro(String(localized: "Fett"), ist: summe.fett, ziel: ziele.fett)
                    }
                }
            }
        }
        .buttonStyle(.federnd)
        .accessibilityHint("Zeigt alle Nährwerte des Tages")
    }

    private func karte<V: View>(@ViewBuilder _ inhalt: () -> V) -> some View {
        HeroKarte { inhalt() }
    }

    private func kennzahl(_ wert: Double, _ titel: String) -> some View {
        VStack(spacing: 2) {
            RollZahl(wert: wert, format: .number.precision(.fractionLength(0))).font(.title3.weight(.bold)).fontDesign(.rounded)
            Text(titel).font(.footnote).opacity(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var bogen: some View {
        let rest = ziele.kcal - gegessen
        let anteil = EssenTagebuchLogik.anteil(ist: Double(gegessen), soll: Double(ziele.kcal))
        return ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(palette.aufAkzent.opacity(0.25), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: 0.75 * anteil)
                .stroke(palette.aufAkzent, style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: rest >= 0 ? [] : [2, 14]))
                .rotationEffect(.degrees(135))
                .animation(bewegungAus ? nil : Feder.weich, value: anteil)
            VStack(spacing: 0) {
                RollZahl(wert: Double(abs(rest)), format: .number.precision(.fractionLength(0)))
                    .font(.title.weight(.heavy)).fontDesign(.rounded).minimumScaleFactor(0.6).lineLimit(1)
                Text(rest >= 0 ? "Übrig" : "Drüber").font(.footnote).opacity(0.8)
            }
            .padding(.horizontal, Abstand.l)
        }
        .frame(width: 136, height: 136)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rest >= 0 ? "\(rest) Kilokalorien übrig" : "\(-rest) Kilokalorien drüber")
    }

    private func makro(_ titel: String, ist: Double, ziel: Int) -> some View {
        let anteil = EssenTagebuchLogik.anteil(ist: ist, soll: Double(ziel))
        return VStack(alignment: .leading, spacing: 6) {
            Text(titel).font(.footnote).opacity(0.8).lineLimit(1).minimumScaleFactor(0.8)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.aufAkzent.opacity(0.25))
                    Capsule().fill(palette.aufAkzent).frame(width: geo.size.width * anteil)
                        .animation(bewegungAus ? nil : Feder.weich, value: anteil)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
            Text("\(Int(ist.rounded())) / \(ziel) g").font(.footnote.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
