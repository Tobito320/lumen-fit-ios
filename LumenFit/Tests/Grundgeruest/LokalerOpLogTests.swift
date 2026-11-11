import XCTest
@testable import LumenFit

/// `ops.jsonl`: anhängen, doppelte Ids, kaputte und abgeschnittene Zeilen.
final class LokalerOpLogTests: XCTestCase {
    private struct Probe: Codable, Equatable { var wert: Int }

    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(12 * 3600)

    private func op(_ id: String, wert: Int, art: String = "probe.setzen", von: ProfilID = .testA) -> Op {
        Op(id: id, art: art, von: von, zeit: t0, d: (try? JSONEncoder().encode(Probe(wert: wert))) ?? Data())
    }

    func testAnhaengenUndNeuLadenBehaeltReihenfolgeUndInhalt() throws {
        let datei = try tempOrdner().appendingPathComponent("ops.jsonl")
        var log = LokalerOpLog(datei: datei)
        XCTAssertTrue(log.lade().isEmpty, "ohne Datei ist der Log leer")
        XCTAssertTrue(log.haengeAn(op("a", wert: 1)))
        XCTAssertTrue(log.haengeAn(op("b", wert: 2, von: .testB)))
        XCTAssertTrue(log.haengeAn(op("c", wert: 3)))

        var neu = LokalerOpLog(datei: datei)
        let ops = neu.lade()
        XCTAssertEqual(ops.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(ops.map(\.von), [.testA, .testB, .testA])
        XCTAssertEqual(ops.compactMap { $0.daten(Probe.self)?.wert }, [1, 2, 3])
        XCTAssertEqual(ops[0].zeit.timeIntervalSince1970, t0.timeIntervalSince1970, accuracy: 0.001)
    }

    func testVieleZeilenAufAllenKernenBehaltenReihenfolgeDoppelteUndKaputte() throws {
        let datei = try tempOrdner().appendingPathComponent("ops.jsonl")
        var log = LokalerOpLog(datei: datei)
        for i in 0..<1500 { XCTAssertTrue(log.haengeAn(op("o\(i)", wert: i))) }
        var text = try Data(contentsOf: datei)
        text.append(Data("{kaputt\n".utf8))
        text.append(try JSONEncoder().encode(op("o7", wert: 7)))   // doppelte Id
        text.append(Data("\n".utf8))
        try text.write(to: datei)

        var neu = LokalerOpLog(datei: datei)
        let ops = neu.lade()
        XCTAssertEqual(ops.map(\.id), (0..<1500).map { "o\($0)" })
        XCTAssertEqual(ops.compactMap { $0.daten(Probe.self)?.wert }, Array(0..<1500))
        XCTAssertTrue(FileManager.default.fileExists(atPath: datei.appendingPathExtension("defekt").path))
    }

    func testSchnellerLeserGleichtDemJSONDecoder() throws {
        let zeilen = [
            #"{"id":"a","art":"habit.setzen","von":"p1","zeit":"2026-11-11T07:31:37.717Z","d":{"art":"wasser","datum":"2026-11-11","wert":3}}"#,
            #"{"d":{"t":"x\"}y","l":[1,{"a":[2]}],"leer":{}},"zeit":"2026-02-28T23:59:59Z","von":"p1","art":"x","id":"b","seq":12,"f":[true,null]}"#,
            #"{ "id" : "c", "art":"x", "von":"p1", "zeit":"2026-11-11T08:31:37.500+01:00", "d" : null }"#,
            #"{"id":"e","art":"x","von":"p1","zeit":"2024-03-01T00:00:00.000-05:30","d":[1,2,"]"]}"#,
        ]
        for z in zeilen {
            let daten = Data(z.utf8)
            let decoder = JSONDecoder()
            decoder.userInfo[Op.zeileSchluessel] = daten
            let erwartet = try decoder.decode(Op.self, from: daten)
            let schnell = try XCTUnwrap(OpSchnellLeser.op(daten), z)
            XCTAssertEqual(schnell.id, erwartet.id)
            XCTAssertEqual(schnell.art, erwartet.art)
            XCTAssertEqual(schnell.von, erwartet.von)
            XCTAssertEqual(schnell.d, erwartet.d, z)
            XCTAssertEqual(schnell.zeit.timeIntervalSince1970, erwartet.zeit.timeIntervalSince1970, accuracy: 0.001, z)
        }
        let abgelehnt = [
            #"{"id":"a","art":"x","von":"p","zeit":"2026-11-11T07:31:37Z","d":{"a":"#,
            #"{"id":"a\"b","art":"x","von":"p","zeit":"2026-11-11T07:31:37Z","d":{}}"#,
            #"{"id":"a","art":"x","von":"p","zeit":"2026-11-11T07:31:37Z"}"#,
            #"{"id":"a","art":"x","von":"p","zeit":"11.11.2026","d":{}}"#,
            #"{kaputt"#,
        ]
        for z in abgelehnt { XCTAssertNil(OpSchnellLeser.op(Data(z.utf8)), z) }
    }

    func testFuegeAnMeldetAngehaengtDoppeltUndFehlgeschlagen() throws {
        let ordner = try tempOrdner()
        var log = LokalerOpLog(datei: ordner.appendingPathComponent("ops.jsonl"))
        XCTAssertEqual(log.fuegeAn(op("a", wert: 1)), .angehaengt)
        XCTAssertEqual(log.fuegeAn(op("a", wert: 2)), .doppelt, "doppelt ist kein Fehler")

        // Eine Datei, in die nichts geschrieben werden kann: der Pfad ist ein Ordner.
        let blockiert = ordner.appendingPathComponent("blockiert.jsonl", isDirectory: true)
        try FileManager.default.createDirectory(at: blockiert, withIntermediateDirectories: true)
        var kaputt = LokalerOpLog(datei: blockiert)
        XCTAssertEqual(kaputt.fuegeAn(op("b", wert: 1)), .fehlgeschlagen)
        XCTAssertFalse(kaputt.haengeAn(op("b", wert: 1)))
        XCTAssertEqual(kaputt.fuegeAn(op("b", wert: 1)), .fehlgeschlagen, "die Id gilt nicht als geschrieben: ein neuer Versuch ist möglich")
    }

    func testDoppelteIdWirdNichtGeschrieben() throws {
        let datei = try tempOrdner().appendingPathComponent("ops.jsonl")
        var log = LokalerOpLog(datei: datei)
        XCTAssertTrue(log.haengeAn(op("a", wert: 1)))
        XCTAssertFalse(log.haengeAn(op("a", wert: 99)), "gleiche Id: nichts schreiben")
        var neu = LokalerOpLog(datei: datei)
        let ops = neu.lade()
        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(ops.first?.daten(Probe.self)?.wert, 1, "die erste Op bleibt")
    }

    func testKaputteZeileWirdUebersprungenGesichertUndDieDateiRepariert() throws {
        let datei = try tempOrdner().appendingPathComponent("ops.jsonl")
        var log = LokalerOpLog(datei: datei)
        log.haengeAn(op("a", wert: 1))
        log.haengeAn(op("b", wert: 2))
        var inhalt = try String(contentsOf: datei, encoding: .utf8).components(separatedBy: "\n").filter { !$0.isEmpty }
        inhalt.insert("{das ist kein json", at: 1)
        try (inhalt.joined(separator: "\n") + "\n").write(to: datei, atomically: true, encoding: .utf8)

        var neu = LokalerOpLog(datei: datei)
        XCTAssertEqual(neu.lade().map(\.id), ["a", "b"])
        let sicherung = datei.appendingPathExtension("defekt")
        XCTAssertTrue(try String(contentsOf: sicherung, encoding: .utf8).contains("{das ist kein json"))

        // Danach ist die Datei sauber: nochmal laden findet nichts Defektes mehr, Anhängen geht.
        var wieder = LokalerOpLog(datei: datei)
        XCTAssertEqual(wieder.lade().map(\.id), ["a", "b"])
        XCTAssertFalse(try String(contentsOf: datei, encoding: .utf8).contains("kein json"))
        XCTAssertTrue(wieder.haengeAn(op("c", wert: 3)))
    }

    func testAbgeschnittenerLetzterSatzBeschaedigtDenNaechstenNicht() throws {
        let datei = try tempOrdner().appendingPathComponent("ops.jsonl")
        var log = LokalerOpLog(datei: datei)
        log.haengeAn(op("a", wert: 1))
        // Abbruch mitten im Schreiben: Datei endet ohne Zeilenumbruch.
        let handle = try FileHandle(forWritingTo: datei)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"id":"halb","art":"probe.setzen"#.utf8))
        try handle.close()

        var neu = LokalerOpLog(datei: datei)
        XCTAssertEqual(neu.lade().map(\.id), ["a"])
        XCTAssertTrue(neu.haengeAn(op("b", wert: 2)))
        var wieder = LokalerOpLog(datei: datei)
        XCTAssertEqual(wieder.lade().map(\.id), ["a", "b"])
    }

    func testBeiFehlenderEndzeileSetztAnhaengenEinenZeilenumbruch() throws {
        let datei = try tempOrdner().appendingPathComponent("ops.jsonl")
        var log = LokalerOpLog(datei: datei)
        log.haengeAn(op("a", wert: 1))
        var text = try String(contentsOf: datei, encoding: .utf8)
        text.removeLast()   // den Umbruch der ersten Zeile wegnehmen
        try text.write(to: datei, atomically: true, encoding: .utf8)

        var offen = LokalerOpLog(datei: datei)
        XCTAssertEqual(offen.lade().map(\.id), ["a"])
        XCTAssertTrue(offen.haengeAn(op("b", wert: 2)))
        var wieder = LokalerOpLog(datei: datei)
        XCTAssertEqual(wieder.lade().map(\.id), ["a", "b"])
    }

    func testDatenFeldBleibtInhaltlichGleich() throws {
        let datei = try tempOrdner().appendingPathComponent("ops.jsonl")
        let roh = Data(#"{"zahl":1.50,"liste":[1,2,3],"text":"Ä \" \\ ü"}"#.utf8)
        var log = LokalerOpLog(datei: datei)
        log.haengeAn(Op(id: "x", art: "probe.roh", von: .testA, zeit: t0, d: roh))
        var neu = LokalerOpLog(datei: datei)
        let gelesen = try XCTUnwrap(neu.lade().first)
        let vorher = try JSONSerialization.jsonObject(with: roh) as? NSDictionary
        let nachher = try JSONSerialization.jsonObject(with: gelesen.d) as? NSDictionary
        XCTAssertEqual(vorher, nachher)
    }
}
