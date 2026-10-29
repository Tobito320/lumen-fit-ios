import SwiftUI

/// Hinweise des Tages (Idee 19): höchstens drei kleine Karten, jede zur Seite oder mit dem Knopf wegwischbar. Der Aufrufer reicht schon die gekürzte Liste.
struct HinweiseKarte: View {
    let hinweise: [TagesHinweis]
    let wische: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Abstand.s) {
            ForEach(hinweise.prefix(TagesHinweisLogik.hoechstens)) { hinweis in
                HeuteHinweisReihe(hinweis: hinweis) { wische(hinweis.id) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(reduceMotion ? nil : Feder.weich, value: hinweise.map(\.id))
    }
}

private struct HeuteHinweisReihe: View {
    let hinweis: TagesHinweis
    let weg: () -> Void
    @State private var versatz: CGFloat = 0
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let schwelle: CGFloat = 80

    var body: some View {
        HStack(alignment: .top, spacing: Abstand.m) {
            Image(systemName: hinweis.symbol).foregroundStyle(palette.text2).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Text(hinweis.titel).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text(hinweis.text).font(.footnote.weight(.medium)).foregroundStyle(palette.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: weg) {
                Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Hinweis ausblenden")
        }
        .padding(.leading, Abstand.l)
        .padding(.vertical, Abstand.xs)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .offset(x: versatz)
        .opacity(1 - min(abs(versatz) / 240, 0.6))
        // simultan, sonst fängt die Karte das senkrechte Scrollen der Seite ab; nur waagerechtes Ziehen bewegt sie
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onChanged { werte in if abs(werte.translation.width) > abs(werte.translation.height) { versatz = werte.translation.width } }
                .onEnded { werte in
                    if abs(werte.translation.width) > Self.schwelle {
                        weg()
                    } else if reduceMotion {
                        versatz = 0
                    } else {
                        withAnimation(Feder.schnell) { versatz = 0 }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Ausblenden", weg)
    }
}
