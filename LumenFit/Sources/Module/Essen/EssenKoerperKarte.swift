// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (TagebuchAnsicht.koerperKarte, rundKnopf)
import SwiftUI

/// Körperwerte: Gewicht mit Minus und Plus (je 0,1 kg), darunter die zuletzt eingetragenen Maße.
struct EssenKoerperKarte: View {
    let tag: String
    let gewicht: (zehntel: Int, datum: String)?
    let werte: [KoerperwertD]
    let aendern: @MainActor (Int) -> Void
    @Environment(\.palette) private var palette
    @State private var schritte = 0

    var body: some View {
        ListenKarte {
            HStack(spacing: Abstand.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gewicht").font(.headline.weight(.bold)).foregroundStyle(palette.text)
                    Text(EssenTagebuchLogik.gewichtText(zehntel: gewicht?.zehntel)).font(.title3.weight(.heavy)).fontDesign(.rounded).monospacedDigit()
                        .foregroundStyle(palette.text)
                        .contentTransition(.numericText(value: Double(gewicht?.zehntel ?? 0)))
                    Text(EssenTagebuchLogik.gewichtUnterzeile(datum: gewicht?.datum, tag: tag)).font(.footnote).foregroundStyle(palette.text2)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: Abstand.s)
                rundKnopf("minus", "0,1 kg weniger", -1)
                rundKnopf("plus", "0,1 kg mehr", 1)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
            ForEach(werte, id: \.art) { w in
                Haarlinie().padding(.leading, Abstand.l)
                HStack {
                    Text(w.art.name).font(.body).foregroundStyle(palette.text)
                    Spacer()
                    Text("\(ErnaehrungLogik.zahl(w.wert)) \(w.art.einheit)").font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                }
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: 48)
                .accessibilityElement(children: .combine)
            }
        }
        .haptik(.auswahl, bei: schritte)
    }

    private func rundKnopf(_ symbol: String, _ titel: String, _ schritt: Int) -> some View {
        Button {
            aendern(schritt)
            schritte += 1
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(palette.aufAkzent)
                .frame(width: 38, height: 38)
                .background(palette.akzent, in: .circle)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(titel)
    }
}
