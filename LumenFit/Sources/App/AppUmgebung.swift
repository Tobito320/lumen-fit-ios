import BackgroundTasks
import Foundation
import Observation

/// Alles, was Ansichten und Module von außen brauchen: Profil, Navigation, Ereignisse, Gesundheit, die Ports und der `DatenSatz` des aktiven Profils.
/// `geteilt` ist die eine Instanz der laufenden App (auch für Intents); im Test-Host ist es eine Vorschau ohne Modulstarts.
@MainActor @Observable
final class AppUmgebung {
    let profil: ProfilStore
    let router: Router
    let ereignisse: EreignisKanal
    let gesundheit: GesundheitsStand
    let uhr: Uhr
    let ordner: URL
    let schluesselbund: any Schluesselbund
    let http: any HTTPLader
    let mitteiler: any Mitteiler
    let healthSchreiber: any HealthSchreiber
    let bruecke: any PartnerAustausch
    /// Konto beim Lumen-Server: Einstellungen ohne Build und Lovea-Freigabe (SPEC 18). Ohne Zugang kein Netz, nur Standardwerte.
    let konto: KontoDienst
    /// Der einmalige Import aus Lovea (läuft von selbst, wenn der Server das Konto freigibt und er noch nicht war).
    let loveaImport = LoveaEinmalImport()
    @ObservationIgnored let healthLeser: any HealthLeser
    var coachMotor: any CoachMotor = RueckfallCoachMotor()              // setzt das Modul coach in start()
    var liveAnzeige: any LiveAnzeige = KeineLiveAnzeige()               // setzt das Modul widgets
    var trainingSteuerung: any TrainingSteuerung = KeineTrainingSteuerung()   // setzt das Modul gym
    var band: any BandDienst = KeinBand()                               // setzt das Modul verbinden
    /// Profil und Passwort-Spur waren im Schlüsselbund, der Profilordner fehlte beim Start: Neuinstallation (SPEC 5.4).
    private(set) var neuinstallationErkannt = false

    @ObservationIgnored private var datenSatz: DatenSatz?
    @ObservationIgnored private var abrufAufgaben: [@MainActor () async -> Void] = []

    /// Der `DatenSatz` des aktiven Profils; nil, solange es kein Profil gibt. Ein Profilwechsel liefert einen neuen.
    var daten: DatenSatz? {
        guard let id = profil.aktiv?.id else { return nil }
        if let vorhanden = datenSatz, vorhanden.profil == id { return vorhanden }
        let neu = DatenSatz(profil: id, ordner: profilOrdner(id), ereignisse: ereignisse, uhr: uhr, bruecke: bruecke)
        datenSatz = neu
        return neu
    }

    init(ordner: URL, schluesselbund: any Schluesselbund, http: any HTTPLader, mitteiler: any Mitteiler, leser: any HealthLeser,
         healthSchreiber: any HealthSchreiber, bruecke: any PartnerAustausch, uhr: @escaping Uhr, passwortRunden: Int = Passwort.standardRunden,
         kontoZugang: KontoZugang? = nil) {
        let kanal = EreignisKanal()
        self.ordner = ordner
        self.uhr = uhr
        self.ereignisse = kanal
        self.schluesselbund = schluesselbund
        self.http = http
        self.mitteiler = mitteiler
        self.healthSchreiber = healthSchreiber
        self.healthLeser = leser
        let dienst = KontoDienst(zugang: kontoZugang, schluesselbund: schluesselbund, http: http, ordner: ordner, uhr: uhr)
        self.konto = dienst
        if kontoZugang != nil {
            // Mit Server: Partner-Daten laufen über ihn, der Datei-Weg zu Lovea bleibt darunter (SPEC 18.7). Ohne Server (Tests, Vorschau) bleibt die Brücke wie übergeben.
            let hochlader = PartnerHochlader()
            hochlader.setze { daten in Task { @MainActor in dienst.partnerHochladen(daten) } }
            self.bruecke = ServerPartnerBruecke(innen: bruecke, serverDatei: ordner.appendingPathComponent(KontoDienst.partnerDatei), hochlader: hochlader)
        } else {
            self.bruecke = bruecke
        }
        self.router = Router()
        let profile = ProfilStore(schluesselbund: schluesselbund, ereignisse: kanal, runden: passwortRunden, uhr: uhr)
        self.profil = profile
        let anker = UmgebungsAnker()
        self.gesundheit = GesundheitsStand(leser: leser, uhr: uhr, band: { anker.bandTage() })
        if let aktiv = profile.aktiv {
            neuinstallationErkannt = !FileManager.default.fileExists(atPath: Self.profilOrdner(ordner, aktiv.id).path)
        }
        anker.umgebung = self
    }

    static func profilOrdner(_ ordner: URL, _ id: ProfilID) -> URL {
        ordner.appendingPathComponent("profile", isDirectory: true).appendingPathComponent(id.rawValue, isDirectory: true)
    }

    func profilOrdner(_ id: ProfilID) -> URL { Self.profilOrdner(ordner, id) }

    /// Ein weiteres Profil neben dem ersten nur, wenn der Server es erlaubt (Standard und offline: nein). Die echte App und die Demo rufen das;
    /// die Vorschau der Tests bleibt offen, damit sie Profile frei anlegen kann.
    func sperreWeitereProfile() {
        let dienst = konto
        profil.weitereProfileErlaubt = { dienst.config.profilAnlegenErlaubt }
    }

    /// Liest die Profile erneut ("Erneut versuchen" nach einem Lesefehler) und prüft, ob es eine Neuinstallation ist.
    func ladeProfileNeu() {
        profil.ladeNeu()
        if let aktiv = profil.aktiv { neuinstallationErkannt = !FileManager.default.fileExists(atPath: profilOrdner(aktiv.id).path) }
    }

