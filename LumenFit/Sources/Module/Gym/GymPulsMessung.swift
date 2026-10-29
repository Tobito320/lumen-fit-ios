// Quelle: Lovea Health/WorkoutPuls.swift (ohne den AirPods-Sammelschalter und ohne StartProtokoll; Schalter nur auf diesem Gerät)
import Foundation
import HealthKit
import Observation
import UIKit

// Puls und Energie im Training (Idee 30), nur wenn ein Sensor sie liefert: seit iOS 26 läuft eine Workout-Sitzung auch auf dem
// iPhone, der Puls kommt von AirPods Pro 3, einem Pulsgurt oder einer Uhr. Ohne Sensor gibt es keinen Puls und keine Energie:
// nie schätzen, die Werte fehlen dann. Akku: aus, bis man es einschaltet, und nur während ein Training läuft.
// Diese Datei ist die einzige mit HKWorkoutSession: fällt sie beim Bauen durch, lässt sie sich ersetzen, ohne dass etwas anderes bricht.

/// Was `GymSitzung` von der Messung braucht. Der Standard `GymKeinePuls` liefert nie etwas (Tests, Vorschau, kein Schalter).
@MainActor protocol GymPulsQuelle: AnyObject {
    /// Letzter Puls, Schnitt über das Training und aktive Kalorien; nil, solange nichts kommt.
    var puls: Int? { get }
    var schnitt: Int? { get }
    var kcal: Int? { get }
    func starten()
    func leeren()
    /// Kein Training läuft: eine Sitzung, die ein App-Ende überlebt hat, beenden (Akku).
    func verwaisteBeenden()
    /// Beendet die Messung. `speichern`: das Training nach Health schreiben. true, wenn die Sitzung es selbst geschrieben hat
    /// (dann darf der `HealthSchreiber` es nicht noch einmal tun).
    func beenden(speichern: Bool) async -> Bool
}

@MainActor final class GymKeinePuls: GymPulsQuelle {
    var puls: Int? { nil }
    var schnitt: Int? { nil }
    var kcal: Int? { nil }
    func starten() {}
    func leeren() {}
    func verwaisteBeenden() {}
    func beenden(speichern: Bool) async -> Bool { false }
}

/// Die HealthKit-Objekte sind nicht Sendable und rufen ihren Delegate auf einer eigenen Queue. Diese Klasse hält sie zusammen
/// und reicht nur Zahlen nach außen.
// @unchecked Sendable: Session und Builder werden nur hier berührt, der Delegate meldet nur Zahlen über einen @Sendable-Rückruf.
private final class GymPulsSitzung: NSObject, HKLiveWorkoutBuilderDelegate, @unchecked Sendable {
    private let session: HKWorkoutSession
    private let builder: HKLiveWorkoutBuilder
    private let melden: @Sendable (_ puls: Int?, _ schnitt: Int?, _ kcal: Int?) -> Void

    /// Fragt die Erlaubnis an (erst beim Einschalten, nie beim App-Start) und startet die Sitzung. Lief noch eine von vor einem
    /// App-Ende, wird sie fortgesetzt statt eine zweite daneben zu starten.
    static func starten(melden: @escaping @Sendable (Int?, Int?, Int?) -> Void) async throws -> GymPulsSitzung {
        let store = HKHealthStore()
        let lesen: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        let schreiben: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)]
        try await store.requestAuthorization(toShare: schreiben, read: lesen)
        let einstellung = HKWorkoutConfiguration()
        einstellung.activityType = .traditionalStrengthTraining
        einstellung.locationType = .indoor
        let alt = try? await store.recoverActiveWorkoutSession()
        let session = try alt ?? HKWorkoutSession(healthStore: store, configuration: einstellung)
        let sitzung = GymPulsSitzung(session: session, melden: melden)
        if alt == nil {
            sitzung.builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: einstellung)
            let jetzt = Date()
            session.prepare()
            session.startActivity(with: jetzt)
            try await sitzung.builder.beginCollection(at: jetzt)
        }
        return sitzung
    }

    /// Eine Sitzung, die ein App-Ende überlebt hat, obwohl kein Training mehr läuft: beenden und verwerfen (Akku).
    static func verwaisteBeenden() async {
        guard let alt = try? await HKHealthStore().recoverActiveWorkoutSession() else { return }
        alt.associatedWorkoutBuilder().discardWorkout()
        alt.end()
    }

    private init(session: HKWorkoutSession, melden: @escaping @Sendable (Int?, Int?, Int?) -> Void) {
        self.session = session
        builder = session.associatedWorkoutBuilder()
        self.melden = melden
        super.init()
        builder.delegate = self
    }

    /// `speichern` schreibt das Training nach Apple Health, sonst wird es verworfen. true, wenn es gespeichert wurde.
    func beenden(speichern: Bool) async -> Bool {
        let jetzt = Date()
        session.stopActivity(with: jetzt)
        var gespeichert = false
        if speichern {
            try? await builder.endCollection(at: jetzt)
            gespeichert = (try? await builder.finishWorkout()) != nil
        } else {
            builder.discardWorkout()
        }
        session.end()
        return gespeichert
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let proMinute = HKUnit.count().unitDivided(by: .minute())
        let herz = workoutBuilder.statistics(for: HKQuantityType(.heartRate))
        let energie = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned))
        melden(
            herz?.mostRecentQuantity().map { Int($0.doubleValue(for: proMinute).rounded()) },
            herz?.averageQuantity().map { Int($0.doubleValue(for: proMinute).rounded()) },
            energie?.sumQuantity().map { Int($0.doubleValue(for: .kilocalorie()).rounded()) }
        )
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

