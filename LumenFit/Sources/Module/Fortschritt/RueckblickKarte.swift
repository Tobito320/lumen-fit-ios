import SwiftUI

/// Idee 39: die Karte des Rückblicks (Woche oder Monat). Auch die Vorlage für das geteilte Bild: nur Text, Lumi und Flächen, kein Muster.
struct RueckblickBild: View {
    let daten: RueckblickDaten
    let stufe: Int
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(spacing: Abstand.m) {
                LumiView(stimmung: daten.stimmung, groesse: 56, stufe: stufe)
                VStack(alignment: .leading, spacing: 2) {
                    Text(daten.titel).font(.title3.weight(.bold)).fontDesign(.rounded)
                    Text("\(KoerperLogik.tagMonat(daten.von)) bis \(KoerperLogik.tagMonat(daten.bis))").font(.footnote).foregroundStyle(palette.text2)
                }
            }
            if daten.gymTage > 0 { Text(daten.zeile).font(.subheadline.weight(.semibold)).monospacedDigit() }
            Text(daten.besterMoment).font(.subheadline)
            Text("Lumen Fit").font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(daten.sprechtext)
    }
}

/// Der Rückblick mit Teilen-Knopf.
struct RueckblickKarte: View {
    let daten: RueckblickDaten
    let stufe: Int

    var body: some View {
        TeilbareKarte(titel: daten.titel, schluessel: daten.sprechtext + "\(stufe)") {
            RueckblickBild(daten: daten, stufe: stufe)
        }
    }
}
