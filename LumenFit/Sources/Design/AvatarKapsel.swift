import SwiftUI

/// Glaskapsel oben rechts auf jedem Tab: Initiale des aktiven Profils, öffnet `.profil(.uebersicht)`.
struct AvatarKapsel: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let name = umgebung.profil.aktiv?.name ?? "Profil"
        Button {
            umgebung.router.oeffne(.profil(.uebersicht))
        } label: {
            Text(String(name.prefix(1)).uppercased())
                .font(.headline.weight(.bold)).fontDesign(.rounded)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Profil \(name)")
        .accessibilityHint("Öffnet dein Profil")
    }
}
