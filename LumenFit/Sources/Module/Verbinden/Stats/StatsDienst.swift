import Foundation
import Observation

/// Stats beim Server (`GET /stats`, `PUT /stats`, Melden, Blockieren). Eine Instanz je Konto (`von`). Der letzte Stand liegt als `stats-server.json`
/// neben dem Konto, damit die Seite auch ohne Netz etwas zeigt. Privat (Standard) geht nichts hoch, die öffentliche Liste lesen alle.
/// Die eigenen Zahlen kommen immer vom Gerät (`StatsPunkte`). In der Demo (`-lumenFitDemo`, nur DEBUG) eine feste Antwort ohne Netz.
@MainActor @Observable
final class StatsDienst {
    nonisolated static let dateiName = "stats-server.json"
    /// So oft holt das Öffnen der Seite höchstens neu.
    nonisolated static let pause: TimeInterval = 60
    /// So oft geht dieselbe Meldung höchstens noch einmal hoch (Vordergrund); eine neue Wahl oder neue Zahlen gehen gleich, neue Schritte allein erst danach.
    nonisolated static let sendePause: TimeInterval = 600

    private(set) var antwort: StatsAntwort?
    private(set) var laedt = false
    /// Die eigenen Zahlen, Trainingsjahr und Hauptübungen vom Gerät; neu gerechnet mit `eigeneRechnen()` (Öffnen, Laden, Senden).
    private(set) var eigene = StatsEigene()

    @ObservationIgnored private let umgebung: AppUmgebung
    @ObservationIgnored private let datei: URL
    @ObservationIgnored private let demo: Bool
    @ObservationIgnored private var zuletzt: Date?
    @ObservationIgnored private var gesendet: (zeit: Date, meldung: StatsMeldung)?
    @ObservationIgnored private var sendet = false
    @ObservationIgnored private var nochmal = false

    private static var instanzen: [ObjectIdentifier: StatsDienst] = [:]

    static func von(_ umgebung: AppUmgebung) -> StatsDienst {
        let schluessel = ObjectIdentifier(umgebung.konto)
        if let da = instanzen[schluessel] { return da }
        let neu = StatsDienst(umgebung: umgebung, demo: LoveaFreigabe.demoAktiv)
        instanzen[schluessel] = neu
        return neu
    }

    init(umgebung: AppUmgebung, demo: Bool = false) {
        #if DEBUG
        let istDemo = demo
        #else
        let istDemo = false
        #endif
        let pfad = umgebung.konto.ordner.appendingPathComponent(Self.dateiName)
        self.umgebung = umgebung
        self.demo = istDemo
        datei = pfad
        antwort = istDemo ? Self.demoAntwort(jetzt: umgebung.uhr())
            : (try? Data(contentsOf: pfad)).flatMap { try? JSONDecoder().decode(StatsAntwort.self, from: $0) }
    }

    private static func demoAntwort(jetzt: Date) -> StatsAntwort? {
        #if DEBUG
        return StatsDemo.antwort(jetzt: jetzt)
        #else
        return nil
        #endif
    }

    private var sessions: [GymSession] { umgebung.daten?.training.sessions ?? [] }
    /// Schritte je Tag nur aus Apple Health (ohne die von Hand), für Stats Schritte.
    private var healthSchritte: [String: Int] { umgebung.gesundheit.schritteAusHealth }

    /// Rechnet die eigenen Zahlen neu (nur bei Änderung wird die Seite neu gezeichnet).
    func eigeneRechnen() {
        let e = umgebung.daten?.einstellungen.werte
        let jetzt = umgebung.uhr()
        var neu = StatsLogik.eigene(sessions: sessions, erfahrung: e?.trainingsErfahrung, jetzt: jetzt)
        neu.schritte = e.flatMap { StatsLogik.schritte(health: healthSchritte, einstellungen: $0, jetzt: jetzt) }
        if neu != eigene { eigene = neu }
    }

    // MARK: Abgleich

    /// Erst die eigene Meldung, dann `GET /stats` (höchstens einmal je Minute, außer `erzwingen`).
    func laden(erzwingen: Bool = false) async {
        eigeneRechnen()
        guard !demo, !laedt else { return }
        let jetzt = umgebung.uhr()
        if !erzwingen, let z = zuletzt, jetzt >= z, jetzt.timeIntervalSince(z) < Self.pause { return }
        guard let k = umgebung.konto.registrierteKennung() else { return }
        laedt = true
        defer { laedt = false }
        zuletzt = jetzt
        await senden()
        guard let r = await umgebung.konto.sendeMitKonto("/stats", methode: "GET", kennung: k), r.status == 200,
              let neu = try? JSONDecoder().decode(StatsAntwort.self, from: r.daten) else { return }
        setze(neu)
    }

    /// Meldet Wahl und Zahlen (`PUT /stats`): nach einem Training, beim Öffnen der App (höchstens alle 10 Minuten dasselbe) und nach einer neuen Wahl.
    /// Privat und nie etwas oben: nichts. Läuft schon eine Meldung, geht danach die neueste hinterher.
    func senden(erzwingen: Bool = false) async {
        guard !demo else { return }
        if sendet { nochmal = true; return }
        sendet = true
        defer { sendet = false }
        var zwingen = erzwingen
        repeat {
            nochmal = false
            await einmalSenden(erzwingen: zwingen)
            zwingen = false
        } while nochmal
    }

