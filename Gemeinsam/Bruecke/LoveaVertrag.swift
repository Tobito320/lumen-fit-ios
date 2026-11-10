import Foundation

/// Dateivertrag mit Lovea (SPEC 5.5). Ordner `<group.com.onlyus.lovea>/LumenFit/`, alle Dateien `version` 1, Daten als ISO 8601.
/// Lovea selbst bleibt in diesem Bau unverändert: Quelle A (Loveas vorhandener `widget-stand.json`) liefert den Partner schon heute.
enum LoveaVertrag {
    nonisolated static let version = 1
    nonisolated static let ordnerName = "LumenFit"
    nonisolated static let zusammenfassungDatei = "zusammenfassung.json"
    nonisolated static let partnerDatei = "partner.json"
    nonisolated static let wuenscheDatei = "band-wuensche.json"
    nonisolated static let erledigtDatei = "band-erledigt.json"
    nonisolated static let statusDatei = "band-status.json"
    nonisolated static let schritteDatei = "band-schritte.json"
    nonisolated static let widgetStandDatei = "widget-stand.json"
    /// Nach so langer Zeit ohne neue Datei gilt der Partner als veraltet (nichts wird angezeigt).
    nonisolated static let frist: TimeInterval = 48 * 3600
    /// So viele ausgeführte Wünsche merkt `band-erledigt.json`.
    nonisolated static let erledigteMaximal = 200

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { datum, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(isoText(datum))
        }
        e.outputFormatting = [.sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let datum = isoDatum(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Kein ISO-8601-Datum"))
            }
            return datum
        }
        return d
    }

    /// ISO 8601 mit Sekundenbruchteilen ("2026-10-29T14:22:11.123Z"). Der Formatierer ist nicht Sendable und wird je Aufruf gebaut (kleine Dateien).
    static func isoText(_ datum: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: datum)
    }

    /// Mit und ohne Sekundenbruchteile lesbar (Lovea darf beides schreiben).
    static func isoDatum(_ text: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: text)
    }
}

/// Dateivertrag mit Lovea (SPEC 5.5); die Umsetzung `LoveaBruecke(ordner:)` gehört dem Grundgerüst, die Regeln dem Modul verbinden.
protocol PartnerAustausch: Sendable {
    func partner(jetzt: Date) -> PartnerStand
    /// Der Trainingspartner ohne die Datei von Lovea (Schalter "Lovea verbinden" aus): nur vom Server. Der Standard kennt keinen.
    func partnerOhneLovea(jetzt: Date) -> PartnerStand
    func schreibe(zusammenfassung: ZusammenfassungDatei)
    func wuensche() -> [BandWunsch]
    func melde(erledigt ids: [String])
    func schreibe(status: BandStatusDatei)
    /// Löscht die eigenen Dateien im Lovea-Ordner (nach dem Löschen des letzten Profils). Der Standard tut nichts (Fakes, `KeinePartnerBruecke`).
    func loescheEigeneDateien()
    func schreibe(serverStand: ZusammenfassungDatei)
    /// Die Weckzeiten mit Schritte-Pflicht aus `band-wuensche.json` (Feld `wecker`, nur Lumen Alarm schreibt es). Der Standard liefert nichts.
    func weckFenster() -> [WeckFenster]
    /// `band-schritte.json` (Lumen Fit schreibt, nur im Ordner von Lumen Alarm). Der Standard tut nichts.
    func schreibe(schritte: BandSchritteDatei)
    func schritte() -> BandSchritteDatei?
}

extension PartnerAustausch {
    func partnerOhneLovea(jetzt: Date) -> PartnerStand { .nichtVerbunden }
    func loescheEigeneDateien() {}
    /// Die Zusammenfassung für den Lumen-Server (alle Bereiche, die eine Verbindung zeigt). Nur die Brücke mit Server tut etwas.
    func schreibe(serverStand: ZusammenfassungDatei) {}
    func weckFenster() -> [WeckFenster] { [] }
    func schreibe(schritte: BandSchritteDatei) {}
    func schritte() -> BandSchritteDatei? { nil }
}

/// `band-wuensche.json` (Lovea schreibt).
struct BandWuenscheDatei: Codable, Equatable, Sendable {
    var version: Int
    var wuensche: [BandWunsch]
    /// Nur von Lumen Alarm: je Weckzeit mit Wünschen die Schritte-Pflicht. Fehlt bei Lovea.
    var wecker: [WeckFenster]?

    enum CodingKeys: String, CodingKey { case version, wuensche, wecker }
}

extension BandWuenscheDatei {
    /// Tolerant: ein kaputtes oder fremdes `wecker` ist nil, die Wünsche bleiben lesbar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        wuensche = try c.decode([BandWunsch].self, forKey: .wuensche)
        wecker = (try? c.decodeIfPresent([WeckFenster].self, forKey: .wecker)) ?? nil
    }
}

/// Eine Weckzeit mit Wünschen (`wecker` in `band-wuensche.json`). `schritteNoetig` 0 = keine Pflicht; `bisAufgewacht`: die Wünsche laufen, bis jemand aufsteht.
struct WeckFenster: Codable, Equatable, Hashable, Sendable {
    var weckzeit: Date
    var schritteNoetig: Int
    var bisAufgewacht: Bool

    enum CodingKeys: String, CodingKey { case weckzeit, schritteNoetig, bisAufgewacht }

    init(weckzeit: Date, schritteNoetig: Int, bisAufgewacht: Bool = false) {
        self.weckzeit = weckzeit
        self.schritteNoetig = schritteNoetig
        self.bisAufgewacht = bisAufgewacht
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weckzeit = try c.decode(Date.self, forKey: .weckzeit)
        schritteNoetig = (try? c.decodeIfPresent(Int.self, forKey: .schritteNoetig)) ?? 0
        bisAufgewacht = (try? c.decodeIfPresent(Bool.self, forKey: .bisAufgewacht)) ?? false
    }

    /// Die Zeit in Sekunden, wie sie in den Ids `wecker-<Sekunden>-<Nr>` steht.
    var sekunden: Int { Int(weckzeit.timeIntervalSince1970.rounded(.down)) }
    var idPraefix: String { "wecker-\(sekunden)-" }
}

/// `band-schritte.json` (Lumen Fit schreibt, Ordner `LumenAlarm`): die Armband-Schritte seit der Weckzeit.
struct BandSchritteDatei: Codable, Equatable, Sendable {
    var version: Int
    var geschrieben: Date
    var weckzeit: Date
    var schritte: Int
    var aufgestanden: Bool
}

/// `band-erledigt.json` (Lumen Fit schreibt): die letzten ausgeführten Wunsch-Ids.
struct BandErledigtDatei: Codable, Equatable, Sendable {
    var version: Int
    var ids: [String]
}

/// Loveas vorhandener `widget-stand.json`, nur die Felder, die Lumen Fit braucht (Schritte, Gym-Woche, Schlaf, Ziele), alle optional.
/// Ort, Wetter, Akku, Status, Herzen, Punkte und Bilder werden nie dekodiert. Das Format gehört Lovea: bei Abweichung heißt es "nicht verbunden".
struct LoveaWidgetStand: Decodable, Equatable, Sendable {
    struct Tag: Decodable, Equatable, Sendable {
        var datum: String
        var erledigt: Bool
    }

    var eigenePerson: String?
    var schritteHeute: [String: Int]?
    var zielSchritte: [String: Int]?
    var gymLetzte7: [String: [Tag]]?
    var zielGymWoche: [String: Int]?
    var schlafMinutenHeute: [String: Int]?
    var zielSchlafMinuten: [String: Int]?
}
