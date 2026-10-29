import SwiftUI

/// Grundfläche der Bildschirme: `grund` mit dem Kopf-Muster des Themes (läuft nach unten aus). Reicht unter Tab- und Navigationsleiste.
struct Hintergrund: View {
    @Environment(\.palette) private var palette
    @Environment(\.lumenThema) private var thema

    var body: some View {
        ZStack {
            palette.grund
            MusterFlaeche(thema: thema, ort: .kopf)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Setzt den Lumen-Hintergrund hinter die Ansicht.
    func lumenHintergrund() -> some View { background { Hintergrund() } }
}
