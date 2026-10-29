import XCTest
@testable import LumenFit

/// Hilfen nur für die Tests des Moduls verbinden (die Hilfen des Grundgerüsts bleiben unberührt).
enum VerbindenTest {
    /// Donnerstag 29.10.2026, 10:00 Berliner Zeit (MEZ).
    static let jetzt = Datum.datum("2026-10-29").addingTimeInterval(10 * 3600)

    /// Ein Lovea-Gruppenordner mit den gewünschten Fixture-Dateien. `widget-stand.json` liegt im Gruppenordner, die Dateien des Vertrags im Unterordner `LumenFit`.
    /// Die Änderungszeit von `widget-stand.json` ist `geaendert` (Quelle A nimmt sie als `geschrieben`).
    static func gruppe(_ test: XCTestCase, widgetStand: Bool = false, geaendert: Date = jetzt.addingTimeInterval(-3600), partner: String? = nil,
                       wuensche: Bool = false) throws -> URL {
        let wurzel = try test.tempOrdner()
        let unter = wurzel.appendingPathComponent(LoveaVertrag.ordnerName, isDirectory: true)
        try FileManager.default.createDirectory(at: unter, withIntermediateDirectories: true)
        if widgetStand {
            let ziel = wurzel.appendingPathComponent(LoveaVertrag.widgetStandDatei)
            try FixtureOrt.daten("Verbinden", "lovea-widget-stand-beispiel.json").write(to: ziel)
            try FileManager.default.setAttributes([.modificationDate: geaendert], ofItemAtPath: ziel.path)
        }
        if let partner { try FixtureOrt.daten("Verbinden", partner).write(to: unter.appendingPathComponent(LoveaVertrag.partnerDatei)) }
        if wuensche { try FixtureOrt.daten("Verbinden", "band-wuensche-beispiel.json").write(to: unter.appendingPathComponent(LoveaVertrag.wuenscheDatei)) }
        return wurzel
    }

    /// Alle Dateien (relativ) unter dem Ordner, sortiert.
    static func dateien(_ ordner: URL) -> [String] {
        let sub = (try? FileManager.default.subpathsOfDirectory(atPath: ordner.path)) ?? []
        return sub.filter { var istOrdner: ObjCBool = false; FileManager.default.fileExists(atPath: ordner.appendingPathComponent($0).path, isDirectory: &istOrdner); return !istOrdner.boolValue }.sorted()
    }

    /// Ein `DatenSatz` ohne Umgebung: Ordner im Temp, Profil "beispiel".
    @MainActor
    static func daten(_ test: XCTestCase, bruecke: any PartnerAustausch = KeinePartnerBruecke(), uhr: @escaping Uhr = { jetzt }) throws -> DatenSatz {
        DatenSatz(profil: TestDaten.profilID, ordner: try test.tempOrdner(), ereignisse: EreignisKanal(), uhr: uhr, bruecke: bruecke)
    }
}

/// Die Zentrale als Fake: zeichnet die Aufrufe der Suche in der Reihenfolge auf (`retrieveConnectedPeripherals`, `retrievePeripherals`, Scan).
final class FakeZentrale: BandSuche {
    var verbundeneGeraete: [BandGeraetInfo] = []
    var bekannteGeraete: [BandGeraetInfo] = []
    private(set) var aufrufe: [String] = []

    func verbundene(dienst: String) -> [BandGeraetInfo] {
        aufrufe.append("verbundene")
        return verbundeneGeraete
    }

    func bekannte(_ kennungen: [UUID]) -> [BandGeraetInfo] {
        aufrufe.append("bekannte")
        return bekannteGeraete.filter { kennungen.contains($0.kennung) }
    }
}

/// Ein Funk, der nichts funkt, aber mitzählt und die gesendeten Pakete merkt.
final class FakeBandFunk: BandFunk, @unchecked Sendable {
    // @unchecked Sendable: jeder Zugriff auf die Felder läuft über `schloss`.
    private let schloss = NSLock()
    private var _aufrufe: [String] = []
    private var _gesendet: [Data] = []
    var aufrufe: [String] { schloss.withLock { _aufrufe } }
    var gesendet: [Data] { schloss.withLock { _gesendet } }
    func starten() { schloss.withLock { _aufrufe.append("starten") } }
    func trennen(vergessen: Bool) { schloss.withLock { _aufrufe.append(vergessen ? "vergessen" : "trennen") } }
    func schlafAnfragen() { schloss.withLock { _aufrufe.append("schlaf") } }
    func senden(_ daten: Data) { schloss.withLock { _aufrufe.append("senden"); _gesendet.append(daten) } }
}

/// Die Fabrik, die `TrackerModell` für den Funk bekommt: zählt, wie oft ein Funk (also ein `CBCentralManager`) entsteht, und reicht Ereignisse hinein.
final class FakeFunkFabrik: @unchecked Sendable {
    // @unchecked Sendable: jeder Zugriff auf die veränderlichen Felder läuft über `schloss`.
    private let schloss = NSLock()
    private var _anzahl = 0
    private var _melden: (@Sendable (TrackerEreignis) -> Void)?
    let funk = FakeBandFunk()

    var anzahl: Int { schloss.withLock { _anzahl } }

    func baue(_ melden: @escaping @Sendable (TrackerEreignis) -> Void) -> any BandFunk {
        schloss.withLock { _anzahl += 1; _melden = melden }
        return funk
    }

    /// Tut so, als meldete der Funk etwas.
    func melde(_ ereignis: TrackerEreignis) { schloss.withLock { _melden }?(ereignis) }
}
