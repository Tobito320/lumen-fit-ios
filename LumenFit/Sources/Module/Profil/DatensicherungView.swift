import SwiftUI
import UniformTypeIdentifiers

/// Datensicherung als Datei (Idee 74): alles in einer JSON-Datei teilen und auf einem neuen Gerät einspielen. Nach einer Neuinstallation steht
/// oben der Abschnitt "Willkommen zurück". Keine Erinnerung, keine Wiederholung: nur die Zeile "Letzte Sicherung" mit "Vor 12 Tagen".
struct DatensicherungView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var datei: URL?
    @State private var waehlen = false
    @State private var offen: ProfilSicherung?
    @State private var bestaetigen = false
    @State private var toast: ToastInhalt?
    @State private var fehler: String?

    var body: some View {
        List {
            if umgebung.neuinstallationErkannt {
                ProfilAbschnitt("Willkommen zurück", fuss: "Dein Profil ist wieder da, Trainings und Essen kommen mit der Sicherung.") {
                    Button("Ohne Sicherung weiter") { umgebung.neuinstallationQuittieren() }
                }
            }
            if let fehler {
                ProfilAbschnitt {
                    Label(fehler, systemImage: "exclamationmark.triangle.fill").foregroundStyle(palette.text)
                }
            }
            ProfilAbschnitt(fuss: "Trainings, Essen, Gewohnheiten, Ziele und Einstellungen in einer Datei, ohne Passwort.") {
                ProfilListenZeile("Letzte Sicherung", wert: kurz)
                Button(action: erstelle) {
                    Label(datei == nil ? "Sicherung erstellen" : "Neu erstellen", systemImage: "externaldrive.badge.plus")
                }
                if let datei {
                    ShareLink(item: datei) { Label("\(datei.lastPathComponent) teilen", systemImage: "square.and.arrow.up") }
                }
            }
            ProfilAbschnitt(fuss: "Was schon da ist, wird übersprungen, nichts wird doppelt.") {
                Button { fehler = nil; waehlen = true } label: {
                    Label("Sicherung einspielen", systemImage: "square.and.arrow.down")
                }
            }
        }
        .profilListe()
        .navigationTitle("Datensicherung")
        .fileImporter(isPresented: $waehlen, allowedContentTypes: [.json]) { ergebnis in lies(ergebnis) }
        .confirmationDialog(bestaetigungTitel, isPresented: $bestaetigen, titleVisibility: .visible) {
            Button("Einspielen") { spieleEin() }
            Button("Abbrechen", role: .cancel) { offen = nil }
        } message: {
            Text(bestaetigungText)
        }
        .lumenToast($toast)
        .onDisappear { if let datei { try? FileManager.default.removeItem(at: datei) } }
    }

    // MARK: - Sichern

    private var kurz: String {
        ProfilSicherungStand.kurz(zuletzt: umgebung.daten.flatMap { ProfilSicherungStand.lade($0.ordner) }, jetzt: umgebung.uhr())
    }

    private func erstelle() {
        guard let daten = umgebung.daten else { return }
        do {
            datei = try ProfilSicherungLogik.schreibeDatei(aus: daten, jetzt: umgebung.uhr())
            fehler = nil
        } catch {
            fehler = "Die Sicherung konnte nicht geschrieben werden. Prüfe, ob auf deinem iPhone Platz frei ist."
        }
    }

    // MARK: - Einspielen

    private func lies(_ ergebnis: Result<URL, Error>) {
        guard case .success(let url) = ergebnis else { return }
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
        do {
            offen = try ProfilSicherung.lies(Data(contentsOf: url))
            bestaetigen = true
        } catch let f as ProfilSicherungFehler {
            fehler = f.text
        } catch {
            fehler = "Die Datei konnte nicht gelesen werden."
        }
    }

    private var bestaetigungTitel: String { "Sicherung einspielen?" }

    private var bestaetigungText: String {
        guard let offen else { return "" }
        var text = "\(offen.ops.count) Einträge vom \(Datum.anzeige(Datum.text(offen.erstellt)))."
        if let daten = umgebung.daten, ProfilSicherungLogik.hatDaten(daten) {
            text += " Dein Profil hat schon Einträge: Neues wird dazugelegt, Gleiches übersprungen, deine Einstellungen bleiben."
        }
        return text
    }

    private func spieleEin() {
        guard let sicherung = offen, let daten = umgebung.daten else { return }
        offen = nil
        let ergebnis = ProfilSicherungLogik.spieleEin(sicherung, in: daten)
        umgebung.neuinstallationQuittieren()
        if ergebnis.neu == 0, ergebnis.uebersprungen > 0 {
            toast = ToastInhalt(titel: "Schon eingespielt", zeile: "Alles aus dieser Sicherung war schon da.", stimmung: .bereit)
        } else {
            toast = ToastInhalt(titel: "Eingespielt", zeile: "\(ergebnis.neu) Einträge sind wieder da.", stimmung: .ziel)
        }
    }
}
