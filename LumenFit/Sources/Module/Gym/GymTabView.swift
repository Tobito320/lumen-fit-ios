import SwiftUI

/// Stub des Grundgerüsts: zeigt Lumi mit "Kommt bald", das Modul ersetzt ihn.
struct GymTabView: View {
    var bereich: GymBereich = .training
    var body: some View { KommtBaldSeite(titel: "Gym") }
}
