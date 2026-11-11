import XCTest
@testable import LumenFit

/// Die Stats-Felder in `Einstellungen` (10.11.2026): alte Dateien ohne sie laden privat, neue Dateien behalten die Wahl, Unbekanntes wird "unbekannt".
@MainActor
final class AlteDateienLadenStatsTests: XCTestCase {
    private func laden(_ json: String) throws -> Einstellungen {
        let ordner = try tempOrdner()
        try Data(json.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        return EinstellungenStore(ordner: ordner).werte
    }

    func testAlteDateiOhneStatsFelderIstPrivat() throws {
        let werte = try laden(#"{"thema":"wald","haptik":false}"#)
        XCTAssertEqual(werte.thema, .wald, "der Rest bleibt")
        XCTAssertFalse(werte.statsFreunde)
        XCTAssertFalse(werte.statsOeffentlich)
        XCTAssertNil(werte.statsSpitzname)
        XCTAssertNil(werte.trainingsErfahrung)
    }

    func testNeueDateiBehaeltStatsWahlUndUnbekanntesWirdNil() throws {
        let werte = try laden(#"{"statsFreunde":true,"statsOeffentlich":true,"statsSpitzname":"Eisenfaust","trainingsErfahrung":"bisZweiJahre"}"#)
        XCTAssertTrue(werte.statsFreunde)
        XCTAssertTrue(werte.statsOeffentlich)
        XCTAssertEqual(werte.statsSpitzname, "Eisenfaust")
        XCTAssertEqual(werte.trainingsErfahrung, .bisZweiJahre)
        let fremd = try laden(#"{"trainingsErfahrung":"zehnJahre","statsFreunde":"ja"}"#)
        XCTAssertNil(fremd.trainingsErfahrung)
        XCTAssertFalse(fremd.statsFreunde)
        var e = Einstellungen()
        e.statsSpitzname = "Eisenfaust"
        e.trainingsErfahrung = .laenger
        let zurueck = try JSONDecoder().decode(Einstellungen.self, from: JSONEncoder().encode(e))
        XCTAssertEqual(zurueck, e, "geschrieben und wieder gelesen")
    }

    /// Der Cache `stats-server.json` aus 1.0 (ohne Schritte) lädt weiter; neue Einträge tragen Schritte heute und im Monat.
    func testStatsCacheOhneUndMitSchritten() throws {
        let umgebung = AppUmgebung.vorschau()
        let alt = #"{"montag":"2026-11-09","ich":{"freunde":true,"oeffentlich":false,"spitzname":null,"ausgeblendet":false},"freunde":[{"id":"aaaa","name":"Freund 1","punkte":75,"trainings":3,"sets":40,"serie":4,"rekorde":{}}],"alle":[{"id":"bbbb","name":"Eisenfaust","jahr":1,"punkte":30,"trainings":2,"sets":10,"serie":4,"ich":false}],"rekorde":{}}"#
        try FileManager.default.createDirectory(at: umgebung.konto.ordner, withIntermediateDirectories: true)
        try Data(alt.utf8).write(to: umgebung.konto.ordner.appendingPathComponent(StatsDienst.dateiName))
        let a = try XCTUnwrap(StatsDienst(umgebung: umgebung).antwort)
        XCTAssertEqual(a.freunde.first?.punkte, 75, "der Rest bleibt")
        XCTAssertNil(a.freunde.first?.schritteHeute)
        XCTAssertNil(a.alle.first?.schritteMonat)
        let neu = alt.replacingOccurrences(of: #""rekorde":{}}],"alle""#, with: #""rekorde":{},"schritteHeute":6240,"schritteMonat":70000}],"alle""#)
            .replacingOccurrences(of: #""ich":false}"#, with: #""ich":false,"schritteHeute":0,"schritteMonat":150000}"#)
        let b = try JSONDecoder().decode(StatsAntwort.self, from: Data(neu.utf8))
        XCTAssertEqual(b.freunde.first?.schritteHeute, 6_240)
        XCTAssertEqual(b.freunde.first?.schritteMonat, 70_000)
        XCTAssertEqual(b.alle.first?.schritteHeute, 0)
        XCTAssertEqual(b.alle.first?.schritteMonat, 150_000)
        XCTAssertEqual(try JSONDecoder().decode(StatsAntwort.self, from: JSONEncoder().encode(b)), b, "geschrieben und wieder gelesen")
    }
}
