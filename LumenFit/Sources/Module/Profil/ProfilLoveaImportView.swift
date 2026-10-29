import SwiftUI

/// Die Seite "Aus Lovea übernehmen" (Profil, Deine Daten): nur erreichbar, wenn der Server das Konto für Lovea freigibt.
struct ProfilLoveaImportSeite: View {
    var body: some View {
        ScrollView {
            ProfilLoveaImportKarte().padding(Abstand.l)
        }
        .navigationTitle("Aus Lovea übernehmen")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}

/// Einmaliger Import der Health-Daten aus Lovea (nur wenn der Server das Konto freigibt; ohne Freigabe zeichnet die Karte nichts).
struct ProfilLoveaImportKarte: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var laeuft = false
    @State private var stand = ""
    @State private var fehler: ProfilLoveaFehler?
    @State private var ergebnis: ProfilLoveaErgebnis?
    @State private var bestaetigen = false

    var body: some View {
        if let zugang = umgebung.konto.loveaZugang(), let daten = umgebung.daten {
            inhalt(zugang: zugang, daten: daten)
        }
    }

    private func inhalt(zugang: ProfilLoveaZugang, daten: DatenSatz) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            ProfilGruppenKopf(text: "Aus Lovea übernehmen")
            if let fehler {
                FehlerKarte(titel: fehler.titel, hilfe: fehler.hilfe)
            }
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    Text("Holt deine Gym-, Essens-, Gewohnheits- und Zieldaten aus Lovea, einmalig. Was schon da ist, wird übersprungen, nichts wird doppelt eingetragen. In Lovea wird nichts verändert.")
                        .font(.subheadline).foregroundStyle(palette.text2)
                    if laeuft {
                        ProgressView(stand.isEmpty ? "Lade" : stand)
                    } else {
                        Button { starte(zugang: zugang, daten: daten) } label: {
                            Label("Aus Lovea übernehmen", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                        }
                        .buttonStyle(.bordered)
                    }
                    if let ergebnis { ergebnisZeilen(ergebnis) }
                }
                .padding(Abstand.l)
            }
        }
        .confirmationDialog("Lovea-Daten übernehmen?", isPresented: $bestaetigen, titleVisibility: .visible) {
            Button("Übernehmen") { los(zugang: zugang, daten: daten, bestaetigt: true) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dein Profil hat schon Einträge. Neues wird dazugelegt, Gleiches übersprungen, deine Einstellungen bleiben.")
        }
    }

    private func ergebnisZeilen(_ e: ProfilLoveaErgebnis) -> some View {
        let a = e.abdeckung
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Text("\(e.trainings) Trainings, \(e.essenstage) Tage Essen übernommen").font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
            Text("\(e.neu) neu, \(e.schonDa) schon da" + (e.uebersprungen > 0 ? ", \(e.uebersprungen) älter als vorhanden" : ""))
                .font(.footnote).foregroundStyle(palette.text2)
            if !a.uebernommen.isEmpty { zeile("Übernommen", a.uebernommen) }
            if !a.roh.isEmpty { zeile("Roh behalten", a.roh) }
            if a.ausgeschlossenGesamt > 0 { Text("Nicht übernommen (kein Health): \(a.ausgeschlossenGesamt)").font(.footnote).foregroundStyle(palette.text2) }
            if !a.unbekannt.isEmpty { zeile("Unbekannt, nicht übernommen", a.unbekannt) }
            if a.unlesbar > 0 { Text("Unlesbar: \(a.unlesbar)").font(.footnote).foregroundStyle(palette.text2) }
        }
        .accessibilityElement(children: .combine)
    }

    private func zeile(_ titel: String, _ zahlen: [String: Int]) -> some View {
        let text = zahlen.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        return Text("\(titel): \(text)").font(.footnote).foregroundStyle(palette.text2)
    }

    private func starte(zugang: ProfilLoveaZugang, daten: DatenSatz) {
        if ProfilSicherungLogik.hatDaten(daten) { bestaetigen = true } else { los(zugang: zugang, daten: daten, bestaetigt: false) }
    }

    private func los(zugang: ProfilLoveaZugang, daten: DatenSatz, bestaetigt: Bool) {
        guard !laeuft else { return }
        laeuft = true; fehler = nil; ergebnis = nil; stand = ""
        Task { @MainActor in
            defer { laeuft = false }
            do {
                ergebnis = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: umgebung.http,
                                                                  freigegeben: umgebung.konto.loveaErlaubt, bestaetigt: bestaetigt) { stand = $0 }
            } catch let f as ProfilLoveaFehler {
                fehler = f
            } catch {
                fehler = .netz
            }
        }
    }
}
