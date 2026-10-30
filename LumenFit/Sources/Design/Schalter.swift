import SwiftUI

/// Schalter aus der Palette: "an" ist die Akzentfläche mit Knopf in `aufAkzent`, "aus" eine blasse Spur mit Knopf in `text2`.
/// Der Systemschalter malt die "an"-Spur im Akzent und den Knopf immer weiß: im dunklen Monochrom und Graphit ist der Akzent weiß,
/// der Zustand war nur noch an der Lage des Knopfs zu erkennen (CI-Bild "Verbindungen"). Maße wie beim System (51 x 31 pt).
struct LumenSchalterStil: ToggleStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var aktiv
    @Environment(\.bewegungAus) private var reduceMotion
    @Environment(\.lumenThema) private var thema

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if thema == .lovea {
            // Lovea 1:1: eigener Schalter mit Gelee-Knopf und Auswahl-Haptik (`LoveaSchalterZeile`).
            Button { configuration.isOn.toggle() } label: { configuration.label }
                .buttonStyle(LoveaSchalterZeile(istAn: configuration.isOn))
                .haptik(.auswahl, bei: configuration.isOn)
                .accessibilityAddTraits(.isToggle)
                .accessibilityValue(configuration.isOn ? "An" : "Aus")
        } else {
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

/// Der Schalter aus Lovea (`LoveaSchalterStil`, `GeleeEffekte.swift`): Spur in Lovea-Rosa (aus: `secondary` mit 30 %), weißer Knopf 27 pt mit Schatten,
/// beim Drücken 35 pt breit, Loslassen mit `Feder.jelly`. 51 x 31 pt, Zeile mindestens 44 pt hoch. Bewegung aus: keine Dehnung, keine Animation.
private struct LoveaSchalterZeile: ButtonStyle {
    let istAn: Bool
    @Environment(\.bewegungAus) private var reduceMotion
    @Environment(\.isEnabled) private var aktiv

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Abstand.m) {
            configuration.label.foregroundStyle(.primary)
            Spacer(minLength: Abstand.s)
            schalter(gedrueckt: configuration.isPressed && !reduceMotion)
        }
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .opacity(aktiv ? 1 : 0.4)
    }

    private func schalter(gedrueckt: Bool) -> some View {
        let spur: Color = istAn ? LumenFarben.loveaRose : Color.secondary.opacity(0.3)
        return ZStack(alignment: istAn ? .trailing : .leading) {
            Capsule().fill(spur)
            Capsule().fill(Color.white)
                .frame(width: gedrueckt ? 35 : 27, height: 27)
                .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                .padding(2)
        }
        .frame(width: 51, height: 31)
        .animation(reduceMotion ? nil : (gedrueckt ? Feder.schnell : Feder.jelly), value: gedrueckt)
        .animation(reduceMotion ? nil : Feder.jelly, value: istAn)
        .accessibilityHidden(true)
    }
}
