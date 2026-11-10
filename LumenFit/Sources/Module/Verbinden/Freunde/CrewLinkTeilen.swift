import SwiftUI

/// "Freund einladen" mit einem Tipp: ein Einladungs-Link für eine Person, 24 Stunden gültig (Server `POST /freunde/einladung`). Der Link wird beim Erscheinen
/// still vorab geholt, damit der Tipp gleich das Teilen öffnet; ohne Netz holt ihn erst der Tipp. Der Link öffnet eine Seite des Servers, die Lumen Fit mit
/// dem Code startet; danach läuft der bekannte Ablauf (Anfrage, Annehmen). `imHub`: als Zeile der Crew-Seite, sonst als Zeile im Formular.
struct CrewLinkTeilen: View {
    var imHub = false
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var link: URL?
    @State private var laedt = false
    @State private var fehlgeschlagen = false

    nonisolated static let nachricht = "Trainier mit mir in Lumen Fit. Der Link gilt 24 Stunden für eine Person."

    var body: some View {
        Group {
            if let link {
                ShareLink(item: link, message: Text(Self.nachricht)) { beschriftung(symbol: "square.and.arrow.up") }
                    .buttonStyle(.plain)
            } else {
                Button { Task { await erstellen(still: false) } } label: { beschriftung(symbol: "link") }
                    .buttonStyle(.plain)
                    .disabled(laedt)
            }
        }
        .accessibilityHint("Öffnet das Teilen mit einem Einladungs-Link")
        .task { if link == nil { await erstellen(still: true) } }
    }

    @ViewBuilder
    private func beschriftung(symbol: String) -> some View {
        let untertitel = fehlgeschlagen ? "Kein Netz. Tippe, um es nochmal zu versuchen." : "Link für eine Person, 24 Stunden gültig"
        if imHub {
            GymZeile(titel: "Freund einladen", untertitel: untertitel) {
                if laedt { ProgressView() } else { Image(systemName: symbol).foregroundStyle(palette.akzent).accessibilityHidden(true) }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("Freund per Link einladen", systemImage: symbol).foregroundStyle(palette.akzent)
                Text(untertitel).font(.footnote).foregroundStyle(palette.text2)
            }
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            .contentShape(.rect)
        }
    }

    private func erstellen(still: Bool) async {
        guard !laedt else { return }
        laedt = true
        let dienst = CrewDienst.von(umgebung)
        link = await dienst.einladungsLink()
        // Der Fehler steht hier an der Zeile, nicht noch einmal als Hinweis auf der Crew-Seite.
        dienst.fehler = nil
        fehlgeschlagen = link == nil && !still
        laedt = false
    }
}
