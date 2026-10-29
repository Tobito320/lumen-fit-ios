import Foundation

enum VitalArt: String, Codable, CaseIterable, Sendable { case ruhepuls, hrv, sauerstoff, atemfrequenz, temperatur, vo2max }

struct VitalMesswert: Codable, Hashable, Sendable {
    var art: VitalArt
    var tag: String
    var wert: Double
}

struct TagesWerte: Codable, Hashable, Identifiable, Sendable {
    var tag: String
    var schritte: Int
    var distanzMeter: Double
    var etagen: Int
    var aktiveKcal: Double
    var trainingMinuten: Int
    var stehStunden: Int?
    var id: String { tag }

    init(tag: String, schritte: Int = 0, distanzMeter: Double = 0, etagen: Int = 0, aktiveKcal: Double = 0, trainingMinuten: Int = 0, stehStunden: Int? = nil) {
        self.tag = tag; self.schritte = schritte; self.distanzMeter = distanzMeter; self.etagen = etagen
        self.aktiveKcal = aktiveKcal; self.trainingMinuten = trainingMinuten; self.stehStunden = stehStunden
    }
}

struct GewichtsMesswert: Codable, Hashable, Sendable {
    var tag: String
    var kg: Double
}

struct HealthWorkout: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var art: String
    var start: Date
    var ende: Date
    var kcal: Double?
    var puls: Double?
}

enum HealthTyp: String, CaseIterable, Sendable {
    case schritte, distanz, etagen, aktiveEnergie, training, stehen, schlaf, ruhepuls, hrv, sauerstoff, atmung, temperatur, vo2max, gewicht, puls
}

enum HealthZugriff: Sendable { case unbekannt, angefragt, verweigert, nichtVerfuegbar }
