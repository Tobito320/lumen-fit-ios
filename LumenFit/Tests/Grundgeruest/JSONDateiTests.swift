import XCTest
@testable import LumenFit

final class JSONDateiTests: XCTestCase {
    private struct Beispiel: Codable, Sendable, Equatable {
        var name: String
        var wann: Date
        var zahlen: [Int]
    }

    private let beispiel = Beispiel(name: "Ä-Test", wann: Date(timeIntervalSince1970: 1_790_000_000), zahlen: [1, 2, 3])

    func testSpeichernUndLadenBringtDasGleicheZurueck() throws {
        let datei = JSONDatei<Beispiel>(try tempOrdner().appendingPathComponent("a.json"))
        XCTAssertNil(datei.lade(), "ohne Datei nil")
        XCTAssertTrue(datei.speichere(beispiel))
        XCTAssertEqual(datei.lade(), beispiel)
    }

    func testDatumLiegtAlsSekundenseit1970InDerDatei() throws {
        let url = try tempOrdner().appendingPathComponent("a.json")
        JSONDatei<Beispiel>(url).speichere(beispiel)
        let objekt = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(objekt["wann"] as? Double, 1_790_000_000)
    }

    func testSpeichernLegtFehlendeOrdnerAnUndUeberschreibt() throws {
        let url = try tempOrdner().appendingPathComponent("tief/unten/a.json")
        let datei = JSONDatei<Beispiel>(url)
        XCTAssertTrue(datei.speichere(beispiel))
        var anders = beispiel
        anders.zahlen = [9]
        XCTAssertTrue(datei.speichere(anders))
        XCTAssertEqual(datei.lade()?.zahlen, [9])
    }

    func testDefekteDateiWirdGesichertStattVerloren() throws {
        let url = try tempOrdner().appendingPathComponent("a.json")
        try Data("{kaputt".utf8).write(to: url)
        let datei = JSONDatei<Beispiel>(url)
        XCTAssertNil(datei.lade())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "die defekte Datei ist weggeräumt")
        let sicherung = url.appendingPathExtension("defekt")
        XCTAssertEqual(try String(contentsOf: sicherung, encoding: .utf8), "{kaputt")
        XCTAssertTrue(datei.speichere(beispiel), "danach startet der Store sauber")
        XCTAssertEqual(datei.lade(), beispiel)
    }

    func testLoeschen() throws {
        let datei = JSONDatei<Beispiel>(try tempOrdner().appendingPathComponent("a.json"))
        datei.speichere(beispiel)
        datei.loesche()
        XCTAssertNil(datei.lade())
        datei.loesche()   // ein zweites Mal schadet nicht
    }
}
