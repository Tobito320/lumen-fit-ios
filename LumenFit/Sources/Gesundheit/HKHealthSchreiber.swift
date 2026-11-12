import Foundation
import HealthKit
import os

/// Schreibt Krafttraining und Gewicht nach Health. Fragt die Schreibrechte erst beim ersten Speichern, je Typ nur einmal für immer
/// (`HealthFrageGedaechtnis`, auch ein weggewischtes Blatt kommt nie wieder; Ändern geht in Health).
// @unchecked Sendable: HKHealthStore ist thread-sicher, aber im SDK nicht als Sendable markiert; `gefragt` liegt unter einem Lock.
final class HKHealthSchreiber: HealthSchreiber, @unchecked Sendable {
    private let speicher = HKHealthStore()
    private let gewichtTyp = HKQuantityType(.bodyMass)
    /// Typen, für die in diesem Lauf schon gefragt wurde.
    private let gefragt = OSAllocatedUnfairLock(initialState: Set<String>())

    init() {}

    private func erlaubt(_ typ: HKSampleType) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        switch speicher.authorizationStatus(for: typ) {
        case .sharingAuthorized: return true
        case .sharingDenied: return false
        default: break
        }
        let kennung = HealthFrageGedaechtnis.schreiben(typ)
        guard !HealthFrageGedaechtnis.gefragt(kennung), gefragt.withLock({ $0.insert(typ.identifier).inserted }) else { return false }
        HealthFrageGedaechtnis.merke([kennung])
        do {
            try await speicher.requestAuthorization(toShare: [typ], read: [])
            return speicher.authorizationStatus(for: typ) == .sharingAuthorized
        } catch { return false }
    }

    func speichere(training: GymSession) async -> Bool {
        guard let ende = training.ende, ende > training.start, await erlaubt(HKObjectType.workoutType()) else { return false }
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
        guard gewichtKg > 0, await erlaubt(gewichtTyp) else { return false }
        let menge = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: gewichtKg)
        let probe = HKQuantitySample(type: gewichtTyp, quantity: menge, start: datum, end: datum)
        do {
            try await speicher.save(probe)
            return true
        } catch { return false }
    }
}
