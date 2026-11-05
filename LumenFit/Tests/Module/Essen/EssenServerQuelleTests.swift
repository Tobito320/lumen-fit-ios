import XCTest
@testable import LumenFit

/// Die Produktdatenbank des Lumen-Servers ohne Netz: `SkriptLader` antwortet mit Fixture-JSON, ein Zugang aus dem Test liefert die Verbindung.
final class EssenServerQuelleTests: XCTestCase {
    private struct Zugang: EssenKiZugang {
        let v: EssenKiVerbindung?
        func verbindung() -> EssenKiVerbindung? { v }
    }

    private let verbindung = EssenKiVerbindung(server: URL(string: "https://example.invalid/api")!, kopfzeilen: ["X-App-Key": "k", "X-Konto": "konto"])

    private func quelle(_ lader: SkriptLader, verbunden: Bool = true) -> EssenServerQuelle {
        EssenServerQuelle(zugang: Zugang(v: verbunden ? verbindung : nil), lader: lader)
    }

    func testSucheGehtAnEssenSucheMitKopfzeilen() async throws {
        let lader = try SkriptLader(fixture: "Essen", "essen-server-suche-skyr.json")
        _ = try await quelle(lader).suche("  skyr ehrmann ")
        let r = try XCTUnwrap(lader.anfragen.first)
        XCTAssertEqual(r.url?.path, "/api/essen/suche")
        let teile = try XCTUnwrap(URLComponents(url: try XCTUnwrap(r.url), resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(teile.first { $0.name == "q" }?.value, "skyr ehrmann")
        XCTAssertEqual(teile.first { $0.name == "n" }?.value, "30")
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-App-Key"), "k")
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-Konto"), "konto")
    }

    func testTrefferWerdenAlsOffLebensmittelAbgebildetUndKaputteUebersprungen() async throws {
        let treffer = try await quelle(try SkriptLader(fixture: "Essen", "essen-server-suche-skyr.json")).suche("skyr")
        XCTAssertEqual(treffer.map(\.id), ["off-4005500123456", "off-4005500123457", "off-4005500123459"], "der Treffer ohne kcal fehlt, die anderen bleiben")
        let e = treffer[0]
        XCTAssertEqual(e.name, "High Protein Skyr Natur")
        XCTAssertEqual(e.marke, "Ehrmann")
        XCTAssertEqual(e.barcode, "4005500123456")
        XCTAssertEqual(e.quelle, "off")
        XCTAssertEqual(e.pro100.kcal, 55, accuracy: 0.001)
        XCTAssertEqual(e.pro100.salz ?? 0, 0.09, accuracy: 0.001)
        XCTAssertEqual(e.portionMenge, 125)
        XCTAssertEqual(e.portionName, "Becher")
        XCTAssertEqual(e.packungMenge, 250)
        XCTAssertFalse(e.fluessig)
        let mango = treffer[1]
        XCTAssertNil(mango.marke)
        XCTAssertNil(mango.portionName, "\"100g\" ist kein Name")
        XCTAssertEqual(mango.packungMenge, 1500)
        XCTAssertTrue(mango.fluessig)
        XCTAssertNil(mango.pro100.zucker)
    }

    func testPackungAusMenge() {
        XCTAssertEqual(EssenServerQuelle.packung("250 g")?.menge, 250)
        XCTAssertEqual(EssenServerQuelle.packung("1,5 kg")?.menge, 1500)
        XCTAssertEqual(EssenServerQuelle.packung("330ml")?.fluessig, true)
        XCTAssertNil(EssenServerQuelle.packung("6 Stück"))
        XCTAssertNil(EssenServerQuelle.packung(nil))
    }

    func testBarcodeBekanntUnbekanntUndFehler() async throws {
        let lader = try SkriptLader(fixture: "Essen", "essen-server-barcode-skyr.json")
        let l = try await quelle(lader).produkt("4005500123456")
        XCTAssertEqual(l?.id, "off-4005500123456")
        XCTAssertEqual(lader.anfragen.first?.url?.path, "/api/essen/barcode/4005500123456")
        let unbekannt = try await quelle(SkriptLader(status: 404, daten: Data(#"{"produkt":null}"#.utf8))).produkt("4099999999994")
        XCTAssertNil(unbekannt)
        do { _ = try await quelle(SkriptLader(status: 500, daten: Data())).produkt("4005500123456"); XCTFail("Fehler erwartet") } catch {
            XCTAssertEqual(error as? EssenServerFehler, .server(500))
        }
    }

    func testKeinZugangBeiFehlenderVerbindungUnd401Und403() async {
        for (verbunden, status) in [(false, 200), (true, 401), (true, 403)] {
            do { _ = try await quelle(SkriptLader(status: status, daten: Data()), verbunden: verbunden).suche("skyr"); XCTFail("Fehler erwartet") } catch {
                XCTAssertEqual(error as? EssenServerFehler, .keinZugang, "\(verbunden) \(status)")
            }
        }
    }

    func testNetzfehlerUndUnlesbareAntwort() async {
        do { _ = try await quelle(SkriptLader.fehler(.notConnectedToInternet)).suche("skyr"); XCTFail("Fehler erwartet") } catch {
            XCTAssertEqual(error as? EssenServerFehler, .netz)
        }
        do { _ = try await quelle(SkriptLader(status: 200, daten: Data("kein json".utf8))).suche("skyr"); XCTFail("Fehler erwartet") } catch {
            XCTAssertEqual(error as? EssenServerFehler, .netz)
        }
    }

    func testLeererTextFragtNichts() async throws {
        let lader = try SkriptLader(fixture: "Essen", "essen-server-suche-skyr.json")
        let leer = try await quelle(lader).suche("   ")
        XCTAssertTrue(leer.isEmpty)
        XCTAssertEqual(lader.aufrufe, 0)
    }
}
