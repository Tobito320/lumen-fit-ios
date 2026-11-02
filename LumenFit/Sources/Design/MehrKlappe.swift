import SwiftUI

/// Eine Zeile "Mehr" (oder "Details"), die den seltenen Rest aufklappt; zu, bis man sie öffnet. Gleiches Muster wie im Gym-Start.
struct MehrKlappe<Inhalt: View>: View {
    let titel: String
    let untertitel: String
    @Binding var offen: Bool
    let inhalt: Inhalt
    @Environment(\.palette) private var palette

    init(_ titel: String = "Mehr", untertitel: String, offen: Binding<Bool>, @ViewBuilder inhalt: () -> Inhalt) {
        self.titel = titel
        self.untertitel = untertitel
        _offen = offen
        self.inhalt = inhalt()
    }

    var body: some View {
        VStack(spacing: Abstand.l) {
            ListenKarte {
                Button { withAnimation(Feder.weich) { offen.toggle() } } label: {
                    GymZeile(titel: titel, untertitel: untertitel) {
                        Image(systemName: offen ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint(offen ? "Klappt zu" : "Klappt auf")
            }
            if offen { inhalt }
        }
    }
}
