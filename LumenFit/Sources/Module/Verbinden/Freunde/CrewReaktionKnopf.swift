import SwiftUI

/// Ein festes Zeichen an eine Person (Respekt, Stark, Anfeuern, Stups). Gefüllt, wenn es schon gesendet ist; noch einmal tippen nimmt es zurück.
/// Nur sichtbar, wenn die Person mir Gym zeigt (`CrewLogik.darfReagieren`).
struct CrewReaktionKnopf: View {
    let eintrag: VerbindungEintrag
    let art: CrewReaktionArt
    let ziel: String
    var text: String = ""
    /// Mit Wort daneben (Freund-Seite) statt nur Symbol (Zeilen).
    var beschriftet = false
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if CrewLogik.darfReagieren(eintrag) {
            let dienst = CrewDienst.von(umgebung)
            let gesendet = dienst.istGesendet(an: eintrag.id, art: art, ziel: ziel)
            let name = CrewLogik.name(eintrag)
            Button {
                Task {
                    if gesendet {
                        await dienst.zuruecknehmen(an: eintrag.id, art: art, ziel: ziel)
                    } else {
                        await dienst.reagieren(an: eintrag.id, art: art, ziel: ziel, text: text)
                    }
                }
            } label: {
                if beschriftet {
                    Label(gesendet ? "\(art.titel) gesendet" : art.titel, systemImage: art.symbol)
                        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                } else {
                    Image(systemName: art.symbol)
                        .font(.body)
                        .foregroundStyle(gesendet ? palette.akzent : palette.text2)
                        .opacity(gesendet ? 1 : 0.7)
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                        .contentShape(.rect)
                }
            }
            .buttonStyle(.plain)
            .modifier(CrewKnopfRahmen(beschriftet: beschriftet, gesendet: gesendet))
            .haptik(.erfolg, bei: gesendet)
            .accessibilityLabel("\(art.titel) an \(name)")
            .accessibilityValue(gesendet ? "gesendet" : "")
            .accessibilityHint(gesendet ? "Nimmt das Zeichen zurück" : "Sendet ein festes Zeichen, keinen Text")
        }
    }
}

/// Beschriftet als umrandeter Knopf, sonst nur das Symbol.
private struct CrewKnopfRahmen: ViewModifier {
    let beschriftet: Bool
    let gesendet: Bool
    @Environment(\.palette) private var palette

    @ViewBuilder func body(content: Content) -> some View {
        if beschriftet {
            content
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(gesendet ? palette.aufAkzent : palette.text)
                .background(gesendet ? palette.akzent : palette.flaeche, in: .rect(cornerRadius: Rundung.feld))
        } else {
            content
        }
    }
}

/// "Crew-Bestwert: Beispiel Freund A 80 kg × 8" unter dem Übungsnamen im Training; ohne Wert (keine Freigabe gym und verlauf) nichts.
struct CrewBestwertZeile: View {
    let uebung: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if let b = CrewLogik.bestwert(uebung: uebung, eintraege: GymCrewQuelle.eintraege(umgebung)) {
            Label(CrewLogik.bestwertText(b), systemImage: "person.2.fill")
                .font(.footnote)
                .foregroundStyle(palette.text2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}
