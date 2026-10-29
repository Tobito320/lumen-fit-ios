import ActivityKit
import Foundation

/// Attribute der Training-Live-Activity. Stub des Grundgerüsts: das Modul widgets baut die Oberfläche und die Knöpfe darauf.
struct TrainingAktivitaet: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stand: TrainingLiveStand
    }

    var planName: String?
}
