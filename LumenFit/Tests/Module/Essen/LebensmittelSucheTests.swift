import XCTest
@testable import LumenFit

@MainActor
final class LebensmittelSucheTests: XCTestCase {
    private func bls() throws -> [Lebensmittel] {
        try JSONDecoder().decode([Lebensmittel].self, from: FixtureOrt.daten("Essen", "bls-4-0-lovea-auszug.json"))
    }

    private func suche(_ lader: SkriptLader, uhr: TestUhr = TestUhr(), speicher: @escaping @MainActor (String) -> Lebensmittel? = { _ in nil }) throws -> LebensmittelSuche {
        LebensmittelSuche(index: LebensmittelIndex(testDaten: try bls()), off: OpenFoodFactsQuelle(lader: lader, uhr: uhr.uhr, version: "1.0"), speicher: speicher)
    }

    // MARK: - BLS lokal zuerst, kein Netz ohne Nutzeraktion

    func testBLSFindetHaferOhneNetz() throws {
        let lader = SkriptLader.fehler(.notConnectedToInternet)
        let s = try suche(lader)
        s.eingabe("Hafer", vorne: [])
        XCTAssertEqual(s.stand.sichtbar.first?.id, "bls-C131000")
        XCTAssertTrue(s.stand.sichtbar.allSatisfy { $0.quelle == "bls" })
        XCTAssertEqual(lader.aufrufe, 0, "Tippen fragt nie das Netz")
    }

    /// Idee 42: Haferflocken, Ei und Reis gibt es ohne Netz, im vollen BLS (7.140 Einträge).
    func testHaferflockenEiUndReisImVollenBLSOhneNetz() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../../Resources/Daten/lebensmittel-basis.json").standardizedFileURL
        let alle = try JSONDecoder().decode([Lebensmittel].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(alle.count, 7000)
        let lader = SkriptLader.fehler(.notConnectedToInternet)
        let s = LebensmittelSuche(index: LebensmittelIndex(testDaten: alle), off: OpenFoodFactsQuelle(lader: lader), speicher: { _ in nil })
        s.eingabe("Haferflocken", vorne: [])
        XCTAssertEqual(s.stand.sichtbar.first?.name, "Hafer Flocken")
        s.eingabe("Ei", vorne: [])
        XCTAssertTrue(s.stand.sichtbar.prefix(12).contains { $0.name == "Hühnerei roh" }, "Ei findet das Hühnerei, nicht nur Eiswein")
        s.eingabe("Apfel", vorne: [])
        XCTAssertEqual(s.stand.sichtbar.first?.name, "Apfel roh")
        s.eingabe("Reis", vorne: [])
        XCTAssertTrue(s.stand.sichtbar.first?.name.hasPrefix("Reis") == true)
        XCTAssertEqual(lader.aufrufe, 0)
    }

    func testTeilungenNurFuerLangeEinzelWoerter() {
        XCTAssertEqual(LebensmittelSuche.teilungen("Reis"), [])
        XCTAssertEqual(LebensmittelSuche.teilungen("Hafer Flocken"), [])
        XCTAssertTrue(LebensmittelSuche.teilungen("haferflocken").contains("hafer flocken"))
        XCTAssertEqual(LebensmittelSuche.teilungen("abcdefg"), ["abc defg", "abcd efg"])
    }

    func testVorneStehtVorBLS() throws {
        let favorit = Lebensmittel(id: "eigen-1", name: "Hafer Mix", pro100: Naehrwerte(kcal: 300, protein: 10, kohlenhydrate: 50, fett: 5))
        let s = try suche(SkriptLader.fehler(.notConnectedToInternet))
        s.eingabe("Hafer", vorne: [favorit])
        XCTAssertEqual(s.stand.sichtbar.first?.id, "eigen-1")
    }

    func testGrundlebensmittelStehtVorZusammensetzungen() {
        let mus = Lebensmittel(id: "bls-1", name: "Apfelmus", pro100: .null)
        let roh = Lebensmittel(id: "bls-2", name: "Apfel roh", pro100: .null)
        let kuchen = Lebensmittel(id: "eigen-1", name: "Apfelkuchen", pro100: .null)
        let s = LebensmittelSuche(index: LebensmittelIndex(testDaten: [mus, roh]),
                                  off: OpenFoodFactsQuelle(lader: SkriptLader.fehler(.notConnectedToInternet)), speicher: { _ in nil })
        s.eingabe("Apfel", vorne: [])
        XCTAssertEqual(s.stand.sichtbar.map(\.id), ["bls-2", "bls-1"], "Apfel roh vor Apfelmus, obwohl der Name länger ist")
        s.eingabe("Apfel", vorne: [kuchen])
        XCTAssertEqual(s.stand.sichtbar.first?.id, "eigen-1", "Eigene und Favoriten bleiben vorn")
    }

    // MARK: - Online nur auf "Suchen"

