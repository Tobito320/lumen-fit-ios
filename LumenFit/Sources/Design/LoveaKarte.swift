import SwiftUI

extension EnvironmentValues {
    /// Bereichsfarbe für die Karten-Tönung im Thema Lovea (von den Tab-Wurzeln gesetzt; nil = Karte bleibt flach).
    @Entry var kartenTint: Color?
}

extension View {
    /// Setzt die Bereichsfarbe der Karten (Schlaf Indigo, Essen Türkis, Gym Mint, Coach Himmel). Wirkt nur im Thema Lovea.
    func kartenTint(_ farbe: Color?) -> some View { environment(\.kartenTint, farbe) }

    /// Kartenfläche: `flaeche`; im Thema Lovea mit Bereichsfarbe zu 14 % und bei erhöhtem Kontrast mit Rand
    /// (Lovea `HealthStil.swift:42-54`, `healthKarte`). Alle anderen Themen: unverändert `flaeche`.
    func lumenKartenFlaeche() -> some View { modifier(LumenKartenFlaeche()) }
}

/// Türkis des Essen-Bereichs in Lovea (`ErnaehrungView.swift:41`).
extension LumenFarben {
    static let loveaEssen = Color(red: 0.13, green: 0.86, blue: 0.66)
}

private struct LumenKartenFlaeche: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(\.lumenThema) private var thema
    @Environment(\.kartenTint) private var tint
    @Environment(\.colorSchemeContrast) private var kontrast

    func body(content: Content) -> some View {
        let form = RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous)
        if thema == .lovea, let tint {
            content.background {
                form.fill(palette.flaeche)
                    .overlay(form.fill(tint.opacity(0.14)))
                    .overlay { if kontrast == .increased { form.strokeBorder(tint.opacity(0.7), lineWidth: 1) } }
            }
        } else {
            content.background(palette.flaeche, in: form)
        }
    }
}
