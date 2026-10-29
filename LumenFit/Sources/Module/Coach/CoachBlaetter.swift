import SwiftUI

/// Die Blätter über dem Chat: Verlauf, Gedächtnis, gemerkte Antworten, Einstellungen.
enum CoachBlatt: String, Identifiable {
    case verlauf, gedaechtnis, merkliste, einstellungen
    var id: String { rawValue }
}

struct CoachBlattAnsicht: View {
    let blatt: CoachBlatt
    let modell: CoachModell
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            inhalt
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
                }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch blatt {
        case .verlauf: CoachVerlaufView(modell: modell)
        case .gedaechtnis: CoachGedaechtnisAnsicht(modell: modell)
        case .merkliste: CoachMerklisteView(modell: modell)
        case .einstellungen: CoachEinstellungenView(modell: modell)
        }
    }
}

/// Die gemerkten Antworten (Lesezeichen aus dem Chat).
struct CoachMerklisteView: View {
    let modell: CoachModell
    @Environment(\.palette) private var palette

    var body: some View {
        let liste = modell.merkliste
        ScrollView {
            if liste.isEmpty {
                LeerZustand(stimmung: .bereit, satz: "Noch nichts gemerkt. Tippe unter einer Antwort auf das Lesezeichen, dann steht sie hier.")
                    .padding(.top, Abstand.xxl)
            } else {
                ListenKarte {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { index, nachricht in
                        if index > 0 { Haarlinie() }
                        VStack(alignment: .leading, spacing: Abstand.xs) {
                            Text(CoachAnzeige.tag(nachricht.zeit)).font(.caption).foregroundStyle(palette.text2)
                            CoachAntwortText(text: nachricht.text)
                            Button("Nicht mehr merken", systemImage: "bookmark.slash") { modell.schalteMerkliste(nachricht) }
                                .font(.subheadline)
                                .frame(minHeight: Abstand.tippflaeche)
                        }
                        .padding(Abstand.l)
                    }
                }
                .padding(Abstand.l)
            }
        }
        .navigationTitle("Gemerkte Antworten")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}
