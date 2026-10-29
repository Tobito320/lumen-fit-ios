import Foundation

/// Was die Live Activity und das Pausen-Ende brauchen (der ActivityKit-Typ gehört dem Modul widgets).
struct TrainingLiveStand: Codable, Hashable, Sendable {
    var uebung: String
    var satz: Int
    var von: Int
    var pauseEnde: Date?
    var start: Date
    var planName: String?
}
