import SwiftUI

/// Grundfläche der Bildschirme: einfarbig `grund`. Reicht unter Tab- und Navigationsleiste.
struct Hintergrund: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.grund
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

extension View {
    /// Setzt den Lumen-Hintergrund hinter die Ansicht.
    func lumenHintergrund() -> some View { background { Hintergrund() } }
}
