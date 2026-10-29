import Foundation
import Observation
import Security

/// Adresse und App-Schlüssel des Lumen-Servers aus dem Block `konto` der `PrivateDaten.json` (gitignored, Secret `PRIVATE_DATEN_JSON`):
/// `{"konto": {"server": "https://…", "appKey": "…"}}`. Ohne Block (Tests, CI, Vorschau) gibt es kein Netz und die Standardwerte gelten.
struct KontoZugang: Sendable, CustomStringConvertible {
    var server: URL
    var appKey: String

    /// Nie Server oder Schlüssel in Logs oder Fehlertexte.
    var description: String { "KontoZugang" }

    static func lade(bundle: Bundle = .main) -> KontoZugang? {
        guard let url = bundle.url(forResource: "PrivateDaten", withExtension: "json"), let daten = try? Data(contentsOf: url) else { return nil }
        return lies(daten)
    }

    static func lies(_ daten: Data) -> KontoZugang? {
        struct Datei: Decodable {
            struct Block: Decodable { var server: String; var appKey: String }
            var konto: Block?
        }
        guard let block = (try? JSONDecoder().decode(Datei.self, from: daten))?.konto, !block.appKey.isEmpty,
              let server = URL(string: block.server), server.scheme == "https", server.host != nil else { return nil }
        return KontoZugang(server: server, appKey: block.appKey)
    }
}

/// Kennung dieses Geräts beim Server: zufällig, einmal erzeugt, liegt mit dem Profil im Schlüsselbund und ändert sich nie
/// (es gibt keine Anmeldung). `registriert`: der Server kennt sie.
struct KontoKennung: Codable, Equatable, Sendable {
    var id: String
    var geheimnis: String
    var registriert = false

    /// ID 32 und Geheimnis 43 Zeichen aus `A-Za-z0-9_-` (Form des Servers: 16 bis 64 und 32 bis 128). nil, wenn der Zufall nicht lieferte.
    static func neu() -> KontoKennung? {
        guard let id = zufall(24), let geheimnis = zufall(32) else { return nil }
        return KontoKennung(id: id, geheimnis: geheimnis)
    }

    private static func zufall(_ bytes: Int) -> String? {
        var puffer = [UInt8](repeating: 0, count: bytes)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes, &puffer) == errSecSuccess else { return nil }
        return Data(puffer).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Was der Server zuletzt gesagt hat, für den Start ohne Netz. Liegt als Datei neben den Profilen (kein Geheimnis darin).
struct KontoStand: Codable, Equatable, Sendable {
    var config = ServerConfig.standard
    var loveaErlaubt = false

    enum CodingKeys: String, CodingKey { case config, loveaErlaubt }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        config = (try? c.decodeIfPresent(ServerConfig.self, forKey: .config)) ?? .standard
        loveaErlaubt = (try? c.decodeIfPresent(Bool.self, forKey: .loveaErlaubt)) ?? false
    }
}

/// Das Konto beim Lumen-Server (SPEC 18): erzeugt Kennung und Geheimnis, meldet das Gerät einmal an, holt die Einstellungen und die Lovea-Freigabe.
/// Kein Login und keine Daten des Profils: nur Kennung, Profilname und App-Version gehen hinaus. Ohne Netz läuft alles mit dem letzten Stand
/// oder den Standardwerten. Gefragt wird beim Start und beim Zurückkommen in den Vordergrund, nie im Takt (kein Timer).
@MainActor @Observable
final class KontoDienst {
    nonisolated static let schluessel = "konto.server"
    nonisolated static let datei = "konto-stand.json"
    /// So selten wird ohne Anlass gefragt.
    nonisolated static let pause: TimeInterval = 300

    private(set) var stand: KontoStand
    /// Der Server hat in dieser Sitzung eine Freigabe-Antwort gegeben (nicht nur der gemerkte Stand).
    private(set) var freigabeAktuell = false

    var config: ServerConfig { stand.config }
    /// Lovea verbinden und der Import sind nur sichtbar, wenn der Server das Konto freigibt (nur Debug-Demo darf es erzwingen).
    var loveaErlaubt: Bool { LoveaFreigabe.erlaubt(freigegeben: stand.loveaErlaubt, demo: LoveaFreigabe.demoAktiv) }

