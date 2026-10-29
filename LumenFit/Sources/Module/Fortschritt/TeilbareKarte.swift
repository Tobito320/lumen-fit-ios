import SwiftUI
import UIKit

/// Zeigt eine Karte und einen Teilen-Knopf. Das Bild entsteht mit `ImageRenderer` (Palette, Schema und Skalierung werden ausdrücklich mitgegeben,
/// weil der Renderer die Umgebung der Ansicht nicht erbt). Die Teilen-Version hat eine feste Breite und einen vollen Hintergrund.
struct TeilbareKarte<Inhalt: View>: View {
    let titel: String
    /// Ändert sich, wenn die Karte neu gerendert werden soll (zum Beispiel der Sprechtext).
    let schluessel: String
    let inhalt: Inhalt
    @State private var bild: Image?
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.lumenThema) private var thema
    @Environment(\.displayScale) private var skalierung

    static var teilBreite: CGFloat { 360 }

    init(titel: String, schluessel: String, @ViewBuilder inhalt: () -> Inhalt) {
        self.titel = titel
        self.schluessel = schluessel
        self.inhalt = inhalt()
    }

    var body: some View {
        VStack(spacing: Abstand.s) {
            inhalt
            if let bild {
                ShareLink(item: bild, preview: SharePreview(titel, image: bild)) {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Teilt die Karte als Bild")
            }
        }
        .task(id: schluessel) { rendere() }
    }

    private func rendere() {
        let karte = inhalt
            .padding(Abstand.l)
            .frame(width: Self.teilBreite)
            .background(palette.grund)
            .environment(\.palette, palette)
            .environment(\.colorScheme, schema)
            .environment(\.lumenThema, thema)
        let renderer = ImageRenderer(content: karte)
        renderer.scale = skalierung
        bild = renderer.uiImage.map { Image(uiImage: $0) }
    }
}
