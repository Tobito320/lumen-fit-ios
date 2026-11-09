import BackgroundTasks
import Foundation
import Observation
import os
import UIKit

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
    /// Die zweite Brücke, zu Lumen Alarm: Ordner `LumenAlarm` in der eigenen Gruppe (Weck-Wünsche lesen, erledigt und Status schreiben). Ohne Signierung leer.
    let alarmBruecke: any PartnerAustausch
    /// Konto beim Lumen-Server: Einstellungen ohne Build und Lovea-Freigabe (SPEC 18). Ohne Zugang kein Netz, nur Standardwerte.
    let konto: KontoDienst
    /// Der einmalige Import aus Lovea (läuft von selbst, wenn der Server das Konto freigibt und er noch nicht war).
    let loveaImport = LoveaEinmalImport()
    @ObservationIgnored let healthLeser: any HealthLeser
    var liveAnzeige: any LiveAnzeige = KeineLiveAnzeige()               // setzt das Modul widgets
    var trainingSteuerung: any TrainingSteuerung = KeineTrainingSteuerung()   // setzt das Modul gym
    var band: any BandDienst = KeinBand()                               // setzt das Modul verbinden
    /// Profil und Passwort-Spur waren im Schlüsselbund, der Profilordner fehlte beim Start: Neuinstallation (SPEC 5.4).
    private(set) var neuinstallationErkannt = false

    @ObservationIgnored private var datenSatz: DatenSatz?
    @ObservationIgnored private var beobachteteTypen: Set<HealthTyp> = []
    @ObservationIgnored private var abrufAufgaben: [@MainActor () async -> Void] = []

    /// Die gewählten Bereiche des aktiven Profils, so wie die App sie zeigt: Schlaf nur, wenn der Server es dem Konto erlaubt (`Einstellungen.wirksam`).
    var bereicheWirksam: Einstellungen {
        (daten?.einstellungen.werte ?? Einstellungen()).wirksam(schlafSichtbar: konto.schlafSichtbar)
    }

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
         kontoZugang: KontoZugang? = nil, alarmBruecke: any PartnerAustausch = KeinePartnerBruecke()) {
        self.alarmBruecke = alarmBruecke
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
        self.gesundheit = GesundheitsStand(leser: leser, uhr: uhr, band: { anker.bandTage() }, importVerlauf: { anker.importVerlauf() },
                                         eigeneNaechte: { anker.eigeneNaechte() }, typen: { anker.healthTypen() }, darfFragen: { anker.healthErlaubt() })
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

    /// Meldet die Health-Hintergrundlieferung für Schritte, Schlaf und Training an (synchron in `ModulStart.starteAlle`), aber nur für gewählte Bereiche.
    /// Ein später eingeschalteter Bereich meldet nur seine neuen Typen nach (nie doppelt). Neue Daten lösen `Ereignis.healthAktualisiert` und alle Abruf-Aufgaben aus.
    func beobachteHealth() {
        guard daten != nil else { return }   // ohne Profil ist noch nichts gewählt; `auffrischen` ruft es nach dem Onboarding nochmal
        // Nur wirksame Bereiche: Schlaf wird für Konten ohne Server-Freigabe weder gelesen noch beobachtet (weniger Wecken im Hintergrund).
        let gewollt = Set<HealthTyp>([.schritte, .schlaf, .training]).intersection(bereicheWirksam.healthTypen)
        let neu = gewollt.subtracting(beobachteteTypen)
        guard !neu.isEmpty else { return }
        beobachteteTypen.formUnion(neu)
        healthLeser.beobachte(neu) { [weak self] fertig in
            Task { @MainActor in
                // Health wartet mit `fertig` auf den Abruf (die App bleibt so lange wach); die eigene Hintergrundzeit sichert die Aufgaben danach ab.
                let zeit = HintergrundZeit("LumenFit-Health-Abruf")
                await self?.fuehreAbrufAus()
                zeit.ende()
                fertig()
            }
        }
    }

    /// Module melden Aufgaben für den Hintergrund-Abruf an (BGTask `com.onlyus.lumen-fit.aktualisieren`); das Grundgerüst führt alle aus (höchstens 20 s) und plant neu.
    func beiAbruf(_ aufgabe: @escaping @MainActor () async -> Void) { abrufAufgaben.append(aufgabe) }

    /// Läuft gerade ein Abruf? Dann startet kein zweiter (die Health-Hintergrundlieferung meldet oft mehrmals kurz hintereinander).
    @ObservationIgnored private var abrufLaeuft = false

    /// Führt alle angemeldeten Abruf-Aufgaben nacheinander aus, höchstens 20 Sekunden: danach wird abgebrochen und die Funktion kehrt
    /// zurück, auch wenn eine Aufgabe den Abbruch nicht beachtet (sonst endet der Hintergrundlauf nie und iOS beendet die App hart).
    func fuehreAbrufAus() async {
        guard !abrufLaeuft else { return }
        abrufLaeuft = true
        defer { abrufLaeuft = false }
        let aufgaben = abrufAufgaben
        let arbeit = Task { @MainActor in
            // Erst Health, dann die Aufgaben: sonst schreiben Lovea-Datei und Server-Stand die Schritte von vorher. Nie die Rechte-Abfrage auslösen.
            if daten?.einstellungen.werte.healthGefragt == true { await gesundheit.aktualisiere() }
            // Erst jetzt melden, einmal je Lieferung: die Leser (Heute, Meilensteine, Lovea-Datei, Widgets) sehen so die frischen Werte statt die alten
            // (vorher meldete jeder der vier Health-Rückrufe sofort, und alle Leser rechneten vierfach auf dem Hauptakteur).
            ereignisse.senden(.healthAktualisiert)
            for aufgabe in aufgaben {
                if Task.isCancelled { return }
                await aufgabe()
            }
        }
        await withCheckedContinuation { (fertig: CheckedContinuation<Void, Never>) in
            let einmal = EinmalSchalter()
            Task { @MainActor in
                await arbeit.value
                if einmal.zuerst() { fertig.resume() }
            }
            Task {
                try? await Task.sleep(for: .seconds(20))
                arbeit.cancel()
                if einmal.zuerst() { fertig.resume() }
            }
        }
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
                                   uhr: { Date() }, kontoZugang: KontoZugang.lade(),
                                   alarmBruecke: LoveaBruecke(ordner: AppGruppe.eigeneWurzel(), ordnerName: AppGruppe.alarmOrdnerName))
        umgebung.sperreWeitereProfile()
        return umgebung
    }
}

