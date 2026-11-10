import Foundation

/// Übernahme aus Lovea, mittlere Stufe (Vertrag mit Lumen Alarm, Abschnitt 1): Lovea legt Wecker, eigene Töne und Erinnerungen in
/// `<Lovea-Gruppe>/AlarmUebergabe/`, Lumen Fit reicht sie unverändert nach `<Lumen-Fit-Gruppe>/LumenAlarm/uebernahme/` weiter, Lumen Alarm übernimmt sie von dort.
/// Lumen Fit liest und deutet nichts davon: es kopiert Dateien (FileManager, Töne werden nie in den Speicher geladen) und schreibt `fit.json` mit Zahlen.
/// Gilt nur für ein Konto mit Lovea-Person (Freigabe vom Server) und nur, wenn die Person im Manifest dieselbe ist. Ohne Freigabe wird nichts kopiert und eine vorhandene Kopie entfernt.
struct AlarmUebernahme: Sendable {
    nonisolated static let quellOrdnerName = "AlarmUebergabe"
    nonisolated static let zielOrdnerName = "uebernahme"
    nonisolated static let uebergabeDatei = "uebergabe.json"
    nonisolated static let zaehlungDatei = "zaehlung.json"
    nonisolated static let fitDatei = "fit.json"
    nonisolated static let ergebnisDatei = "uebernahme-ergebnis.json"
    nonisolated static let tonOrdner = "toene"

    /// `zaehlung.json`: nur Zahlen und der Hash, keine Inhalte. Lovea schreibt sie zuletzt (Fertig-Marke).
    struct Zaehlung: Codable, Equatable, Sendable {
        var version: Int
        var person: String
        var wecker: Int
        var toene: Int
        var erinnerungen: Int
        var hash: String

        enum CodingKeys: String, CodingKey { case version, person, wecker, toene, erinnerungen, hash }

        init(version: Int, person: String, wecker: Int, toene: Int, erinnerungen: Int, hash: String) {
            self.version = version
            self.person = person
            self.wecker = wecker
            self.toene = toene
            self.erinnerungen = erinnerungen
            self.hash = hash
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decode(Int.self, forKey: .version)
            person = try c.decode(String.self, forKey: .person)
            hash = try c.decode(String.self, forKey: .hash)
            wecker = (try? c.decodeIfPresent(Int.self, forKey: .wecker)) ?? 0
            toene = (try? c.decodeIfPresent(Int.self, forKey: .toene)) ?? 0
            erinnerungen = (try? c.decodeIfPresent(Int.self, forKey: .erinnerungen)) ?? 0
        }
    }

    /// `fit.json`: was Lumen Fit weitergereicht hat (dieselben Zahlen wie in der Zählung).
    struct FitDatei: Codable, Equatable, Sendable {
        var version: Int
        var weitergereicht: Date
        var person: String
        var wecker: Int
        var toene: Int
        var erinnerungen: Int
    }

    /// `uebernahme-ergebnis.json` von Lumen Alarm: was übernommen wurde (nur Zahlen). Fehlende Felder zählen 0.
    struct Ergebnis: Equatable, Sendable {
        var uebernommen: Zahlen
        var schonDa: Zahlen
        var uebersprungen: Zahlen
    }

    struct Zahlen: Equatable, Sendable {
        var wecker = 0
        var toene = 0
        var erinnerungen = 0
    }

    enum Stand: Equatable, Sendable {
        /// Kein Konto mit Lovea-Person, oder die Person im Manifest passt nicht: nichts kopiert, die alte Kopie ist weg.
        case keineFreigabe
        /// Lovea hat (noch) nichts Fertiges abgelegt.
        case keineQuelle
        /// Mitten im Schreiben bei Lovea oder die Quelle änderte sich beim Kopieren: beim nächsten Mal noch einmal.
        case unvollstaendig
        case unveraendert
        case weitergereicht(FitDatei)
        case fehler
    }

    /// `<Lovea-Gruppe>/AlarmUebergabe/` (nil ohne Signierung).
    let quelle: URL?
    /// `<Lumen-Fit-Gruppe>/LumenAlarm/` (nil ohne Signierung); darin liegt `uebernahme/`.
    let alarmOrdner: URL?

    init(loveaGruppe: URL?, alarmOrdner: URL?) {
        quelle = loveaGruppe?.appendingPathComponent(Self.quellOrdnerName, isDirectory: true)
        self.alarmOrdner = alarmOrdner
    }

