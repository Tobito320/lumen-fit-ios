import SwiftUI

/// Kachel "Foto" in "Mahlzeit hinzufügen". Sichtbar nur, wenn der Server die Funktion für dieses Konto freigibt.
/// Vor dem ersten Foto kommt das Blatt mit der Zustimmung; erst nach "Erlauben" geht die Kamera auf.
struct EssenKiFotoKnopf: View {
    let mahlzeit: Mahlzeit
    let tag: String
    let vonHand: @MainActor () -> Void
    let fertig: @MainActor (String) -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var offen = false
    @State private var zustimmungOffen = false

    var body: some View {
        Group {
            if EssenKiModul.freigabe(umgebung).erlaubt, let store = EssenKiModul.store(umgebung) {
                Button { if store.zustimmung.erlaubt { offen = true } else { zustimmungOffen = true } } label: {
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
        .sheet(isPresented: $zustimmungOffen, onDismiss: {
            if EssenKiModul.store(umgebung)?.zustimmung.erlaubt == true { offen = true }
        }) {
            if let store = EssenKiModul.store(umgebung) { EssenKiZustimmungBlatt(store: store) }
        }
        .sheet(isPresented: $offen) {
            EssenKiFotoBlatt(mahlzeit: mahlzeit, datum: tag, fertig: fertig, vonHand: vonHand)
        }
        .task { await EssenKiModul.freigabe(umgebung).pruefen() }
    }
}
