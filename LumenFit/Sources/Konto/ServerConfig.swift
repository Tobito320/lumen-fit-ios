import Foundation

/// Die Einstellungen vom Server (`GET /config`, SPEC 18): ohne neuen Build änderbar. Klein und fest; unbekannte Schlüssel werden ignoriert (so bleibt ein alter gemerkter Stand mit `coachSichtbar` lesbar).
/// Die Standardwerte gelten, solange der Server nie geantwortet hat (offline, erster Start): sie sind die sichere Seite (kein zweites Profil).
struct ServerConfig: Equatable, Codable, Sendable {
    /// Ein weiteres Profil neben dem ersten anlegen. Das erste Profil geht immer.
    var profilAnlegenErlaubt = false
    /// So viele Tage zwischen zwei Namensänderungen; 0 heißt keine Sperre.
    var nameAendernTage = 7
    /// Der Server stellt "Band in Lumen Fit nutzen" für dieses Konto von selbst an (Standard nur dort, wo er es sagt). Ein bewusstes Aus in der App gewinnt.
    var bandStandard = false
    /// Schlaf, Armband und AirPods sind sichtbar: der Server sagt es nur dem Konto, das sie nutzen darf (Standard: Konten mit Lovea-Person). Ohne Antwort und ohne gemerkten Stand bleiben sie weg.
    var schlafSichtbar = false
    /// Schlaf-Beleg an den Entwickler (Diagnose): nur auf Freigabe des Servers für genau dieses Konto, Standard aus. Ohne Antwort bleibt er aus.
    var schlafBeleg = false

    nonisolated static let standard = ServerConfig()
    nonisolated static let tageBereich = 0...365

    enum CodingKeys: String, CodingKey { case profilAnlegenErlaubt, nameAendernTage, bandStandard, schlafSichtbar, schlafBeleg }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profilAnlegenErlaubt = (try? c.decodeIfPresent(Bool.self, forKey: .profilAnlegenErlaubt)) ?? false
        nameAendernTage = Self.tage(try? c.decodeIfPresent(Int.self, forKey: .nameAendernTage)) ?? 7
        bandStandard = (try? c.decodeIfPresent(Bool.self, forKey: .bandStandard)) ?? false
        schlafSichtbar = (try? c.decodeIfPresent(Bool.self, forKey: .schlafSichtbar)) ?? false
        schlafBeleg = (try? c.decodeIfPresent(Bool.self, forKey: .schlafBeleg)) ?? false
    }

    private static func tage(_ wert: Int?) -> Int? { wert.map { min(max($0, tageBereich.lowerBound), tageBereich.upperBound) } }

    /// Führt die Antwort des Servers (`{"config": {...}}`) in `basis` ein: gültige Schlüssel ersetzen, fehlende oder falsch getypte bleiben wie in `basis`.
    /// nil, wenn die Antwort kein Objekt `config` enthält (dann bleibt alles, wie es war).
    static func zusammen(_ basis: ServerConfig, antwort: Data) -> ServerConfig? {
        struct Huelle: Decodable { var config: [String: JSONValue]? }
        guard let werte = (try? JSONDecoder().decode(Huelle.self, from: antwort))?.config else { return nil }
        var neu = basis
        if case .bool(let b)? = werte["profilAnlegenErlaubt"] { neu.profilAnlegenErlaubt = b }
        if case .bool(let b)? = werte["bandStandard"] { neu.bandStandard = b }
        if case .bool(let b)? = werte["schlafSichtbar"] { neu.schlafSichtbar = b }
        if case .bool(let b)? = werte["schlafBeleg"] { neu.schlafBeleg = b }
        if case .number(let d)? = werte["nameAendernTage"], d.isFinite, d == d.rounded(), let t = tage(Int(exactly: d)) { neu.nameAendernTage = t }
        return neu
    }
}