    /// Die Willkommen-zurück-Karte ist beantwortet (Sicherung eingespielt oder abgelehnt).
    func neuinstallationQuittieren() { neuinstallationErkannt = false }

    // MARK: - Hintergrund-Abruf

    /// Meldet die Health-Hintergrundlieferung für Schritte, Schlaf und Training an (synchron in `ModulStart.starteAlle`). Neue Daten lösen
    /// `Ereignis.healthAktualisiert` und alle Abruf-Aufgaben aus.
    func beobachteHealth() {
        healthLeser.beobachte([.schritte, .schlaf, .training]) { [weak self] in
            Task { @MainActor in await self?.fuehreAbrufAus() }
        }
    }

    /// Module melden Aufgaben für den Hintergrund-Abruf an (BGTask `com.onlyus.lumen-fit.aktualisieren`); das Grundgerüst führt alle aus (höchstens 20 s) und plant neu.
    func beiAbruf(_ aufgabe: @escaping @MainActor () async -> Void) { abrufAufgaben.append(aufgabe) }

    /// Führt alle angemeldeten Abruf-Aufgaben nacheinander aus, höchstens 20 Sekunden (danach wird abgebrochen).
    func fuehreAbrufAus() async {
        ereignisse.senden(.healthAktualisiert)
        let aufgaben = abrufAufgaben
        let arbeit = Task { @MainActor in
            for aufgabe in aufgaben {
                if Task.isCancelled { return }
                await aufgabe()
            }
        }
        let wache = Task {
            try? await Task.sleep(for: .seconds(20))
            arbeit.cancel()
        }
        await arbeit.value
        wache.cancel()
    }

    // MARK: - Fabriken

    /// Die eine Instanz der laufenden App; im Test-Host eine Vorschau ohne Modulstarts.
    static let geteilt: AppUmgebung = {
        if ModulStart.imTestHost { return vorschau() }
        #if DEBUG
        let argumente = StartArgumente.lies()
        if argumente.demo { return demo(fixtures: argumente.fixtures) }
        #endif
        return live()
    }()

    /// Ohne Netz, ohne Health, ohne Schlüsselbund und Dateien der App: alles im Speicher beziehungsweise in einem frischen Temp-Ordner.
    /// `fixtures` legt Antworten für den `HTTPLader` ab (`FixtureLader`).
    static func vorschau(fixtures: URL? = nil, uhr: @escaping Uhr = { Date() }) -> AppUmgebung {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("lumenfit-vorschau-\(UUID().uuidString)", isDirectory: true)
        return AppUmgebung(ordner: temp, schluesselbund: SpeicherSchluesselbund(),
                           http: fixtures.map { FixtureLader(ordner: $0) } ?? FixtureLader(ordner: nil),
                           mitteiler: StilleMitteilung(), leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(),
                           bruecke: KeinePartnerBruecke(), uhr: uhr, passwortRunden: 1_000)
    }

    /// Die echte App: Schlüsselbund (mit Rückfall im unsignierten Simulator), HealthKit, App-Gruppe, Lovea-Brücke.
    static func live() -> AppUmgebung {
        let umgebung = AppUmgebung(ordner: AppGruppe.ordner(), schluesselbund: RueckfallSchluesselbund(), http: URLSessionLader(), mitteiler: SystemMitteiler(),
                                   leser: HKHealthLeser(), healthSchreiber: HKHealthSchreiber(), bruecke: LoveaBruecke(ordner: AppGruppe.loveaOrdner()),
                                   uhr: { Date() }, kontoZugang: KontoZugang.lade())
        umgebung.sperreWeitereProfile()
        return umgebung
    }
}

/// Reicht `AppUmgebung` an `GesundheitsStand` weiter, ohne dass dieser sie kennt (der Stand wird vor ihr fertig). Die Band-Tage kommen aus dem
/// Raum des aktiven Profils (Ops `fit.band.tag`, die letzte Op je Tag gewinnt).
@MainActor private final class UmgebungsAnker {
    weak var umgebung: AppUmgebung?

    func bandTage() -> [BandTagOp] {
        guard let raum = umgebung?.daten?.raum else { return [] }
        var tage: [String: BandTagOp] = [:]
        for op in raum.ops(arten: ["fit.band.tag"]) { if let t = op.daten(BandTagOp.self) { tage[t.tag] = t } }
        return Array(tage.values)
    }
}

/// Plant und führt den Hintergrund-Abruf aus. `register` muss vor Ende des App-Starts laufen (`ModulStart.starteAlle`).
enum AbrufPlaner {
    nonisolated static let kennung = "com.onlyus.lumen-fit.aktualisieren"

    // @unchecked Sendable: BGAppRefreshTask ist nicht Sendable; es wird nur einmal an den Hauptakteur gereicht und dort beendet.
    private struct Auftrag: @unchecked Sendable { let aufgabe: BGAppRefreshTask }

    @MainActor static func registriere(_ umgebung: AppUmgebung) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: kennung, using: nil) { aufgabe in
            guard let aufgabe = aufgabe as? BGAppRefreshTask else { aufgabe.setTaskCompleted(success: false); return }
            let auftrag = Auftrag(aufgabe: aufgabe)
            Task { @MainActor in
                plane()
                await umgebung.fuehreAbrufAus()
                auftrag.aufgabe.setTaskCompleted(success: true)
            }
        }
        plane()
    }

    /// Frühestens in 15 Minuten; wann iOS wirklich startet, entscheidet das System (nichts darf davon abhängen).
    @MainActor static func plane() {
        let anfrage = BGAppRefreshTaskRequest(identifier: kennung)
        anfrage.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(anfrage)
    }
}
