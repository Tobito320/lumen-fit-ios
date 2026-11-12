import Foundation
import HealthKit

/// Merkt über App-Starts hinweg, für welche Health-Typen das System-Blatt schon kam; danach fragt die App von selbst nie wieder
/// (Wunsch 12.11.2026: "It asked the first time and that's enough"). Ändern geht in Health. Vorher stand das nur im Speicher eines Laufs:
/// ein weggewischtes Blatt lässt den Typ "nicht entschieden", und das Blatt kam bei jedem Start wieder.
enum HealthFrageGedaechtnis {
    static let schluessel = "lumenfit.health.gefragt"

    static func lesen(_ typ: HKObjectType) -> String { "lesen:" + typ.identifier }
    static func schreiben(_ typ: HKObjectType) -> String { "schreiben:" + typ.identifier }

    /// Schreib- und Leserechte des Trainings mit Puls (`GymPulsSitzung`) und des `HKHealthSchreiber`.
    static var pulsSchreiben: Set<HKSampleType> { [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned)] }
    static var pulsLesen: Set<HKObjectType> { [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)] }
    // berechnet statt `let`: HealthKit-Typen sind nicht sicher Sendable (Swift 6).
    static var schreibTypen: Set<HKSampleType> { [HKObjectType.workoutType(), HKQuantityType(.bodyMass)] }

    static func gefragt(_ kennung: String, ablage: UserDefaults = .standard) -> Bool {
        (ablage.stringArray(forKey: schluessel) ?? []).contains(kennung)
    }

    static func merke(_ kennungen: some Sequence<String>, ablage: UserDefaults = .standard) {
        let alt = Set(ablage.stringArray(forKey: schluessel) ?? [])
        let neu = alt.union(kennungen)
        if neu != alt { ablage.set(neu.sorted(), forKey: schluessel) }
    }

    /// Erster Start nach dem Update: wer Health schon erlaubt hat, wurde für diese Typen schon gefragt (sonst käme jedes offene Blatt noch einmal).
    static func uebernimmAltbestand(_ kennungen: some Sequence<String>, ablage: UserDefaults = .standard) {
        guard ablage.object(forKey: schluessel) == nil else { return }
        merke(kennungen, ablage: ablage)
    }

    /// Alle Rechte, nach denen die App für diese Bereiche fragt (Lesen, Schreiben, Puls).
    static func alleKennungen(fuer bereiche: Set<HealthTyp>) -> Set<String> {
        Set(bereiche.flatMap(HKHealthLeser.lesetypen).map { lesen($0) }).union(schreibTypen.map { schreiben($0) }).union(pulsSchreiben.map { schreiben($0) }).union(pulsLesen.map { lesen($0) })
    }
}
