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
    /// Der einmalige Lovea-Import ist durch (lokal gemerkt; der Server merkt es je Konto, damit er nach einer Neuinstallation nicht nochmal läuft).
    var loveaImportErledigt = false
    /// Der Server weiß noch nicht, dass der Import durch ist (Netzfehler beim Melden): beim nächsten Abgleich nochmal melden.
    var importMeldungOffen = false
    /// Die Lovea-Person des Kontos laut Server (Text; nur gemerkt, solange `loveaErlaubt` gilt). Prüfung der Übernahme für Lumen Alarm: nur "nicht leer" und "gleich".
    var loveaPerson: String?
    /// Essen zurück zu Lovea (09.11.2026): der Server schaltet den Export (`essenExportAn`), gesendet sind die ersten `essenExportAnzahl` Essen-Ops des Logs
    /// (er hängt nur an), `essenExportZiele` ist der zuletzt gesendete Stand der Ziele, `essenExportErledigt` der erste volle Lauf (auch vom Server gemeldet).
    var essenExportAn = false
    var essenExportAnzahl = 0
    var essenExportZiele: String?
    var essenExportErledigt = false
    /// Das Profil, dem dieses Gerätekonto gehört (`ProfilID.rawValue`): das aktive beim ersten Abgleich. Konto, Lovea-Person, Export-Zähler und Crew sind je Gerät,
    /// die Daten je Profil; mit einem zweiten Profil würden sonst dessen Essen-Ops als die Lovea-Person des Kontos gesendet und die Crew bekäme seine Werte.
    var kontoProfil: String?

    enum CodingKeys: String, CodingKey { case config, loveaErlaubt, loveaImportErledigt, importMeldungOffen, loveaPerson, essenExportAn, essenExportAnzahl, essenExportZiele, essenExportErledigt, kontoProfil }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        config = (try? c.decodeIfPresent(ServerConfig.self, forKey: .config)) ?? .standard
        loveaErlaubt = (try? c.decodeIfPresent(Bool.self, forKey: .loveaErlaubt)) ?? false
        loveaImportErledigt = (try? c.decodeIfPresent(Bool.self, forKey: .loveaImportErledigt)) ?? false
        importMeldungOffen = (try? c.decodeIfPresent(Bool.self, forKey: .importMeldungOffen)) ?? false
        loveaPerson = (try? c.decodeIfPresent(String.self, forKey: .loveaPerson)) ?? nil
        essenExportAn = (try? c.decodeIfPresent(Bool.self, forKey: .essenExportAn)) ?? false
        essenExportAnzahl = max(0, (try? c.decodeIfPresent(Int.self, forKey: .essenExportAnzahl)) ?? 0)
        essenExportZiele = (try? c.decodeIfPresent(String.self, forKey: .essenExportZiele)) ?? nil
        essenExportErledigt = (try? c.decodeIfPresent(Bool.self, forKey: .essenExportErledigt)) ?? false
        kontoProfil = (try? c.decodeIfPresent(String.self, forKey: .kontoProfil)) ?? nil
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
    /// Schlaf, Armband und AirPods zeigen sich nur, wenn der Server es dem Konto sagt; der gemerkte Stand gilt bei Funkloch. Nur Debug-Demo darf es erzwingen.
    var schlafSichtbar: Bool { stand.config.schlafSichtbar || LoveaFreigabe.demoAktiv }
    /// Der Server hat den Schlaf-Beleg für dieses Konto freigegeben (Diagnose, Standard aus; der gemerkte Stand gilt bei Funkloch).
    var schlafBelegAn: Bool { stand.config.schlafBeleg }
    /// Die Lovea-Person des Kontos, nur mit echter Server-Freigabe (nie in der Demo); sonst nil.
    var loveaPerson: String? { stand.loveaErlaubt ? stand.loveaPerson : nil }
    /// Der Server gibt das Konto frei und der einmalige Import ist noch nicht gelaufen (nie in der Demo).
    var loveaImportOffen: Bool { stand.loveaErlaubt && !stand.loveaImportErledigt }
    /// Der Server hat den Essen-Export angeschaltet und das Konto ist für Lovea freigegeben (nie in der Demo).
    var essenExportAn: Bool { loveaErlaubt && stand.essenExportAn }
    var essenExportAnzahl: Int { stand.essenExportAnzahl }
    var essenExportZiele: String? { stand.essenExportZiele }
    var essenExportErledigt: Bool { stand.essenExportErledigt }
    /// Zähler für den Nutzungs-Bündel (Bereiche und Funktionen, keine Inhalte); wird beim Abgleich einmal je Start gesendet.
    let nutzung: NutzungSpeicher
    /// Die Verbindungen zu anderen Personen (QR-Einladung, Lovea-Partner) so, wie der Server sie zuletzt gemeldet hat.
    let verbindungen: VerbindungenSpeicher
    /// Der Stand der Verbindungen hat sich geändert (neu geholt, Einstellung, Entfernen): Partner-Stand, Lovea-Freigaben und Hochladen nachziehen.
    @ObservationIgnored var beiVerbindungenGeaendert: (@MainActor () -> Void)?

    @ObservationIgnored private let zugang: KontoZugang?
    @ObservationIgnored private let schluesselbund: any Schluesselbund
    @ObservationIgnored private let http: any HTTPLader
    @ObservationIgnored private let uhr: Uhr
    @ObservationIgnored private let ablage: URL
    @ObservationIgnored let ordner: URL
    /// Der Partner-Stand vom Server, so wie `ServerPartnerBruecke` ihn liest.
    nonisolated static let partnerDatei = "partner-server.json"
    /// So selten wird die Zusammenfassung für den Partner hochgeladen.
    nonisolated static let partnerPause: TimeInterval = 120
    /// Solange der gebaute Stand "im Gym" sagt, geht der nächste Satz schneller raus (Mitlauf der Crew).
    nonisolated static let partnerPauseImGym: TimeInterval = 20
    @ObservationIgnored private var partnerAusstehend: Data?
    @ObservationIgnored private var letzterPartnerUpload: Date?
    @ObservationIgnored private var nutzungGesendetInSitzung = false
    @ObservationIgnored private var letzterNutzungsUpload: Date?
    @ObservationIgnored private let version: String
    @ObservationIgnored private var laeuft = false
    @ObservationIgnored private var letzterVersuch: Date?
    /// Der Server hat die Anmeldung als ungültig abgelehnt (400): in dieser Sitzung nicht nochmal.
    @ObservationIgnored private var aufgegeben = false
    /// Der Profilname der letzten Anmeldung: damit ein Blatt (Code zeigen, scannen) das Konto nachholen kann, wenn der Start kein Netz hatte.
    @ObservationIgnored private var letzterProfilName: String?

    init(zugang: KontoZugang?, schluesselbund: any Schluesselbund, http: any HTTPLader, ordner: URL, uhr: @escaping Uhr = { Date() },
         version: String = KontoDienst.appVersion) {
        self.zugang = zugang
        self.schluesselbund = schluesselbund
        self.http = http
        self.uhr = uhr
        self.version = version
        let datei = ordner.appendingPathComponent(Self.datei)
        self.ablage = datei
        self.ordner = ordner
        self.nutzung = NutzungSpeicher(ordner: ordner, uhr: uhr)
        self.verbindungen = VerbindungenSpeicher(datei: ordner.appendingPathComponent(VerbindungenSpeicher.dateiName))
        let gelesen = (try? Data(contentsOf: datei)).flatMap { try? JSONDecoder().decode(KontoStand.self, from: $0) }
        self.stand = gelesen ?? KontoStand()
    }

    /// Merkt die Server-Einstellungen (auch für Tests, die ohne Netz eine Erlaubnis setzen).
    func uebernimm(_ config: ServerConfig) {
        stand.config = config
        sichere()
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

    private func anfrage(_ pfad: String, methode: String? = nil, post: Data? = nil, kennung: KontoKennung?) -> URLRequest? {
        guard let zugang, var teile = URLComponents(url: zugang.server, resolvingAgainstBaseURL: false) else { return nil }
        let basis = teile.path.hasSuffix("/") ? String(teile.path.dropLast()) : teile.path
        teile.path = basis + pfad
        guard let url = teile.url else { return nil }
        var a = URLRequest(url: url)
        a.timeoutInterval = 15
        a.httpMethod = methode ?? (post == nil ? "GET" : "POST")
        if let post { a.httpBody = post; a.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        var kopf = ["X-App-Key": zugang.appKey, "X-App-Version": version]
        if let kennung { kopf = kopfzeilen(kennung, zugang: zugang) }
        for (name, wert) in kopf { a.setValue(wert, forHTTPHeaderField: name) }
        return a
    }

    /// Status und Antwort; nil bei einem Netzfehler.
    /// Misst jeden Aufruf des Lumen-Servers (feste Routennamen, Status, Dauer als Bereich) für die Nutzungsmeldung, wenn die Person zugestimmt hat.
    private func sende(_ anfrage: URLRequest?) async -> (status: Int, daten: Data)? {
        guard let anfrage else { return nil }
        let beginn = ContinuousClock.now
        let antwort = try? await http.lade(anfrage)
        nutzung.route(methode: anfrage.httpMethod, pfad: anfrage.url?.path, status: antwort?.1.statusCode, dauer: NutzungMass.sekunden(ContinuousClock.now - beginn))
        guard let antwort else { return nil }
        return (antwort.1.statusCode, antwort.0)
    }

    /// Holt Kennung, meldet das Gerät an (einmal, bei Netzfehler später nochmal), dann Einstellungen und Freigabe.
    /// `profilName`: Name des aktiven Profils; ohne Profil wird nichts angemeldet (der Server verlangt einen Namen).
    func aktualisiere(profilName: String?, erzwingen: Bool = false) async {
        if let profilName { letzterProfilName = profilName }
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
            if let neu = ServerConfig.zusammen(stand.config, antwort: c.daten) { uebernimm(neu) }
        }
        if let f = await sende(anfrage("/lovea/freigabe", kennung: kennung)), f.status == 200 {
            struct Antwort: Decodable { var erlaubt: Bool?; var importErledigt: Bool?; var person: String?; var essenExportErledigt: Bool?; var essenExportAn: Bool? }
            // Nur ein vorhandenes `erlaubt` ändert den Stand: true gibt frei, false nimmt zurück, fehlend (`{}`) ändert nichts.
            if let a = try? JSONDecoder().decode(Antwort.self, from: f.daten), let erlaubt = a.erlaubt {
                stand.loveaErlaubt = erlaubt
                stand.loveaPerson = erlaubt ? a.person : nil
                // Der Server vergisst das nicht (Neuinstallation); ein ausdrückliches false (Merker zurückgesetzt) gilt, solange keine eigene Meldung aussteht.
                if let erledigt = a.importErledigt, !stand.importMeldungOffen { stand.loveaImportErledigt = erledigt }
                if let an = a.essenExportAn { stand.essenExportAn = an }
                if a.essenExportErledigt == true { stand.essenExportErledigt = true }
                freigabeAktuell = true
                sichere()
            }
        }
        if stand.importMeldungOffen { await meldeImportAnServer(kennung) }
        // Neuer Weg: Verbindungen vom Server (Antwort filtert er selbst). Kennt der Server ihn nicht (älterer Stand), bleibt der alte Partner-Weg.
        if !(await verbindungenAbgleichen(kennung)), stand.loveaErlaubt { await partnerAbgleichen(kennung) }
        await nutzungUebertragen(kennung)
    }

    /// Eine Anfrage mit den Kopfzeilen des Kontos. nil bei Netzfehler.
    func sendeMitKonto(_ pfad: String, methode: String, body: Data? = nil, kennung: KontoKennung) async -> (status: Int, daten: Data)? {
        await sende(anfrage(pfad, methode: methode, post: body, kennung: kennung))
    }

    // MARK: - Essen-Export nach Lovea

    /// Schickt Ops an Lovea (`POST /lovea/ops`, der Server setzt Key und Person). Rückgabe: Status; nil ohne Netz oder ohne angemeldetes Gerät.
    func loveaOpsSenden(_ ops: [Op]) async -> Int? {
        struct Paket: Encodable { var ops: [Op] }
        guard let k = registrierteKennung(), let koerper = try? JSONEncoder().encode(Paket(ops: ops)) else { return nil }
        return await sendeMitKonto("/lovea/ops", methode: "POST", body: koerper, kennung: k)?.status
    }

    /// Gehört das Konto diesem Profil? Das erste Profil, das fragt (der Abgleich beim Start fragt mit dem aktiven), wird gemerkt; jedes andere bekommt false.
    /// shortcut: wird das gemerkte Profil gelöscht, ruht der Export, bis jemand das Konto neu zuordnet; bei Bedarf beim Löschen zurücksetzen.
    @discardableResult
    func gehoertZuProfil(_ id: ProfilID) -> Bool {
        if stand.kontoProfil == nil {
            stand.kontoProfil = id.rawValue
            sichere()
        }
        return stand.kontoProfil == id.rawValue
    }

    /// Merkt, was gesendet ist: so viele Essen-Ops von vorn, und der Stand der Ziele.
    func essenExportMerken(anzahl: Int, ziele: String?) {
        stand.essenExportAnzahl = anzahl
        stand.essenExportZiele = ziele
        sichere()
    }

    /// Der erste volle Lauf ist durch: lokal merken und dem Server melden (Merker je Konto).
    func essenExportAbgeschlossen() async {
        stand.essenExportErledigt = true
        sichere()
        if let k = registrierteKennung() { _ = await sendeMitKonto("/lovea/export-erledigt", methode: "POST", kennung: k) }
    }

    // MARK: - Einmal-Import

    /// Der Import ist durch: lokal merken und dem Server melden (bei Netzfehler später nochmal).
    func loveaImportAbgeschlossen() async {
        stand.loveaImportErledigt = true
        stand.importMeldungOffen = true
        sichere()
        if case .da(let k) = liesKennung(), k.registriert { await meldeImportAnServer(k) }
    }

    /// Meldet den Beleg eines Import-Laufs (nur Zahlen) oder einen Fehler. Gibt den Status des Servers zurück; nil, wenn nicht gesendet werden konnte
    /// (Netzfehler, Gerät beim Server nicht angemeldet). Ein Wiederholen gibt es nicht: der nächste Lauf meldet neu.
    func meldeImportBeleg<T: Encodable & Sendable>(_ beleg: T) async -> Int? {
        guard case .da(let k) = liesKennung(), k.registriert, let koerper = try? JSONEncoder().encode(beleg) else { return nil }
        return await sendeMitKonto("/lovea/import-beleg", methode: "POST", body: koerper, kennung: k)?.status
    }

    /// Schickt den Schlaf-Beleg (`SchlafBeleg`, JSON) an `/diagnose/schlaf`. Status des Servers; nil bei Netzfehler oder wenn das Gerät nicht angemeldet ist.
    /// Der Server nimmt ihn nur an, wenn der Schalter für das Konto an ist (sonst 403).
    func schlafBelegSenden(_ koerper: Data) async -> Int? {
        guard schlafBelegAn, case .da(let k) = liesKennung(), k.registriert else { return nil }
        return await sendeMitKonto("/diagnose/schlaf", methode: "POST", body: koerper, kennung: k)?.status
    }

    private func meldeImportAnServer(_ kennung: KontoKennung) async {
        guard let r = await sendeMitKonto("/lovea/import-erledigt", methode: "POST", kennung: kennung) else { return }
        // 200: gemerkt. 403: der Server gibt das Konto nicht (mehr) frei, dann gibt es nichts zu melden.
        if r.status == 200 || r.status == 403 { stand.importMeldungOffen = false; sichere() }
    }

    // MARK: - Partner über den Server

    /// Die Zusammenfassung für den Partner (`zusammenfassung.json`-Form) wird gemerkt und beim nächsten Gelegenheit hochgeladen (höchstens alle 2 Minuten).
    func partnerHochladen(_ daten: Data) {
        partnerAusstehend = daten
        guard case .da(let k) = liesKennung(), k.registriert else { return }
        Task { await partnerSenden(k) }
    }

    /// Die Kennung dieses Geräts, wenn der Server sie kennt (für die Wege der Verbindungen).
    func registrierteKennung() -> KontoKennung? {
        if case .da(let k) = liesKennung(), k.registriert { return k }
        return nil
    }

    /// Wie `registrierteKennung`, aber holt das Konto nach: läuft die Anmeldung gerade (Start), wird bis zu fünf Sekunden darauf gewartet,
    /// sonst wird sie sofort versucht (der erste Start hatte kein Netz). nil: der Server kennt dieses Gerät nicht (Netz, voll, abgelehnt).
    func kennungBereit() async -> KontoKennung? {
        for _ in 0..<10 {
            if let k = registrierteKennung() { return k }
            if !laeuft {
                await aktualisiere(profilName: letzterProfilName, erzwingen: true)
                return registrierteKennung()
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return registrierteKennung()
    }

    /// Die nächste Zusammenfassung geht sofort raus, ohne die 2 Minuten Pause (nach einer Änderung der Freigaben).
    func hochladenFreigeben() { letzterPartnerUpload = nil }

    /// Nichts mehr hochladen (keine Verbindung zeigt etwas): eine gemerkte, noch nicht gesendete Zusammenfassung verfällt.
    func hochladenVerwerfen() { partnerAusstehend = nil }

    /// 20 Sekunden, wenn die Zusammenfassung `imGym` meldet, sonst 2 Minuten (auch bei Daten, die nicht lesbar sind).
    nonisolated static func pauseFuer(_ daten: Data) -> TimeInterval {
        let imGym = (try? LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: daten))?.heute.verlauf?.imGym == true
        return imGym ? partnerPauseImGym : partnerPause
    }

    func partnerSenden(_ kennung: KontoKennung, erzwingen: Bool = false) async {
        guard let daten = partnerAusstehend else { return }
        let jetzt = uhr()
        if !erzwingen, let letzter = letzterPartnerUpload, jetzt.timeIntervalSince(letzter) >= 0, jetzt.timeIntervalSince(letzter) < Self.pauseFuer(daten) { return }
        letzterPartnerUpload = jetzt
        // Oft im Hintergrund gestartet (Health-Lieferung, Wechsel in den Hintergrund): die Anfrage darf zu Ende laufen, sonst reißt iOS sie ab (`partner_put.netz`).
        let zeit = HintergrundZeit("LumenFit-Partner-Upload")
        defer { zeit.ende() }
        if let r = await sendeMitKonto("/partner", methode: "PUT", body: daten, kennung: kennung), r.status == 200 || r.status == 400 {
            partnerAusstehend = nil   // 400: der Server mag diese Form nie; nicht endlos wiederholen
        }
    }

    /// Lädt Eigenes hoch und holt den Partner. Ergebnis liegt als Datei neben den Profilen (`partner-server.json`); kein Partner = Datei weg.
    private func partnerAbgleichen(_ kennung: KontoKennung) async {
        await partnerSenden(kennung, erzwingen: true)
        guard let r = await sendeMitKonto("/partner", methode: "GET", kennung: kennung), r.status == 200 else { return }
        struct Antwort: Decodable { var partner: ZusammenfassungDatei? }
        let datei = ordner.appendingPathComponent(Self.partnerDatei)
        guard let a = try? LoveaVertrag.decoder().decode(Antwort.self, from: r.daten) else { return }
        if let p = a.partner, let daten = try? LoveaVertrag.encoder().encode(p) {
            try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
            try? daten.write(to: datei, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: datei)
        }
    }

    // MARK: - Nutzung

    /// Sendet die gesammelten Zähler: einmal je Start (auch leer, das ist der "aktive Tag") und ältere Tage, die noch offen sind.
    private func nutzungUebertragen(_ kennung: KontoKennung, zwischendurch: Bool = false) async {
        guard nutzung.an else { return }
        let heute = Datum.text(uhr())
        let tage = nutzung.faellig(heute: heute, ersterInSitzung: !nutzungGesendetInSitzung && !zwischendurch, zwischendurch: zwischendurch)
        guard !tage.isEmpty else { return }
        for (tag, zaehler) in tage {
            guard nutzung.an else { return }   // zwischen zwei Tagen ausgeschaltet: nichts Weiteres senden
            let gruppen = zaehler.mehr.filter { !$0.value.isEmpty }
            let koerper = try? JSONEncoder().encode(NutzungMeldung(tag: tag, bereiche: zaehler.bereiche, funktionen: zaehler.funktionen,
                                                                   gruppen: gruppen.isEmpty ? nil : gruppen, ios: NutzungGeraet.ios, geraet: NutzungGeraet.typ))
            guard let r = await sendeMitKonto("/nutzung", methode: "POST", body: koerper, kennung: kennung) else { continue }
            // 200 gesendet; 400: der Server nimmt den Tag nicht (zu alt): verwerfen, nicht endlos wiederholen.
            if r.status == 200 || r.status == 400 { nutzung.abgeschickt(tag: tag) }
            if r.status == 200 { nutzungGesendetInSitzung = true }
        }
    }

    /// So selten gehen die Zähler zwischendurch raus (Wechsel in den Hintergrund), damit Fehler nicht erst beim nächsten Start ankommen.
    nonisolated static let nutzungPause: TimeInterval = 300

    /// Beim Wechsel in den Hintergrund: Zähler von heute senden, höchstens alle 5 Minuten, nur mit Zustimmung und angemeldetem Gerät. Best effort, kein Wiederholen.
    func nutzungHochladen() async {
        guard nutzung.an, case .da(let kennung) = liesKennung(), kennung.registriert else { return }
        let jetzt = uhr()
        if let letzter = letzterNutzungsUpload, jetzt.timeIntervalSince(letzter) >= 0, jetzt.timeIntervalSince(letzter) < Self.nutzungPause { return }
        // Ohne neuen Inhalt startet die Pause nicht, sonst bliebe ein Fehler kurz danach bis zu 5 Minuten liegen.
        guard !nutzung.faellig(heute: Datum.text(jetzt), ersterInSitzung: false, zwischendurch: true).isEmpty else { return }
        letzterNutzungsUpload = jetzt
        let zeit = HintergrundZeit("LumenFit-Nutzung-Upload")   // läuft beim Wechsel in den Hintergrund, braucht eigene Zeit
        defer { zeit.ende() }
        await nutzungUebertragen(kennung, zwischendurch: true)
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
