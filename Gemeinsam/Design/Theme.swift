import SwiftUI

extension ThemaID {
    var anzeigeName: String {
        switch self {
        case .monochrom: "Monochrom"
        case .graphit: "Graphit"
        case .stahl: "Stahl"
        case .glut: "Glut"
        case .wald: "Wald"
        }
    }
}

extension Erscheinung {
    var anzeigeName: String {
        switch self {
        case .system: "System"
        case .hell: "Hell"
        case .dunkel: "Dunkel"
        }
    }
}

private struct LumenThemeModifier: ViewModifier {
    let thema: ThemaID
    let erscheinung: Erscheinung
    @Environment(\.colorScheme) private var systemSchema
    @Environment(\.colorSchemeContrast) private var kontrast

    func body(content: Content) -> some View {
        let dunkel = switch erscheinung {
        case .system: systemSchema == .dark
        case .hell: false
        case .dunkel: true
        }
        let palette = LumenFarben.palette(thema: thema, dunkel: dunkel, kontrastHoch: kontrast == .increased)
        content
            .environment(\.palette, palette)
            .environment(\.lumenThema, thema)
            .tint(palette.akzent)
            .preferredColorScheme(erscheinung == .system ? nil : (dunkel ? .dark : .light))
    }
}

extension View {
    /// Setzt Palette, Tint, Erscheinung und Muster-Thema aus Thema und Erscheinung.
    func lumenTheme(_ thema: ThemaID, erscheinung: Erscheinung) -> some View {
        modifier(LumenThemeModifier(thema: thema, erscheinung: erscheinung))
    }
}
