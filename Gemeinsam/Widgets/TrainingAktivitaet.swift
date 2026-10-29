import ActivityKit
import Foundation

/// Attribute der Training-Live-Activity (Dynamic Island und Sperrbildschirm). Die App startet, aktualisiert und beendet sie
/// (`LiveActivityDienst`), das Widget-Ziel zeichnet sie (`TrainingLiveWidget`). Aktualisiert wird nur bei Satzwechsel.
struct TrainingAktivitaet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stand: TrainingLiveStand
    }

    var planName: String?
}
