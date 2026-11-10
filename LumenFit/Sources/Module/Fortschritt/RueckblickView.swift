import SwiftUI

/// Wochen- und Monatsrückblick (Idee 39) mit Teilen als Bild, darunter der FitPassport (Idee 40).
struct RueckblickView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var zeitraum = RueckblickDaten.Zeitraum.woche

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let daten = Rueckblick.bauen(zeitraum, bezug: q.heute, sessions: q.sessions, gym: q.gym, schlafMinuten: q.schlaf)
        let passport = FitPassport.bauen(name: umgebung.profil.aktiv?.name, sessions: q.sessions, gym: q.gym, schlafMinuten: q.schlaf,
                                         medaillen: q.medaillen.count, stufe: q.stufe, heute: q.heute)
        ScrollView {
            VStack(spacing: Abstand.l) {
                Picker("Zeitraum", selection: $zeitraum) {
                    ForEach(RueckblickDaten.Zeitraum.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .haptik(.auswahl, bei: zeitraum)
                if daten.gymTage > 0 {
                    RueckblickKarte(daten: daten, stufe: q.stufe)
                } else {
                    LeerZustand(stimmung: .bereit, satz: String(localized: "\(daten.titel). Starte eins, Lumi schreibt mit."), handlung: String(localized: "Training starten")) {
                        umgebung.router.oeffne(.gym(.training))
                    }
                    .lumenKartenFlaeche()
                }
                FitPassportKarte(daten: passport)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .navigationTitle("Rückblick")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .fortschrittToast()
    }
}
