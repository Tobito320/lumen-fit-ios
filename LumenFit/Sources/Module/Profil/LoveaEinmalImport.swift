import SwiftUI

/// Der einmalige Import aus Lovea, ohne dass jemand etwas tippt: gibt der Server dem Konto eine Lovea-Person (`KontoDienst.loveaImportOffen`),
/// läuft er beim nächsten Abgleich von selbst, mit sichtbarem Fortschritt und Ergebnis. Danach ist er für dieses Konto erledigt (lokal und auf dem
/// Server), und es gibt dafür keinen Knopf mehr. Lovea bleibt unverändert (nur lesen), nichts wird doppelt (Kennungen).
@MainActor @Observable
final class LoveaEinmalImport {
    enum Zustand: Equatable {
        case aus
        case laeuft(String)
        case fertig(ProfilLoveaErgebnis)
        /// Gelaufen, aber der Beleg zeigt eine Lücke (unbekannte Art, nicht wiedergefunden ...): bleibt offen, der Server hat den Beleg.
        case unvollstaendig(ProfilLoveaErgebnis)
        case fehler(ProfilLoveaFehler)
    }

    private(set) var zustand: Zustand = .aus
    /// Stille Gründe (Lauf startet nicht) werden je Start nur einmal gemeldet.
    @ObservationIgnored private var gemeldeteGruende: Set<String> = []
    /// Ein unvollständiger Lauf wird in diesem Start nicht wiederholt (sonst lädt jedes Zurückkommen alles nochmal).
    @ObservationIgnored private var unvollstaendigImStart = false

    /// Startet den Import, wenn er offen ist und gerade keiner läuft. Nach einem Fehler startet der nächste Abgleich ihn neu (nichts war übernommen oder
    /// nur teilweise; Doppeltes wird übersprungen). Nach jedem Lauf geht ein Beleg (nur Zahlen) an den Server; erledigt ist der Import erst, wenn der Beleg
    /// vollständig ist und beim Server ankam. Gibt zurück, ob ein Lauf stattfand.
    @discardableResult
    func starteWennOffen(konto: KontoDienst, daten: DatenSatz?, lader: any HTTPLader, hintergrund: (any EssenKiHintergrund)? = nil) async -> Bool {
        if case .laeuft = zustand { return false }
        if case .fertig = zustand { return false }
        if unvollstaendigImStart { return false }
        guard konto.loveaImportOffen else { return false }
        guard let daten else { await meldeStill("keine_daten", konto: konto); return false }
        guard let zugang = konto.loveaZugang() else { await meldeStill("kein_zugang", konto: konto); return false }
        zustand = .laeuft("Lade")
        let stand = ProfilLoveaLadeStand()
        // Kurz zurück zum Home-Bildschirm bricht den Lauf nicht ab: iOS gibt dafür grob 30 Sekunden.
        let wach = hintergrund ?? EssenKiSystemHintergrund()
        wach.start()
        defer { wach.ende() }
        do {
            let ergebnis = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: lader, freigegeben: konto.loveaErlaubt, bestaetigt: true, stand: stand) { [self] text in
                zustand = .laeuft(text)
            }
            let beleg = ProfilLoveaBeleg.baue(ergebnis, zeit: Date())
            let status = await konto.meldeImportBeleg(beleg)
            // 404: ein älterer Server kennt die Route noch nicht; 403: das Konto ist nicht mehr freigegeben. Alles andere heißt: kein Beleg angekommen, also nicht erledigt.
            guard let status, [200, 403, 404].contains(status) else {
                zustand = .fehler(status.map { ProfilLoveaFehler.server($0) } ?? ProfilLoveaFehler.netz)
                return true
            }
            if beleg.vollstaendig {
                await konto.loveaImportAbgeschlossen()
                zustand = .fertig(ergebnis)
            } else {
                unvollstaendigImStart = true
                zustand = .unvollstaendig(ergebnis)
            }
        } catch {
            let f = error as? ProfilLoveaFehler ?? .netz
            zustand = .fehler(f)
            _ = await konto.meldeImportBeleg(ProfilLoveaFehlerBeleg(zeit: Date(), fehler: f.belegName, geladen: stand.geladen, bisSeq: stand.bisSeq))
        }
        return true
    }

    private func meldeStill(_ grund: String, konto: KontoDienst) async {
        guard gemeldeteGruende.insert(grund).inserted else { return }
        _ = await konto.meldeImportBeleg(ProfilLoveaFehlerBeleg(zeit: Date(), fehler: grund))
    }

    /// Schließt Ergebnis oder Fehler (Tippen oder nach ein paar Sekunden).
    func schliesse() {
        switch zustand {
        case .fertig, .unvollstaendig, .fehler: zustand = .aus
        default: break
        }
    }
}

/// Karte oben in der App: Fortschritt, Ergebnis oder Fehler des Imports. Zeichnet nichts, solange der Import nichts zu sagen hat.
struct LoveaEinmalKarte: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let lauf = umgebung.loveaImport
        Group {
            switch lauf.zustand {
            case .aus:
                EmptyView()
            case .laeuft(let stand):
                karte {
                    HStack(spacing: Abstand.m) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Deine Daten kommen aus Lovea").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                            Text(stand).font(.footnote).foregroundStyle(palette.text2)
                        }
                    }
                }
            case .fertig(let e):
                karte {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aus Lovea übernommen").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                        Text(Self.ergebnisText(e)).font(.footnote).foregroundStyle(palette.text2)
                    }
                }
                .onTapGesture { lauf.schliesse() }
                .task { try? await Task.sleep(for: .seconds(10)); lauf.schliesse() }
            case .unvollstaendig:
                FehlerKarte(titel: "Nicht alles ist angekommen", hilfe: "Lumen Fit hat die Lücke gemeldet und versucht es beim nächsten Start nochmal. Lovea blieb unverändert.")
                    .onTapGesture { lauf.schliesse() }
            case .fehler(let f):
                FehlerKarte(titel: f.titel, hilfe: f.hilfe + " Lumen Fit versucht es beim nächsten Öffnen nochmal.")
                    .onTapGesture { lauf.schliesse() }
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.top, Abstand.s)
        .accessibilityElement(children: .combine)
    }

    private func karte<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        ListenKarte { inhalt().frame(maxWidth: .infinity, alignment: .leading).padding(Abstand.l) }
    }

    /// "12 Trainings, 30 Tage Essen übernommen; 5 neu ..." in einfachen Worten.
    static func ergebnisText(_ e: ProfilLoveaErgebnis) -> String {
        "\(e.trainings) Trainings und \(e.essenstage) Tage Essen sind jetzt in Lumen Fit. Lovea blieb unverändert."
    }
}
