import SwiftUI

/// Der Text der Frage nach der Nutzungsmeldung: was gezählt wird, was nie, wo man es abschaltet. Im Onboarding und im Blatt für Bestandskonten derselbe.
struct NutzungFrageText: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(ProfilTexte.NutzungFrage.titel).font(.title.bold()).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                Text(ProfilTexte.NutzungFrage.einleitung).font(.body).foregroundStyle(palette.text2)
            }
            ListenKarte {
                zeile("chart.bar.fill", ProfilTexte.NutzungFrage.gezaehlt)
                Haarlinie()
                zeile("hand.raised.fill", ProfilTexte.NutzungFrage.nie)
                Haarlinie()
                zeile("person.crop.circle.fill", ProfilTexte.NutzungFrage.konto)
                Haarlinie()
                zeile("switch.2", ProfilTexte.NutzungFrage.aus)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func zeile(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Abstand.m) {
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(palette.text).frame(width: 28).accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(palette.text)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Zwei gleichwertige Knöpfe, gleiche Größe und gleicher Stil, keiner vorgewählt.
struct NutzungFrageKnoepfe: View {
    @Environment(\.palette) private var palette
    let antwort: (NutzungAntwort) -> Void

    var body: some View {
        VStack(spacing: Abstand.s) {
            knopf(ProfilTexte.NutzungFrage.ja, .ja)
            knopf(ProfilTexte.NutzungFrage.nein, .nein)
        }
    }

    private func knopf(_ titel: String, _ wert: NutzungAntwort) -> some View {
        Button { antwort(wert) } label: { Text(titel).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(palette.aufAkzent)
    }
}

/// Die Frage für Konten, die schon vor dem Update da waren: einmal beim nächsten Start, bis geantwortet ist. Schließen geht nur mit einer Antwort.
struct NutzungFrageBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        VStack(spacing: Abstand.l) {
            ScrollView { NutzungFrageText().padding(.horizontal, Abstand.l).padding(.top, Abstand.l) }
                .scrollBounceBehavior(.basedOnSize)
            NutzungFrageKnoepfe { antwort in
                umgebung.daten?.einstellungen.aendere { $0.antworteNutzung(antwort, tag: Datum.text(umgebung.uhr())) }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.l)
        }
        .lumenHintergrund()
        .interactiveDismissDisabled()
    }
}

// MARK: - Messpunkte in Ansichten

extension View {
    /// Zählt, ob dieser Eintrag gesehen und ob er angetippt wurde (feste Namen, `NutzungEintrag`). Ohne Zustimmung tut es nichts.
    func nutzungEintrag(_ eintrag: NutzungEintrag) -> some View { modifier(NutzungEintragMarke(eintrag: eintrag)) }

    /// Ein Ablauf (QR-Verbinden, Essen eintragen) beginnt, wenn die Ansicht erscheint; verschwindet sie vor dem Ende, zählt die letzte Stufe als Abbruch.
    func nutzungAblauf(_ ablauf: NutzungAblauf, stufe: String) -> some View { modifier(NutzungAblaufMarke(ablauf: ablauf, stufe: stufe)) }
}

private struct NutzungEintragMarke: ViewModifier {
    @Environment(AppUmgebung.self) private var umgebung
    let eintrag: NutzungEintrag

    func body(content: Content) -> some View {
        content
            .onAppear { umgebung.konto.nutzung.gesehen(eintrag) }
            // Keine Tipp-Geste hier: in einer Liste schluckt sie den Tipp auf den Zeileninhalt. "Getippt" zählt die Zielseite beim Erscheinen.
    }
}

private struct NutzungAblaufMarke: ViewModifier {
    @Environment(AppUmgebung.self) private var umgebung
    let ablauf: NutzungAblauf
    let stufe: String

    func body(content: Content) -> some View {
        content
            .onAppear { umgebung.konto.nutzung.ablauf(ablauf, stufe: stufe) }
            .onDisappear { umgebung.konto.nutzung.ablaufEnde(ablauf) }
    }
}
