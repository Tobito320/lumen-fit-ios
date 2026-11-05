// Quelle: Lovea Health/Tests/KiFotoTests.swift (Fehlerzuordnung; der Weg zum Server ist neu)
import XCTest
@testable import LumenFit

/// Der Weg zum Lumen-Server ohne Netz: `SkriptLader` antwortet, ein Zugang aus dem Test liefert die Verbindung.
final class EssenKiClientTests: XCTestCase {
    private struct Zugang: EssenKiZugang {
        let v: EssenKiVerbindung?
        func verbindung() -> EssenKiVerbindung? { v }
    }

    private let verbindung = EssenKiVerbindung(server: URL(string: "https://example.invalid/api")!, kopfzeilen: ["X-App-Key": "k", "X-Konto": "konto"])

    private let antwortJson = """
    {"ok":true,"ist_essen":true,"items":[{"name":"Reis","gramm":200,"kcal_pro_100g":130,"protein_pro_100g":2.7,"kohlenhydrate_pro_100g":28,"fett_pro_100g":0.3,"sicherheit":"hoch"}],
     "versteckt":[],"gesamt":{"kcal":260,"kcal_min":230,"kcal_max":300},"frage":null,"bemerkung":"","rest":5}
    """

    private func client(_ lader: SkriptLader, verbunden: Bool = true) -> EssenKiClient {
        EssenKiClient(zugang: Zugang(v: verbunden ? verbindung : nil), lader: lader)
    }

    func testAnfrageGehtAnKiFotoMitKopfzeilenUndJson() async throws {
        let lader = SkriptLader(status: 200, daten: Data(antwortJson.utf8))
        let a = try await client(lader).analysieren(bild: Data([1, 2, 3]), hinweis: "mit Öl", mahlzeit: .abend)
        XCTAssertEqual(a.items.first?.name, "Reis")
        let r = try XCTUnwrap(lader.anfragen.first)
        XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertEqual(r.url?.path, "/api/ki/foto")
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-App-Key"), "k")
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-Konto"), "konto")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(r.httpBody)
        let j = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(j["bild"], Data([1, 2, 3]).base64EncodedString())
        XCTAssertEqual(j["mime"], "image/jpeg")
        XCTAssertEqual(j["hinweis"], "mit Öl")
        XCTAssertEqual(j["mahlzeit"], "abend")
    }

    func testOhneVerbindungKeinNetzaufruf() async {
        let lader = SkriptLader(status: 200, daten: Data(antwortJson.utf8))
        do {
            _ = try await client(lader, verbunden: false).analysieren(bild: Data(), hinweis: "", mahlzeit: .mittag)
            XCTFail("sollte werfen")
        } catch {
            XCTAssertEqual(error as? EssenKiFehler, .nichtEingerichtet)
        }
        XCTAssertEqual(lader.aufrufe, 0)
    }

    func testNetzfehlerUndKaputteAntwort() async {
        do {
            _ = try await client(SkriptLader.fehler(.notConnectedToInternet)).analysieren(bild: Data(), hinweis: "", mahlzeit: .mittag)
            XCTFail("sollte werfen")
        } catch {
            XCTAssertEqual(error as? EssenKiFehler, .netz)
        }
        do {
            _ = try await client(SkriptLader(status: 200, daten: Data("kein json".utf8))).analysieren(bild: Data(), hinweis: "", mahlzeit: .mittag)
            XCTFail("sollte werfen")
        } catch {
            XCTAssertEqual(error as? EssenKiFehler, .ungueltig)
        }
    }

