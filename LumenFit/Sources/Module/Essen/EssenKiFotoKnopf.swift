import SwiftUI

/// Kachel "Foto" in "Mahlzeit hinzufügen". Sichtbar nur, wenn der Server die Funktion für dieses Konto freigibt.
struct EssenKiFotoKnopf: View {
    let mahlzeit: Mahlzeit
    let tag: String
    let vonHand: @MainActor () -> Void
    let fertig: @MainActor (String) -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var offen = false

    var body: some View {
        Group {
            if EssenKiModul.freigabe(umgebung).erlaubt, EssenKiModul.store(umgebung) != nil {
                Button { offen = true } label: {
                    VStack(spacing: Abstand.xs) {
                        Image(systemName: "camera.macro").font(.title3).accessibilityHidden(true)
                        Text("Foto").font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .lumenKartenFlaeche()
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Essen fotografieren, KI schätzt Kalorien")
            }
        }
        .sheet(isPresented: $offen) {
            EssenKiFotoBlatt(mahlzeit: mahlzeit, datum: tag, fertig: fertig, vonHand: vonHand)
        }
        .task { await EssenKiModul.freigabe(umgebung).pruefen() }
    }
}
