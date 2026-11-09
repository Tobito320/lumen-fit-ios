import SwiftUI

/// "Link erstellen" in "Person hinzufügen": ein Einladungs-Link für eine Person, 24 Stunden gültig (Server `POST /freunde/einladung`). Der Link öffnet
/// eine Seite des Servers, die Lumen Fit mit dem Code startet; danach läuft der bekannte Ablauf (Anfrage, Annehmen). Erst ein Tipp erzeugt ihn.
struct CrewLinkTeilen: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var link: URL?
    @State private var laedt = false
    @State private var fehlgeschlagen = false

    var body: some View {
        if let link {
            ShareLink(item: link, message: Text("Trainier mit mir in Lumen Fit. Der Link gilt 24 Stunden für eine Person.")) {
                Label("Link teilen", systemImage: "square.and.arrow.up")
            }
            .frame(minHeight: Abstand.tippflaeche)
        } else {
            Button {
                Task { await erstellen() }
            } label: {
                HStack {
                    Label("Link erstellen", systemImage: "link")
                    if laedt {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .frame(minHeight: Abstand.tippflaeche)
            .disabled(laedt)
            if fehlgeschlagen {
                Text("Das hat nicht geklappt. Prüfe die Verbindung und versuche es nochmal.").font(.footnote).foregroundStyle(palette.text2)
            }
        }
    }

    private func erstellen() async {
        laedt = true
        let dienst = CrewDienst.von(umgebung)
        link = await dienst.einladungsLink()
        // Der Fehler steht hier an der Zeile, nicht noch einmal als Hinweis auf der Crew-Seite.
        dienst.fehler = nil
        fehlgeschlagen = link == nil
        laedt = false
    }
}
