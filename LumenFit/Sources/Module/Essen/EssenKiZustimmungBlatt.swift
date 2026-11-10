import SwiftUI

/// Ausdrückliche Zustimmung vor dem ersten Foto (und Widerruf an derselben Stelle): an wen das Foto geht, was mitgeht, was gespeichert wird.
/// Die Sätze geben wieder, was `server/ki-foto.js` tut: der Lumen-Server zählt nur Fotos je Tag, OpenAI bekommt die Anfrage mit `store: false`.
struct EssenKiZustimmungBlatt: View {
    let store: EssenKiAuftragStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    Image(systemName: "camera.macro").font(.largeTitle).foregroundStyle(palette.akzent).accessibilityHidden(true)
                    Text("Essen per Foto schätzen").font(.title2.bold()).foregroundStyle(palette.text)
                    Text("Eine KI schätzt aus dem Foto Zutaten, Gramm und Kalorien. Dafür muss das Foto dein iPhone verlassen.")
                        .foregroundStyle(palette.text)
                    ListenKarte {
                        VStack(alignment: .leading, spacing: Abstand.m) {
                            zeile("paperplane", "Wohin: über den Lumen-Server an OpenAI (USA) zur Auswertung.")
                            zeile("photo", "Was: das Foto (verkleinert, ohne Ort und Aufnahmezeit), die Mahlzeit und ein Hinweis, wenn du einen eintippst.")
                            zeile("externaldrive.badge.xmark", "Der Lumen-Server speichert weder Foto noch Antwort. Er zählt nur, wie viele Fotos du am Tag schickst.")
                            zeile("lock", "OpenAI bekommt die Anfrage mit der Einstellung, die Antwort nicht zu speichern. Für die Verarbeitung dort gelten die Regeln von OpenAI.")
                            zeile("iphone", "Das Foto selbst bleibt auf deinem iPhone, bis du die Schätzung übernimmst oder verwirfst.")
                        }
                        .padding(Abstand.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Ohne deine Zustimmung geht kein Foto raus; Suchen, Scannen und Eintragen von Hand gehen immer. Du kannst die Zustimmung hier jederzeit zurücknehmen.")
                        .font(.footnote).foregroundStyle(palette.text2)
                    knoepfe
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle("Foto-Schätzung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } } }
        }
    }

    @ViewBuilder
    private var knoepfe: some View {
        if store.zustimmung.erlaubt {
            Label("Du hast zugestimmt.", systemImage: "checkmark.circle.fill").foregroundStyle(palette.text)
            Button(role: .destructive) { store.zustimmen(false); dismiss() } label: {
                Text("Zustimmung zurücknehmen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
        } else {
            Button { store.zustimmen(true); dismiss() } label: {
                Text("Erlauben").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            Button { dismiss() } label: {
                Text("Nicht erlauben").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
        }
    }

    private func zeile(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label { Text(text).foregroundStyle(palette.text) } icon: {
            Image(systemName: symbol).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
    }
}
