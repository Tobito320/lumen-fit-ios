import Foundation
import XCTest
@testable import LumenFit

// Test-Hilfen des Grundgerüsts (SPEC 5.9). Module legen eigene Helfer mit eigenem Namen in ihrem Testordner an und ändern diese Datei nicht.

// MARK: - Profile

extension ProfilID {
    /// Feste Kennungen für Tests. Die Port-Tests aus Lovea kennen zwei Personen, die Faltungen sind nach ProfilID getrennt.
    static let testA = ProfilID(rawValue: "test-a")
    static let testB = ProfilID(rawValue: "test-b")
    static let testAlle: [ProfilID] = [.testA, .testB]
}

// MARK: - Uhr

/// Eine Uhr, die nur auf Befehl weiterläuft. `uhr` ist der `Uhr`-Wert für `AppUmgebung`, Stores und Räume.
final class TestUhr: @unchecked Sendable {
    private let schloss = NSLock()
    private var jetzt: Date

    /// Standard: Mittwoch 23.09.2026, 12:00 Berlin.
    init(_ start: Date = Datum.datum("2026-09-23").addingTimeInterval(12 * 3600)) { jetzt = start }

    var lesen: Date { schloss.withLock { jetzt } }
    var uhr: Uhr { { [self] in lesen } }

    func vor(sekunden: TimeInterval) { schloss.withLock { jetzt = jetzt.addingTimeInterval(sekunden) } }
    func setze(_ datum: Date) { schloss.withLock { jetzt = datum } }
}

// MARK: - Ordner und Fixtures

private final class TestBundleAnker {}

extension XCTestCase {
    /// Ein frischer, leerer Ordner; wird nach dem Test gelöscht.
    func tempOrdner() throws -> URL {
        let ordner = FileManager.default.temporaryDirectory.appending(path: "lumenfit-test-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: ordner) }
        return ordner
    }
}

/// Fixtures liegen als Ordnerreferenz im Test-Bundle: `Fixtures/<Modul>/<datei>`. Zugriff nur hierüber.
enum FixtureOrt {
    static var ordner: URL {
        Bundle(for: TestBundleAnker.self).bundleURL.appending(path: "Fixtures", directoryHint: .isDirectory)
    }

    static func url(_ modul: String, _ datei: String) -> URL {
        ordner.appending(path: modul, directoryHint: .isDirectory).appending(path: datei)
    }

    static func daten(_ modul: String, _ datei: String) throws -> Data {
        try Data(contentsOf: url(modul, datei))
    }
}

// MARK: - Netz

/// `HTTPLader` mit Skript: die Antworten kommen der Reihe nach (die letzte gilt weiter), jeder Aufruf wird gezählt und gemerkt.
final class SkriptLader: HTTPLader, @unchecked Sendable {
    struct Antwort: Sendable {
        var status: Int
        var daten: Data
        var fehler: URLError.Code?
    }

    private let schloss = NSLock()
    private var antworten: [Antwort]
    private var _anfragen: [URLRequest] = []

    init(_ antworten: [Antwort] = []) { self.antworten = antworten }

    convenience init(status: Int = 200, daten: Data) { self.init([Antwort(status: status, daten: daten, fehler: nil)]) }

    /// Aus einer Fixture-Datei: `SkriptLader(fixture: "Essen", "off-v2-product-4008400402222.json")`.
    convenience init(fixture modul: String, _ datei: String, status: Int = 200) throws {
        self.init(status: status, daten: try FixtureOrt.daten(modul, datei))
    }

    static func fehler(_ code: URLError.Code) -> SkriptLader { SkriptLader([Antwort(status: 0, daten: Data(), fehler: code)]) }

    var aufrufe: Int { schloss.withLock { _anfragen.count } }
    var anfragen: [URLRequest] { schloss.withLock { _anfragen } }

    func lade(_ anfrage: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let antwort: Antwort = schloss.withLock {
            _anfragen.append(anfrage)
            if antworten.count > 1 { return antworten.removeFirst() }
            return antworten.first ?? Antwort(status: 404, daten: Data(), fehler: nil)
        }
        if let fehler = antwort.fehler { throw URLError(fehler) }
        let url = anfrage.url ?? URL(fileURLWithPath: "/")
        guard let http = HTTPURLResponse(url: url, statusCode: antwort.status, httpVersion: "HTTP/1.1", headerFields: nil) else { throw HTTPFehler.keineAntwort }
        return (antwort.daten, http)
    }
}

// MARK: - Health

/// Feste Reihen statt HealthKit. `beobachtet` merkt, welche Typen jemand beobachten wollte; `melde()` löst die Rückrufe aus.
final class FakeHealthLeser: HealthLeser, @unchecked Sendable {
    private let schloss = NSLock()
    private var _zugriff: HealthZugriff
    private var _tage: [TagesWerte]
    private var _naechte: [SchlafNacht]
    private var _vitale: [VitalArt: [VitalMesswert]]
    private var _gewichte: [GewichtsMesswert]
    private var _workouts: [HealthWorkout]
    private var _beobachter: [@Sendable () -> Void] = []
    private var _tagesAbfragen: [(von: String, bis: String)] = []

