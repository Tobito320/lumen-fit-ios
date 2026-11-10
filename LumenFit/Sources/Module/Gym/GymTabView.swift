import SwiftUI

/// Der Training-Tab: die Startseite (heute trainieren, letzte Einheiten) oder, wenn ein Training läuft, das laufende. Keine Segmentleiste:
/// ein Tipp auf den Tab führt sofort ins Training. Der Plan ist eine Unterseite (`PlanSeiteView`), der Fortschritt hat einen eigenen Tab.
struct TrainingTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var sitzung: GymSitzung?

    var body: some View {
        inhalt
            .lumenHintergrund()
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.large)
            // Die Sitzung entsteht hier, nicht im Körper: `GymSitzung.von` setzt den Port, das darf nicht beim Zeichnen passieren.
            // Alle Stellen holen dieselbe Instanz (`von` gibt die gesetzte zurück), es entsteht nie eine zweite.
            .task { sitzung = GymSitzung.von(umgebung) }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let sitzung {
            // Beide Aufbauten zeigen dieselbe Sitzung: ein Theme-Wechsel tauscht nur die Darstellung, das Training läuft weiter.
            switch GymSeite.wahl(bereich: .training, laeuft: sitzung.sessionId != nil) {
            case .lauf: TrainingLaufView(sitzung: sitzung)
            case .start, .plan, .fortschritt: GymStartView(sitzung: sitzung)
            }
        } else {
            Spacer()
        }
    }
}

/// Der Plan als Unterseite des Training-Tabs (Route `.gym(.plaene)`); die Sitzung ist dieselbe wie im Training.
struct PlanSeiteView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var sitzung: GymSitzung?

    var body: some View {
        Group {
            if let sitzung { PlanView(sitzung: sitzung) } else { Spacer() }
        }
        .lumenHintergrund()
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .task { sitzung = GymSitzung.von(umgebung) }
    }
}
