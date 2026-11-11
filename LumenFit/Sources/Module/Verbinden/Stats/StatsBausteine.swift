import SwiftUI

/// Die Chips Schritte, Punkte, Trainings, Sets, Serie (seitlich wischbar); die gewählte in Lime. Bei Schritte darunter Heute | Monat.
struct StatsChips: View {
    @Binding var mass: StatsMass
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ScrollView(.horizontal, showsIndicators: false) { chips }
            if mass.istSchritte {
                Picker("Zeitraum", selection: $mass) {
                    Text("Heute").tag(StatsMass.schritteHeute)
                    Text("Monat").tag(StatsMass.schritteMonat)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var chips: some View {
        HStack(spacing: Abstand.s) {
            ForEach(StatsMass.chips) { m in
                let an = m == mass || (m.istSchritte && mass.istSchritte)
                // Schritte nochmal antippen behält Heute oder Monat.
                Button { if !an { mass = m } } label: {
                    Text(m.titel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(an ? palette.aufAkzentFlaeche : palette.text)
                        .padding(.horizontal, Abstand.m)
                        .frame(minHeight: 36)
                        .background(an ? palette.akzentFlaeche : palette.flaeche, in: .capsule)
                        .overlay(Capsule().stroke(an ? Color.clear : palette.haar, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityAddTraits(an ? .isSelected : [])
            }
        }
    }
}

/// Die Karte oben: Lumi, für wen der Platz gilt, "Platz 3 von 4", der eigene Wert, ein Satz; darunter die Zeile, wer mich sieht, mit Knopf.
struct StatsPlatzKarte: View {
    let gruppe: String
    /// nil: ich stehe nicht in der Liste (Schritte nicht mitgezählt).
    let rang: Int?
    let von: Int
    let wert: String
    let satz: String?
    let stimmung: LumiStimmung
    let sichtSymbol: String
    let sichtText: String
    let knopf: String
    let aktion: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte { inhalt.padding(Abstand.l) }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(alignment: .center, spacing: Abstand.l) {
                LumiView(stimmung: stimmung, groesse: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gruppe).font(.footnote).foregroundStyle(palette.text2)
                    if let rang {
                        HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                            Text("Platz \(rang)").font(.title2.weight(.bold)).foregroundStyle(palette.text)
                            Text("von \(von)").font(.subheadline).foregroundStyle(palette.text2)
                        }
                    } else {
                        Text("Nicht dabei").font(.title2.weight(.bold)).foregroundStyle(palette.text)
                    }
                    Text(wert).font(.subheadline).foregroundStyle(palette.text2)
                    if let satz { Text(satz).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true) }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            Haarlinie()
            HStack(spacing: Abstand.s) {
                Image(systemName: sichtSymbol).foregroundStyle(palette.text2).accessibilityHidden(true)
                Text(sichtText).font(.footnote).foregroundStyle(palette.text2).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Abstand.s)
                Button(knopf, action: aktion)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, Abstand.m)
                    .frame(minHeight: Abstand.tippflaeche)
                    .background(palette.flaeche, in: .capsule)
                    .overlay(Capsule().stroke(palette.haar, lineWidth: 1))
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.text)
            }
        }
    }
}

/// Eine Zeile der Liste: Platz, Kreis mit dem ersten Buchstaben, Name (bei mir mit Untertitel), Wert. Die eigene Zeile ist Lime hinterlegt.
struct StatsZeileView: View {
    let zeile: CrewRang
    var untertitel: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            Text("\(zeile.rang)").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text2).frame(minWidth: 28, alignment: .leading)
            Text(String(zeile.name.prefix(1)).uppercased())
                .font(.footnote.weight(.bold))
                .foregroundStyle(palette.text)
                .frame(width: 30, height: 30)
                .background(palette.grund, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(zeile.name).font(.body.weight(zeile.ich ? .bold : .regular)).foregroundStyle(palette.text).lineLimit(1)
                if let untertitel { Text(untertitel).font(.caption).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: Abstand.s)
            Text(StatsLogik.zahl(zeile.wert)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(minHeight: Abstand.tippflaeche)
        .background(zeile.ich ? palette.akzent.opacity(0.18) : Color.clear)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Platz \(zeile.rang), \(zeile.name), \(zeile.wert)"))
    }
}

/// Eine Zeile mit farbigem Symbol wie in den iOS-Einstellungen, Wert rechts und Pfeil.
struct StatsMenueZeile: View {
    let symbol: String
    let farbe: Color
    let titel: String
    var wert: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            SymbolQuadrat(symbol: symbol, farbe: farbe)
            Text(titel).font(.body).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            if let wert { Text(wert).font(.subheadline).foregroundStyle(palette.text2) }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
    }
}

/// Überschrift eines Abschnitts mit kleinem Zusatz rechts ("gegen deine Freunde").
struct StatsKopf: View {
    let titel: String
    var zusatz: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titel).font(.title3.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Spacer()
            if let zusatz { Text(zusatz).font(.footnote).foregroundStyle(palette.text2) }
        }
        .padding(.top, Abstand.s)
    }
}

/// Texte, wenn ich bei Schritte nicht in der Liste stehe (Mitzählen > Schritte aus oder keine Health-Freigabe).
enum StatsTexte {
    static var schritteNichtDabei: String { String(localized: "Schritte mitzählen, um mitzumachen.") }
    static var schritteWie: String { String(localized: "Profil > Präferenzen > Mitzählen: Schritte an und Apple Health erlauben.") }
}
