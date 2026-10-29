import Foundation

/// Training und Gewicht nach Health, nur auf Schalter (`Einstellungen.healthSchreiben`, Standard aus).
protocol HealthSchreiber: Sendable {
    func speichere(training: GymSession) async -> Bool
    func speichere(gewichtKg: Double, am datum: Date) async -> Bool
}

/// Standard ohne Health: speichert nichts.
struct KeinHealthSchreiber: HealthSchreiber {
    func speichere(training: GymSession) async -> Bool { false }
    func speichere(gewichtKg: Double, am datum: Date) async -> Bool { false }
}
