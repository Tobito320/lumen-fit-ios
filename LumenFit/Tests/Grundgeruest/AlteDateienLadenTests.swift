import XCTest
@testable import LumenFit

/// Dateien aus älteren oder neueren Ständen dürfen nie dazu führen, dass der Store leer startet oder Daten verliert.
@MainActor
final class AlteDateienLadenTests: XCTestCase {
    func testEinstellungenMitNurEinemFeldUndFremdenFeldernSindLesbar() throws {
        let ordner = try tempOrdner()
        try Data(#"{"thema":"wald","gibtEsNochNicht":{"a":1}}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let store = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(store.werte.thema, .wald)
        XCTAssertEqual(store.werte.erscheinung, .system)
        XCTAssertTrue(store.werte.haptik)
        XCTAssertFalse(store.werte.healthSchreiben)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("einstellungen.json.defekt").path))
    }

    func testEinUnbekanntesThemeErgibtDenStandardUndBehaeltDenRest() throws {
        let ordner = try tempOrdner()
        try Data(#"{"thema":"neonpink","haptik":false,"gewichtsEinheit":"stone"}"#.utf8).write(to: ordner.appendingPathComponent("einstellungen.json"))
        let store = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(store.werte.thema, .monochrom)
        XCTAssertFalse(store.werte.haptik, "der gültige Rest bleibt")
        XCTAssertEqual(store.werte.gewichtsEinheit, .kg)
    }

    func testEinstellungenUeberlebenNeustartUndMeldenAenderungen() async throws {
        let ordner = try tempOrdner()
        let kanal = EreignisKanal()
        let strom = kanal.strom()
        let store = EinstellungenStore(ordner: ordner, ereignisse: kanal)
        store.aendere { $0.thema = .glut; $0.mitteilungen["partner"] = true }
        store.aendere { $0.thema = .glut }   // keine Änderung, kein Ereignis, keine Schreibarbeit
        let neu = EinstellungenStore(ordner: ordner)
        XCTAssertEqual(neu.werte.thema, .glut)
        XCTAssertEqual(neu.werte.mitteilungen, ["partner": true])

        kanal.senden(.vordergrund)
        var anzahl = 0
        for await e in strom {
            if case .einstellungenGeaendert = e { anzahl += 1 }
            if case .vordergrund = e { break }
        }
        XCTAssertEqual(anzahl, 1)
    }

    func testZieleMitFehlendenUndFalschenFeldern() throws {
        let ordner = try tempOrdner()
        try Data(#"{"schritte":12000,"art":"turbo","kalorien":"viel"}"#.utf8).write(to: ordner.appendingPathComponent("ziele.json"))
        let store = ZieleStore(ordner: ordner)
        XCTAssertEqual(store.ziele.schritte, 12_000)
        XCTAssertEqual(store.ziele.art, .halten)
        XCTAssertEqual(store.ziele.kalorien, 2_400)
        XCTAssertEqual(store.ziele.schlafMinuten, 480)
    }

    func testKaputteDateiStartetLeerUndWirdGesichert() throws {
        let ordner = try tempOrdner()
        try Data("{kaputt".utf8).write(to: ordner.appendingPathComponent("ziele.json"))
        let store = ZieleStore(ordner: ordner)
        XCTAssertEqual(store.ziele, Ziele())
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("ziele.json.defekt").path))
    }

    func testOpsAusLoveaSicherungenMitSeqUndOhneBruchteileSindLesbar() throws {
        let ordner = try tempOrdner()
        let zeilen = [
            #"{"id":"a","seq":12,"art":"habit.setzen","von":"test-a","zeit":"2026-09-23T10:00:00.000Z","d":{"art":"wasser","datum":"2026-09-23","wert":5},"unbekannt":1}"#,
            #"{"id":"b","art":"habit.setzen","von":"test-a","zeit":"2026-09-23T10:05:00Z","d":{"art":"wasser","datum":"2026-09-23","wert":6}}"#,
        ]
        try (zeilen.joined(separator: "\n") + "\n").write(to: ordner.appendingPathComponent("ops.jsonl"), atomically: true, encoding: .utf8)
        var log = LokalerOpLog(datei: ordner.appendingPathComponent("ops.jsonl"))
        let ops = log.lade()
        XCTAssertEqual(ops.map(\.id), ["a", "b"])
        XCTAssertEqual(ops[1].zeit.timeIntervalSince1970, 1_790_157_900, accuracy: 0.001, "2026-09-23T10:05:00Z ohne Sekundenbruchteile")
        XCTAssertEqual(ops[0].daten(HabitSetzenD.self)?.wert, 5)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("ops.jsonl.defekt").path))
    }
}
