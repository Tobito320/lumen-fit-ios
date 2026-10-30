// Quelle: Lovea Health/SchritteDetail.swift (SchritteGrossRing)
import SwiftUI

/// Der große Bogen des Schritte-Details: offene 270 Grad, Öffnung unten (kein geschlossener Aktivitätsring, design.md Abschnitt 2). Die erste Runde füllt bis
/// zum Ziel, darüber läuft eine zweite, hellere Runde. In der Mitte Zeitraum, Zahl, "von N Schritten" und ab dem Ziel ein Siegel.
/// Gedacht für die schwarze Platte (`HeroKarte(platte: true)`): Farbe ist das Ring-Original, Text weiß.
struct SchritteBogen: View {
    let titel: String
    let anzahl: Int?
    let ziel: Int
    @Environment(\.bewegungAus) private var bewegungAus
    @ScaledMetric(relativeTo: .largeTitle) private var skala: CGFloat = 1

    var body: some View {
        let seite = 230 * min(max(skala, 1), 1.25)
        let laeufe = SchritteBogenLogik.laeufe(anzahl: anzahl, ziel: ziel)
        let farbe = LumenFarben.ring(.bewegen, dunkel: true)
        let strich: CGFloat = 20
        ZStack {
            ZStack {
                Circle().trim(from: 0, to: 0.75).stroke(farbe.opacity(0.22), style: StrokeStyle(lineWidth: strich, lineCap: .round))
                Circle().trim(from: 0, to: 0.75 * laeufe.erste).stroke(farbe, style: StrokeStyle(lineWidth: strich, lineCap: .round))
                if laeufe.zweite > 0 {
                    Circle().trim(from: 0, to: 0.75 * laeufe.zweite)
                        .stroke(farbe.mix(with: .white, by: 0.45), style: StrokeStyle(lineWidth: strich, lineCap: .round))
                }
            }
            .rotationEffect(.degrees(135))
            mitte(seite: seite, laeufe: laeufe)
        }
        .padding(strich / 2 + 2)
        .frame(width: seite, height: seite)
        .animation(bewegungAus ? nil : Feder.weich, value: laeufe)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel): \(anzahl.map(HeuteQuellen.zahl) ?? "keine") von \(HeuteQuellen.zahl(ziel)) Schritten\(laeufe.erreicht ? ", Ziel erreicht" : "")")
    }

    private func mitte(seite: CGFloat, laeufe: SchritteBogenLogik.Laeufe) -> some View {
        VStack(spacing: 4) {
            Text(titel).font(.system(size: seite * 0.075, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.7)
            Text(anzahl.map(HeuteQuellen.zahl) ?? "–")
                .font(.system(size: seite * 0.2, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(anzahl ?? 0)))
            Text("von \(HeuteQuellen.zahl(ziel)) Schritten").font(.system(size: seite * 0.056, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            if laeufe.erreicht {
                Label(laeufe.zweite > 0 ? "Ziel \(laeufe.prozent) %" : "Ziel", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold)).foregroundStyle(.black)
                    .padding(.horizontal, Abstand.s).padding(.vertical, 4)
                    .background(Capsule().fill(LumenFarben.ring(.bewegen, dunkel: true)))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, seite * 0.14)
    }
}
