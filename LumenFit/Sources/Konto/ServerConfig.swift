import Foundation

/// Die Einstellungen vom Server (`GET /config`, SPEC 18): ohne neuen Build änderbar. Klein und fest; unbekannte Schlüssel werden ignoriert.
/// Die Standardwerte gelten, solange der Server nie geantwortet hat (offline, erster Start): sie sind die sichere Seite (kein zweites Profil).
struct ServerConfig: Equatable, Codable, Sendable {
    /// Ein weiteres Profil neben dem ersten anlegen. Das erste Profil geht immer.
    var profilAnlegenErlaubt = false
    /// So viele Tage zwischen zwei Namensänderungen; 0 heißt keine Sperre.
    var nameAendernTage = 7

    nonisolated static let standard = ServerConfig()
    nonisolated static let tageBereich = 0...365

    enum CodingKeys: String, CodingKey { case profilAnlegenErlaubt, nameAendernTage }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profilAnlegenErlaubt = (try? c.decodeIfPresent(Bool.self, forKey: .profilAnlegenErlaubt)) ?? false
        nameAendernTage = Self.tage(try? c.decodeIfPresent(Int.self, forKey: .nameAendernTage)) ?? 7
    }

    private static func tage(_ wert: Int?) -> Int? { wert.map { min(max($0, tageBereich.lowerBound), tageBereich.upperBound) } }

    /// Führt die Antwort des Servers (`{"config": {...}}`) in `basis` ein: gültige Schlüssel ersetzen, fehlende oder falsch getypte bleiben wie in `basis`.
    /// nil, wenn die Antwort kein Objekt `config` enthält (dann bleibt alles, wie es war).
    static func zusammen(_ basis: ServerConfig, antwort: Data) -> ServerConfig? {
        struct Huelle: Decodable { var config: [String: JSONValue]? }
        guard let werte = (try? JSONDecoder().decode(Huelle.self, from: antwort))?.config else { return nil }
        var neu = basis
        if case .bool(let b)? = werte["profilAnlegenErlaubt"] { neu.profilAnlegenErlaubt = b }
        if case .number(let d)? = werte["nameAendernTage"], d.isFinite, d == d.rounded(), let t = tage(Int(exactly: d)) { neu.nameAendernTage = t }
        return neu
    }
}
