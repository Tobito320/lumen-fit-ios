import Foundation

/// Die Datensicherung: eine JSON-Datei `lumenfit-sicherung-<datum>.json` mit allem, was ein Profil ausmacht (SPEC 5.4, Idee 74).
/// Sie enthält nie das Passwort und keine Passwort-Spur (kein Salz, kein Hash): Name und Passwort liegen im Schlüsselbund, nicht hier.
struct ProfilSicherung: Codable, Sendable {
    static let aktuelleVersion = 1

    var version: Int
    var erstellt: Date
    var ops: [Op]
    var einstellungen: Einstellungen
    var ziele: Ziele
    var koerper: Koerperdaten?
    var essenZiele: ErnaehrungsZiele?
    var freigaben: [FreigabeArt]

    init(version: Int = ProfilSicherung.aktuelleVersion, erstellt: Date, ops: [Op], einstellungen: Einstellungen, ziele: Ziele,
         koerper: Koerperdaten? = nil, essenZiele: ErnaehrungsZiele? = nil, freigaben: [FreigabeArt] = []) {
        self.version = version; self.erstellt = erstellt; self.ops = ops; self.einstellungen = einstellungen
        self.ziele = ziele; self.koerper = koerper; self.essenZiele = essenZiele; self.freigaben = freigaben
    }

    private enum CodingKeys: String, CodingKey { case version, erstellt, ops, einstellungen, ziele, koerper, essenZiele, freigaben }

    /// Felder, die spätere Fassungen dazubekommen, sind optional: eine ältere Datei bleibt lesbar.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        erstellt = try c.decode(Date.self, forKey: .erstellt)
        ops = try c.decodeIfPresent([Op].self, forKey: .ops) ?? []
        einstellungen = try c.decodeIfPresent(Einstellungen.self, forKey: .einstellungen) ?? Einstellungen()
        ziele = try c.decodeIfPresent(Ziele.self, forKey: .ziele) ?? Ziele()
        koerper = try c.decodeIfPresent(Koerperdaten.self, forKey: .koerper)
        essenZiele = try c.decodeIfPresent(ErnaehrungsZiele.self, forKey: .essenZiele)
        freigaben = try c.decodeIfPresent([FreigabeArt].self, forKey: .freigaben) ?? []
    }

    // MARK: - Datei

    /// `lumenfit-sicherung-2026-10-29.json`
    static func dateiname(jetzt: Date) -> String { "lumenfit-sicherung-\(Datum.text(jetzt)).json" }

    func daten() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Liest und prüft eine Sicherung. Die Version steht zuerst: eine neuere Datei wird nie halb gelesen.
    static func lies(_ daten: Data) throws -> ProfilSicherung {
        struct Kopf: Decodable { var version: Int }
        guard let kopf = try? JSONDecoder().decode(Kopf.self, from: daten), kopf.version >= 1 else { throw ProfilSicherungFehler.keineSicherung }
        guard kopf.version <= aktuelleVersion else { throw ProfilSicherungFehler.zuNeu(kopf.version) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let sicherung = try? decoder.decode(ProfilSicherung.self, from: daten) else { throw ProfilSicherungFehler.keineSicherung }
        return sicherung
    }
}

enum ProfilSicherungFehler: Error, Equatable, Sendable {
    /// Die Datei ist keine Sicherung von Lumen Fit (oder kaputt).
    case keineSicherung
    /// Die Sicherung stammt aus einer neueren Fassung der App.
    case zuNeu(Int)

    var text: String {
        switch self {
        case .keineSicherung: "Das ist keine Sicherung von Lumen Fit oder die Datei ist kaputt."
        case .zuNeu: "Diese Sicherung ist von einer neueren Fassung von Lumen Fit. Bitte aktualisiere die App zuerst."
        }
    }
}

struct ProfilSicherungErgebnis: Equatable, Sendable {
    /// Eingespielte Einträge.
    var neu: Int
    /// Schon vorhanden (gleiche Kennung) oder durch Neueres im Profil ersetzt.
    var uebersprungen: Int
}

/// Wann zuletzt gesichert wurde (`sicherung-stand.json` im Profilordner). Nur Text in der App, keine Erinnerung (Lumen Fit ist nur Health).
struct ProfilSicherungStand: Codable, Equatable, Sendable {
    var zuletzt: Date?

    static func datei(_ ordner: URL) -> JSONDatei<ProfilSicherungStand> {
        JSONDatei<ProfilSicherungStand>(ordner.appendingPathComponent("sicherung-stand.json"))
    }

    static func lade(_ ordner: URL) -> Date? { datei(ordner).lade()?.zuletzt }

    static func merke(_ ordner: URL, jetzt: Date) { datei(ordner).speichere(ProfilSicherungStand(zuletzt: jetzt)) }

    /// "Letzte Sicherung: vor 12 Tagen"
    static func zeile(zuletzt: Date?, jetzt: Date) -> String {
        guard let zuletzt else { return "Noch keine Sicherung" }
        let tage = Datum.tageZwischen(Datum.text(zuletzt), Datum.text(jetzt))
        switch tage {
        case ..<1: return "Letzte Sicherung: heute"
        case 1: return "Letzte Sicherung: gestern"
        default: return "Letzte Sicherung: vor \(tage) Tagen"
        }
    }
}

