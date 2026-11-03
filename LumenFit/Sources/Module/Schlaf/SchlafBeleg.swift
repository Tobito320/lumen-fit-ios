import Foundation

/// Eine Nacht in Kurzform für den Schlaf-Beleg: Zeiten, Schlafminuten und Minuten je Phase (Name der Phase).
struct SchlafBelegNacht: Codable, Equatable, Sendable {
    var tag: String
    var von: Date
    var bis: Date
    var schlafMinuten: Int
    var phasenMinuten: [String: Int]
    /// Nur bei der gewählten Nacht: die Quelle, die gilt, und die Quellen, die dieselbe Nacht auch gemeldet haben.
    var quelle: String?
    var weitere: [String]?
}

/// Schritte eines Tages je Quelle: das Band (Ops und Speicher des Bands) und Health getrennt, nil = die Quelle hat den Tag nicht.
struct SchlafBelegSchritte: Codable, Equatable, Sendable {
    var tag: String
    var band: Int?
    var health: Int?
}

/// Der Schlaf-Beleg (Diagnose, nur wenn der Server ihn für dieses Konto freigibt): Rohwerte von Schlaf und Schritten der letzten 14 Tage,
/// damit ein Agent falsches Tracking untersuchen kann. Geht an `/diagnose/schlaf`, nie an Dritte. Keine Namen, keine Adressen.
struct SchlafBeleg: Codable, Equatable, Sendable {
    var version = 1
    var erzeugt: Date
    var build: String
    var zeitzone: String
    var zeitzoneOffsetSekunden: Int
    var heute: String
    /// Ende der letzten Band-Abfrage, die bis zum Schluss durchlief (nil: seit dem App-Start keine).
    var letzterBandSync: Date?
    /// Die Nächte, die die App zeigt (Ergebnis der Quellenwahl), mit Quelle.
    var gewaehlt: [SchlafBelegNacht]
    /// Band: die Ops `fit.band.schlaf` roh (Zeitleiste) und die Nächte des Trackers vor der Umrechnung (Phase des Bands und Minuten).
    var band: [BandSchlafOp]
    var bandRoh: [TrackerSchlaf.Nacht]
    /// Health: die fertigen Nächte in Kurzform und die rohen Proben mit Quelle.
    var health: [SchlafBelegNacht]
    var healthProben: [HealthSchlafProbe]
    /// Von Hand eingetragene Nächte.
    var hand: [SchlafBelegNacht]
    var schritte: [SchlafBelegSchritte]
    /// Die Zeilen des Band-Logs (Rohantworten, Auswertung mit verworfenen Nächten, Uhr stellen); nur im Speicher der App, nach einem Neustart leer.
    var bandLog: [String]
    /// Daraus die Zeilen zur Band-Uhr (gestellt, Antwort). Das Band wird nie ausgelesen, nur gestellt; hier steht, was gesendet wurde und was zurückkam.
    var bandUhrLog: [String]
}

/// Reine Logik des Schlaf-Belegs: wann er fällig ist und wie er aus den Quellen zusammengesetzt wird. Kein Netz, kein Speicher.
enum SchlafBelegLogik {
    /// So viele Tage (Nächte) reichen zurück.
    static let tage = 14
    /// Höchstens einmal je Stunde.
    static let pause: TimeInterval = 3600
    /// Obergrenze für rohe Health-Proben (die neuesten bleiben); hält den Beleg weit unter den 512 KB des Servers.
    static let hoechstProben = 1500
    static let hoechstLogZeilen = 60
    static let hoechstZeile = 1200

    struct Eingabe: Sendable {
        var jetzt: Date
        var build: String
        var zone: TimeZone
        var gewaehlt: [SchlafGewaehlteNacht] = []
        var bandOps: [BandSchlafOp] = []
        var bandRoh: [TrackerSchlaf.Nacht] = []
        var healthNaechte: [String: SchlafNacht] = [:]
        var healthProben: [HealthSchlafProbe] = []
        var hand: [String: SchlafNacht] = [:]
        var bandSchritte: [String: Int] = [:]
        var healthSchritte: [String: Int] = [:]
        var letzterBandSync: Date?
        var bandLog: [String] = []
    }

