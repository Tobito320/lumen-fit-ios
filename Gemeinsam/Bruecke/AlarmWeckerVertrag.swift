import Foundation

// Dateien für Wecker und Erinnerungen des Coachs (Vertrag mit Lumen Alarm, Abschnitt 2). Ordner `<Lumen-Fit-Gruppe>/LumenAlarm/`, alle Dateien `version` 1,
// Daten ISO 8601, Decoder tolerant (unbekannte Felder werden ignoriert, fehlende optionale Felder sind nil):
//   wecker-stand.json     Lumen Alarm schreibt: die Wecker und Erinnerungen, damit der Coach ihre Ids kennt
//   wecker-auftraege.json Lumen Fit schreibt: was der Coach angelegt, geändert, geschaltet oder gelöscht haben will
//   wecker-ergebnis.json  Lumen Alarm schreibt: was daraus geworden ist (die letzten 100)

/// Ein Befehl des Coachs für Wecker oder Erinnerungen, so wie der Marker ihn trägt (`[[wecker: ...]]`, `[[erinnern: ...]]`). Ids sind Texte: eine UUID oder `haupt`.
/// `tage` zählt 1 (Montag) bis 7 (Sonntag); leer heißt einmalig (bei Erinnerungen mit `datum` an diesem Tag).
enum WeckerBefehl: Equatable, Sendable {
    case weckerNeu(minute: Int, tage: [Int], name: String)
    case weckerAendern(id: String, minute: Int, tage: [Int], name: String?)
    case weckerSchalter(id: String, an: Bool)
    case weckerLoeschen(id: String)
    case erinnerungNeu(minute: Int, tage: [Int], datum: String?, text: String)
    case erinnerungAendern(id: String, minute: Int, tage: [Int], datum: String?, text: String?)
    case erinnerungSchalter(id: String, an: Bool)
    case erinnerungLoeschen(id: String)
}

/// `wecker-auftraege.json`: `{ version, auftraege: [ { id, angelegt, art, ... } ] }`.
struct WeckerAuftraegeDatei: Codable, Equatable, Sendable {
    var version: Int
    var auftraege: [WeckerAuftrag]
}

/// Ein Auftrag. `id` ist ein UUID-Text je Auftrag (Lumen Alarm führt jede Id höchstens einmal aus). Welche Felder gesetzt sind, sagt `art`.
struct WeckerAuftrag: Codable, Equatable, Identifiable, Sendable {
    enum Art: String, Codable, Sendable {
        case weckerNeu, weckerAendern, weckerSchalter, weckerLoeschen
        case erinnerungNeu, erinnerungAendern, erinnerungSchalter, erinnerungLoeschen
    }

    var id: String
    var angelegt: Date
    var art: Art
    var minute: Int?
    var tage: [Int]?
    var name: String?
    var weckerId: String?
    var an: Bool?
    var erinnerungId: String?
    var datum: String?
    var text: String?

    init(id: String, angelegt: Date, art: Art) {
        self.id = id
        self.angelegt = angelegt
        self.art = art
    }

    init(id: String, angelegt: Date, befehl: WeckerBefehl) {
        switch befehl {
        case .weckerNeu(let minute, let tage, let name):
            self.init(id: id, angelegt: angelegt, art: .weckerNeu)
            self.minute = minute; self.tage = tage; self.name = name
        case .weckerAendern(let wid, let minute, let tage, let name):
            self.init(id: id, angelegt: angelegt, art: .weckerAendern)
            weckerId = wid; self.minute = minute; self.tage = tage; self.name = name
        case .weckerSchalter(let wid, let an):
            self.init(id: id, angelegt: angelegt, art: .weckerSchalter)
            weckerId = wid; self.an = an
        case .weckerLoeschen(let wid):
            self.init(id: id, angelegt: angelegt, art: .weckerLoeschen)
            weckerId = wid
        case .erinnerungNeu(let minute, let tage, let datum, let text):
            self.init(id: id, angelegt: angelegt, art: .erinnerungNeu)
            self.minute = minute; self.tage = tage; self.datum = datum; self.text = text
        case .erinnerungAendern(let eid, let minute, let tage, let datum, let text):
            self.init(id: id, angelegt: angelegt, art: .erinnerungAendern)
            erinnerungId = eid; self.minute = minute; self.tage = tage; self.datum = datum; self.text = text
        case .erinnerungSchalter(let eid, let an):
            self.init(id: id, angelegt: angelegt, art: .erinnerungSchalter)
            erinnerungId = eid; self.an = an
        case .erinnerungLoeschen(let eid):
            self.init(id: id, angelegt: angelegt, art: .erinnerungLoeschen)
            erinnerungId = eid
        }
    }
}

/// `wecker-stand.json` (Lumen Alarm schreibt). Kaputte einzelne Einträge fallen weg, die Datei bleibt lesbar.
struct WeckerStandDatei: Decodable, Equatable, Sendable {
    struct Haupt: Equatable, Sendable {
        var aktiv: Bool
        var minute: Int
        var name: String?
    }

    struct Wecker: Equatable, Sendable {
        var id: String
        var minute: Int
        var name: String?
        var tage: [Int]
        var aktiv: Bool
        var einmalAm: String?
    }

