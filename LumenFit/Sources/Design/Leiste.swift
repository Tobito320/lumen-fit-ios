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

/// Tab-Leiste wie in Lovea (`AppRootView.leiste()`): `.sidebarAdaptable` und die Leiste schrumpft beim Abwärtsscrollen. Nur im Theme Lovea; auf dem iPhone ändert
/// `.sidebarAdaptable` nichts am Aufbau. Der Tint kommt schon aus dem Theme (`lumenTheme` setzt `.tint(palette.akzent)`).
private struct LumenTabLeiste: ViewModifier {
    @Environment(\.lumenThema) private var thema

    @ViewBuilder
    func body(content: Content) -> some View {
        if thema == .lovea {
            content.tabViewStyle(.sidebarAdaptable).tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

extension View {
    func lumenTabLeiste() -> some View { modifier(LumenTabLeiste()) }
}