    private func einmalSenden(erzwingen: Bool) async {
        guard let e = umgebung.daten?.einstellungen.werte, let profil = umgebung.daten?.profil, umgebung.konto.gehoertZuProfil(profil),
              let k = umgebung.konto.registrierteKennung() else { return }
        let jetzt = umgebung.uhr()
        let m = StatsLogik.meldung(einstellungen: e, sessions: sessions, health: healthSchritte, jetzt: jetzt)
        let obenNichts = !(antwort?.ich.freunde ?? false) && !(antwort?.ich.oeffentlich ?? false)
        if m == .aus, obenNichts, (gesendet?.meldung ?? .aus) == .aus { return }
        // Nur neue Schritte warten die Pause ab; Schritte an oder aus (Mitzählen, Health) gehen wie eine neue Wahl gleich.
        if !erzwingen, let g = gesendet, g.meldung.ohneSchritte == m.ohneSchritte, (g.meldung.schritteTag == nil) == (m.schritteTag == nil),
           jetzt >= g.zeit, jetzt.timeIntervalSince(g.zeit) < Self.sendePause { return }
        guard let ich = await put(m, kennung: k).ich else { return }
        gesendet = (jetzt, m)
        aendere { $0.ich = ich }
    }

    /// "Akzeptieren und mitmachen": erst der Server (Spitzname erlaubt und frei?), dann die Wahl auf dem Gerät. nil heißt geklappt, sonst der Text dazu.
    func mitmachen(spitzname roh: String) async -> String? {
        let name = StatsLogik.spitzname(roh)
        if let g = StatsLogik.spitznameGrund(name) { return StatsLogik.spitznameText(g) }
        guard !demo else {
            umgebung.daten?.einstellungen.aendere { $0.statsOeffentlich = true; $0.statsSpitzname = name }
            return nil
        }
        guard var e = umgebung.daten?.einstellungen.werte, let k = umgebung.konto.registrierteKennung() else { return StatsLogik.fehlerText(nil) }
        e.statsOeffentlich = true
        e.statsSpitzname = name
        let jetzt = umgebung.uhr()
        let m = StatsLogik.meldung(einstellungen: e, sessions: sessions, health: healthSchritte, jetzt: jetzt)
        let r = await put(m, kennung: k)
        guard let ich = r.ich else { return StatsLogik.fehlerText(r.fehler) }
        gesendet = (jetzt, m)
        aendere { $0.ich = ich }
        umgebung.daten?.einstellungen.aendere { $0.statsOeffentlich = true; $0.statsSpitzname = name }
        await laden(erzwingen: true)
        return nil
    }

    // MARK: Melden, Blockieren

    /// Melden (Alle): für mich sofort ausgeblendet, ab drei Meldungen für alle, bis es geprüft ist. nil heißt geklappt, sonst der Text.
    func melden(_ id: String) async -> String? { await markieren(id, weg: "melden") }

    /// Blockieren (Alle): wir sehen uns beide nicht mehr.
    func blockieren(_ id: String) async -> String? { await markieren(id, weg: "blockieren") }

    private func markieren(_ id: String, weg: String) async -> String? {
        if !demo {
            guard let k = umgebung.konto.registrierteKennung(), let body = try? JSONEncoder().encode(["id": id]),
                  let r = await umgebung.konto.sendeMitKonto("/stats/\(weg)", methode: "POST", body: body, kennung: k) else { return StatsLogik.fehlerText(nil) }
            // 404: der Eintrag ist ohnehin weg.
            guard r.status == 200 || r.status == 404 else { return StatsLogik.fehlerText(Self.code(r.daten)) }
        }
        aendere { $0.alle.removeAll { $0.id == id } }
        return nil
    }

    /// Profil gelöscht: den Server leeren, wenn dort etwas liegt, und den Stand vergessen.
    func vergessen() async {
        let oben = antwort?.ich.freunde == true || antwort?.ich.oeffentlich == true || (gesendet.map { $0.meldung != .aus } ?? false)
        if !demo, oben, let k = umgebung.konto.registrierteKennung() { _ = await put(.aus, kennung: k) }
        antwort = nil
        gesendet = nil
        zuletzt = nil
        try? FileManager.default.removeItem(at: datei)
    }

    // MARK: Intern

    private struct PutAntwort: Decodable { var ich: StatsIch }

    private func put(_ m: StatsMeldung, kennung k: KontoKennung) async -> (ich: StatsIch?, fehler: String?) {
        guard let body = try? JSONEncoder().encode(m),
              let r = await umgebung.konto.sendeMitKonto("/stats", methode: "PUT", body: body, kennung: k) else { return (nil, nil) }
        guard r.status == 200, let a = try? JSONDecoder().decode(PutAntwort.self, from: r.daten) else { return (nil, Self.code(r.daten)) }
        return (a.ich, nil)
    }

    private static func code(_ daten: Data) -> String? {
        (try? JSONDecoder().decode([String: String].self, from: daten))?["fehler"]
    }

    private func setze(_ neu: StatsAntwort) {
        antwort = neu
        guard !demo, let daten = try? JSONEncoder().encode(neu) else { return }
        try? FileManager.default.createDirectory(at: datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? daten.write(to: datei, options: .atomic)
    }

    /// Ändert den Stand vor Ort (ohne Antwort noch keiner: dann ein leerer der Woche).
    private func aendere(_ f: (inout StatsAntwort) -> Void) {
        var neu = antwort ?? StatsAntwort(montag: Datum.wochenstart(Datum.text(umgebung.uhr())),
                                          ich: StatsIch(freunde: false, oeffentlich: false, spitzname: nil, ausgeblendet: false), freunde: [], alle: [], rekorde: [:])
        f(&neu)
        setze(neu)
    }
}
