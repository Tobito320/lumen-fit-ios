import SwiftUI

/// Seite "Kalender und Verlauf" (Entwurf): Kalender, "Einheiten je Woche", dann die Einheiten je Woche (nur die laufende offen).
/// "+" oben rechts trägt ein Training nach. Die frühere Seite "Verlauf" (Woche im Detail; Konstanz, Gewicht, Stimmung, Rekorde und Plateaus,
/// alle Trainingstage) steht als zwei Zeilen zwischen Diagramm und Wochen.
struct FortVerlaufSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var nachtragen = false

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                KalenderKarte()
                if q.hatTraining {
                    FortKopf("Einheiten je Woche")
                    EinheitenKarte(sessions: q.sessions, heute: q.heute, jetzt: q.jetzt)
                }
                ListenKarte {
                    FortListenZeile("Woche im Detail", wert: String(localized: "Besuche, Muskeln"), symbol: "list.bullet.rectangle", farbe: Bereichsfarbe.verlauf) {
                        VerlaufView(ansicht: .woche)
                    }
                    Haarlinie()
                    FortListenZeile("Konstanz und Rekorde", wert: String(localized: "Stimmung, Plateaus"), symbol: "chart.xyaxis.line", farbe: Bereichsfarbe.verlauf) {
                        VerlaufView(ansicht: .verlauf)
                    }
                }
                VerlaufNachWochen(sessions: q.sessions, heute: q.heute, jetzt: q.jetzt)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Kalender und Verlauf")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Training nachtragen", systemImage: "plus") { nachtragen = true }
            }
        }
        .sheet(isPresented: $nachtragen) { EinheitNachtragenBlatt(jetzt: umgebung.uhr()) }
    }
}
