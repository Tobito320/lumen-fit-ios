import SwiftUI

/// Der Text der Coach-Kachel, rein gerechnet: pausiert -> "Pausiert", sonst die wichtigste Karte der Regeln oder "Frag mich".
enum CoachKachelText {
    struct Inhalt: Equatable {
        let titel: String
        let untertitel: String
    }

    static func inhalt(pausiert: Bool, erstesThema: String?) -> Inhalt {
        if pausiert { return Inhalt(titel: "Pausiert", untertitel: "Tippen, um den Coach wieder zu wecken") }
        if let thema = erstesThema?.trimmingCharacters(in: .whitespacesAndNewlines), !thema.isEmpty {
            return Inhalt(titel: "Frag mich", untertitel: thema)
        }
        return Inhalt(titel: "Frag mich", untertitel: "Zu Schlaf, Schritten, Training oder Essen")
    }
}

/// Die Coach-Kachel für den Heute-Tab. Tippen öffnet den Chat; ist der Coach pausiert, weckt Tippen ihn wieder auf.
struct CoachKachelView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var weckZaehler = 0
    @State private var einstellungen: CoachEinstellungen?

    var body: some View {
        let inhalt = CoachKachelText.inhalt(pausiert: pausiert, erstesThema: erstesThema)
        Button { tippe() } label: {
            ListenKarte {
                HStack(spacing: Abstand.m) {
                    LumiView(stimmung: pausiert ? .schlaeft : .bereit, groesse: 40)
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text(inhalt.titel).font(.headline).foregroundStyle(palette.text)
                        Text(inhalt.untertitel).font(.subheadline).foregroundStyle(palette.text2).lineLimit(2)
                    }
                    Spacer(minLength: Abstand.s)
                    Image(systemName: pausiert ? "play.circle" : "chevron.right")
                        .font(.footnote).foregroundStyle(palette.text2)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                }
                .padding(Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
            }
        }
        .buttonStyle(.plain)
        .haptik(.auswahl, bei: weckZaehler)
        .task(id: umgebung.daten?.profil) { einstellungen = umgebung.daten.map { CoachEinstellungen(ordner: $0.ordner) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach. \(inhalt.titel). \(inhalt.untertitel)")
        .accessibilityHint(pausiert ? "Weckt den Coach wieder auf" : "Öffnet den Chat")
    }

    private var pausiert: Bool { einstellungen?.stand.pause ?? false }

    private var erstesThema: String? {
        guard let daten = umgebung.daten, !pausiert else { return nil }
        return CoachRegeln.karten(CoachDaten.eingabe(umgebung, daten)).first?.titel
    }

    private func tippe() {
        if pausiert {
            einstellungen?.setzePause(false)
            weckZaehler += 1
        } else {
            umgebung.router.oeffne(.coach(frage: nil))
        }
    }
}