    /// Fällig, wenn noch nie gesendet, die letzte Sendung eine Stunde her ist oder in der Zukunft liegt (Uhr zurückgestellt).
    static func faellig(letzter: Date?, jetzt: Date) -> Bool {
        guard let letzter else { return true }
        let seitdem = jetzt.timeIntervalSince(letzter)
        return seitdem < 0 || seitdem >= pause
    }

    static func bauen(_ e: Eingabe) -> SchlafBeleg {
        let heute = Datum.text(e.jetzt)
        let ab = Datum.addTage(heute, -(tage - 1))
        let imFenster: @Sendable (String) -> Bool = { $0 >= ab && $0 <= heute }
        let beginn = Datum.datum(ab).addingTimeInterval(-86400)
        let proben = e.healthProben.filter { $0.bis >= beginn }.sorted { $0.von < $1.von }.suffix(hoechstProben)
        let log = e.bandLog.suffix(hoechstLogZeilen).map { String($0.prefix(hoechstZeile)) }
        var schritte: [SchlafBelegSchritte] = []
        for tag in Set(e.bandSchritte.keys).union(e.healthSchritte.keys).filter(imFenster).sorted() {
            schritte.append(SchlafBelegSchritte(tag: tag, band: e.bandSchritte[tag], health: e.healthSchritte[tag]))
        }
        return SchlafBeleg(
            erzeugt: e.jetzt, build: e.build, zeitzone: e.zone.identifier, zeitzoneOffsetSekunden: e.zone.secondsFromGMT(for: e.jetzt), heute: heute,
            letzterBandSync: e.letzterBandSync,
            gewaehlt: e.gewaehlt.filter { imFenster($0.nacht.tag) }.map { kurz($0.nacht, quelle: $0.quelle.name, weitere: $0.weitere.map(\.name)) },
            band: e.bandOps.filter { imFenster($0.tag) }.sorted { $0.tag < $1.tag },
            bandRoh: e.bandRoh.filter { imFenster($0.tag) }.sorted { $0.tag < $1.tag },
            health: e.healthNaechte.values.filter { imFenster($0.tag) }.sorted { $0.tag < $1.tag }.map { kurz($0) },
            healthProben: Array(proben),
            hand: e.hand.values.filter { imFenster($0.tag) }.sorted { $0.tag < $1.tag }.map { kurz($0) },
            schritte: schritte, bandLog: log, bandUhrLog: log.filter { $0.contains(" zeit: ") })
    }

    /// Die Nacht in Kurzform: Minuten je Phase aus den Abschnitten.
    static func kurz(_ nacht: SchlafNacht, quelle: String? = nil, weitere: [String]? = nil) -> SchlafBelegNacht {
        var minuten: [String: Int] = [:]
        for a in nacht.abschnitte { minuten[a.phase.name, default: 0] += Int((a.bis.timeIntervalSince(a.von) / 60).rounded()) }
        return SchlafBelegNacht(tag: nacht.tag, von: nacht.von, bis: nacht.bis, schlafMinuten: nacht.schlafMinuten, phasenMinuten: minuten,
                                quelle: quelle, weitere: weitere?.isEmpty == false ? weitere : nil)
    }

    /// JSON für den Server: Zeiten als ISO 8601, Schlüssel sortiert (gleiche Eingabe, gleiche Bytes).
    static func kodieren(_ beleg: SchlafBeleg) -> Data? {
        let kodierer = JSONEncoder()
        kodierer.dateEncodingStrategy = .iso8601
        kodierer.outputFormatting = [.sortedKeys]
        return try? kodierer.encode(beleg)
    }
}
