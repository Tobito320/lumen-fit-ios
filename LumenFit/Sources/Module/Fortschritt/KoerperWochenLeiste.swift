// Quelle: Lovea Health/Koerper/KoerperView.swift (Streifen)
import SwiftUI

/// Die Woche Mo bis So mit Datumszahl, darunter die Bilanz. Der Zustand steht in Form und Füllung, nie nur in Farbe: gefüllter Kreis mit Haken = trainiert,
/// dicker Ring = heute, dünner Ring mit "Beine" oder "Ober" darunter = Plan-Tag, der kommt, gestrichelter Ring = Plan-Tag, der ausfiel, blasse Scheibe = Ruhetag.
/// Die Haken springen nacheinander auf (Reduce Motion: sofort).
struct KoerperWochenLeiste: View {
    let woche: KoerperWoche
    /// Im Heute-Tab des Lovea-Aufbaus (Lovea `Streifen`, `KoerperView.swift:500`): der gewählte Tag bekommt einen Ring, ein Tipp wählt den Tag.
    var gewaehlt: String?
    var waehlen: ((String) -> Void)?
    /// Eingebettet in die Tagesform-Karte: ohne eigene Karte und ohne Bilanz.
    var eingebettet = false
    @State private var geladen = false
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion

    var body: some View {
        if eingebettet {
            leiste
        } else {
            ListenKarte {
                VStack(spacing: Abstand.m) {
                    leiste
                    Text(woche.bilanz)
                        .font(.footnote)
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(Abstand.l)
            }
        }
    }

    private var leiste: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(woche.tage.enumerated()), id: \.element.datum) { i, tag in
                zelle(tag, index: i)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tag.sprechtext)
                    .accessibilityAddTraits(tag.datum == gewaehlt ? .isSelected : [])
            }
        }
        .onAppear { geladen = true }
    }

    @ViewBuilder
    private func zelle(_ tag: KoerperWoche.Tag, index: Int) -> some View {
        if let waehlen {
            Button { waehlen(tag.datum) } label: { spalte(tag, index: index) }.buttonStyle(.plain)
        } else {
            spalte(tag, index: index)
        }
    }

    private func spalte(_ tag: KoerperWoche.Tag, index: Int) -> some View {
        VStack(spacing: Abstand.xs) {
            Text(tag.kuerzel)
                .font(.caption.weight(tag.heute ? .bold : .medium))
                .foregroundStyle(tag.heute ? palette.text : palette.text2)
            kreis(tag, index: index)
                .frame(width: 36, height: 36)
                .overlay {
                    if tag.datum == gewaehlt, !tag.heute { Circle().strokeBorder(palette.text, lineWidth: 2).padding(-3) }
                }
            // Das Wort steht in jeder Spalte (leer als Leerzeichen), damit alle Spalten gleich hoch sind.
            Text(tag.planWort ?? " ")
                .font(.caption2)
                .foregroundStyle(palette.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
    }

    @ViewBuilder private func kreis(_ tag: KoerperWoche.Tag, index: Int) -> some View {
        switch tag.anzeige {
        case .fertig:
            ZStack {
                Circle().fill(palette.text)
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(palette.grund)
            }
            .scaleEffect(geladen || reduceMotion ? 1 : 0.3)
            .opacity(geladen || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? nil : Feder.federnd.delay(Double(index) * 0.05), value: geladen)
        case .heute:
            ring(tag, palette.text, StrokeStyle(lineWidth: 2.5), palette.text)
        case .kommt:
            ring(tag, palette.rand, StrokeStyle(lineWidth: 1.5), palette.text)
        case .verpasst:
            ring(tag, palette.rand.opacity(0.7), StrokeStyle(lineWidth: 1.5, dash: [3, 3]), palette.text2)
        case .ruhe:
            ZStack {
                Circle().fill(palette.haar)
                zahl(tag.nummer, palette.text2)
            }
        }
    }

    private func ring(_ tag: KoerperWoche.Tag, _ farbe: Color, _ strich: StrokeStyle, _ zahlFarbe: Color) -> some View {
        ZStack {
            Circle().strokeBorder(farbe, style: strich)
            zahl(tag.nummer, zahlFarbe)
        }
    }

    private func zahl(_ n: Int, _ farbe: Color) -> some View {
        Text("\(n)").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(farbe)
    }
}
