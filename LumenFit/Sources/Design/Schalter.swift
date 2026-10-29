import SwiftUI

/// Schalter aus der Palette: "an" ist die Akzentfläche mit Knopf in `aufAkzent`, "aus" eine blasse Spur mit Knopf in `text2`.
/// Der Systemschalter malt die "an"-Spur im Akzent und den Knopf immer weiß: im dunklen Monochrom und Graphit ist der Akzent weiß,
/// der Zustand war nur noch an der Lage des Knopfs zu erkennen (CI-Bild "Verbindungen"). Maße wie beim System (51 x 31 pt).
struct LumenSchalterStil: ToggleStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var aktiv
    @Environment(\.bewegungAus) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: Abstand.m) {
                configuration.label
                Spacer(minLength: Abstand.s)
                spur(an: configuration.isOn)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "An" : "Aus")
    }

    private func spur(an: Bool) -> some View {
        Capsule()
            .fill(an ? palette.akzent : palette.text2.opacity(0.35))
            .frame(width: 51, height: 31)
            .overlay(alignment: an ? .trailing : .leading) {
                Circle().fill(an ? palette.aufAkzent : palette.text2).padding(3)
            }
            .animation(reduceMotion ? nil : Feder.schnell, value: an)
            .opacity(aktiv ? 1 : 0.4)
            .accessibilityHidden(true)
    }
}

extension ToggleStyle where Self == LumenSchalterStil {
    static var lumenSchalter: LumenSchalterStil { LumenSchalterStil() }
}
