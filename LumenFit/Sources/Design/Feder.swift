import SwiftUI

/// Ein Satz Federn für die ganze App (gleiche wie Bahnherz und Lovea). Unter Reduce Motion überblenden Aufrufer stattdessen.
enum Feder {
    /// Tippantwort, Chip-Auswahl.
    nonisolated static let schnell: Animation = .snappy(duration: 0.28)
    /// Übergänge, Sheet-Inhalte.
    nonisolated static let weich: Animation = .smooth(duration: 0.38)
    /// Freude: Rekord, Meilenstein.
    nonisolated static let federnd: Animation = .bouncy(duration: 0.42, extraBounce: 0.12)
    /// Loslassen von Knöpfen (Press-Zustand 0,94).
    nonisolated static let jelly: Animation = .spring(response: 0.32, dampingFraction: 0.55)
}

/// Knöpfe weichen beim Drücken aus (0,94) und federn zurück. Reduce Motion: keine Bewegung, nur gedimmt.
struct FederKnopfStil: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FederKnopfInhalt(konfiguration: configuration)
    }
}

extension ButtonStyle where Self == FederKnopfStil {
    static var federnd: FederKnopfStil { FederKnopfStil() }
}

private struct FederKnopfInhalt: View {
    let konfiguration: ButtonStyleConfiguration
    @Environment(\.bewegungAus) private var reduceMotion

    var body: some View {
        konfiguration.label
            .scaleEffect(konfiguration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(konfiguration.isPressed && reduceMotion ? 0.6 : 1)
            .animation(reduceMotion || konfiguration.isPressed ? Feder.schnell : Feder.jelly, value: konfiguration.isPressed)
    }
}
