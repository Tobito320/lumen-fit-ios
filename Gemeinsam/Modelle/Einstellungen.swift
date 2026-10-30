import Foundation

enum ThemaID: String, Codable, CaseIterable, Sendable { case monochrom, graphit, stahl, glut, wald, lovea }
enum Erscheinung: String, Codable, CaseIterable, Sendable { case system, hell, dunkel }
enum GewichtsEinheit: String, Codable, Sendable { case kg, lb }

/// Alle Felder haben Standardwerte; `init(from:)` nutzt `decodeIfPresent`, damit neue Felder alte Dateien nie unlesbar machen.
/// Ein unbekannter oder falsch getippter Wert (zum Beispiel ein Theme, das es später nicht mehr gibt) ergibt den Standard statt einer unlesbaren Datei.
struct Einstellungen: Codable, Equatable, Sendable {
    var thema: ThemaID = .monochrom
    var erscheinung: Erscheinung = .system
    var haptik = true
    var gewichtsEinheit: GewichtsEinheit = .kg
    var healthSchreiben = false          // Training und Gewicht nach Health (Idee 17, 30)
    var bandAktiv = false                // Idee 85, Annahme 9
    var loveaVerbunden = false           // Idee 81
    var alarmWeckt = true                // Lumen Alarm darf das Band wecken (Gerät, Standard an)
    var mitteilungen: [String: Bool] = [:]
    var healthGefragt = false

    init() {}

    private enum CodingKeys: String, CodingKey {
        case thema, erscheinung, haptik, gewichtsEinheit, healthSchreiben, bandAktiv, loveaVerbunden, alarmWeckt, mitteilungen, healthGefragt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        thema = (try? c.decodeIfPresent(ThemaID.self, forKey: .thema)) ?? .monochrom
        erscheinung = (try? c.decodeIfPresent(Erscheinung.self, forKey: .erscheinung)) ?? .system
        haptik = (try? c.decodeIfPresent(Bool.self, forKey: .haptik)) ?? true
        gewichtsEinheit = (try? c.decodeIfPresent(GewichtsEinheit.self, forKey: .gewichtsEinheit)) ?? .kg
        healthSchreiben = (try? c.decodeIfPresent(Bool.self, forKey: .healthSchreiben)) ?? false
        bandAktiv = (try? c.decodeIfPresent(Bool.self, forKey: .bandAktiv)) ?? false
        loveaVerbunden = (try? c.decodeIfPresent(Bool.self, forKey: .loveaVerbunden)) ?? false
        alarmWeckt = (try? c.decodeIfPresent(Bool.self, forKey: .alarmWeckt)) ?? true
        mitteilungen = (try? c.decodeIfPresent([String: Bool].self, forKey: .mitteilungen)) ?? [:]
        healthGefragt = (try? c.decodeIfPresent(Bool.self, forKey: .healthGefragt)) ?? false
    }
}