    init(zugriff: HealthZugriff = .angefragt, tage: [TagesWerte] = [], naechte: [SchlafNacht] = [], vitale: [VitalArt: [VitalMesswert]] = [:],
         gewichte: [GewichtsMesswert] = [], workouts: [HealthWorkout] = []) {
        _zugriff = zugriff
        _tage = tage
        _naechte = naechte
        _vitale = vitale
        _gewichte = gewichte
        _workouts = workouts
    }

    var tagesAbfragen: [(von: String, bis: String)] { schloss.withLock { _tagesAbfragen } }
    var beobachterAnzahl: Int { schloss.withLock { _beobachter.count } }

    func setze(tage: [TagesWerte]) { schloss.withLock { _tage = tage } }
    func setze(zugriff: HealthZugriff) { schloss.withLock { _zugriff = zugriff } }

    /// Tut so, als hätte HealthKit neue Daten gemeldet.
    func melde() {
        let rueckrufe = schloss.withLock { _beobachter }
        for rueckruf in rueckrufe { rueckruf() }
    }

    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff { schloss.withLock { _zugriff } }

    func tagesWerte(von: String, bis: String) async -> [TagesWerte] {
        schloss.withLock {
            _tagesAbfragen.append((von, bis))
            return _tage.filter { $0.tag >= von && $0.tag <= bis }
        }
    }

    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] {
        schloss.withLock { _naechte.filter { $0.tag >= von && $0.tag <= bis } }
    }

    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] {
        schloss.withLock { (_vitale[art] ?? []).filter { $0.tag >= von && $0.tag <= bis } }
    }

    func gewichte(von: String, bis: String) async -> [GewichtsMesswert] {
        schloss.withLock { _gewichte.filter { $0.tag >= von && $0.tag <= bis } }
    }

    func workouts(von: String, bis: String) async -> [HealthWorkout] {
        schloss.withLock { _workouts.filter { Datum.text($0.start) >= von && Datum.text($0.start) <= bis } }
    }

    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) {
        schloss.withLock { _beobachter.append(aenderung) }
    }
}

// MARK: - Weitere Ports

final class FakeMitteiler: Mitteiler, @unchecked Sendable {
    struct Meldung: Equatable, Sendable {
        var id: String
        var titel: String
        var text: String
        var route: Route?
    }

    private let schloss = NSLock()
    private var _meldungen: [Meldung] = []
    private var erlaubt: Bool

    init(erlaubt: Bool = true) { self.erlaubt = erlaubt }

    var meldungen: [Meldung] { schloss.withLock { _meldungen } }

    func erlaubnisHolen() async -> Bool { erlaubt }

    func zeige(id: String, titel: String, text: String, route: Route?) async {
        schloss.withLock { _meldungen.append(Meldung(id: id, titel: titel, text: text, route: route)) }
    }
}

final class FakeLiveAnzeige: LiveAnzeige, @unchecked Sendable {
    private let schloss = NSLock()
    private var _staende: [TrainingLiveStand?] = []

    /// Alle gemeldeten Stände in der Reihenfolge; `nil` heißt "Anzeige beenden".
    var staende: [TrainingLiveStand?] { schloss.withLock { _staende } }

    func training(_ stand: TrainingLiveStand?) async { schloss.withLock { _staende.append(stand) } }
}

final class FakeBandDienst: BandDienst, @unchecked Sendable {
    private let schloss = NSLock()
    private var _status: BandStatus
    private var _muster: [BandMuster] = []

    init(status: BandStatus = BandStatus(verbunden: true, akkuProzent: 80, name: "Testband")) { _status = status }

    var muster: [BandMuster] { schloss.withLock { _muster } }

    func status() async -> BandStatus { schloss.withLock { _status } }
    func verbinde() async { schloss.withLock { _status.verbunden = true } }
    func trenne() async { schloss.withLock { _status.verbunden = false } }
    func vibriere(_ muster: BandMuster) async { schloss.withLock { _muster.append(muster) } }
}

final class FakeCoachMotor: CoachMotor, @unchecked Sendable {
    private let schloss = NSLock()
    private var texte: [String]
    private var _anfragen = 0
    let name: String
    private let frei: Bool

    init(name: String = "Fake", verfuegbar: Bool = true, texte: [String] = ["Antwort"]) {
        self.name = name
        frei = verfuegbar
        self.texte = texte
    }

    var anfragen: Int { schloss.withLock { _anfragen } }

