import SwiftUI

/// Der Coach-Tab (und die Route `.coach(frage:)`): ein Chat je Tag mit Antworten ohne Blase, Chips mit Handlung, Morgen-Check, Schnellfragen nach
/// Tageszeit, Daumen und Merkliste. `frage` kommt von Links und anderen Tabs und wird beim Öffnen gestellt.
struct CoachTabView: View {
    var frage: String?
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        CoachTabHalter(umgebung: umgebung, frage: frage)
    }
}

/// Hält das Modell des Tabs; es entsteht einmal je Tab (die Umgebung kommt erst aus dem Environment).
private struct CoachTabHalter: View {
    let frage: String?
    @State private var modell: CoachModell

    init(umgebung: AppUmgebung, frage: String?) {
        self.frage = frage
        _modell = State(initialValue: CoachModell(umgebung: umgebung))
    }

    var body: some View {
        CoachChatView(modell: modell, frage: frage)
    }
}
