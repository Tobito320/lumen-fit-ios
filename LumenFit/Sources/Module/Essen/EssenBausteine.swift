// Quelle: Lovea Health/Ernaehrung/EssenAmpelKarte.swift und ErnaehrungRating.swift (Inhalt; die Ansichten sind neu im Lumen-Design)
import SwiftUI

/// Halal- und Zucker-Ampel: zwei Pillen mit Symbol und Text (nie nur Farbe), darunter der Grund. Nur ein Hinweis aus Zutaten und Nährwerten.
struct EssenAmpelKarte: View {
    let lebensmittel: Lebensmittel
    @Environment(\.palette) private var palette

    var body: some View {
        let halal = EssenAmpelAnzeige.halal(EssenAmpel.halal(lebensmittel))
        let zucker = EssenAmpelAnzeige.zucker(EssenAmpel.zucker(lebensmittel))
        VStack(alignment: .leading, spacing: Abstand.m) {
            zeile(halal)
            zeile(zucker)
            Text("Ein Hinweis aus der Zutatenliste, keine Garantie. Zutatenlisten sind oft lückenhaft.")
                .font(.footnote)
                .foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    private func zeile(_ a: EssenAmpelAnzeige) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Pille(text: a.text, symbolName: a.symbol)
            Text(a.grund).font(.subheadline).foregroundStyle(palette.text2)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Die Schilder aus `FoodRating` in einer Zeile, seitlich scrollbar.
struct EssenSchilderZeile: View {
    let schilder: [FoodSchild]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Abstand.s) {
                ForEach(schilder) { s in
                    Pille(text: s.text, symbolName: s.positiv ? "plus.circle.fill" : "minus.circle.fill")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Eine Zeile in Suchlisten: Name, Marke und Energie je 100 g; Quelle als kleine Zeile.
struct EssenLebensmittelZeile: View {
    let lebensmittel: Lebensmittel
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Text(lebensmittel.name).font(.body).foregroundStyle(palette.text).multilineTextAlignment(.leading)
                Text([lebensmittel.marke, EssenQuelle.name(lebensmittel)].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            Text("\(Int(lebensmittel.pro100.kcal.rounded())) kcal")
                .font(.subheadline).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text2)
        }
        .padding(.vertical, Abstand.xs)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lebensmittel.anzeigeName), \(Int(lebensmittel.pro100.kcal.rounded())) Kilokalorien auf 100 \(lebensmittel.basisEinheit.rawValue), \(EssenQuelle.zeile(lebensmittel))")
    }
}

/// Zahlenfeld mit deutschem Komma. Leer oder ungültig bleibt `nil`.
struct EssenZahlFeld: View {
    let titel: String
    let einheit: String
    @Binding var text: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Text(titel).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 110)
                .accessibilityLabel(titel)
            Text(einheit).foregroundStyle(palette.text2).frame(minWidth: 36, alignment: .leading)
        }
        .frame(minHeight: Abstand.tippflaeche)
    }
}

/// Waagerechter Balken in Grautönen (Essen ist monochrom): Spur in `haar`, Füllung in `text`. 0 bis 1.
struct EssenBalken: View {
    let anteil: Double
    var hoehe: CGFloat = 8
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.haar)
                Capsule().fill(palette.text.opacity(0.75)).frame(width: geo.size.width * min(max(anteil, 0), 1))
            }
        }
        .frame(height: hoehe)
        .accessibilityHidden(true)
    }
}
