import SwiftUI

/// Stub des Grundgerüsts: zeigt Lumi mit "Kommt bald", das Modul ersetzt ihn.
struct SchlafTabView: View {
    var bereich: SchlafBereich = .letzteNacht
    var body: some View { KommtBaldSeite(titel: "Schlaf") }
}
