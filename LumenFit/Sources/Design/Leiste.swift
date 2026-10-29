import SwiftUI

/// Untere Leiste mit Eingabe oder Hauptknopf (Chat, Training, Essen eintragen): der Grund der Seite mit einer Haarlinie oben.
/// Das System-Material `.bar` wurde im dunklen Monochrom zu einem grauen Streifen auf schwarzem Grund (CI-Bild "Coach").
private struct LumenLeiste: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .background(palette.grund)
            .overlay(alignment: .top) { palette.haar.frame(height: 1) }
    }
}

extension View {
    func lumenLeiste() -> some View { modifier(LumenLeiste()) }
}
