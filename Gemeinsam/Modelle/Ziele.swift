import Foundation

enum Zielart: String, Codable, Sendable { case aufbauen, halten, abnehmen }
enum Geschlecht: String, Codable, Sendable { case weiblich, maennlich, divers }

struct Ziele: Codable, Equatable, Sendable {
    var schritte = 10_000
    var aktiveKcal = 600
    var kalorien = 2_400
    var proteinGramm = 140
    var schlafMinuten = 480
    var gymTageProWoche = 3
    var wasserMl = 2_500
    var gewichtKg: Double?
    var art: Zielart = .halten

    init() {}

    private enum CodingKeys: String, CodingKey {
        case schritte, aktiveKcal, kalorien, proteinGramm, schlafMinuten, gymTageProWoche, wasserMl, gewichtKg, art
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schritte = (try? c.decodeIfPresent(Int.self, forKey: .schritte)) ?? 10_000
        aktiveKcal = (try? c.decodeIfPresent(Int.self, forKey: .aktiveKcal)) ?? 600
        kalorien = (try? c.decodeIfPresent(Int.self, forKey: .kalorien)) ?? 2_400
        proteinGramm = (try? c.decodeIfPresent(Int.self, forKey: .proteinGramm)) ?? 140
        schlafMinuten = (try? c.decodeIfPresent(Int.self, forKey: .schlafMinuten)) ?? 480
        gymTageProWoche = (try? c.decodeIfPresent(Int.self, forKey: .gymTageProWoche)) ?? 3
        wasserMl = (try? c.decodeIfPresent(Int.self, forKey: .wasserMl)) ?? 2_500
        gewichtKg = try? c.decodeIfPresent(Double.self, forKey: .gewichtKg)
        art = (try? c.decodeIfPresent(Zielart.self, forKey: .art)) ?? .halten
    }
}

struct Koerperdaten: Codable, Equatable, Sendable {
    var groesseCm: Int?
    var geburtsjahr: Int?
    var geschlecht: Geschlecht?

    init(groesseCm: Int? = nil, geburtsjahr: Int? = nil, geschlecht: Geschlecht? = nil) {
        self.groesseCm = groesseCm; self.geburtsjahr = geburtsjahr; self.geschlecht = geschlecht
    }
}