@MainActor @Observable
final class GymPulsMessung: GymPulsQuelle {
    /// Der Schalter gilt pro Gerät (kein Profildatum): Standard aus.
    nonisolated static let schluessel = "gym.puls"

    private(set) var puls: Int?
    private(set) var schnitt: Int?
    private(set) var kcal: Int?

    @ObservationIgnored private var sitzung: GymPulsSitzung?
    @ObservationIgnored private var startet = false
    /// Beenden kam, während die Sitzung noch startete.
    @ObservationIgnored private var abbruch = false
    @ObservationIgnored private var aufgeraeumt = false

    init() {}

    var an: Bool {
        get {
            access(keyPath: \.an)
            return UserDefaults.standard.bool(forKey: Self.schluessel)
        }
        set {
            withMutation(keyPath: \.an) { UserDefaults.standard.set(newValue, forKey: Self.schluessel) }
        }
    }

    private var istIPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    /// Startet die Messung, wenn sie eingeschaltet ist und noch nicht läuft. Fragt beim ersten Mal nach der Erlaubnis für Health.
    func starten() {
        guard an, istIPhone, sitzung == nil, !startet, HKHealthStore.isHealthDataAvailable() else { return }
        startet = true
        abbruch = false
        Task {
            defer { startet = false }
            do {
                let neu = try await GymPulsSitzung.starten { puls, schnitt, kcal in
                    Task { @MainActor in self.uebernehmen(puls, schnitt, kcal) }
                }
                // Während des Startens ausgeschaltet oder das Training beendet: gleich wieder verwerfen.
                if an, !abbruch { sitzung = neu } else { _ = await neu.beenden(speichern: false) }
            } catch {
                // Keine Erlaubnis oder kein Workout möglich: das Training läuft ohne Puls weiter, die Werte fehlen.
            }
        }
    }

    /// Kein Training läuft, aber die Messung ist eingeschaltet: eine Sitzung, die ein App-Ende überlebt hat, beenden. Einmal je App-Start.
    func verwaisteBeenden() {
        guard an, istIPhone, sitzung == nil, !startet, !aufgeraeumt else { return }
        aufgeraeumt = true
        Task { await GymPulsSitzung.verwaisteBeenden() }
    }

    /// Beendet die Messung. Die Werte bleiben stehen, bis das nächste Training startet.
    func beenden(speichern: Bool) async -> Bool {
        abbruch = true
        guard let alt = sitzung else { return false }
        sitzung = nil
        puls = nil
        return await alt.beenden(speichern: speichern)
    }

    /// Vor einem neuen Training: alte Werte weg.
    func leeren() {
        guard sitzung == nil else { return }
        puls = nil
        schnitt = nil
        kcal = nil
    }

    private func uebernehmen(_ puls: Int?, _ schnitt: Int?, _ kcal: Int?) {
        guard sitzung != nil || startet else { return }
        if let puls { self.puls = puls }
        if let schnitt { self.schnitt = schnitt }
        if let kcal { self.kcal = kcal }
    }
}
