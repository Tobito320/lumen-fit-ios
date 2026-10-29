import XCTest
@testable import LumenFit

/// Open Food Facts nur über `SkriptLader` und die echten, gekürzten Antworten aus `Fixtures/Essen`, nie über das Netz.
final class OpenFoodFactsQuelleTests: XCTestCase {
    private func quelle(_ lader: SkriptLader, uhr: TestUhr = TestUhr()) -> OpenFoodFactsQuelle {
        OpenFoodFactsQuelle(lader: lader, uhr: uhr.uhr, version: "9.9")
    }

    func testBekannterBarcode() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-v2-product-4008400402222.json")
        let ergebnis = try await quelle(lader).produkt("4008400402222")
        let l = try XCTUnwrap(ergebnis)
        XCTAssertEqual(l.id, "off-4008400402222")
        XCTAssertEqual(l.barcode, "4008400402222")
        XCTAssertEqual(l.pro100.kcal, 539, accuracy: 0.01)
        XCTAssertEqual(l.pro100.protein, 6.3, accuracy: 0.01)
        XCTAssertEqual(l.quelle, "off")
        XCTAssertEqual(lader.aufrufe, 1)
    }

    func testAnfrageHatUserAgentFelderUndKeineMail() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-v2-product-4008400402222.json")
        _ = try await quelle(lader).produkt("4008400402222")
        let anfrage = try XCTUnwrap(lader.anfragen.first)
        let agent = try XCTUnwrap(anfrage.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertEqual(agent, "LumenFit/9.9 (iOS)")
        XCTAssertFalse(agent.contains("@"))
        XCTAssertFalse(agent.contains("http"), "keine Adresse im Namen der App")
        let url = try XCTUnwrap(anfrage.url)
        XCTAssertEqual(url.host, "world.openfoodfacts.org")
        XCTAssertEqual(url.path, "/api/v2/product/4008400402222.json")
        XCTAssertTrue(url.query?.contains("fields=") == true)
        XCTAssertEqual(anfrage.httpMethod ?? "GET", "GET")
    }

    func testUpcABekommtFuehrendeNull() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-v2-product-4008400402222.json")
        _ = try await quelle(lader).produkt("012345678905")
        XCTAssertEqual(lader.anfragen.first?.url?.path, "/api/v2/product/0012345678905.json")
    }

    func testUnbekanntMit404() async throws {
        let lader = SkriptLader(status: 404, daten: Data())
        let l = try await quelle(lader).produkt("4099999999994")
        XCTAssertNil(l)
    }

    func testUnbekanntMitStatusNull() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-v2-product-nicht-gefunden.json")
        let l = try await quelle(lader).produkt("4099999999994")
        XCTAssertNil(l)
        XCTAssertEqual(lader.aufrufe, 1, "kein Wiederholversuch bei status 0")
    }

    func testNurKilojouleWirdUmgerechnet() async throws {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: FixtureOrt.daten("Essen", "off-v2-product-4008400402222.json")) as? [String: Any])
        var produkt = try XCTUnwrap(json["product"] as? [String: Any])
        var n = try XCTUnwrap(produkt["nutriments"] as? [String: Any])
        for schluessel in n.keys where schluessel.hasPrefix("energy-kcal") { n[schluessel] = nil }
        produkt["nutriments"] = n
        json["product"] = produkt
        let lader = SkriptLader(status: 200, daten: try JSONSerialization.data(withJSONObject: json))
        let ergebnis = try await quelle(lader).produkt("4008400402222")
        let l = try XCTUnwrap(ergebnis)
        XCTAssertEqual(l.pro100.kcal, 2252 / 4.184, accuracy: 0.01)
    }

    func testEinWiederholversuchBeiHTTP500() async throws {
        let ok = try FixtureOrt.daten("Essen", "off-v2-product-4008400402222.json")
        let lader = SkriptLader([.init(status: 500, daten: Data(), fehler: nil), .init(status: 200, daten: ok, fehler: nil)])
        let l = try await quelle(lader).produkt("4008400402222")
        XCTAssertNotNil(l)
        XCTAssertEqual(lader.aufrufe, 2)
    }

    func testZweimal500IstServerfehlerOhneDrittenVersuch() async {
        let lader = SkriptLader(status: 500, daten: Data())
        do {
            _ = try await quelle(lader).produkt("4008400402222")
            XCTFail("Serverfehler erwartet")
        } catch {
            XCTAssertEqual(error as? OffFehler, .server(500))
        }
        XCTAssertEqual(lader.aufrufe, 2)
    }

    func testProduktLimitFuenfzehnJeMinute() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-v2-product-4008400402222.json")
        let uhr = TestUhr()
        let q = quelle(lader, uhr: uhr)
        for _ in 0..<15 { _ = try await q.produkt("4008400402222") }
        XCTAssertEqual(lader.aufrufe, 15)
        do {
            _ = try await q.produkt("4008400402222")
            XCTFail("Limit erwartet")
        } catch {
            guard case .limit(let sekunden)? = error as? OffFehler else { return XCTFail("falscher Fehler \(error)") }
            XCTAssertEqual(sekunden, 60)
        }
        XCTAssertEqual(lader.aufrufe, 15, "keine 16. Abfrage")
        uhr.vor(sekunden: 61)
        _ = try await q.produkt("4008400402222")
        XCTAssertEqual(lader.aufrufe, 16)
    }

    func testWiederholversuchZaehltAlsAbfrage() async throws {
        let ok = try FixtureOrt.daten("Essen", "off-v2-product-4008400402222.json")
        let lader = SkriptLader([.init(status: 500, daten: Data(), fehler: nil), .init(status: 200, daten: ok, fehler: nil)])
        let q = quelle(lader)
        _ = try await q.produkt("4008400402222")      // 2 Abfragen
        for _ in 0..<13 { _ = try await q.produkt("4008400402222") }
        XCTAssertEqual(lader.aufrufe, 15)
        do { _ = try await q.produkt("4008400402222"); XCTFail("Limit erwartet") } catch { XCTAssertNotNil(error as? OffFehler) }
    }

    func testSucheNutztSuchadresseUndLiefertTreffer() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-search-haferflocken.json")
        let treffer = try await quelle(lader).suche("Haferflocken")
        XCTAssertFalse(treffer.isEmpty)
        XCTAssertTrue(treffer.allSatisfy { $0.quelle == "off" && $0.id.hasPrefix("off-") })
        let url = try XCTUnwrap(lader.anfragen.first?.url)
        XCTAssertEqual(url.host, "search.openfoodfacts.org")
        XCTAssertEqual(url.path, "/search")
        XCTAssertTrue(url.query?.contains("q=Haferflocken") == true)
        // Das erste Fixture-Produkt hat nur Kilojoule (1565): 374 kcal.
        let erste = try XCTUnwrap(treffer.first { $0.barcode == "4013200254742" })
        XCTAssertEqual(erste.pro100.kcal, 1565 / 4.184, accuracy: 0.01)
    }

    func testSucheLimitZehnJeMinuteUndLeererTextOhneAbfrage() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-search-haferflocken.json")
        let q = quelle(lader)
        let leer = try await q.suche("   ")
        XCTAssertTrue(leer.isEmpty)
        XCTAssertEqual(lader.aufrufe, 0)
        for _ in 0..<10 { _ = try await q.suche("Haferflocken") }
        do { _ = try await q.suche("Haferflocken"); XCTFail("Limit erwartet") } catch { XCTAssertNotNil(error as? OffFehler) }
        XCTAssertEqual(lader.aufrufe, 10)
    }

    func testSucheWiederholtEinmalBeiHTTP500() async throws {
        let ok = try FixtureOrt.daten("Essen", "off-search-haferflocken.json")
        let lader = SkriptLader([.init(status: 500, daten: Data(), fehler: nil), .init(status: 200, daten: ok, fehler: nil)])
        let treffer = try await quelle(lader).suche("Haferflocken")
        XCTAssertFalse(treffer.isEmpty)
        XCTAssertEqual(lader.aufrufe, 2)
    }

    func testRateFensterGibtWartezeitZurueck() {
        var fenster = EssenRateFenster(limit: 2)
        let t0 = Date(timeIntervalSince1970: 1000)
        XCTAssertNil(fenster.versuche(jetzt: t0))
        XCTAssertNil(fenster.versuche(jetzt: t0.addingTimeInterval(10)))
        XCTAssertEqual(fenster.versuche(jetzt: t0.addingTimeInterval(20)), 40)
        XCTAssertNil(fenster.versuche(jetzt: t0.addingTimeInterval(61)))
    }
}
