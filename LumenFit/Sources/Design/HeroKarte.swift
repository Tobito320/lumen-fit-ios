import SwiftUI

/// Die eine mutige Karte je Bildschirm: einfarbige `akzent`-Fläche, ohne Schatten. `platte: true` ist die schwarze Ringplatte
/// (für `LumenBogen`), dort ist der Text weiß.
struct HeroKarte<Inhalt: View>: View {
    let platte: Bool
    let inhalt: Inhalt
    @Environment(\.palette) private var palette

    init(platte: Bool = false, @ViewBuilder inhalt: () -> Inhalt) {
        self.platte = platte
        self.inhalt = inhalt()
    }

    var body: some View {
        let grund = platte ? LumenFarben.ringPlatte : palette.akzent
        let schrift = platte ? Color.white : palette.aufAkzent
        inhalt
            .foregroundStyle(schrift)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Abstand.l)
            .background(grund)
            .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
    }
}

/// Flache Karte (`flaeche`, kein Schatten), Zeilen mit Haarlinie dazwischen (`Haarlinie`).
struct ListenKarte<Inhalt: View>: View {
    let inhalt: Inhalt
    @Environment(\.palette) private var palette
    @Environment(\.lumenThema) private var thema
    @Environment(\.kartenTint) private var tint
    @Environment(\.colorSchemeContrast) private var kontrast

    init(@ViewBuilder inhalt: () -> Inhalt) { self.inhalt = inhalt() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { inhalt }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    palette.flaeche
                    if thema == .lovea, let tint { tint.opacity(0.14) }
                }
            }
            .overlay {
                if thema == .lovea, let tint, kontrast == .increased {
                    RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).strokeBorder(tint.opacity(0.7), lineWidth: 1)
                }
            }
            .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
    }
}

/// Reine Trennlinie zwischen Zeilen einer Karte.
struct Haarlinie: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle().fill(palette.haar).frame(height: 1).accessibilityHidden(true)
    }
}
