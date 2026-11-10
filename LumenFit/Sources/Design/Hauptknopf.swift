import SwiftUI

/// Hauptknopf: Fläche in `akzentFlaeche` (Lime), Schrift in `aufAkzentFlaeche`. Der Standard `.borderedProminent` malt die Schrift immer weiß,
/// im dunklen Monochrom ist der Akzent aber weiß: weiße Schrift auf weißer Fläche (CI-Bild "Eintragen"). Dieser Stil liest beides aus der Palette.
struct LumenHauptknopfStil: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var aktiv

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.aufAkzentFlaeche)
            .padding(.horizontal, Abstand.l)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.akzentFlaeche.opacity(configuration.isPressed ? 0.8 : 1), in: .capsule)
            // Hell hat die Lime-Fläche auf Weiß zu wenig Kante (1,5:1): ein feiner Rand in `akzent` (5,2:1). Dunkel ist er unsichtbar gleich.
            .overlay(Capsule().strokeBorder(palette.akzent, lineWidth: 1))
            .opacity(aktiv ? 1 : 0.4)
            .contentShape(.capsule)
    }
}

extension ButtonStyle where Self == LumenHauptknopfStil {
    static var lumenHauptknopf: LumenHauptknopfStil { LumenHauptknopfStil() }
}
