import XCTest
@testable import LumenFit

/// Der Crew-Dienst ohne Netz: Cache lesen, kaputter Cache kippt nichts, neue Herausforderung nach den Regeln des Servers, Demo nur in DEBUG.
@MainActor
final class CrewDienstTests: XCTestCase {
    func testCacheWirdBeimStartGelesenKaputterIstLeer() throws {
        let umgebung = AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)
        let datei = umgebung.konto.ordner.appendingPathComponent(CrewDienst.dateiName)
        try FileManager.default.createDirectory(at: umgebung.konto.ordner, withIntermediateDirectories: true)
        let a = CrewAntwort(reaktionen: [CrewReaktion(id: "r", von: "v", name: "Freund", art: .stark, ziel: "einheit:2026-11-09", zeit: Date(timeIntervalSince1970: 1_000))])
        try LoveaVertrag.encoder().encode(a).write(to: datei)
        XCTAssertEqual(CrewDienst(umgebung: umgebung).antwort, a)
        try Data("kaputt".utf8).write(to: datei)
        XCTAssertNil(CrewDienst(umgebung: umgebung).antwort)
    }

    func testNeueHerausforderungNachDenRegelnDesServers() throws {
        let jetzt = CrewTestDaten.jetzt
        let duell = CrewNeueHerausforderung(art: .saetze, modus: .gegen, tage: 7, ziel: 50, uebung: "Kniebeuge", einladen: ["v"], jetzt: jetzt)
        XCTAssertNil(duell.ziel, "Ziel nur bei gemeinsam")
        XCTAssertNil(duell.uebung)
        XCTAssertNil(duell.ende)
        XCTAssertEqual(duell.tage, 7)
        let sonntag = CrewNeueHerausforderung(art: .uebung, modus: .gemeinsam, tage: nil, ziel: nil, uebung: "Kniebeuge", einladen: Array(repeating: "v", count: 12), jetzt: jetzt)
        XCTAssertNil(sonntag.tage)
        XCTAssertEqual(sonntag.ende.flatMap(LoveaVertrag.isoDatum).map(Datum.text), "2025-11-02")
        XCTAssertEqual(sonntag.ziel, 1)
        XCTAssertEqual(sonntag.uebung, "Kniebeuge")
        XCTAssertEqual(sonntag.einladen.count, 9)
        let json = try XCTUnwrap(String(data: try JSONEncoder().encode(duell), encoding: .utf8))
        XCTAssertFalse(json.contains("ziel"))
        XCTAssertFalse(json.contains("ende"))
    }

    #if DEBUG
    func testDemoHatZweiHerausforderungenUndDreiReaktionenOhneEchteNamen() {
        let a = CrewDemo.antwort(jetzt: CrewTestDaten.jetzt)
        XCTAssertEqual(a.herausforderungen.count, 2)
        XCTAssertEqual(a.reaktionen.count, 3)
        XCTAssertTrue(a.reaktionen.allSatisfy { $0.name.hasPrefix("Beispiel Freund") })
        XCTAssertTrue(a.herausforderungen.allSatisfy { CrewLogik.istId($0.id) })
        XCTAssertEqual(CrewLogik.einstiegStand(a, jetzt: CrewTestDaten.jetzt), "Duell: du führst")
        let umgebung = AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)
        XCTAssertEqual(CrewDienst(umgebung: umgebung, demo: true).antwort?.herausforderungen.count, 2)
    }
    #endif
}
