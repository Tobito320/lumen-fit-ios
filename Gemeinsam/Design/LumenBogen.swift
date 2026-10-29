import SwiftUI

/// Ein Wert eines Bogens: Anteil 0 bis 1 (darüber wird gekappt, kein zweiter Umlauf), die Zahl daneben und die Beschriftung.
struct BogenWert: Identifiable, Sendable {
    var id: Datenbereich
    var anteil: Double
    var zahl: String
    var beschriftung: String
}

/// Offene 270-Grad-Bögen (Öffnung unten, runde Enden, 9 pt stark, Spur, 6 pt Abstand) mit Zahl und Beschriftung daneben und Lumi in der Mitte.
/// Gedacht für die schwarze Ringplatte (`HeroKarte(platte: true)`): Farben sind die Ring-Originale, Text ist weiß.
/// Kein Ring im Sinne von Apples Aktivitätsringen: offene Form, Beschriftung, eigene Daten (design.md Abschnitt 2). Ersatz: `LumenBalken`.
struct LumenBogen<Mitte: View>: View {
    let werte: [BogenWert]
    let mitte: Mitte
    @Environment(\.colorScheme) private var schema

    nonisolated static var strich: CGFloat { 9 }
    nonisolated static var abstand: CGFloat { 6 }

    init(werte: [BogenWert], mitte: Mitte) {
        self.werte = werte
        self.mitte = mitte
    }

    var body: some View {
        HStack(alignment: .center, spacing: Abstand.l) {
            ZStack {
                ForEach(Array(werte.enumerated()), id: \.element.id) { index, wert in
                    let rand = CGFloat(index) * (Self.strich + Self.abstand)
                    BogenSpur(anteil: wert.anteil, farbe: LumenFarben.ring(wert.id, dunkel: schema == .dark), strich: Self.strich)
                        .padding(rand + Self.strich / 2)
                }
                mitte
            }
            .frame(width: 148, height: 148)
            VStack(alignment: .leading, spacing: Abstand.s) {
                ForEach(werte) { wert in
                    HStack(spacing: Abstand.s) {
                        Image(systemName: wert.id.symbolName)
                            .foregroundStyle(LumenFarben.ring(wert.id, dunkel: schema == .dark))
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(wert.zahl).font(.headline.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(.white)
                            Text(wert.beschriftung).font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Spur (voller Bogen, blass) und Wert (Anteil des Bogens, runde Enden). 270 Grad, Öffnung unten.
private struct BogenSpur: View {
    let anteil: Double
    let farbe: Color
    let strich: CGFloat

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(farbe.opacity(0.22), style: StrokeStyle(lineWidth: strich, lineCap: .round))
            Circle().trim(from: 0, to: 0.75 * min(max(anteil, 0), 1)).stroke(farbe, style: StrokeStyle(lineWidth: strich, lineCap: .round))
        }
        .rotationEffect(.degrees(135))
    }
}