/// Reicht `AppUmgebung` an `GesundheitsStand` weiter, ohne dass dieser sie kennt (der Stand wird vor ihr fertig). Die Band-Tage kommen aus dem
/// Raum des aktiven Profils (Ops `fit.band.tag`, die letzte Op je Tag gewinnt).
@MainActor private final class UmgebungsAnker {
    weak var umgebung: AppUmgebung?

    func healthTypen() -> Set<HealthTyp> { (umgebung?.bereicheWirksam ?? Einstellungen()).healthTypen }

    /// Die Person hat Health erlaubt (Onboarding oder Health-Zugriff): erst dann fragt der Stand nach Leserechten.
    func healthErlaubt() -> Bool { umgebung?.daten?.einstellungen.werte.healthGefragt == true }

    func importVerlauf() -> ImportVerlaufStand { umgebung?.daten?.importVerlauf.stand ?? ImportVerlaufStand() }

    /// `gesundheit.tage` und `.naechte` lesen diese beiden bei jedem Zugriff, auch mehrmals je `body`. Ohne Merken liefe jedes Mal ein voller Lauf über alle Ops
    /// mit JSON-Decode auf dem Hauptakteur. Gleicher Raum mit gleicher Op-Anzahl gibt dasselbe Ergebnis (Ops werden nur angehängt).
    private struct Merkschluessel: Equatable { let raum: ObjectIdentifier; let profil: ProfilID; let anzahl: Int }
    private var naechteGemerkt: (schluessel: Merkschluessel, wert: SchlafEigeneQuellen)?
    private var bandGemerkt: (schluessel: Merkschluessel, wert: [BandTagOp])?

