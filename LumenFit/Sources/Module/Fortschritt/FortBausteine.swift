import SwiftUI

/// Abschnittskopf im neuen Design: Titel groß, rechts optional ein Hinweis oder ein Lime-Link ("Alle").
struct FortKopf<Ziel: View>: View {
    let titel: LocalizedStringKey
    var hinweis: String?
    var linkTitel: LocalizedStringKey?
    let ziel: Ziel
    @Environment(\.palette) private var palette

    init(_ titel: LocalizedStringKey, hinweis: String? = nil, linkTitel: LocalizedStringKey? = nil, @ViewBuilder ziel: () -> Ziel) {
        self.titel = titel
        self.hinweis = hinweis
        self.linkTitel = linkTitel
        self.ziel = ziel()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
            Text(titel).font(.title2.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Spacer(minLength: Abstand.s)
            if let hinweis { Text(hinweis).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.trailing) }
            if let linkTitel {
                NavigationLink { ziel } label: {
                    Text(linkTitel).font(.body.weight(.semibold)).foregroundStyle(palette.akzent).frame(minHeight: Abstand.tippflaeche).contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Abstand.xs)
    }
}

extension FortKopf where Ziel == EmptyView {
    init(_ titel: LocalizedStringKey, hinweis: String? = nil) {
        self.init(titel, hinweis: hinweis) { EmptyView() }
    }
}

/// Listen-Zeile des neuen Designs: farbiges Symbol-Quadrat, Titel, rechts der Wert und der Pfeil. Öffnet `ziel` oder eine Route.
struct FortListenZeile<Ziel: View>: View {
    let titel: LocalizedStringKey
    let wert: String?
    let symbol: String
    let farbe: Color
    var route: Route?
    let ziel: Ziel
    @Environment(\.palette) private var palette

    init(_ titel: LocalizedStringKey, wert: String? = nil, symbol: String, farbe: Color, @ViewBuilder ziel: () -> Ziel) {
        self.titel = titel
        self.wert = wert
        self.symbol = symbol
        self.farbe = farbe
        self.ziel = ziel()
    }

    var body: some View {
        if let route {
            NavigationLink(value: route) { zeile }.buttonStyle(.plain)
        } else {
            NavigationLink { ziel } label: { zeile }.buttonStyle(.plain)
        }
    }

    private var zeile: some View {
        HStack(spacing: Abstand.m) {
            SymbolQuadrat(symbol: symbol, farbe: farbe)
            Text(titel).font(.body).foregroundStyle(palette.text).multilineTextAlignment(.leading)
            Spacer(minLength: Abstand.s)
            if let wert { Text(wert).font(.body).foregroundStyle(palette.text2).monospacedDigit().lineLimit(1) }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension FortListenZeile where Ziel == EmptyView {
    init(_ titel: LocalizedStringKey, wert: String? = nil, symbol: String, farbe: Color, route: Route) {
        self.init(titel, wert: wert, symbol: symbol, farbe: farbe) { EmptyView() }
        self.route = route
    }
}

/// Lumi klein mit einem Satz (Entwurf "Lumi-Zeile").
struct FortLumiZeile: View {
    let stimmung: LumiStimmung
    let satz: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            LumiView(stimmung: stimmung, groesse: 40).accessibilityHidden(true)
            Text(satz).font(.subheadline.weight(.medium)).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Kleine Säulen ohne Achsen, antippbar oder nicht: der aktuelle/gewählte Balken in Lime, die anderen gedämpft.
struct FortSaeulen: View {
    struct Saeule: Identifiable {
        let id: String
        let beschriftung: String
        let wert: Double
        let sprechtext: String
    }
    let saeulen: [Saeule]
    let hervorgehoben: String?
    var hoehe: CGFloat = 80
    var beiTipp: ((String) -> Void)?
    @Environment(\.palette) private var palette

    var body: some View {
        let hoechster = max(saeulen.map(\.wert).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: Abstand.s) {
            ForEach(saeulen) { s in
                let an = s.id == hervorgehoben
                let saeule = VStack(spacing: Abstand.xs) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(an ? palette.akzent : palette.akzent.opacity(0.4))
                        .frame(height: max(4, hoehe * s.wert / hoechster))
                        .frame(maxWidth: 28)
                    Text(s.beschriftung).font(.caption2.weight(an ? .bold : .regular)).foregroundStyle(an ? palette.text : palette.text2)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                if let beiTipp {
                    Button { beiTipp(s.id) } label: { saeule.frame(minHeight: Abstand.tippflaeche, alignment: .bottom).contentShape(.rect) }
                        .buttonStyle(.plain)
                        .accessibilityLabel(s.sprechtext)
                        .accessibilityAddTraits(an ? .isSelected : [])
                } else {
                    saeule.accessibilityElement(children: .ignore).accessibilityLabel(s.sprechtext)
                }
            }
        }
        .frame(height: hoehe + 24, alignment: .bottom)
    }
}

/// Merkt sich das letzte Ergebnis einer Rechnung und rechnet nur neu, wenn sich die Eingabe ändert (Regel: keine Rechnungen bei jedem Aufbau).
/// Kein `@Observable`: die Ansicht beobachtet die Stores selbst und hält den Merker in `@State`.
@MainActor final class FortMerker<Eingabe: Equatable, Ergebnis> {
    private var eingabe: Eingabe?
    private var ergebnis: Ergebnis?

    func wert(_ e: Eingabe, rechne: () -> Ergebnis) -> Ergebnis {
        if e == eingabe, let ergebnis { return ergebnis }
        let neu = rechne()
        eingabe = e
        ergebnis = neu
        return neu
    }
}

/// Eingabe für Rechnungen über die Einheiten: Einheiten, Plan und der Tag.
struct FortTrainingEingabe: Equatable {
    let sessions: [GymSession]
    let plan: TrainingsPlan
    let heute: String
}
