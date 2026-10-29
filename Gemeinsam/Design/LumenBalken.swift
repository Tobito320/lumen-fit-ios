import SwiftUI

/// Ersatz für `LumenBogen` mit denselben Daten: je Bereich ein waagerechter Balken mit Symbol, Zahl und Beschriftung.
/// Für den Fall, dass App Review die Bögen beanstandet (design.md Abschnitt 2, Punkt 5): Umbau ist nur der Austausch dieser Ansicht.
struct LumenBalken: View {
    let werte: [BogenWert]
    @Environment(\.colorScheme) private var schema

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            ForEach(werte) { wert in
                let farbe = LumenFarben.ring(wert.id, dunkel: schema == .dark)
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    HStack(spacing: Abstand.s) {
                        Image(systemName: wert.id.symbolName).foregroundStyle(farbe).accessibilityHidden(true)
                        Text(wert.zahl).font(.headline.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(.white)
                        Text(wert.beschriftung).font(.caption).foregroundStyle(.white.opacity(0.8))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(farbe.opacity(0.22))
                            Capsule().fill(farbe).frame(width: geo.size.width * min(max(wert.anteil, 0), 1))
                        }
                    }
                    .frame(height: 8)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
