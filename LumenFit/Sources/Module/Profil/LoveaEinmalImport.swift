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
        case fehler(ProfilLoveaFehler)
    }

    private(set) var zustand: Zustand = .aus

    /// Startet den Import, wenn er offen ist und gerade keiner läuft. Nach einem Fehler startet der nächste Abgleich ihn neu (nichts war übernommen oder
    /// nur teilweise; Doppeltes wird übersprungen). Gibt zurück, ob ein Lauf stattfand.
    @discardableResult
    func starteWennOffen(konto: KontoDienst, daten: DatenSatz?, lader: any HTTPLader) async -> Bool {
        if case .laeuft = zustand { return false }
        if case .fertig = zustand { return false }
        guard konto.loveaImportOffen, let daten, let zugang = konto.loveaZugang() else { return false }
        zustand = .laeuft("Lade")
        do {
            let ergebnis = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: lader, freigegeben: konto.loveaErlaubt, bestaetigt: true) { [self] text in
                zustand = .laeuft(text)
            }
            await konto.loveaImportAbgeschlossen()
            zustand = .fertig(ergebnis)
        } catch let f as ProfilLoveaFehler {
            zustand = .fehler(f)
        } catch {
            zustand = .fehler(.netz)
        }
        return true
    }

    /// Schließt Ergebnis oder Fehler (Tippen oder nach ein paar Sekunden).
    func schliesse() {
        switch zustand {
        case .fertig, .fehler: zustand = .aus
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
