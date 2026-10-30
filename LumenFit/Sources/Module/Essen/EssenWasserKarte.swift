// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (TagebuchAnsicht.wasserKarte, glas)
import SwiftUI

/// Wasserzähler: Flaschen-Raster (ein Glas = 250 ml), Tipp auf das nächste leere Glas zählt eins mehr, Tipp auf ein volles Glas geht dorthin zurück.
/// Der Wert ist der Wasser-Habit des Tages (gleiche Zahl wie in Heute), dazu das Wasser aus Getränken im Tagebuch.
struct EssenWasserKarte: View {
    let glaeser: Int
    let zielGlaeser: Int
    let ausLebensmittelnMl: Int
    let bearbeitbar: Bool
    let setzen: @MainActor (Int) -> Void
    @Environment(\.palette) private var palette
    @State private var zaehler = 0

    var body: some View {
        let anzahl = EssenTagebuchLogik.glasAnzahl(ziel: zielGlaeser, voll: glaeser, bearbeitbar: bearbeitbar)
        VStack(spacing: Abstand.m) {
            VStack(spacing: 2) {
                Text("Wasser").font(.headline.weight(.bold)).foregroundStyle(palette.text)
                Text("Ziel: \(EssenTagebuchLogik.liter(zielGlaeser * EssenTagebuchLogik.glasMl))").font(.footnote).foregroundStyle(palette.text2)
            }
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: Double(glaeser * EssenTagebuchLogik.glasMl) / 1000, format: .number.precision(.fractionLength(0...2)))
                    .font(.title.weight(.heavy)).fontDesign(.rounded)
                Text("l").font(.title3.weight(.semibold))
            }
            .foregroundStyle(palette.text)
            .accessibilityElement(children: .combine)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Abstand.s), count: 6), spacing: Abstand.s) {
                ForEach(0..<anzahl, id: \.self) { glas($0) }
            }
            Text("+ Wasser aus Lebensmitteln: \(ausLebensmittelnMl) ml").font(.footnote).foregroundStyle(palette.text2)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity)
        .lumenKartenFlaeche()
        .haptik(.auswahl, bei: zaehler)
    }

    private func glas(_ i: Int) -> some View {
        let voll = i < glaeser
        let naechstes = i == glaeser
        return Button {
            setzen(EssenTagebuchLogik.glaeserNachTipp(index: i, voll: glaeser))
            zaehler += 1
        } label: {
            Group {
                if naechstes && bearbeitbar {
                    Image(systemName: "plus.circle.fill").foregroundStyle(palette.akzent)
                } else {
                    Image(systemName: voll ? "waterbottle.fill" : "waterbottle").foregroundStyle(voll ? palette.akzent : palette.rand.opacity(0.5))
                }
            }
            .font(.title).imageScale(.large)
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .disabled(!bearbeitbar || i > glaeser)
        .accessibilityLabel(naechstes && bearbeitbar ? "Glas \(i + 1) dazu" : (voll ? "Glas \(i + 1), voll" : "Glas \(i + 1), leer"))
        .accessibilityHint(voll ? "Setzt den Zähler auf \(i) Gläser zurück" : "")
    }
}
