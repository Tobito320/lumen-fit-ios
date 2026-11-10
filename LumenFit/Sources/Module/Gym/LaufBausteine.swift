import SwiftUI

/// Eine Kachel der Reihe Dauer / Volumen / Sets (Entwurf `.s3`): kleine Überschrift, große Zahl.
struct LaufKachel<Wert: View>: View {
    let titel: LocalizedStringKey
    let wert: Wert
    @Environment(\.palette) private var palette

    init(_ titel: LocalizedStringKey, @ViewBuilder wert: () -> Wert) {
        self.titel = titel
        self.wert = wert()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.footnote).foregroundStyle(palette.text2)
            wert.font(.title3.weight(.semibold)).fontDesign(.rounded).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Drei Kacheln nebeneinander mit Trennlinien auf einer Karte; ab Accessibility-Größe untereinander.
struct LaufKachelReihe<Inhalt: View>: View {
    let inhalt: Inhalt
    @Environment(\.dynamicTypeSize) private var schrift

    init(@ViewBuilder inhalt: () -> Inhalt) { self.inhalt = inhalt() }

    var body: some View {
        let layout = schrift.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Abstand.s)) : AnyLayout(HStackLayout(spacing: Abstand.m))
        layout { inhalt }
            .padding(Abstand.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lumenKartenFlaeche()
    }
}

/// Kleiner Lumi mit einem Satz (Entwurf `.lumz`).
struct LaufLumiZeile: View {
    let stimmung: LumiStimmung
    let text: LocalizedStringKey
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.s) {
            LumiView(stimmung: stimmung, groesse: 32).accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(palette.text2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Abstand.xs)
    }
}

/// Spaltenbreiten der Satz-Tabelle (Entwurf `.th`/`.sr`: Set, Letztes Mal, kg, Reps, Haken); Kopf und Zeilen nutzen dieselben.
enum LaufSpalten {
    nonisolated static let nummer: CGFloat = 44
    nonisolated static let kg: CGFloat = 62
    nonisolated static let wdh: CGFloat = 50
    nonisolated static let haken: CGFloat = 44
    nonisolated static let abstand: CGFloat = 6
}
