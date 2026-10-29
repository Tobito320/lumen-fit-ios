import SwiftUI

/// Der Gym-Tab: oben die Wahl zwischen Training, Plan und Fortschritt. Läuft ein Training, zeigt "Training" das laufende, sonst die
/// Startseite. `bereich` kommt aus der Route (`Route.gym`) und gilt als Startwert.
struct GymTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var bereich: GymBereich
    @State private var sitzung: GymSitzung?

    init(bereich: GymBereich = .training) {
        _bereich = State(initialValue: bereich)
    }

    var body: some View {
        VStack(spacing: Abstand.s) {
            Picker("Bereich", selection: $bereich) {
                Text("Training").tag(GymBereich.training)
                Text("Plan").tag(GymBereich.plaene)
                Text("Fortschritt").tag(GymBereich.fortschritt)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Abstand.l)
            inhalt
        }
        .lumenHintergrund()
        .navigationTitle("Gym")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() } }
        // Die Sitzung entsteht hier, nicht im Körper: `GymSitzung.von` setzt den Port, das darf nicht beim Zeichnen passieren.
        .task { sitzung = GymSitzung.von(umgebung) }
    }

    @ViewBuilder
    private var inhalt: some View {
        if let sitzung {
            switch bereich {
            case .training:
                if sitzung.sessionId != nil { TrainingLaufView(sitzung: sitzung) } else { GymStartView(sitzung: sitzung) }
            case .plaene:
                PlanView(sitzung: sitzung)
            case .fortschritt:
                FortschrittSegmentView()
            }
        } else {
            Spacer()
        }
    }
}
