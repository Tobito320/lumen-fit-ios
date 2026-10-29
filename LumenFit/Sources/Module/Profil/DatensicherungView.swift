import SwiftUI
import UniformTypeIdentifiers

/// Datensicherung als Datei (Idee 74): alles in einer JSON-Datei teilen und auf einem neuen Gerät einspielen. Nach einer Neuinstallation steht
/// oben die Willkommen-zurück-Karte "Datensicherung einspielen?". Keine Erinnerung, keine Wiederholung: nur die Zeile "Letzte Sicherung: vor 12 Tagen".
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
        let name = umgebung.profil.aktiv?.name ?? ""
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                if umgebung.neuinstallationErkannt { willkommenZurueck(name: name) }
                if let fehler { FehlerKarte(titel: "Das hat nicht geklappt", hilfe: fehler) }

                VStack(alignment: .leading, spacing: Abstand.s) {
                    ProfilGruppenKopf(text: "Sichern")
                    ListenKarte {
                        VStack(alignment: .leading, spacing: Abstand.m) {
                            Text("Eine Datei mit deinen Trainings, deinem Essenstagebuch, deinen Gewohnheiten, Zielen und Einstellungen. Ohne Passwort. Speichere sie in Dateien oder schick sie dir selbst.")
                                .font(.subheadline).foregroundStyle(palette.text2)
                            Text(zeile).font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
                            Button(action: erstelle) {
                                Label(datei == nil ? "Sicherung erstellen" : "Neu erstellen", systemImage: "externaldrive.badge.plus")
                                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(palette.aufAkzent)
                            if let datei {
                                ShareLink(item: datei) {
                                    Label("\(datei.lastPathComponent) teilen", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(Abstand.l)
                    }
                }

                VStack(alignment: .leading, spacing: Abstand.s) {
                    ProfilGruppenKopf(text: "Einspielen")
                    ListenKarte {
                        VStack(alignment: .leading, spacing: Abstand.m) {
                            Text("Wähle eine Sicherung von Lumen Fit. Was schon da ist, wird übersprungen, nichts wird doppelt eingetragen.")
                                .font(.subheadline).foregroundStyle(palette.text2)
                            Button { fehler = nil; waehlen = true } label: {
                                Label("Sicherung einspielen", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(Abstand.l)
                    }
                }

                ProfilLoveaImportKarte()
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Datensicherung")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
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

    // MARK: - Willkommen zurück

    private func willkommenZurueck(name: String) -> some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack(spacing: Abstand.m) {
                    LumiView(stimmung: .bereit, groesse: 56)
                    Text(name.isEmpty ? "Willkommen zurück!" : "Willkommen zurück, \(name)!").font(.title3.bold())
                }
                Text("Dein Profil ist wieder da, deine Trainings und dein Essen noch nicht. Datensicherung einspielen?").font(.subheadline)
                HStack(spacing: Abstand.m) {
                    Button { fehler = nil; waehlen = true } label: {
                        Text("Sicherung wählen").font(.body.weight(.semibold)).frame(minHeight: Abstand.tippflaeche).padding(.horizontal, Abstand.m)
                            .background(palette.aufAkzent.opacity(0.2), in: .capsule)
                    }
                    Button { umgebung.neuinstallationQuittieren() } label: {
                        Text("Ohne Sicherung weiter").font(.body).frame(minHeight: Abstand.tippflaeche)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Sichern

    private var zeile: String {
        ProfilSicherungStand.zeile(zuletzt: umgebung.daten.flatMap { ProfilSicherungStand.lade($0.ordner) }, jetzt: umgebung.uhr())
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
            toast = ToastInhalt(titel: "Eingespielt", zeile: "\(ergebnis.neu) Einträge sind wieder da.", stimmung: .stolz)
        }
    }
}
