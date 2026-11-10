import SwiftUI

extension ThemaID {
    var anzeigeName: String {
        switch self {
        case .schlicht: String(localized: "Schlicht")
        case .monochrom: String(localized: "Monochrom")
        case .graphit: String(localized: "Graphit")
        case .stahl: String(localized: "Stahl")
        case .glut: String(localized: "Glut")
        case .wald: String(localized: "Wald")
        case .lovea: String(localized: "Lovea")
        }
    }
}

extension Erscheinung {
    var anzeigeName: String {
        switch self {
        case .system: String(localized: "System")
        case .hell: String(localized: "Hell")
        case .dunkel: String(localized: "Dunkel")
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
    /// Setzt Palette, Tint und Erscheinung aus Thema und Erscheinung (alle Themes liefern dieselbe Palette).
    func lumenTheme(_ thema: ThemaID, erscheinung: Erscheinung) -> some View {
        modifier(LumenThemeModifier(thema: thema, erscheinung: erscheinung))
    }
}
