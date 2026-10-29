import SwiftUI

/// Schalter wie das System, nur die Farbe der "an"-Spur kommt aus der Palette. Im dunklen Monochrom und Graphit ist der Akzent weiß: die Spur
/// wäre weiß wie der Knopf, der Zustand nur an der Lage des Knopfs zu erkennen (CI-Bild "Verbindungen"). Dort bekommt die Spur `text2`.
struct LumenSchalterStil: ToggleStyle {
    @Environment(\.palette) private var palette
    @Environment(\.lumenThema) private var thema
    @Environment(\.colorScheme) private var schema

    func makeBody(configuration: Configuration) -> some View {
        let akzentIstWeiss = schema == .dark && (thema == .monochrom || thema == .graphit)
        Toggle(configuration).tint(akzentIstWeiss ? palette.text2 : palette.akzent)
    }
}

extension ToggleStyle where Self == LumenSchalterStil {
    static var lumenSchalter: LumenSchalterStil { LumenSchalterStil() }
}