    private func schluessel(_ raum: LokalerRaum) -> Merkschluessel { Merkschluessel(raum: ObjectIdentifier(raum), profil: raum.profil, anzahl: raum.anzahl) }

    func eigeneNaechte() -> SchlafEigeneQuellen {
        guard let raum = umgebung?.daten?.raum else { return SchlafEigeneQuellen.lesen(nil) }
        if let g = naechteGemerkt, g.schluessel == schluessel(raum) { return g.wert }
        let wert = SchlafEigeneQuellen.lesen(raum)
        naechteGemerkt = (schluessel(raum), wert)
        return wert
    }

    func bandTage() -> [BandTagOp] {
        guard let raum = umgebung?.daten?.raum else { return [] }
        if let g = bandGemerkt, g.schluessel == schluessel(raum) { return g.wert }
        var tage: [String: BandTagOp] = [:]
        for op in raum.ops(arten: ["fit.band.tag"]) { if let t = op.daten(BandTagOp.self) { tage[t.tag] = t } }
        let wert = SchritteHandLogik.zusammen(band: tage, hand: SchritteHandLogik.tage(ops: raum.ops(arten: [SchritteHandLogik.art])))
        bandGemerkt = (schluessel(raum), wert)
        return wert
    }
}

/// Plant und führt den Hintergrund-Abruf aus. `register` muss vor Ende des App-Starts laufen (`ModulStart.starteAlle`).
enum AbrufPlaner {
    nonisolated static let kennung = "com.onlyus.lumen-fit.aktualisieren"

    // @unchecked Sendable: BGAppRefreshTask ist nicht Sendable; es wird nur einmal an den Hauptakteur gereicht und dort beendet.
    private struct Auftrag: @unchecked Sendable { let aufgabe: BGAppRefreshTask }

    @MainActor static func registriere(_ umgebung: AppUmgebung) {
        // `@Sendable`: sonst erbt der Rückruf den Hauptakteur, iOS ruft ihn aber außerhalb davon, und Swift 6 bricht die App dann zur Laufzeit ab.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: kennung, using: .main) { @Sendable aufgabe in
            guard let aufgabe = aufgabe as? BGAppRefreshTask else { aufgabe.setTaskCompleted(success: false); return }
            let auftrag = Auftrag(aufgabe: aufgabe)
            let einmal = EinmalSchalter()
            let arbeit = Task { @MainActor in
                plane()
                await umgebung.fuehreAbrufAus()
                if einmal.zuerst() { auftrag.aufgabe.setTaskCompleted(success: true) }
            }
            // Ohne Ablauf-Handler beendet iOS die App hart, wenn die Zeit um ist (Absturz im Hintergrund). Genau einmal abschließen.
            aufgabe.expirationHandler = { @Sendable in
                arbeit.cancel()
                if einmal.zuerst() { auftrag.aufgabe.setTaskCompleted(success: false) }
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

/// Lässt genau einen Aufrufer durch (für "genau einmal abschließen" aus verschiedenen Threads).
final class EinmalSchalter: Sendable {
    private let schon = OSAllocatedUnfairLock(initialState: false)

    /// `true` beim ersten Aufruf, danach immer `false`.
    func zuerst() -> Bool {
        schon.withLock { war in
            defer { war = true }
            return !war
        }
    }
}

/// Hält die App für einen Abruf wach (höchstens die Zeit, die iOS gibt) und gibt die Zeit zurück, sobald `ende()` kommt oder iOS sie zurückfordert.
@MainActor final class HintergrundZeit {
    private var kennung = UIBackgroundTaskIdentifier.invalid

    init(_ name: String) {
        kennung = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.ende() }
        }
    }

    func ende() {
        guard kennung != .invalid else { return }
        UIApplication.shared.endBackgroundTask(kennung)
        kennung = .invalid
    }
}