    func testOnlineSuchenHaengtTrefferHintenAn() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-search-haferflocken.json")
        let s = try suche(lader)
        s.eingabe("Hafer", vorne: [])
        let vorher = s.stand.sichtbar.map(\.id)
        XCTAssertFalse(vorher.isEmpty)
        XCTAssertEqual(lader.aufrufe, 0)
        await s.onlineSuchen()
        XCTAssertEqual(lader.aufrufe, 1)
        XCTAssertEqual(Array(s.stand.sichtbar.map(\.id).prefix(vorher.count)), vorher, "nichts springt")
        XCTAssertGreaterThan(s.stand.sichtbar.count, vorher.count)
        XCTAssertEqual(s.online, .fertig(treffer: 3))
    }

    func testOnlineSuchenZuKurzFragtNichts() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-search-haferflocken.json")
        let s = try suche(lader)
        s.eingabe("h", vorne: [])
        await s.onlineSuchen()
        XCTAssertEqual(lader.aufrufe, 0)
    }

    func testOnlineOffline() async throws {
        let s = try suche(SkriptLader.fehler(.notConnectedToInternet))
        s.eingabe("Haferflocken", vorne: [])
        await s.onlineSuchen()
        XCTAssertEqual(s.online, .offline)
        XCTAssertFalse(s.stand.sichtbar.isEmpty, "die BLS-Treffer bleiben stehen")
    }

    func testOnlineLimit() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-search-haferflocken.json")
        let s = try suche(lader)
        s.eingabe("Haferflocken", vorne: [])
        for _ in 0..<10 { await s.onlineSuchen() }
        await s.onlineSuchen()
        guard case .limit(let sekunden) = s.online else { return XCTFail("Limit erwartet, war \(s.online)") }
        XCTAssertGreaterThan(sekunden, 0)
        XCTAssertEqual(lader.aufrufe, 10)
    }

    // MARK: - Barcode

    func testBarcodeBekanntAusOFF() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-v2-product-4008400402222.json")
        let s = try suche(lader)
        let r = await s.barcode("4008400402222")
        guard case .gefunden(let l) = r else { return XCTFail("gefunden erwartet, war \(r)") }
        XCTAssertEqual(l.id, "off-4008400402222")
        XCTAssertEqual(EssenQuelle.zeile(l), "Quelle: Open Food Facts")
    }

    func testBarcodeUnbekanntFuehrtZurHandeingabe() async throws {
        let s404 = try suche(SkriptLader(status: 404, daten: Data()))
        let r404 = await s404.barcode("4099999999994")
        XCTAssertEqual(r404, .unbekannt("4099999999994"))
        let sNull = try suche(try SkriptLader(fixture: "Essen", "off-v2-product-nicht-gefunden.json"))
        let rNull = await sNull.barcode("4099999999994")
        XCTAssertEqual(rNull, .unbekannt("4099999999994"))
    }

    func testBarcodeAusDemSpeicherBrauchtKeinNetz() async throws {
        let bekannt = Lebensmittel(id: "off-4311501679715", name: "Skyr", barcode: "4311501679715", pro100: Naehrwerte(kcal: 65, protein: 11, kohlenhydrate: 4, fett: 0.2))
        let lader = SkriptLader.fehler(.notConnectedToInternet)
        let s = try suche(lader, speicher: { $0 == "4311501679715" ? bekannt : nil })
        let r = await s.barcode("4311501679715")
        XCTAssertEqual(r, .gefunden(bekannt))
        XCTAssertEqual(lader.aufrufe, 0)
    }

    func testLetzterTrefferWirdGemerkt() async throws {
        let lader = try SkriptLader(fixture: "Essen", "off-v2-product-4008400402222.json")
        let s = try suche(lader)
        _ = await s.barcode("4008400402222")
        XCTAssertEqual(s.letzterTreffer?.code, "4008400402222")
        let zweites = await s.barcode("4008400402222")
        guard case .gefunden = zweites else { return XCTFail("gefunden erwartet") }
        XCTAssertEqual(lader.aufrufe, 1, "der zweite Scan fragt nicht noch einmal")
    }

    func testBarcodeOhneNetzIstOffline() async throws {
        let s = try suche(SkriptLader.fehler(.notConnectedToInternet))
        let r = await s.barcode("4008400402222")
        XCTAssertEqual(r, .offline("4008400402222"))
    }

    // MARK: - Quelle

    func testQuellenzeile() throws {
        let hafer = try XCTUnwrap(bls().first)
        XCTAssertEqual(EssenQuelle.zeile(hafer), "Quelle: BLS")
        let off = Lebensmittel(id: "off-1", name: "X", pro100: .null)
        XCTAssertEqual(EssenQuelle.zeile(off), "Quelle: Open Food Facts")
        let eigen = Lebensmittel(id: "eigen-1", name: "X", pro100: .null)
        XCTAssertEqual(EssenQuelle.zeile(eigen), "Quelle: von dir eingetragen")
        let rezept = Lebensmittel(id: "rezept-1", name: "X", pro100: .null)
        XCTAssertEqual(EssenQuelle.zeile(rezept), "Quelle: dein Rezept")
    }
}