    struct Erinnerung: Equatable, Sendable {
        var id: String
        var minute: Int
        var text: String
        var tage: [Int]
        var datum: String?
        var aktiv: Bool
    }

    var version: Int
    var geschrieben: Date?
    var haupt: Haupt?
    var wecker: [Wecker]
    var erinnerungen: [Erinnerung]

    init(version: Int, geschrieben: Date? = nil, haupt: Haupt? = nil, wecker: [Wecker] = [], erinnerungen: [Erinnerung] = []) {
        self.version = version
        self.geschrieben = geschrieben
        self.haupt = haupt
        self.wecker = wecker
        self.erinnerungen = erinnerungen
    }

    private enum CodingKeys: String, CodingKey { case version, geschrieben, haupt, wecker, erinnerungen }

    /// Ein Eintrag, der nicht lesbar ist, ist nil und wird aussortiert.
    private struct Lose<T: Decodable>: Decodable {
        let wert: T?
        init(from decoder: Decoder) throws { wert = try? T(from: decoder) }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        geschrieben = (try? c.decodeIfPresent(Date.self, forKey: .geschrieben)) ?? nil
        haupt = (try? c.decodeIfPresent(HauptLesen.self, forKey: .haupt))?.wert
        wecker = ((try? c.decodeIfPresent([Lose<WeckerLesen>].self, forKey: .wecker)) ?? nil)?.compactMap { $0.wert?.wert } ?? []
        erinnerungen = ((try? c.decodeIfPresent([Lose<ErinnerungLesen>].self, forKey: .erinnerungen)) ?? nil)?.compactMap { $0.wert?.wert } ?? []
    }

    private struct HauptLesen: Decodable {
        let wert: Haupt
        private enum K: String, CodingKey { case aktiv, minute, name }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            wert = Haupt(aktiv: (try? c.decodeIfPresent(Bool.self, forKey: .aktiv)) ?? true, minute: try c.decode(Int.self, forKey: .minute),
                         name: (try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil)
        }
    }

    private struct WeckerLesen: Decodable {
        let wert: Wecker
        private enum K: String, CodingKey { case id, minute, name, tage, aktiv, einmalAm }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            wert = Wecker(id: try c.decode(String.self, forKey: .id), minute: try c.decode(Int.self, forKey: .minute),
                          name: (try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil,
                          tage: (try? c.decodeIfPresent([Int].self, forKey: .tage)) ?? [],
                          aktiv: (try? c.decodeIfPresent(Bool.self, forKey: .aktiv)) ?? true,
                          einmalAm: (try? c.decodeIfPresent(String.self, forKey: .einmalAm)) ?? nil)
        }
    }

    private struct ErinnerungLesen: Decodable {
        let wert: Erinnerung
        private enum K: String, CodingKey { case id, minute, text, tage, datum, aktiv }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: K.self)
            wert = Erinnerung(id: try c.decode(String.self, forKey: .id), minute: try c.decode(Int.self, forKey: .minute),
                              text: (try? c.decodeIfPresent(String.self, forKey: .text)) ?? "",
                              tage: (try? c.decodeIfPresent([Int].self, forKey: .tage)) ?? [],
                              datum: (try? c.decodeIfPresent(String.self, forKey: .datum)) ?? nil,
                              aktiv: (try? c.decodeIfPresent(Bool.self, forKey: .aktiv)) ?? true)
        }
    }
}

/// `wecker-ergebnis.json` (Lumen Alarm schreibt): zu jedem ausgeführten Auftrag `ok`, bei einem Fehler der Grund.
struct WeckerErgebnisDatei: Decodable, Equatable, Sendable {
    struct Ergebnis: Equatable, Sendable {
        var id: String
        var ok: Bool
        var grund: String?
        var objektId: String?
        var name: String?
        var minute: Int?
    }

    var version: Int
    var geschrieben: Date?
    var ergebnisse: [Ergebnis]

    init(version: Int, geschrieben: Date? = nil, ergebnisse: [Ergebnis] = []) {
        self.version = version
        self.geschrieben = geschrieben
        self.ergebnisse = ergebnisse
    }

    private enum CodingKeys: String, CodingKey { case version, geschrieben, ergebnisse }

    private struct Lose: Decodable {
        let wert: Ergebnis?
        private enum K: String, CodingKey { case id, ok, grund, objektId, name, minute }
        init(from decoder: Decoder) throws {
            wert = try? Self.lies(decoder)
        }

        private static func lies(_ decoder: Decoder) throws -> Ergebnis {
            let c = try decoder.container(keyedBy: K.self)
            return Ergebnis(id: try c.decode(String.self, forKey: .id), ok: try c.decode(Bool.self, forKey: .ok),
                            grund: (try? c.decodeIfPresent(String.self, forKey: .grund)) ?? nil,
                            objektId: (try? c.decodeIfPresent(String.self, forKey: .objektId)) ?? nil,
                            name: (try? c.decodeIfPresent(String.self, forKey: .name)) ?? nil,
                            minute: (try? c.decodeIfPresent(Int.self, forKey: .minute)) ?? nil)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        geschrieben = (try? c.decodeIfPresent(Date.self, forKey: .geschrieben)) ?? nil
        ergebnisse = ((try? c.decodeIfPresent([Lose].self, forKey: .ergebnisse)) ?? nil)?.compactMap(\.wert) ?? []
    }
}
