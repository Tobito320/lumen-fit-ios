import SwiftUI
import UIKit

/// Die Blätter über dem Chat: Suche, Verlauf, Gedächtnis, gemerkte Antworten, Einstellungen.
enum CoachBlatt: String, Identifiable {
    case suche, verlauf, gedaechtnis, merkliste, einstellungen
    var id: String { rawValue }
}

struct CoachBlattAnsicht: View {
    let blatt: CoachBlatt
    let modell: CoachModell
    /// Springt im Chat zu der Nachricht mit dieser Kennung (Suche).
    var springe: (String) -> Void = { _ in }
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
        case .suche: CoachSucheBlatt(modell: modell) { id in schliessen(); springe(id) }
        case .verlauf: CoachVerlaufView(modell: modell)
        case .gedaechtnis: CoachGedaechtnisAnsicht(modell: modell)
        case .merkliste: CoachMerklisteView(modell: modell)
        case .einstellungen: CoachEinstellungenView(modell: modell)
        }
    }
}

/// Suche im Chat von heute und davor (ohne ausgeblendete Tage). Tippen springt zur Nachricht und hebt sie hervor; ein Treffer aus einem älteren Tag öffnet diesen Tag.
struct CoachSucheBlatt: View {
    let modell: CoachModell
    let waehle: (String) -> Void
    @Environment(\.palette) private var palette
    @State private var begriff = ""

    var body: some View {
        let treffer = CoachLokal.suche(modell.sichtbarerVerlauf, begriff: begriff)
        let tage = modell.vergangeneTage
        List {
            if begriff.trimmingCharacters(in: .whitespaces).isEmpty {
                LeerZustand(stimmung: .denkt, satz: "Suche in deinem Chat mit dem Coach.").listRowBackground(Color.clear)
            } else if treffer.isEmpty {
                LeerZustand(stimmung: .denkt, satz: "Dazu finde ich nichts.").listRowBackground(Color.clear)
            } else {
                ForEach(treffer.reversed()) { nachricht in
                    if let tag = CoachTage.tag(mit: nachricht.id, in: tage) {
                        NavigationLink { CoachTagLeser(tag: tag, modell: modell) } label: { zeile(nachricht) }
                            .listRowBackground(palette.flaeche)
                            .accessibilityHint("Öffnet den Tag")
                    } else {
                        Button { waehle(nachricht.id) } label: { zeile(nachricht) }
                            .buttonStyle(.plain)
                            .listRowBackground(palette.flaeche)
                            .accessibilityHint("Springt zur Nachricht")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Suchen")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $begriff, placement: .navigationBarDrawer(displayMode: .always), prompt: "Im Chat suchen")
        .lumenHintergrund()
    }

    private func zeile(_ nachricht: CoachNachricht) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text("\(nachricht.rolle == .nutzer ? "Du" : "Coach"), \(CoachAnzeige.zeitText(nachricht.zeit))")
                .font(.caption).foregroundStyle(palette.text2)
            Text(CoachText.vorschau(nachricht.text)).font(.body).foregroundStyle(palette.text).lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
        .contentShape(.rect)
    }
}

/// Die gemerkten Antworten (Lesezeichen aus dem Chat). Wischen oder langes Drücken: nicht mehr merken, kopieren, teilen.
struct CoachMerklisteView: View {
    let modell: CoachModell
    @Environment(\.palette) private var palette

    var body: some View {
        let liste = modell.merkliste
        List {
            if liste.isEmpty {
                LeerZustand(stimmung: .bereit, satz: "Noch nichts gemerkt. Tippe unter einer Antwort auf das Lesezeichen, dann steht sie hier.")
                    .listRowBackground(Color.clear)
            } else {
                ForEach(liste) { nachricht in
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text(CoachAnzeige.tag(nachricht.zeit)).font(.caption).foregroundStyle(palette.text2)
                        CoachAntwortText(text: nachricht.text)
                    }
                    .padding(.vertical, Abstand.xs)
                    .listRowBackground(palette.flaeche)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Nicht mehr merken", systemImage: "bookmark.slash", role: .destructive) { modell.schalteMerkliste(nachricht) }
                    }
                    .contextMenu {
                        Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = CoachAnzeige.kopierText(nachricht.text) }
                        ShareLink(item: CoachAnzeige.kopierText(nachricht.text)) { Label("Teilen", systemImage: "square.and.arrow.up") }
                        Button("Nicht mehr merken", systemImage: "bookmark.slash", role: .destructive) { modell.schalteMerkliste(nachricht) }
                    }
                    .accessibilityAction(named: "Nicht mehr merken") { modell.schalteMerkliste(nachricht) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Gemerkte Antworten")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}
