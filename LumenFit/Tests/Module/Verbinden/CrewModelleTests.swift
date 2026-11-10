import XCTest
@testable import LumenFit

/// `GET /freunde` tolerant lesen: was die App nicht kennt, fällt weg, fehlende Felder haben Standardwerte, der Cache übersteht den Rundweg.
final class CrewModelleTests: XCTestCase {
    private func lies(_ json: String) throws -> CrewAntwort {
        try LoveaVertrag.decoder().decode(CrewAntwort.self, from: Data(json.utf8))
    }

    private let beispiel = """
    {
      "herausforderungen": [{
        "id": "a1", "art": "saetze", "modus": "gegen", "ziel": null, "uebung": null,
        "start": "2026-11-09T08:00:00.000Z", "ende": "2026-11-16T08:00:00Z", "status": "laeuft", "ersteller": true, "ich": "dabei",
        "teilnehmer": [
          {"id": "t-ich", "verbunden": false, "ich": true, "name": "Du", "status": "dabei", "wert": 12, "aktualisiert": "2026-11-09T09:00:00.000Z"},
          {"id": "v-1", "verbunden": true, "ich": false, "name": "Freund", "status": "eingeladen", "wert": 0, "aktualisiert": null}
        ]
      }, {
        "id": "a2", "art": "laufen", "modus": "gegen", "start": "2026-11-09T08:00:00Z", "ende": "2026-11-16T08:00:00Z", "teilnehmer": []
      }, {
        "id": "a3", "art": "tage", "modus": "gemeinsam", "ziel": 20, "start": "2026-11-09T08:00:00Z", "ende": "2026-11-16T08:00:00Z"
      }],
      "reaktionen": [
        {"id": "r1", "von": "v-1", "name": "Freund", "art": "respekt", "ziel": "rekord:2026-11-09:kniebeuge", "text": "Kniebeuge 120 kg × 5", "zeit": "2026-11-09T10:00:00.000Z"},
        {"id": "r2", "von": "v-1", "name": "Freund", "art": "winken", "ziel": "x", "zeit": "2026-11-09T10:00:00.000Z"},
        {"id": "r3", "von": "v-1", "art": "stups", "zeit": "2026-11-09T10:00:00Z"}
      ],
      "gesendet": [{"an": "v-1", "art": "stark", "ziel": "einheit:2026-11-08"}, {"an": "v-1", "art": "neu", "ziel": "x"}],
      "spaeter": 1
    }
    """

    func testBeispielDesVertragsUnbekannteArtFaelltWeg() throws {
        let a = try lies(beispiel)
        XCTAssertEqual(a.herausforderungen.map(\.id), ["a1", "a3"])
        let h = try XCTUnwrap(a.herausforderungen.first)
        XCTAssertEqual(h.mass, .saetze)
        XCTAssertEqual(h.modus, .gegen)
        XCTAssertTrue(h.ersteller)
        XCTAssertTrue(h.dabei)
        XCTAssertEqual(h.meine?.wert, 12)
        XCTAssertEqual(h.teilnehmer.map(\.status), ["dabei", "eingeladen"])
        XCTAssertNil(h.teilnehmer[1].aktualisiert)
        XCTAssertEqual(a.reaktionen.map(\.id), ["r1", "r3"])
        XCTAssertEqual(a.reaktionen.first?.text, "Kniebeuge 120 kg × 5")
        XCTAssertEqual(a.gesendet, [CrewGesendet(an: "v-1", art: .stark, ziel: "einheit:2026-11-08")])
    }

    func testFehlendeFelderHabenStandardwerte() throws {
        let a = try lies(beispiel)
        let g = try XCTUnwrap(a.herausforderungen.last)
        XCTAssertEqual(g.ziel, 20)
        XCTAssertEqual(g.status, "laeuft")
        XCTAssertFalse(g.ersteller)
        XCTAssertEqual(g.teilnehmer, [])
        let stups = try XCTUnwrap(a.reaktionen.last)
        XCTAssertEqual(stups.name, "")
        XCTAssertEqual(stups.ziel, "")
        XCTAssertEqual(stups.text, "")
        XCTAssertEqual(try lies("{}"), CrewAntwort())
        XCTAssertEqual(try lies(#"{"herausforderungen": 3, "reaktionen": null}"#), CrewAntwort())
    }

    func testCacheRundweg() throws {
        let a = try lies(beispiel)
        let daten = try LoveaVertrag.encoder().encode(a)
        XCTAssertEqual(try LoveaVertrag.decoder().decode(CrewAntwort.self, from: daten), a)
    }

    func testReaktionsArtenTitelUndSymbole() {
        XCTAssertEqual(CrewReaktionArt.allCases.map(\.titel), ["Respekt", "Stark", "Anfeuern", "Gym heute?"])
        XCTAssertEqual(CrewReaktionArt.stups.symbol, "hand.point.right.fill")
        XCTAssertEqual(CrewMass.rangliste, [.tage, .saetze, .volumen, .rekorde])
    }
}