    func verfuegbar() async -> Bool { frei }

    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
        let text: String = schloss.withLock {
            _anfragen += 1
            return texte.count > 1 ? texte.removeFirst() : (texte.first ?? "")
        }
        return CoachAntwort(text: text, chips: [])
    }
}

final class FakePartnerAustausch: PartnerAustausch, @unchecked Sendable {
    private let schloss = NSLock()
    private var _partner: PartnerStand
    private var _wuensche: [BandWunsch]
    private var _zusammenfassungen: [ZusammenfassungDatei] = []
    private var _erledigt: [[String]] = []
    private var _status: [BandStatusDatei] = []

    init(partner: PartnerStand = .nichtVerbunden, wuensche: [BandWunsch] = []) {
        _partner = partner
        _wuensche = wuensche
    }

    var zusammenfassungen: [ZusammenfassungDatei] { schloss.withLock { _zusammenfassungen } }
    var erledigt: [[String]] { schloss.withLock { _erledigt } }
    var status: [BandStatusDatei] { schloss.withLock { _status } }

    func partner(jetzt: Date) -> PartnerStand { schloss.withLock { _partner } }
    func schreibe(zusammenfassung: ZusammenfassungDatei) { schloss.withLock { _zusammenfassungen.append(zusammenfassung) } }
    func wuensche() -> [BandWunsch] { schloss.withLock { _wuensche } }
    func melde(erledigt ids: [String]) { schloss.withLock { _erledigt.append(ids) } }
    func schreibe(status: BandStatusDatei) { schloss.withLock { _status.append(status) } }
}

// MARK: - Beispieldaten

/// Erfundene Daten: das Profil heißt "Beispiel", alle Werte sind ausgedacht.
enum TestDaten {
    static let profilID = ProfilID(rawValue: "beispiel")

    private static func codiert(_ wert: some Encodable) -> Data { (try? JSONEncoder().encode(wert)) ?? Data("{}".utf8) }

    static func op(_ art: String, _ d: some Encodable, von: ProfilID = profilID, zeit: Date, id: String = UUID().uuidString) -> Op {
        Op(id: id, art: art, von: von, zeit: zeit, d: codiert(d))
    }

    /// Eine abgeschlossene Einheit: einchecken, eine Übung mit zwei abgehakten Sätzen, auschecken.
    static func gymOps(von: ProfilID = profilID, start: Date, session: String = "beispiel-einheit") -> [Op] {
        let satz1 = PlanSatz(wdh: 8, kg: 60, failure: false, ok: true)
        let satz2 = PlanSatz(wdh: 8, kg: 62.5, failure: false, ok: true)
        return [
            op("gym.checkin", GymD(session: session, tag: "push", start: start), von: von, zeit: start, id: "\(session)-ci"),
            op("gym.uebung", GymD(session: session, plan: "p1", uebung: "beispiel-bank", status: "start"), von: von, zeit: start + 60, id: "\(session)-u1"),
            op("gym.uebung", GymD(session: session, plan: "p1", uebung: "beispiel-bank", status: "satz", saetze: [satz1, satz2]), von: von, zeit: start + 600, id: "\(session)-u2"),
            op("gym.uebung", GymD(session: session, plan: "p1", uebung: "beispiel-bank", status: "fertig", saetze: [satz1, satz2]), von: von, zeit: start + 660, id: "\(session)-u3"),
            op("gym.checkout", GymD(session: session, ende: start + 3600, status: "ende"), von: von, zeit: start + 3600, id: "\(session)-co"),
        ]
    }

    static let haferflocken = Lebensmittel(id: "eigen-beispiel-hafer", name: "Beispiel-Haferflocken", fluessig: false,
                                           pro100: Naehrwerte(kcal: 370, protein: 13, kohlenhydrate: 59, fett: 7), portionMenge: 40, portionName: "Schale")

    /// Ein Frühstück mit 60 g Haferflocken.
    static func essenOps(von: ProfilID = profilID, datum: String, zeit: Date) -> [Op] {
        let eintrag = EssenEintrag(id: "beispiel-essen-\(datum)", datum: datum, mahlzeit: .fruehstueck, menge: 60, einheit: .g, lebensmittel: haferflocken, geloescht: nil)
        return [op("essen.setzen", eintrag, von: von, zeit: zeit, id: eintrag.id)]
    }

    /// Wasser (Zähler) und Gym-Haken für einen Tag.
    static func habitOps(von: ProfilID = profilID, datum: String, wasser: Int = 6, gym: Bool = true, zeit: Date) -> [Op] {
        func setzen(_ art: String, _ wert: Int) -> Op {
            op("habit.setzen", HabitSetzenD(art: art, datum: datum, wert: wert), von: von, zeit: zeit, id: "beispiel-\(art)-\(datum)")
        }
        return [setzen("wasser", wasser)] + (gym ? [setzen("gym", 1)] : [])
    }
}
