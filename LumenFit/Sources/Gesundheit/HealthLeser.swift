import Foundation

/// Health hinter einem Port: die App liest über `HealthLeser`, Tests über `FakeHealthLeser`. `tag` ist überall `yyyy-MM-dd` (Berlin).
protocol HealthLeser: Sendable {
    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff
    func tagesWerte(von: String, bis: String) async -> [TagesWerte]
    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht]
    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert]
    func gewichte(von: String, bis: String) async -> [GewichtsMesswert]
    func workouts(von: String, bis: String) async -> [HealthWorkout]
    /// `HKObserverQuery` mit Hintergrundlieferung: ruft `aenderung` bei neuen Daten, auch wenn iOS die App dafür im Hintergrund startet. Der Fake tut nichts.
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void)
}

/// Standard ohne Health (Vorschau ohne Daten): alles leer, `nichtVerfuegbar`.
struct LeererHealthLeser: HealthLeser {
    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff { .nichtVerfuegbar }
    func tagesWerte(von: String, bis: String) async -> [TagesWerte] { [] }
    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] { [] }
    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] { [] }
    func gewichte(von: String, bis: String) async -> [GewichtsMesswert] { [] }
    func workouts(von: String, bis: String) async -> [HealthWorkout] { [] }
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) {}
}
