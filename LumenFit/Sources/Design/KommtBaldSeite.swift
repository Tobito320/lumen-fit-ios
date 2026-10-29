import SwiftUI

/// Platzhalter der Modul-Stubs: Lumi, ein Satz, die Avatar-Kapsel. Jedes Modul ersetzt seinen Stub und nutzt diese Seite nicht mehr
/// (`grep "Kommt bald"` ist im Integrationsschritt leer).
struct KommtBaldSeite: View {
    let titel: String
    var avatar = true

    var body: some View {
        ScrollView {
            LeerZustand(stimmung: .bereit, satz: "Kommt bald")
                .padding(.top, Abstand.xxl)
        }
        .navigationTitle(titel)
        .lumenHintergrund()
        .toolbar {
            if avatar { ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() } }
        }
    }
}
