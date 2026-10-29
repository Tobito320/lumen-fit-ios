import Foundation
import HealthKit

/// Schreibt Krafttraining und Gewicht nach Health. Fragt die Schreibrechte erst beim ersten Speichern.
// @unchecked Sendable: HKHealthStore ist thread-sicher, aber im SDK nicht als Sendable markiert.
final class HKHealthSchreiber: HealthSchreiber, @unchecked Sendable {
    private let speicher = HKHealthStore()
    private let gewichtTyp = HKQuantityType(.bodyMass)

    init() {}

    private func erlaubt() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let schreiben: Set<HKSampleType> = [HKObjectType.workoutType(), gewichtTyp]
        do {
            try await speicher.requestAuthorization(toShare: schreiben, read: [])
            return true
        } catch { return false }
    }

    func speichere(training: GymSession) async -> Bool {
        guard let ende = training.ende, ende > training.start, await erlaubt() else { return false }
        let konfiguration = HKWorkoutConfiguration()
        konfiguration.activityType = .traditionalStrengthTraining
        let bauer = HKWorkoutBuilder(healthStore: speicher, configuration: konfiguration, device: .local())
        do {
            try await bauer.beginCollection(at: training.start)
            try await bauer.endCollection(at: ende)
            return try await bauer.finishWorkout() != nil
        } catch { return false }
    }

    func speichere(gewichtKg: Double, am datum: Date) async -> Bool {
        guard gewichtKg > 0, await erlaubt() else { return false }
        let menge = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: gewichtKg)
        let probe = HKQuantitySample(type: gewichtTyp, quantity: menge, start: datum, end: datum)
        do {
            try await speicher.save(probe)
            return true
        } catch { return false }
    }
}