    func testFehlerArtDesServersHatVorrangVorDemStatus() {
        func f(_ status: Int, _ art: String?) -> EssenKiFehler {
            EssenKiClient.fehler(status: status, daten: Data((art.map { #"{"fehler":"\#($0)"}"# } ?? "").utf8))
        }
        XCTAssertEqual(f(429, "tageslimit"), .tageslimit(max: nil))
        XCTAssertEqual(EssenKiClient.fehler(status: 429, daten: Data(#"{"fehler":"tageslimit","max":5}"#.utf8)), .tageslimit(max: 5))
        XCTAssertEqual(f(429, "zuVieleAnfragen"), .zuVieleAnfragen)
        XCTAssertEqual(f(413, "bildZuGross"), .bildZuGross)
        XCTAssertEqual(f(503, "guthaben"), .guthaben)
        XCTAssertEqual(f(503, "nichtEingerichtet"), .nichtEingerichtet)
        XCTAssertEqual(f(403, "nichtErlaubt"), .nichtEingerichtet)
        XCTAssertEqual(f(400, "ungueltig"), .ungueltig)
        XCTAssertEqual(f(502, "netz"), .netz)
        XCTAssertEqual(f(502, "kiFehler"), .unbekannt)
        XCTAssertEqual(f(401, nil), .nichtEingerichtet)
        XCTAssertEqual(f(413, nil), .bildZuGross)
        XCTAssertEqual(f(429, nil), .zuVieleAnfragen)
        XCTAssertEqual(f(500, nil), .unbekannt)
    }

    func testFreigabeLogikLiestNurEchtesTrue() {
        func e(_ s: String) -> Bool? { EssenKiFreigabeLogik.erlaubt(antwort: Data(s.utf8)) }
        XCTAssertEqual(e(#"{"config":{"kiFotoErlaubt":true}}"#), true)
        XCTAssertEqual(e(#"{"config":{"kiFotoErlaubt":false}}"#), false)
        XCTAssertEqual(e(#"{"config":{"kiFotoErlaubt":"true"}}"#), false)
        XCTAssertEqual(e(#"{"config":{}}"#), false)
        XCTAssertNil(e(#"{"x":1}"#))
        XCTAssertNil(e("kaputt"))
    }

    @MainActor
    func testFreigabeFragtDenServerUndMerktSichDieAntwort() async throws {
        let lader = SkriptLader(status: 200, daten: Data(#"{"config":{"kiFotoErlaubt":true}}"#.utf8))
        let freigabe = EssenKiFreigabe(zugang: Zugang(v: verbindung), lader: lader, uhr: { Date(timeIntervalSince1970: 1_000) })
        XCTAssertFalse(freigabe.erlaubt)
        await freigabe.pruefen()
        XCTAssertTrue(freigabe.erlaubt)
        XCTAssertEqual(lader.anfragen.first?.url?.path, "/api/config")
        await freigabe.pruefen()
        XCTAssertEqual(lader.aufrufe, 1, "innerhalb der Pause keine zweite Frage")
        await freigabe.pruefen(erzwingen: true)
        XCTAssertEqual(lader.aufrufe, 2)
    }

    @MainActor
    func testFreigabeBleibtAusOhneZugangOderBeiVerbot() async {
        let ohne = EssenKiFreigabe(zugang: Zugang(v: nil), lader: SkriptLader(status: 200, daten: Data(#"{"config":{"kiFotoErlaubt":true}}"#.utf8)))
        await ohne.pruefen()
        XCTAssertFalse(ohne.erlaubt)
        let verboten = EssenKiFreigabe(zugang: Zugang(v: verbindung), lader: SkriptLader(status: 403, daten: Data()))
        await verboten.pruefen()
        XCTAssertFalse(verboten.erlaubt)
    }

    func testKontoZugangBrauchtRegistriertesGeraet() throws {
        let bund = SpeicherSchluesselbund()
        let zugang = KontoZugang(server: URL(string: "https://example.invalid")!, appKey: "k")
        let z = EssenKiKontoZugang(zugang: zugang, schluesselbund: bund, version: "1.0")
        XCTAssertNil(z.verbindung(), "kein Eintrag")
        try bund.schreibe(JSONEncoder().encode(KontoKennung(id: "id", geheimnis: "g", registriert: false)), fuer: KontoDienst.schluessel)
        XCTAssertNil(z.verbindung(), "noch nicht registriert")
        try bund.schreibe(JSONEncoder().encode(KontoKennung(id: "id", geheimnis: "g", registriert: true)), fuer: KontoDienst.schluessel)
        let v = try XCTUnwrap(z.verbindung())
        XCTAssertEqual(v.kopfzeilen["X-Konto"], "id")
        XCTAssertEqual(v.kopfzeilen["X-App-Version"], "1.0")
        XCTAssertNil(EssenKiKontoZugang(zugang: nil, schluesselbund: bund, version: "1.0").verbindung())
    }
}
