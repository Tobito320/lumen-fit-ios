import SwiftUI

/// Der Training-Tab: die Startseite (heute trainieren, letzte Einheiten) oder, wenn ein Training läuft, das laufende. Keine Segmentleiste:
/// ein Tipp auf den Tab führt sofort ins Training. Plan und Fortschritt liegen im Plan-Tab (`PlanTabView`).
struct TrainingTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var sitzung: GymSitzung?

    var body: some View {
        inhalt
            .lumenHintergrund()
            .navigationTitle("Training")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() } }
            // Die Sitzung entsteht hier, nicht im Körper: `GymSitzung.von` setzt den Port, das darf nicht beim Zeichnen passieren.
            // Beide Gym-Tabs holen dieselbe Instanz (`von` gibt die gesetzte zurück), es entsteht nie eine zweite.
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

/// Der Plan-Tab: oben die Wahl zwischen Plan und Fortschritt. `bereich` kommt aus der Route (`Route.gym`) und gilt als Startwert;
/// `.training` gibt es hier nicht und zählt als Plan.
struct PlanTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var bereich: GymBereich
    @State private var sitzung: GymSitzung?

    init(bereich: GymBereich = .plaene) {
        _bereich = State(initialValue: bereich == .fortschritt ? .fortschritt : .plaene)
    }

    var body: some View {
        VStack(spacing: Abstand.s) {
            Picker("Bereich", selection: $bereich) {
                Text("Plan").tag(GymBereich.plaene)
                Text("Fortschritt").tag(GymBereich.fortschritt)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Abstand.l)
            inhalt
        }
        .lumenHintergrund()
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() } }
        .task { sitzung = GymSitzung.von(umgebung) }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let sitzung {
            switch GymSeite.wahl(bereich: bereich, laeuft: sitzung.sessionId != nil) {
            case .fortschritt: FortschrittSegmentView()
            case .plan, .start, .lauf: PlanView(sitzung: sitzung)
            }
        } else {
            Spacer()
        }
    }
}
