import SwiftUI

/// "Bereiche" im Profil: Gym, Essen und Schlaf an oder aus. Aus heißt ausgeblendet, nie gelöscht.
enum ProfilBereiche {
    static func titel(_ bereich: AppBereich) -> String {
        switch bereich {
        case .gym: "Gym"
        case .essen: "Essen"
        case .schlaf: "Schlaf"
        }
    }

    static func symbol(_ bereich: AppBereich) -> String {
        switch bereich {
        case .gym: "dumbbell.fill"
        case .essen: "fork.knife"
        case .schlaf: "bed.double.fill"
        }
    }

    static let erklaerung = "Ausblenden löscht nichts. Deine Daten bleiben, bis du den Bereich wieder einschaltest. Einer bleibt immer an."

    /// Schaltet einen Bereich im aktiven Profil. false, wenn nichts passiert ist (kein Profil oder der letzte eingeschaltete Bereich).
    /// Beim Einschalten werden die fehlenden Health-Rechte erfragt und die Beobachtung nachgemeldet.
    @MainActor @discardableResult
    static func schalte(_ bereich: AppBereich, an: Bool, in umgebung: AppUmgebung) -> Bool {
        guard let store = umgebung.daten?.einstellungen else { return false }
        var neu = store.werte
        guard neu.setze(bereich, an: an) else { return false }
        store.werte = neu
        if an {
            umgebung.beobachteHealth()
            Task { await umgebung.gesundheit.aktualisiere() }
        }
        return true
    }
}

/// Drei Schalter oben im Profil-Blatt. Der letzte eingeschaltete ist gesperrt.
struct ProfilBereicheAbschnitt: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let werte = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        let nurEiner = AppBereich.allCases.filter { werte.zeigt($0) }.count == 1
        ProfilAbschnitt("Bereiche", fuss: ProfilBereiche.erklaerung) {
            ForEach(AppBereich.allCases, id: \.self) { bereich in
                Toggle(isOn: Binding(get: { werte.zeigt(bereich) },
                                     set: { ProfilBereiche.schalte(bereich, an: $0, in: umgebung) })) {
                    ProfilListenZeile(ProfilBereiche.titel(bereich), symbol: ProfilBereiche.symbol(bereich))
                }
                .disabled(nurEiner && werte.zeigt(bereich))
            }
        }
    }
}
