// Quelle: Lovea Health/Essen/EssenClient.swift (KiClient.essen und Fehlerzuordnung; der Weg zum Server ist neu: Lumen-Server mit Konto-Kopfzeilen)
import Foundation
import Observation

/// Adresse und Kopfzeilen eines angemeldeten Geräts beim Lumen-Server.
struct EssenKiVerbindung: Sendable {
    var server: URL
    var kopfzeilen: [String: String]
}

/// Woher der Client die Verbindung bekommt. Ein Port, damit Tests nie den Schlüsselbund oder `PrivateDaten.json` brauchen.
protocol EssenKiZugang: Sendable {
    /// nil, solange es keinen Zugang gibt (kein Server in der Konfiguration, Gerät nicht angemeldet).
    func verbindung() -> EssenKiVerbindung?
}

/// Der echte Zugang: Server und App-Schlüssel aus der Konfiguration, Kennung und Geheimnis des Geräts aus dem Schlüsselbund (dieselben
/// wie beim `KontoDienst`). Ein Gerät, das der Server noch nicht kennt, hat keine Verbindung.
struct EssenKiKontoZugang: EssenKiZugang {
    let zugang: KontoZugang?
    let schluesselbund: any Schluesselbund
    let version: String

    func verbindung() -> EssenKiVerbindung? {
        guard let zugang, let roh = try? schluesselbund.lese(KontoDienst.schluessel),
              let kennung = try? JSONDecoder().decode(KontoKennung.self, from: roh), kennung.registriert else { return nil }
        return EssenKiVerbindung(server: zugang.server, kopfzeilen: [
            "X-App-Key": zugang.appKey, "X-Konto": kennung.id, "X-Geheimnis": kennung.geheimnis, "X-App-Version": version,
        ])
    }
}

/// Foto -> Schätzung. Ein Port, damit der Auftrags-Store ohne Netz getestet wird.
protocol EssenKiSender: Sendable {
    func analysieren(bild: Data, hinweis: String, mahlzeit: Mahlzeit) async throws -> EssenKiAnalyse
}

/// Spricht mit `POST /ki/foto` des Lumen-Servers. Der OpenAI-Schlüssel liegt nur dort, die App kennt ihn nie.
struct EssenKiClient: EssenKiSender {
    let zugang: any EssenKiZugang
    let lader: any HTTPLader

    private struct Anfrage: Encodable {
        let bild: String
        let mime: String
        let hinweis: String
        let mahlzeit: String
    }

    func analysieren(bild: Data, hinweis: String, mahlzeit: Mahlzeit) async throws -> EssenKiAnalyse {
        guard let verbindung = zugang.verbindung() else { throw EssenKiFehler.nichtEingerichtet }
        var anfrage = URLRequest(url: verbindung.server.appendingPathComponent("ki/foto"))
        anfrage.httpMethod = "POST"
        anfrage.timeoutInterval = 90
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, wert) in verbindung.kopfzeilen { anfrage.setValue(wert, forHTTPHeaderField: name) }
        do {
            anfrage.httpBody = try JSONEncoder().encode(Anfrage(bild: bild.base64EncodedString(), mime: "image/jpeg", hinweis: hinweis, mahlzeit: mahlzeit.rawValue))
        } catch {
            throw EssenKiFehler.ungueltig
        }
        let antwort: (Data, HTTPURLResponse)
        do {
            antwort = try await lader.lade(anfrage)
        } catch {
            throw EssenKiFehler.netz
        }
        guard antwort.1.statusCode == 200 else { throw Self.fehler(status: antwort.1.statusCode, daten: antwort.0) }
        do {
            return try JSONDecoder().decode(EssenKiAnalyse.self, from: antwort.0)
        } catch {
            throw EssenKiFehler.ungueltig
        }
    }

    /// Erst die Fehlerart des Servers (`{"fehler": "..."}`), sonst der Status. Alles Unbekannte ist `.unbekannt`.
    static func fehler(status: Int, daten: Data) -> EssenKiFehler {
        struct Huelle: Decodable { let fehler: String?; let max: Int? }
        let huelle = try? JSONDecoder().decode(Huelle.self, from: daten)
        switch huelle?.fehler {
        case "tageslimit"?: return .tageslimit(max: huelle?.max)
        case "zuVieleAnfragen"?: return .zuVieleAnfragen
        case "bildZuGross"?: return .bildZuGross
        case "guthaben"?: return .guthaben
        case "nichtEingerichtet"?, "nichtErlaubt"?: return .nichtEingerichtet
        case "ungueltig"?: return .ungueltig
        case "netz"?: return .netz
        default: break
        }
        switch status {
        case 401, 403, 503: return .nichtEingerichtet
        case 413: return .bildZuGross
        case 429: return .zuVieleAnfragen
        case 400: return .ungueltig
        default: return .unbekannt
        }
    }
}

