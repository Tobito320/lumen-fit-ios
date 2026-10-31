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
    /// Lovea-Aufbau (`CoachChatView.swift:16`, `CoachFormKachel`): eine Kachel im Raster von "Dein Tag" statt der Karte.
    var alsKachel = false
    /// Lovea-Aufbau: der Chat öffnet im Stapel des Heute-Tabs (wie `NavigationLink(value: HealthZiel.coach)`), nicht als Tabwechsel.
    var oeffne: (() -> Void)?
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var weckZaehler = 0
    @State private var einstellungen: CoachEinstellungen?

    var body: some View {
        let inhalt = CoachKachelText.inhalt(pausiert: pausiert, erstesThema: erstesThema)
        Group {
            if alsKachel {
                Button { tippe() } label: { kachel(inhalt) }.buttonStyle(.federnd)
            } else {
                Button { tippe() } label: { karte(inhalt) }.buttonStyle(.plain)
            }
        }
        .haptik(.auswahl, bei: weckZaehler)
        .task(id: umgebung.daten?.profil) { einstellungen = umgebung.daten.map { CoachEinstellungen(ordner: $0.ordner) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach. \(inhalt.titel). \(inhalt.untertitel)")
        .accessibilityHint(pausiert ? "Weckt den Coach wieder auf" : "Öffnet den Chat")
    }

    /// Wie `TagesFormKachel`: Symbol, Name, Wert, eine Zeile Zusatz (Lovea: Sparkles in Mint, "Frag mich", Thema des ersten Rats).
    private func kachel(_ inhalt: CoachKachelText.Inhalt) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(HabitFarbe.mint.farbe)
                .frame(width: 70, height: 70)
                .accessibilityHidden(true)
            Text("Coach").font(.caption.weight(.semibold)).foregroundStyle(palette.text2).lineLimit(1).padding(.top, 4)
            Text(inhalt.titel).font(.body.bold()).foregroundStyle(palette.text).lineLimit(1).minimumScaleFactor(0.7)
            Text(pausiert ? "Tippen zum Fortsetzen" : (erstesThema ?? " ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(palette.flaeche, in: .rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect(cornerRadius: 20, style: .continuous))
    }

    private func karte(_ inhalt: CoachKachelText.Inhalt) -> some View {
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

    private var pausiert: Bool { einstellungen?.stand.pause ?? false }

    private var erstesThema: String? {
        guard let daten = umgebung.daten, !pausiert else { return nil }
        return CoachRegeln.karten(CoachDaten.eingabe(umgebung, daten)).first?.titel
    }

    private func tippe() {
        if pausiert {
            einstellungen?.setzePause(false)
            weckZaehler += 1
        } else if let oeffne {
            oeffne()
        } else {
            umgebung.router.oeffne(.coach(frage: nil))
        }
    }
}
