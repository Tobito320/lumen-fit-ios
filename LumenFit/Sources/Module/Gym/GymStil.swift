import SwiftUI

/// Kleine Bausteine, die mehrere Gym-Ansichten teilen. Alles im Lumen-Design (Palette, Abstände), Tippflächen mindestens 44 pt.

enum GymFarbe {
    /// Die Tief-Farbe für Text und dünne Linien (Kontrast 4,5:1). Gym ist immer "Trainieren".
    static func gruen(schema: ColorScheme, kontrast: ColorSchemeContrast) -> Color {
        LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased)
    }
}

/// Minus, Zahl, Plus: statt Zahlen zu tippen. Für VoiceOver ein einziges verstellbares Element ("Gewicht, 62,5 kg").
struct GymSchalter: View {
    let titel: String
    let wert: String
    let minus: () -> Void
    let plus: () -> Void
    /// Tipp auf die Zahl (Zahlenfeld zum Eintippen); nil = die Zahl ist nur Anzeige.
    var tippen: (() -> Void)? = nil
    @Environment(\.palette) private var palette

    private var zahl: some View {
        Text(wert)
            .font(.title3.weight(.bold)).fontDesign(.rounded).monospacedDigit()
            .contentTransition(.numericText())
            .frame(minWidth: 52)
            .foregroundStyle(palette.text)
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: minus) {
                Image(systemName: "minus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche).contentShape(.rect)
            }
            if let tippen {
                Button(action: tippen) { zahl.frame(minHeight: Abstand.tippflaeche).contentShape(.rect) }
            } else {
                zahl
            }
            Button(action: plus) {
                Image(systemName: "plus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche).contentShape(.rect)
            }
        }
        .buttonStyle(.federnd)
        .foregroundStyle(palette.text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titel)
        .accessibilityValue(wert)
        .accessibilityAction(named: "Zahl eintippen") { tippen?() }
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: plus()
            case .decrement: minus()
            @unknown default: break
            }
        }
    }
}

/// Abschnittsüberschrift über einer Karte.
struct GymAbschnitt: View {
    let titel: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(titel)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(palette.text2)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Eine Zeile in einer `ListenKarte`: Titel, Untertitel und eine Handlung rechts. Mindestens 44 pt hoch.
struct GymZeile<Rechts: View>: View {
    let titel: String
    let untertitel: String?
    let rechts: Rechts
    @Environment(\.palette) private var palette

    init(titel: String, untertitel: String? = nil, @ViewBuilder rechts: () -> Rechts) {
        self.titel = titel
        self.untertitel = untertitel
        self.rechts = rechts()
    }

    var body: some View {
        HStack(spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.body.weight(.medium)).foregroundStyle(palette.text)
                if let untertitel { Text(untertitel).font(.footnote).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: Abstand.s)
            rechts
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
    }
}

extension GymZeile where Rechts == EmptyView {
    init(titel: String, untertitel: String? = nil) {
        self.init(titel: titel, untertitel: untertitel) { EmptyView() }
    }
}

/// Zeit als "1:05" aus Sekunden.
enum GymFormat {
    static func zeit(_ sekunden: Int) -> String { WorkoutLogik.zeitText(Double(sekunden)) }

    /// "12. Oktober" aus einem Datum (Berlin).
    static func tag(_ datum: Date) -> String { Datum.anzeige(Datum.text(datum)) }
}

/// Listen-Zeile des neuen Designs: farbiges Symbol links (`SymbolQuadrat`), Titel, Untertitel, Pfeil. Texte kommen fertig übersetzt (`String(localized:)`).
struct GymSymbolZeile: View {
    let symbol: String
    let farbe: Color
    let titel: String
    var untertitel: String? = nil
    var pfeil = true
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            SymbolQuadrat(symbol: symbol, farbe: farbe)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.body.weight(.medium)).foregroundStyle(palette.text)
                if let untertitel { Text(untertitel).font(.footnote).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: Abstand.s)
            if pfeil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Eine Übung als Zeile: Bild, Name, Untertitel ("Brust · 3 Sets"), Pfeil.
struct GymUebungZeile: View {
    let id: String
    let koerper: String?
    let titel: String
    let untertitel: String
    var pfeil = true
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            UebungsBild(id: id, koerper: koerper, tippbar: false).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.body.weight(.medium)).foregroundStyle(palette.text).lineLimit(2)
                Text(untertitel).font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            if pfeil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Filter-Chip: gewählt Lime-Fläche mit dunkler Schrift, sonst Fläche mit Rand. Tippfläche 44 pt.
struct GymChip: View {
    let text: String
    let aktiv: Bool
    let aktion: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: aktion) {
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(aktiv ? palette.aufAkzentFlaeche : palette.text)
                .padding(.horizontal, Abstand.m)
                .padding(.vertical, Abstand.s)
                .background(aktiv ? palette.akzentFlaeche : palette.flaeche, in: .capsule)
                .overlay(Capsule().stroke(aktiv ? Color.clear : palette.haar, lineWidth: 1))
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}

/// Kleine Pille als Knopf ("Kurz · 30 min", "Ohne Plan", "Hilfe?"): Fläche mit Rand, an = Lime-Rand.
struct GymPillenKnopf: View {
    let text: String
    let symbol: String
    var an = false
    let aktion: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: aktion) {
            Label(text, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.text)
                .padding(.horizontal, Abstand.m)
                .padding(.vertical, Abstand.s)
                .background(palette.flaeche, in: .capsule)
                .overlay(Capsule().stroke(an ? palette.akzent : palette.haar, lineWidth: an ? 1.5 : 1))
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(an ? .isSelected : [])
    }
}
