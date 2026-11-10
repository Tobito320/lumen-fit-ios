import SwiftUI

/// "Einsichten und Hinweise" (Route `einsichten`, Zeile im Tab Fortschritt, Besitzer 10.11.2026): was die Startseite nicht mehr zeigt. Die Hinweise des Tages
/// (wegwischbar, die Sonntags- und Monatsend-Karte öffnet den Rückblick) und "Das fällt mir auf". Dieselben Daten wie früher auf der Startseite (`HeuteModell`).
struct HeuteEinsichtenSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var modell: HeuteModell?

    var body: some View {
        ScrollView {
            if let modell, let s = modell.stand {
                VStack(spacing: Abstand.l) {
                    if s.hinweise.isEmpty && s.einsichten.isEmpty {
                        LeerZustand(stimmung: .bereit, satz: String(localized: "Gerade gibt es nichts Neues. Hinweise und Einsichten stehen hier, sobald es welche gibt."))
                            .lumenKartenFlaeche()
                    }
                    if !s.hinweise.isEmpty { HinweiseKarte(hinweise: s.hinweise) { modell.wischeHinweis($0) } }
                    if !s.einsichten.isEmpty { EinsichtenKarte(einsichten: s.einsichten) }
                }
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
            }
        }
        .lumenHintergrund()
        .navigationTitle("Einsichten und Hinweise")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: umgebung.profil.aktiv?.id) {
            let m = modell ?? HeuteModell(umgebung: umgebung)
            modell = m
            m.berechne()
            await m.lade()
            await m.beobachte()
        }
    }
}
