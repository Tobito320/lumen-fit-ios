// Quelle: Lovea Health/Heute/HeuteView.swift (TagesformKarte.ring, stufenFarbe)
import SwiftUI

/// Der Tagesform-Ring aus Lovea (nur im Theme "Lovea"): Ring mit der Zahl in der Mitte, daneben das Urteil. Die Farbe zeigt die Stufe
/// (ab 70 grün, ab 50 orange, darunter rot), Zahl und Urteil stehen immer dabei. Der Ring füllt sich mit einer Feder; "Bewegung reduzieren": sofort.
struct TagesformRing: View {
    let akku: Int?
    let urteil: String
    @ScaledMetric(relativeTo: .largeTitle) private var ringGroesse = 76.0
    @Environment(\.bewegungAus) private var ruhig
    @Environment(\.palette) private var palette

    /// Ab 70 grün, ab 50 orange, darunter rot; ohne Zahl neutral.
    private var stufenFarbe: Color {
        guard let akku else { return palette.text2 }
        if akku >= TagesformKlartext.vollAb { return .green }
        if akku >= TagesformKlartext.leichtAb { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: Abstand.l) {
            ring
            VStack(alignment: .leading, spacing: 2) {
                Text(urteil).font(.title3.bold()).foregroundStyle(palette.text)
                if let akku {
                    Text("Energie \(akku) von 100").font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private var ring: some View {
        let durchmesser = min(ringGroesse, 120)
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)   // Lovea: `Color.secondary.opacity(0.2)`
            if let akku {
                Circle()
                    .trim(from: 0, to: Double(min(max(akku, 0), 100)) / 100)
                    .stroke(stufenFarbe, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text(akku.map { String($0) } ?? "–")
                .font(.system(size: durchmesser * 0.38, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
                .contentTransition(.numericText())
        }
        .frame(width: durchmesser, height: durchmesser)
        .animation(ruhig ? nil : Feder.weich, value: akku)
    }
}
