import SwiftUI

/// Tabellenexport (Idee 80): Training und Essen als CSV zum Teilen. Die Dateien entstehen beim Öffnen der Seite im Temp-Ordner und verschwinden beim Schließen.
struct ProfilExportView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var training: URL?
    @State private var essen: URL?
    @State private var einheiten = 0
    @State private var eintraege = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Text("Deine Daten als Tabelle für Excel, Numbers oder Google Tabellen. Trennzeichen ist das Semikolon, Zahlen haben ein Komma.")
                    .font(.body).foregroundStyle(palette.text2)
                ListenKarte {
                    exportZeile(titel: "Training", zeile: einheiten == 1 ? "1 Einheit" : "\(einheiten) Einheiten", symbol: "dumbbell.fill", datei: training)
                    Haarlinie()
                    exportZeile(titel: "Essen", zeile: eintraege == 1 ? "1 Eintrag" : "\(eintraege) Einträge", symbol: "fork.knife", datei: essen)
                }
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Als Tabelle teilen")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .task { erzeuge() }
        .onDisappear { loesche() }
    }

    @ViewBuilder
    private func exportZeile(titel: String, zeile: String, symbol: String, datei: URL?) -> some View {
        if let datei {
            ShareLink(item: datei) { ProfilZeile(symbol: symbol, titel: titel, zeile: zeile + ", CSV teilen", pfeil: false) }
                .buttonStyle(.plain)
        } else {
            ProfilZeile(symbol: symbol, titel: titel, zeile: zeile, pfeil: false)
        }
    }

    private func erzeuge() {
        guard let daten = umgebung.daten else { return }
        let jetzt = umgebung.uhr()
        let sessions = daten.training.sessions
        let alleEintraege = daten.essen.tage.sorted().flatMap { daten.essen.eintraege($0) }
        einheiten = sessions.count
        eintraege = alleEintraege.count
        training = schreibe(ProfilCsvExport.training(sessions) { UebungsKatalog.nachId[$0]?.name }, name: ProfilCsvExport.dateiname("training", jetzt: jetzt))
        essen = schreibe(ProfilCsvExport.essen(alleEintraege), name: ProfilCsvExport.dateiname("essen", jetzt: jetzt))
    }

    private func schreibe(_ text: String, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        return (try? Data(text.utf8).write(to: url, options: .atomic)) != nil ? url : nil
    }

    private func loesche() {
        for url in [training, essen].compactMap({ $0 }) { try? FileManager.default.removeItem(at: url) }
        training = nil
        essen = nil
    }
}
