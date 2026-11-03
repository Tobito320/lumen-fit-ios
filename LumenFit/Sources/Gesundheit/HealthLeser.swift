import Foundation

/// Eine rohe Schlafprobe aus Health (Diagnose, `SchlafBeleg`): `wert` ist der Rohwert von `HKCategoryValueSleepAnalysis` (0 im Bett, 1 Schlaf ohne Phase,
/// 2 wach, 3 Kern, 4 Tief, 5 REM), `quelle` die Kennung der Quelle (App oder Gerät), `geraet` der Gerätetyp, nie ein Name.
struct HealthSchlafProbe: Codable, Equatable, Sendable {
    var wert: Int
    var von: Date
    var bis: Date
    var quelle: String
    var geraet: String?
}

/// Health hinter einem Port: die App liest über `HealthLeser`, Tests über `FakeHealthLeser`. `tag` ist überall `yyyy-MM-dd` (Berlin).
protocol HealthLeser: Sendable {
    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff
    func tagesWerte(von: String, bis: String) async -> [TagesWerte]
    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht]
    /// Die rohen Schlafproben mit Quelle (nur für den Schlaf-Beleg, wenn der Server ihn freigibt). Standard: leer.
    func schlafProben(von: String, bis: String) async -> [HealthSchlafProbe]
    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert]
    func gewichte(von: String, bis: String) async -> [GewichtsMesswert]
    func workouts(von: String, bis: String) async -> [HealthWorkout]
    /// `HKObserverQuery` mit Hintergrundlieferung: ruft `aenderung` bei neuen Daten, auch wenn iOS die App dafür im Hintergrund startet. Der Fake tut nichts.
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void)
}

extension HealthLeser {
    func schlafProben(von: String, bis: String) async -> [HealthSchlafProbe] { [] }
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
