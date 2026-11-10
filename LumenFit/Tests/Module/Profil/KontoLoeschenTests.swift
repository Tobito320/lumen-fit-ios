import XCTest
@testable import LumenFit

/// "Konto löschen" (App Store 5.1.1(v)): Passwort, dann `DELETE /konto`, erst danach das Gerät. Mit `SkriptLader`, ohne echte Verbindung.
@MainActor
final class KontoLoeschenTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")

    private func antwort(_ status: Int) -> SkriptLader.Antwort { .init(status: status, daten: Data("{}".utf8), fehler: nil) }
    private func netzfehler() -> SkriptLader.Antwort { .init(status: 0, daten: Data(), fehler: .notConnectedToInternet) }

    /// Ein angemeldetes Gerät mit gemerktem Stand und Verbindungs-Datei.
    private func angemeldet(_ lader: SkriptLader, bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), ordner: URL) throws -> KontoDienst {
        let kennung = KontoKennung(id: String(repeating: "k", count: 32), geheimnis: String(repeating: "g", count: 43), registriert: true)
        try bund.schreibe(try JSONEncoder().encode(kennung), fuer: KontoDienst.schluessel)
        let d = KontoDienst(zugang: zugang, schluesselbund: bund, http: lader, ordner: ordner, version: "0.0.1")
        d.uebernimm(ServerConfig.standard)
        try Data("{}".utf8).write(to: ordner.appendingPathComponent(KontoDienst.partnerDatei))
        return d
    }

    func testReihenfolgePasswortDannServerDannGeraet() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let lader = SkriptLader([antwort(200)])
        let d = try angemeldet(lader, bund: bund, ordner: ordner)
        var spur: [String] = []
        let e = await KontoLoeschen.fuehreAus(
            passwortStimmt: { spur.append("passwort"); return true },
            server: { spur.append("server"); let r = await d.kontoLoeschen(); spur.append("\(lader.aufrufe)"); return r },
            lokal: { spur.append("lokal"); return true })
        XCTAssertEqual(e, .geloescht)
        XCTAssertEqual(spur, ["passwort", "server", "1", "lokal"])
        XCTAssertEqual(lader.anfragen.first?.httpMethod, "DELETE")
        XCTAssertEqual(lader.anfragen.first?.url?.path, "/konto")
        XCTAssertEqual(lader.anfragen.first?.value(forHTTPHeaderField: "X-Konto"), String(repeating: "k", count: 32))
        XCTAssertEqual(lader.anfragen.first?.value(forHTTPHeaderField: "X-Geheimnis"), String(repeating: "g", count: 43))
        XCTAssertNil(bund.lese(KontoDienst.schluessel), "Kennung vergessen: der nächste Abgleich legt ein neues Konto an")
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent(KontoDienst.datei).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent(KontoDienst.partnerDatei).path))
        XCTAssertNil(d.registrierteKennung())
    }

    func testOhneNetzWirdNichtsGeloescht() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let d = try angemeldet(SkriptLader([netzfehler()]), bund: bund, ordner: ordner)
        var lokal = false
        let e = await KontoLoeschen.fuehreAus(passwortStimmt: { true }, server: { await d.kontoLoeschen() }, lokal: { lokal = true; return true })
        XCTAssertEqual(e, .keinNetz)
        XCTAssertFalse(lokal, "ohne Netz bleibt alles auf dem iPhone")
        XCTAssertNotNil(bund.lese(KontoDienst.schluessel))
        XCTAssertNotNil(d.registrierteKennung())
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent(KontoDienst.datei).path))
        XCTAssertNotNil(KontoLoeschen.meldung(e))
    }

    func testFalschesPasswortFragtDenServerNie() async throws {
        let lader = SkriptLader([antwort(200)])
        let d = try angemeldet(lader, ordner: try tempOrdner())
        var lokal = false
        let e = await KontoLoeschen.fuehreAus(passwortStimmt: { false }, server: { await d.kontoLoeschen() }, lokal: { lokal = true; return true })
        XCTAssertEqual(e, .falschesPasswort)
        XCTAssertEqual(lader.aufrufe, 0)
        XCTAssertFalse(lokal)
        XCTAssertNil(KontoLoeschen.meldung(e), "das Passwort-Blatt meldet selbst")
    }

    func testServerAntworten() async throws {
        // 401: dort schon unbekannt (zweiter Versuch nach Abbruch) zählt als gelöscht; 403 (gesperrt) und 5xx lassen alles stehen.
        for (status, erwartet) in [(401, KontoLoeschErgebnis.geloescht), (403, .abgelehnt), (500, .abgelehnt)] {
            let bund = SpeicherSchluesselbund()
            let d = try angemeldet(SkriptLader([antwort(status)]), bund: bund, ordner: try tempOrdner())
            let e = await d.kontoLoeschen()
            XCTAssertEqual(e, erwartet, "\(status)")
            XCTAssertEqual(bund.lese(KontoDienst.schluessel) == nil, erwartet == .geloescht, "\(status)")
        }
        let ergebnis = await KontoLoeschen.fuehreAus(passwortStimmt: { true }, server: { .abgelehnt }, lokal: { XCTFail("nie lokal"); return true })
        XCTAssertEqual(ergebnis, .abgelehnt)
        let halb = await KontoLoeschen.fuehreAus(passwortStimmt: { true }, server: { .geloescht }, lokal: { false })
        XCTAssertEqual(halb, .lokalFehlgeschlagen)
        XCTAssertNotNil(KontoLoeschen.meldung(halb))
    }

    func testOhneAngemeldetesGeraetNurLokal() async throws {
        let lader = SkriptLader([antwort(200)])
        let d = KontoDienst(zugang: zugang, schluesselbund: SpeicherSchluesselbund(), http: lader, ordner: try tempOrdner(), version: "0.0.1")
        let e = await d.kontoLoeschen()
        XCTAssertEqual(e, .geloescht)
        XCTAssertEqual(lader.aufrufe, 0, "ohne Kennung kennt der Server nichts von diesem Gerät")
    }

    func testDanachMeldetSichDasGeraetMitNeuerKennungAn() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let lader = SkriptLader([antwort(200), antwort(201), antwort(200)])
        let d = try angemeldet(lader, bund: bund, ordner: ordner)
        _ = await d.kontoLoeschen()
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertEqual(lader.anfragen.dropFirst().first?.url?.path, "/konto")
        XCTAssertEqual(lader.anfragen.dropFirst().first?.httpMethod, "POST")
        let neu = try JSONDecoder().decode(KontoKennung.self, from: try XCTUnwrap(bund.lese(KontoDienst.schluessel)))
        XCTAssertNotEqual(neu.id, String(repeating: "k", count: 32))
        XCTAssertTrue(neu.registriert)
    }

    func testPasswortPruefungImHintergrund() async throws {
        let store = ProfilStore(schluesselbund: SpeicherSchluesselbund(), ereignisse: EreignisKanal(), runden: 1_000)
        let p = try store.anlegen(name: "Beispiel", passwort: "geheim123")
        let richtig = await store.pruefeImHintergrund(passwort: "geheim123", fuer: p.id)
        let falsch = await store.pruefeImHintergrund(passwort: "falsch", fuer: p.id)
        XCTAssertTrue(richtig)
        XCTAssertFalse(falsch)
    }
}
