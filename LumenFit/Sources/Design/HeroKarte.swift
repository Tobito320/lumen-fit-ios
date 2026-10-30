import SwiftUI

/// Die eine mutige Karte je Bildschirm: `akzent`-Fläche mit Streifenmuster, ohne Schatten. `platte: true` ist die schwarze Ringplatte
/// (für `LumenBogen`), dort sind Text und Streifen weiß.
struct HeroKarte<Inhalt: View>: View {
    let platte: Bool
    let inhalt: Inhalt
    @Environment(\.palette) private var palette
    @Environment(\.lumenThema) private var thema

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
            .background {
                ZStack {
                    grund
                    MusterFlaeche(thema: thema, ort: .hero)
                        .environment(\.palette, Palette(grund: palette.grund, flaeche: palette.flaeche, text: palette.text, text2: palette.text2,
                                                       rand: palette.rand, haar: palette.haar, akzent: palette.akzent, aufAkzent: schrift))
                }
            }
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
                    MusterFlaeche(thema: thema, ort: .karte)
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