/// Erzeugen und Einspielen. Einspielen ändert nur das aktive Profil (`von` aller Einträge wird auf dessen Kennung umgeschrieben).
@MainActor
enum ProfilSicherungLogik {
    /// Arten, bei denen die zuletzt eingetroffene Op gewinnt (Op ohne seq, Annahme 30): eine ältere Sicherung darf eine neuere Wahl nicht überschreiben.
    static let letzteGewinnt: Set<String> = ["gym.plan", "einstellung.setzen"]

    /// Alle Ops des Profils aus dem Log (Dateireihenfolge).
    static func alleOps(_ daten: DatenSatz) -> [Op] {
        var log = LokalerOpLog(datei: daten.ordner.appendingPathComponent("ops.jsonl"))
        return log.lade()
    }

    static func erzeuge(aus daten: DatenSatz, jetzt: Date) -> ProfilSicherung {
        let essenZiele = daten.essen.ernaehrungsZiele
        return ProfilSicherung(
            erstellt: jetzt, ops: alleOps(daten), einstellungen: daten.einstellungen.werte, ziele: daten.ziele.ziele,
            koerper: daten.ziele.koerper, essenZiele: essenZiele.eingerichtet ? essenZiele : nil,
            freigaben: FreigabeArt.allCases.filter { daten.verbindung.freigaben.contains($0) })
    }

    /// Schreibt die Sicherung in den Temp-Ordner (zum Teilen) und merkt sich den Zeitpunkt.
    static func schreibeDatei(aus daten: DatenSatz, jetzt: Date) throws -> URL {
        let sicherung = erzeuge(aus: daten, jetzt: jetzt)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(ProfilSicherung.dateiname(jetzt: jetzt))
        try sicherung.daten().write(to: url, options: .atomic)
        ProfilSicherungStand.merke(daten.ordner, jetzt: jetzt)
        return url
    }

    /// Löscht Sicherungs- und Tabellen-Dateien aus dem Temp-Ordner (sie enthalten Daten im Klartext): nach "Alles löschen" und "Zurücksetzen".
    static func raeumeTempAuf(ordner: URL = FileManager.default.temporaryDirectory) {
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: ordner.path)) ?? [] where name.hasPrefix("lumenfit-") && (name.hasSuffix(".json") || name.hasSuffix(".csv")) {
            try? fm.removeItem(at: ordner.appendingPathComponent(name))
        }
    }

    /// Ist im Profil schon etwas gespeichert? Dann bleibt Neueres Sieger (siehe `letzteGewinnt`).
    static func hatDaten(_ daten: DatenSatz) -> Bool { !alleOps(daten).isEmpty }

    /// Spielt die Sicherung ins Profil ein. Doppelte Kennungen (auch in der Datei selbst) werden übersprungen, so ist das Einspielen idempotent.
    /// Die Einträge laufen in Zeitreihenfolge in den Raum, die Stores laden live nach. Gerätegebundene Schalter (Band, Lovea, Health schreiben)
    /// bleiben aus: auf einem neuen Gerät fragen sie sonst beim Start nach Rechten.
    @discardableResult
    static func spieleEin(_ sicherung: ProfilSicherung, in daten: DatenSatz) -> ProfilSicherungErgebnis {
        let vorher = alleOps(daten)
        let leer = vorher.isEmpty
        var bekannt = Set(vorher.map(\.id))
        var neuste: [String: Date] = [:]
        for op in vorher where letzteGewinnt.contains(op.art) { neuste[op.art] = max(neuste[op.art] ?? .distantPast, op.zeit) }

        var ergebnis = ProfilSicherungErgebnis(neu: 0, uebersprungen: 0)
        let geordnet = sicherung.ops.enumerated().sorted { ($0.element.zeit, $0.offset) < ($1.element.zeit, $1.offset) }.map(\.element)
        for op in geordnet {
            guard bekannt.insert(op.id).inserted else { ergebnis.uebersprungen += 1; continue }
            if !leer, letzteGewinnt.contains(op.art), let juengste = neuste[op.art], op.zeit < juengste {
                ergebnis.uebersprungen += 1
                continue
            }
            daten.raum.einreihen(Op(id: op.id, art: op.art, von: daten.profil, zeit: op.zeit, d: op.d))
            ergebnis.neu += 1
        }

        // Kleine Dateien: nur setzen, wo das Profil noch beim Standard ist (Neuinstallation), nie Eigenes überschreiben.
        if daten.einstellungen.werte == Einstellungen() {
            var geraetefrei = sicherung.einstellungen
            geraetefrei.bandAktiv = false; geraetefrei.loveaVerbunden = false; geraetefrei.alarmWeckt = Einstellungen().alarmWeckt; geraetefrei.healthSchreiben = false; geraetefrei.healthGefragt = false
            daten.einstellungen.werte = geraetefrei
        }
        if daten.ziele.ziele == Ziele() { daten.ziele.setze(sicherung.ziele) }
        if daten.ziele.koerper == Koerperdaten(), let k = sicherung.koerper { daten.ziele.setzeKoerper(k) }
        if !daten.essen.ernaehrungsZiele.eingerichtet, let z = sicherung.essenZiele { daten.essen.zieleSichern(z) }
        if daten.verbindung.freigaben.isEmpty { daten.verbindung.freigaben = Set(sicherung.freigaben) }
        return ergebnis
    }
}