/// Reine Logik: ob der Server eine KI-Funktion für dieses Konto freigibt (Schalter, Standard `kiFotoErlaubt`, in der Antwort von `GET /config`).
enum EssenKiFreigabeLogik {
    /// nil, wenn die Antwort kein Objekt `config` hat (dann bleibt der letzte Stand). Fehlt der Schlüssel oder ist er nicht `true`: aus.
    static func erlaubt(antwort: Data, schalter: String = "kiFotoErlaubt") -> Bool? {
        struct Huelle: Decodable { let config: [String: JSONValue]? }
        guard let werte = (try? JSONDecoder().decode(Huelle.self, from: antwort))?.config else { return nil }
        if case .bool(let an)? = werte[schalter] { return an }
        return false
    }
}

/// Weiß, ob der Foto-Knopf sichtbar sein darf. Fragt den Server (`GET /config`, ein kleiner Aufruf) beim Öffnen von Essen, höchstens alle 5 Minuten,
/// nie im Takt. Ohne Antwort, ohne Zugang oder bei abgeschaltetem Schalter bleibt der Knopf unsichtbar.
@MainActor @Observable
final class EssenKiFreigabe {
    nonisolated static let pause: TimeInterval = 300

    private(set) var erlaubt = false
    /// true, sobald der Server (oder das Fehlen eines Zugangs) die Frage nach der Freigabe sicher beantwortet hat; vorher ist `erlaubt` nur der Anfangswert.
    private(set) var geprueft = false

    @ObservationIgnored private let zugang: any EssenKiZugang
    @ObservationIgnored private let lader: any HTTPLader
    @ObservationIgnored private let uhr: Uhr
    @ObservationIgnored private let schalter: String
    @ObservationIgnored private var letzter: Date?
    @ObservationIgnored private var laeuft = false

    /// `schalter`: der Schlüssel in `GET /config` (Foto: `kiFotoErlaubt`).
    init(zugang: any EssenKiZugang, lader: any HTTPLader, uhr: @escaping Uhr = { Date() }, schalter: String = "kiFotoErlaubt") {
        self.zugang = zugang
        self.lader = lader
        self.uhr = uhr
        self.schalter = schalter
    }

    func pruefen(erzwingen: Bool = false) async {
        guard !laeuft else { return }
        guard let verbindung = zugang.verbindung() else {
            erlaubt = false
            geprueft = true
            return
        }
        let jetzt = uhr()
        if !erzwingen, let letzter, jetzt.timeIntervalSince(letzter) >= 0, jetzt.timeIntervalSince(letzter) < Self.pause { return }
        laeuft = true
        defer { laeuft = false }
        var anfrage = URLRequest(url: verbindung.server.appendingPathComponent("config"))
        anfrage.timeoutInterval = 15
        for (name, wert) in verbindung.kopfzeilen { anfrage.setValue(wert, forHTTPHeaderField: name) }
        // Erst eine Antwort des Servers setzt die Pause: ein Funkloch beim Start sperrt die Funktion nicht fünf Minuten lang.
        guard let antwort = try? await lader.lade(anfrage) else { return }
        letzter = jetzt
        switch antwort.1.statusCode {
        case 200: if let neu = EssenKiFreigabeLogik.erlaubt(antwort: antwort.0, schalter: schalter) { erlaubt = neu; geprueft = true }
        case 401, 403: erlaubt = false; geprueft = true
        default: break
        }
    }
}
