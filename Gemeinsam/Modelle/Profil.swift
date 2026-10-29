import Foundation

/// Kennung eines Profils. Als Text kodiert (nicht als Objekt), damit sie in Ops und Dateien schlank bleibt.
struct ProfilID: Hashable, Codable, Sendable, RawRepresentable, Identifiable {
    var rawValue: String
    var id: String { rawValue }

    init(rawValue: String) { self.rawValue = rawValue }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    static func neu() -> ProfilID { ProfilID(rawValue: UUID().uuidString) }
}

/// Salz, Hash und Rundenzahl des Passworts. Das Passwort selbst wird nie gespeichert.
struct PasswortSpur: Codable, Hashable, Sendable {
    var salz: Data
    var hash: Data
    var runden: Int
}

struct Profil: Codable, Hashable, Identifiable, Sendable {
    var id: ProfilID
    var name: String
    var erstellt: Date
    var passwort: PasswortSpur
}
