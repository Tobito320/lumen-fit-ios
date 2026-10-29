import SwiftUI

/// Stub des Grundgerüsts: zeigt Lumi mit "Kommt bald", das Modul ersetzt ihn.
struct EssenTabView: View {
    var bereich: EssenBereich = .heute
    var body: some View { KommtBaldSeite(titel: "Essen") }
}
