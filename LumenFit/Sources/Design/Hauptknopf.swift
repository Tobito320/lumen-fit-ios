import SwiftUI

/// Hauptknopf: Fläche in der Akzentfarbe, Schrift in `aufAkzent`. Der Standard `.borderedProminent` malt die Schrift immer weiß,
/// im dunklen Monochrom ist der Akzent aber weiß: weiße Schrift auf weißer Fläche (CI-Bild "Eintragen"). Dieser Stil liest beides aus der Palette.
struct LumenHauptknopfStil: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var aktiv

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(palette.aufAkzent)
            .padding(.horizontal, Abstand.l)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.akzent.opacity(configuration.isPressed ? 0.8 : 1), in: .capsule)
            .opacity(aktiv ? 1 : 0.4)
            .contentShape(.capsule)
    }
}

extension ButtonStyle where Self == LumenHauptknopfStil {
    static var lumenHauptknopf: LumenHauptknopfStil { LumenHauptknopfStil() }
}