    private var ziel: URL? { alarmOrdner?.appendingPathComponent(Self.zielOrdnerName, isDirectory: true) }

    // MARK: - Weitergeben

    /// Reicht weiter, wenn es etwas Neues gibt. `person`: die Lovea-Person des Kontos laut Server (nil: keine Freigabe).
    @discardableResult
    func weitergeben(person: String?, jetzt: Date = Date()) -> Stand {
        guard let quelle, let ziel else { return .keineQuelle }
        guard let erlaubt = Self.sauber(person) else { entferne(); return .keineFreigabe }
        guard let zaehlung = Self.lies(Zaehlung.self, quelle.appendingPathComponent(Self.zaehlungDatei)), zaehlung.version == LoveaVertrag.version else { return .keineQuelle }
        guard Self.sauber(zaehlung.person) == erlaubt else { entferne(); return .keineFreigabe }
        // Die Person steht auch im Manifest selbst; weicht sie von der Zählung ab, schreibt Lovea gerade.
        guard let kopf = Self.lies(Kopf.self, quelle.appendingPathComponent(Self.uebergabeDatei)), Self.sauber(kopf.person) == erlaubt else { return .unvollstaendig }

        let toeneQuelle = Self.dateien(quelle.appendingPathComponent(Self.tonOrdner))
        let zielZaehlung = Self.lies(Zaehlung.self, ziel.appendingPathComponent(Self.zaehlungDatei))
        let fit = Self.lies(FitDatei.self, ziel.appendingPathComponent(Self.fitDatei))
        if zielZaehlung?.hash == zaehlung.hash, fit != nil,
           Self.dateien(ziel.appendingPathComponent(Self.tonOrdner)) == toeneQuelle,
           FileManager.default.fileExists(atPath: ziel.appendingPathComponent(Self.uebergabeDatei).path) {
            return .unveraendert
        }

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: ziel.appendingPathComponent(Self.tonOrdner, isDirectory: true), withIntermediateDirectories: true)
            // Ab hier gilt die Kopie als unfertig: ohne Zählung übernimmt Lumen Alarm nichts.
            try? fm.removeItem(at: ziel.appendingPathComponent(Self.zaehlungDatei))
            try? fm.removeItem(at: ziel.appendingPathComponent(Self.fitDatei))
            try Self.tonKopie(von: quelle.appendingPathComponent(Self.tonOrdner), nach: ziel.appendingPathComponent(Self.tonOrdner), quelleListe: toeneQuelle)
            try Self.ersetze(quelle.appendingPathComponent(Self.uebergabeDatei), ziel.appendingPathComponent(Self.uebergabeDatei))
            // Hat Lovea inzwischen neu geschrieben, ist die Kopie gemischt: nicht fertig melden.
            guard Self.lies(Zaehlung.self, quelle.appendingPathComponent(Self.zaehlungDatei))?.hash == zaehlung.hash else { return .unvollstaendig }
            try Self.ersetze(quelle.appendingPathComponent(Self.zaehlungDatei), ziel.appendingPathComponent(Self.zaehlungDatei))
            let neu = FitDatei(version: LoveaVertrag.version, weitergereicht: jetzt, person: zaehlung.person, wecker: zaehlung.wecker,
                               toene: zaehlung.toene, erinnerungen: zaehlung.erinnerungen)
            try LoveaVertrag.encoder().encode(neu).write(to: ziel.appendingPathComponent(Self.fitDatei), options: .atomic)
            return .weitergereicht(neu)
        } catch {
            return .fehler
        }
    }

    /// Entfernt die Kopie samt `fit.json` (keine Freigabe mehr, letztes Profil gelöscht). `uebernahme-ergebnis.json` gehört Lumen Alarm und bleibt.
    func entferne() {
        guard let ziel else { return }
        try? FileManager.default.removeItem(at: ziel)
    }

    // MARK: - Anzeige

    /// Was Lumen Fit zuletzt weitergereicht hat; nil, solange nichts da ist.
    func weitergereicht() -> FitDatei? {
        guard let ziel else { return nil }
        return Self.lies(FitDatei.self, ziel.appendingPathComponent(Self.fitDatei))
    }

    /// Das Ergebnis von Lumen Alarm; nil, solange Lumen Alarm nichts gemeldet hat.
    func ergebnis() -> Ergebnis? {
        guard let alarmOrdner, let daten = try? Data(contentsOf: alarmOrdner.appendingPathComponent(Self.ergebnisDatei)) else { return nil }
        return Self.ergebnis(daten)
    }

    /// Tolerant gelesen: Zahlen fehlen = 0, nur eine kaputte Datei ist nil.
    static func ergebnis(_ daten: Data) -> Ergebnis? {
        guard let wurzel = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any] else { return nil }
        func zahlen(_ schluessel: String) -> Zahlen {
            let d = wurzel[schluessel] as? [String: Any] ?? [:]
            func n(_ k: String) -> Int { (d[k] as? NSNumber)?.intValue ?? 0 }
            return Zahlen(wecker: n("wecker"), toene: n("toene"), erinnerungen: n("erinnerungen"))
        }
        return Ergebnis(uebernommen: zahlen("uebernommen"), schonDa: zahlen("schonDa"), uebersprungen: zahlen("uebersprungen"))
    }

    /// Die kleine Zeile für Profil > Geräte, nur Zahlen. nil, wenn nichts weitergereicht wurde.
    func zeile() -> String? {
        guard let fit = weitergereicht() else { return nil }
        var text = String(localized: "Aus Lovea weitergereicht: \(Self.zahlenText(Zahlen(wecker: fit.wecker, toene: fit.toene, erinnerungen: fit.erinnerungen))).")
        if let e = ergebnis() { text += String(localized: " Von Lumen Alarm übernommen: \(Self.zahlenText(e.uebernommen)).") }
        return text
    }

    nonisolated static func zahlenText(_ z: Zahlen) -> String {
        let toene = z.toene == 1 ? String(localized: "Ton") : String(localized: "Töne")
        let erinnerungen = z.erinnerungen == 1 ? String(localized: "Erinnerung") : String(localized: "Erinnerungen")
        return String(localized: "\(z.wecker) Wecker, \(z.toene) \(toene), \(z.erinnerungen) \(erinnerungen)")
    }

    // MARK: - Dateien

    private struct Kopf: Decodable { var person: String }

    /// Person als Vergleichswert: ohne Rand-Leerzeichen, klein; leer ist keine Person.
    nonisolated static func sauber(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !t.isEmpty else { return nil }
        return t
    }

    private static func lies<T: Decodable>(_ typ: T.Type, _ url: URL) -> T? {
        guard let daten = try? Data(contentsOf: url) else { return nil }
        return try? LoveaVertrag.decoder().decode(typ, from: daten)
    }

    /// Dateiname und Größe aller Dateien eines Ordners (Töne werden nie gelesen, nur gemessen).
    private static func dateien(_ ordner: URL) -> [String: Int] {
        let namen = (try? FileManager.default.contentsOfDirectory(atPath: ordner.path)) ?? []
        var liste: [String: Int] = [:]
        for name in namen where !name.hasPrefix(".") {
            let groesse = (try? FileManager.default.attributesOfItem(atPath: ordner.appendingPathComponent(name).path)[.size] as? NSNumber)?.intValue
            liste[name] = groesse ?? -1
        }
        return liste
    }

    /// Kopiert nur neue oder geänderte Töne und entfernt, was bei Lovea nicht mehr da ist.
    private static func tonKopie(von: URL, nach: URL, quelleListe: [String: Int]) throws {
        let fm = FileManager.default
        let zielListe = dateien(nach)
        for name in zielListe.keys where quelleListe[name] == nil { try? fm.removeItem(at: nach.appendingPathComponent(name)) }
        for (name, groesse) in quelleListe where zielListe[name] != groesse {
            try ersetze(von.appendingPathComponent(name), nach.appendingPathComponent(name))
        }
    }

    /// Kopie über einen Zwischennamen im Zielordner, dann ersetzen: Lumen Alarm sieht nie eine halbe Datei.
    private static func ersetze(_ von: URL, _ nach: URL) throws {
        let fm = FileManager.default
        let zwischen = nach.deletingLastPathComponent().appendingPathComponent(".kopie-\(UUID().uuidString)")
        try fm.copyItem(at: von, to: zwischen)
        if fm.fileExists(atPath: nach.path) {
            _ = try fm.replaceItemAt(nach, withItemAt: zwischen)
        } else {
            try fm.moveItem(at: zwischen, to: nach)
        }
    }
}
