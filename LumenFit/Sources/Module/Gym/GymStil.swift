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
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Button(action: minus) {
                Image(systemName: "minus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche).contentShape(.rect)
            }
            Text(wert)
                .font(.title3.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 52)
                .foregroundStyle(palette.text)
            Button(action: plus) {
                Image(systemName: "plus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche).contentShape(.rect)
            }
        }
        .buttonStyle(.federnd)
        .foregroundStyle(palette.text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titel)
        .accessibilityValue(wert)
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
