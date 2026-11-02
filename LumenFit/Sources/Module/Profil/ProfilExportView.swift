import SwiftUI

/// Tabellenexport (Idee 80): Training und Essen als CSV zum Teilen. Die Dateien entstehen beim Öffnen der Seite im Temp-Ordner und verschwinden beim Schließen.
struct ProfilExportView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var training: URL?
    @State private var essen: URL?
    @State private var einheiten = 0
    @State private var eintraege = 0

    var body: some View {
        List {
            ProfilAbschnitt(fuss: "CSV für Excel, Numbers oder Google Tabellen, mit Semikolon und Dezimalkomma.") {
                exportZeile(titel: "Training", wert: einheiten == 1 ? "1 Einheit" : "\(einheiten) Einheiten", symbol: "dumbbell.fill", datei: training)
                exportZeile(titel: "Essen", wert: eintraege == 1 ? "1 Eintrag" : "\(eintraege) Einträge", symbol: "fork.knife", datei: essen)
            }
        }
        .profilListe()
        .navigationTitle("Als Tabelle teilen")
        .task { erzeuge() }
        .onDisappear { loesche() }
    }

    @ViewBuilder
    private func exportZeile(titel: String, wert: String, symbol: String, datei: URL?) -> some View {
        if let datei {
            ShareLink(item: datei) { ProfilListenZeile(titel, symbol: symbol, wert: wert) }
                .accessibilityHint("Teilt die Tabelle als CSV")
        } else {
            ProfilListenZeile(titel, symbol: symbol, wert: wert)
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
