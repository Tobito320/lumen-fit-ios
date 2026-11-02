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
/// Lesen verträgt fehlende Felder (`decodeIfPresent`): ein später ergänztes oder fehlendes Feld macht keinen Schlüsselbund-Eintrag unlesbar.
/// Eine Spur ohne Salz oder Hash stimmt nie (leerer Hash), das Profil bleibt aber lesbar und lässt sich zurücksetzen.
struct PasswortSpur: Codable, Hashable, Sendable {
    var salz: Data
    var hash: Data
    var runden: Int

    enum CodingKeys: String, CodingKey { case salz, hash, runden }

    init(salz: Data, hash: Data, runden: Int) {
        self.salz = salz
        self.hash = hash
        self.runden = runden
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        salz = (try? c.decodeIfPresent(Data.self, forKey: .salz)) ?? Data()
        hash = (try? c.decodeIfPresent(Data.self, forKey: .hash)) ?? Data()
        runden = (try? c.decodeIfPresent(Int.self, forKey: .runden)) ?? 600_000   // Standard der ersten Fassung
    }
}

/// Wie `PasswortSpur` tolerant beim Lesen. Ohne `id` gibt es kein Profil (der Eintrag wird beim Laden übersprungen und gesichert).
struct Profil: Codable, Hashable, Identifiable, Sendable {
    var id: ProfilID
    var name: String
    var erstellt: Date
    var passwort: PasswortSpur
    /// Wann der Name zuletzt geändert wurde (für die Sperre "alle 7 Tage"); nil, solange er nie geändert wurde.
    var nameGeaendert: Date?
    /// Das Profil wurde ohne Passwort angelegt (Passwort ist freiwillig): Wechseln und Alles löschen fragen nur nach einer Bestätigung. `passwort` ist dann leer.
    /// Fehlt das Feld in einem alten Eintrag, gilt false: ein Profil mit Passwort behält es.
    var ohnePasswort: Bool

    enum CodingKeys: String, CodingKey { case id, name, erstellt, passwort, nameGeaendert, ohnePasswort }

    init(id: ProfilID, name: String, erstellt: Date, passwort: PasswortSpur, nameGeaendert: Date? = nil, ohnePasswort: Bool = false) {
        self.ohnePasswort = ohnePasswort
        self.id = id
        self.name = name
        self.erstellt = erstellt
        self.passwort = passwort
        self.nameGeaendert = nameGeaendert
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ProfilID.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Profil"
        erstellt = (try? c.decodeIfPresent(Date.self, forKey: .erstellt)) ?? Date(timeIntervalSince1970: 0)
        passwort = (try? c.decodeIfPresent(PasswortSpur.self, forKey: .passwort)) ?? PasswortSpur(salz: Data(), hash: Data(), runden: 1)
        nameGeaendert = try? c.decodeIfPresent(Date.self, forKey: .nameGeaendert)
        ohnePasswort = (try? c.decodeIfPresent(Bool.self, forKey: .ohnePasswort)) ?? false
    }
}