    @ObservationIgnored private let zugang: KontoZugang?
    @ObservationIgnored private let schluesselbund: any Schluesselbund
    @ObservationIgnored private let http: any HTTPLader
    @ObservationIgnored private let uhr: Uhr
    @ObservationIgnored private let ablage: URL
    @ObservationIgnored private let version: String
    @ObservationIgnored private var laeuft = false
    @ObservationIgnored private var letzterVersuch: Date?
    /// Der Server hat die Anmeldung als ungültig abgelehnt (400): in dieser Sitzung nicht nochmal.
    @ObservationIgnored private var aufgegeben = false

    init(zugang: KontoZugang?, schluesselbund: any Schluesselbund, http: any HTTPLader, ordner: URL, uhr: @escaping Uhr = { Date() },
         version: String = KontoDienst.appVersion) {
        self.zugang = zugang
        self.schluesselbund = schluesselbund
        self.http = http
        self.uhr = uhr
        self.version = version
        let datei = ordner.appendingPathComponent(Self.datei)
        self.ablage = datei
        let gelesen = (try? Data(contentsOf: datei)).flatMap { try? JSONDecoder().decode(KontoStand.self, from: $0) }
        self.stand = gelesen ?? KontoStand()
    }

    nonisolated static var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }

    // MARK: - Kennung

    private enum KennungStand { case da(KontoKennung), fehlt, nichtLesbar }

    private func liesKennung() -> KennungStand {
        let roh: Data?
        do { roh = try schluesselbund.lese(Self.schluessel) } catch { return .nichtLesbar }
        guard let roh else { return .fehlt }
        // Ein Eintrag, der da ist, aber nicht deutbar: nie überschreiben (die Kennung hängt am Konto beim Server).
        guard let kennung = try? JSONDecoder().decode(KontoKennung.self, from: roh) else { return .nichtLesbar }
        return .da(kennung)
    }

    private func speichere(_ kennung: KontoKennung) -> Bool {
        guard let daten = try? JSONEncoder().encode(kennung) else { return false }
        return (try? schluesselbund.schreibe(daten, fuer: Self.schluessel)) != nil
    }

    /// Die gespeicherte Kennung; beim allerersten Mal wird sie erzeugt. nil, wenn der Schlüsselbund nicht lesbar ist oder nicht schreibt.
    private func kennung() -> KontoKennung? {
        switch liesKennung() {
        case .da(let k): return k
        case .nichtLesbar: return nil
        case .fehlt:
            guard let neu = KontoKennung.neu(), speichere(neu) else { return nil }
            return neu
        }
    }

    // MARK: - Abfragen

    /// Kopfzeilen für Wege des Servers, die ein Konto verlangen (auch der Lovea-Proxy beim Import).
    func kopfzeilen(_ kennung: KontoKennung, zugang: KontoZugang) -> [String: String] {
        ["X-App-Key": zugang.appKey, "X-Konto": kennung.id, "X-Geheimnis": kennung.geheimnis, "X-App-Version": version]
    }

    private func anfrage(_ pfad: String, post: Data? = nil, kennung: KontoKennung?) -> URLRequest? {
        guard let zugang, var teile = URLComponents(url: zugang.server, resolvingAgainstBaseURL: false) else { return nil }
        let basis = teile.path.hasSuffix("/") ? String(teile.path.dropLast()) : teile.path
        teile.path = basis + pfad
        guard let url = teile.url else { return nil }
        var a = URLRequest(url: url)
        a.timeoutInterval = 15
        a.httpMethod = post == nil ? "GET" : "POST"
        if let post { a.httpBody = post; a.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        var kopf = ["X-App-Key": zugang.appKey, "X-App-Version": version]
        if let kennung { kopf = kopfzeilen(kennung, zugang: zugang) }
        for (name, wert) in kopf { a.setValue(wert, forHTTPHeaderField: name) }
        return a
    }

    /// Status und Antwort; nil bei einem Netzfehler.
    private func sende(_ anfrage: URLRequest?) async -> (status: Int, daten: Data)? {
        guard let anfrage, let antwort = try? await http.lade(anfrage) else { return nil }
        return (antwort.1.statusCode, antwort.0)
    }

    /// Holt Kennung, meldet das Gerät an (einmal, bei Netzfehler später nochmal), dann Einstellungen und Freigabe.
    /// `profilName`: Name des aktiven Profils; ohne Profil wird nichts angemeldet (der Server verlangt einen Namen).
    func aktualisiere(profilName: String?, erzwingen: Bool = false) async {
        guard zugang != nil, !laeuft, !aufgegeben else { return }
        let jetzt = uhr()
        if !erzwingen, let letzter = letzterVersuch, jetzt.timeIntervalSince(letzter) >= 0, jetzt.timeIntervalSince(letzter) < Self.pause { return }
        laeuft = true
        defer { laeuft = false }
        letzterVersuch = jetzt
        guard var kennung = kennung() else { return }

        var erstesConfig: (status: Int, daten: Data)?
        if !kennung.registriert {
            guard let name = profilName.flatMap({ Self.serverName($0) }) else { return }
            let koerper = try? JSONSerialization.data(withJSONObject: ["id": kennung.id, "geheimnis": kennung.geheimnis, "name": name, "version": version])
            let status = await sende(anfrage("/konto", post: koerper, kennung: nil))?.status
            switch status {
            case 201?:
                kennung.registriert = true
            case 409?:
                // Gleiche ID: entweder war die Anmeldung schon durch (Antwort ging verloren) oder ein anderes Gerät hat sie. Unsere Header entscheiden.
                erstesConfig = await sende(anfrage("/config", kennung: kennung))
                if erstesConfig?.status == 200 {
                    kennung.registriert = true
                } else if erstesConfig?.status == 401 {
                    if let neu = KontoKennung.neu() { _ = speichere(neu) }   // echte Kollision: neue Kennung, beim nächsten Mal anmelden
                    return
                } else {
                    return
                }
            case 400?:
                aufgegeben = true
                return
            default:
                return   // Netzfehler, 429, 5xx: beim nächsten Start oder Vordergrund nochmal
            }
            guard speichere(kennung) else { return }
        }

        var configAntwort = erstesConfig
        if configAntwort == nil { configAntwort = await sende(anfrage("/config", kennung: kennung)) }
        if let c = configAntwort, c.status == 200 {
            if let neu = ServerConfig.zusammen(stand.config, antwort: c.daten) { stand.config = neu; sichere() }
        }
        if let f = await sende(anfrage("/lovea/freigabe", kennung: kennung)), f.status == 200 {
            struct Antwort: Decodable { var erlaubt: Bool? }
            if let a = try? JSONDecoder().decode(Antwort.self, from: f.daten) {
                stand.loveaErlaubt = a.erlaubt == true   // nur ein klares true gibt frei
                freigabeAktuell = true
                sichere()
            }
        }
    }

    /// Der Server verlangt 1 bis 40 Zeichen.
    nonisolated static func serverName(_ roh: String) -> String? {
        let name = String(roh.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        return name.isEmpty ? nil : name
    }

    private func sichere() {
        guard let daten = try? JSONEncoder().encode(stand) else { return }
        try? FileManager.default.createDirectory(at: ablage.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: ablage, options: .atomic)
    }

    // MARK: - Lovea-Import

    /// Zugang für den Import über den Proxy des Servers (`<Server>/lovea`); nil, solange Lovea nicht freigegeben ist oder das Gerät nicht angemeldet ist.
    func loveaZugang() -> ProfilLoveaZugang? {
        guard loveaErlaubt else { return nil }
        #if DEBUG
        if LoveaFreigabe.demoAktiv { return ProfilLoveaZugang(server: URL(string: "https://lovea.example.invalid/lovea")!, kopfzeilen: [:]) }
        #endif
        guard let zugang, case .da(let k) = liesKennung(), k.registriert else { return nil }
        return ProfilLoveaZugang(server: zugang.server.appendingPathComponent("lovea"), kopfzeilen: kopfzeilen(k, zugang: zugang))
    }
}
