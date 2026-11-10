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
}
