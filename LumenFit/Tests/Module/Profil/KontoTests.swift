import XCTest
@testable import LumenFit

/// Konto beim Lumen-Server, Einstellungen vom Server, Lovea-Freigabe, Namensregel und Sperren. Alles mit erfundenen Werten und einem `SkriptLader`:
/// es gibt keine echte Verbindung.
@MainActor
final class KontoTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")

    private func antwort(_ status: Int, _ json: String = "{}") -> SkriptLader.Antwort { .init(status: status, daten: Data(json.utf8), fehler: nil) }
    private func netzfehler() -> SkriptLader.Antwort { .init(status: 0, daten: Data(), fehler: .notConnectedToInternet) }

    private func dienst(_ lader: SkriptLader, bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), ordner: URL? = nil, ohneZugang: Bool = false,
                        uhr: TestUhr = TestUhr()) throws -> KontoDienst {
        KontoDienst(zugang: ohneZugang ? nil : zugang, schluesselbund: bund, http: lader, ordner: try ordner ?? tempOrdner(), uhr: uhr.uhr, version: "0.0.1")
    }

    private func gespeicherteKennung(_ bund: SpeicherSchluesselbund) throws -> KontoKennung {
        try JSONDecoder().decode(KontoKennung.self, from: try XCTUnwrap(bund.lese(KontoDienst.schluessel)))
    }

    private let configJson = #"{"config":{"profilAnlegenErlaubt":true,"nameAendernTage":3,"irgendwasNeues":{"a":1}}}"#
    private let freigabeJson = #"{"erlaubt":true,"person":"person-a"}"#

    // MARK: - Config

    func testStandardwerteSindDieSichereSeite() {
        let c = ServerConfig.standard
        XCTAssertFalse(c.profilAnlegenErlaubt, "kein zweites Profil, solange der Server nichts sagt")
        XCTAssertEqual(c.nameAendernTage, 7)
    }

    func testConfigFuehrtGueltigesEinUndIgnoriertUnbekanntes() throws {
        let c = try XCTUnwrap(ServerConfig.zusammen(.standard, antwort: Data(configJson.utf8)))
        XCTAssertTrue(c.profilAnlegenErlaubt)
        XCTAssertEqual(c.nameAendernTage, 3)
    }

    func testFalscheTypenUndFehlendeSchluesselLassenDenBisherigenWert() throws {
        var basis = ServerConfig.standard
        basis.profilAnlegenErlaubt = true
        basis.nameAendernTage = 5
        let c = try XCTUnwrap(ServerConfig.zusammen(basis, antwort: Data(#"{"config":{"profilAnlegenErlaubt":"ja","nameAendernTage":"viele"}}"#.utf8)))
        XCTAssertEqual(c, basis)
        let teil = try XCTUnwrap(ServerConfig.zusammen(basis, antwort: Data(#"{"config":{"nameAendernTage":2}}"#.utf8)))
        XCTAssertTrue(teil.profilAnlegenErlaubt, "fehlender Schlüssel behält den Wert")
        XCTAssertEqual(teil.nameAendernTage, 2)
        XCTAssertNil(ServerConfig.zusammen(basis, antwort: Data("kein json".utf8)))
        XCTAssertNil(ServerConfig.zusammen(basis, antwort: Data(#"{"fehler":"x"}"#.utf8)), "ohne Objekt config bleibt alles")
    }

    func testTageWerdenBegrenztUndBruchzahlenAbgelehnt() throws {
        func tage(_ wert: String) throws -> Int {
            try XCTUnwrap(ServerConfig.zusammen(.standard, antwort: Data(#"{"config":{"nameAendernTage":\#(wert)}}"#.utf8))).nameAendernTage
        }
        XCTAssertEqual(try tage("-5"), 0)
        XCTAssertEqual(try tage("100000"), 365)
        XCTAssertEqual(try tage("0"), 0, "0 heißt keine Sperre")
        XCTAssertEqual(try tage("2.5"), 7, "keine halben Tage: der Wert bleibt")
    }

    func testOhneZugangKeinNetzUndStandardwerte() async throws {
        let lader = SkriptLader([antwort(200, configJson)])
        let d = try dienst(lader, ohneZugang: true)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertEqual(lader.aufrufe, 0)
        XCTAssertEqual(d.config, .standard)
        XCTAssertFalse(d.loveaErlaubt)
    }

    func testOfflineBleibtBeimLetztenStandUndStartetMitStandardwerten() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let gut = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson)])
        let d = try dienst(gut, bund: bund, ordner: ordner)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(d.config.profilAnlegenErlaubt)

        let offline = SkriptLader([netzfehler()])
        let neu = try dienst(offline, bund: bund, ordner: ordner)
        XCTAssertEqual(neu.config.nameAendernTage, 3, "der gemerkte Stand gilt schon vor der ersten Antwort")
        XCTAssertTrue(neu.loveaErlaubt)
        await neu.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertEqual(neu.config.nameAendernTage, 3, "Netzfehler ändert nichts")

        let frisch = try dienst(SkriptLader([netzfehler()]), bund: SpeicherSchluesselbund(), ordner: try tempOrdner())
        XCTAssertEqual(frisch.config, .standard, "erster Start ohne Netz: Standardwerte")
        XCTAssertFalse(frisch.loveaErlaubt)
    }

    // MARK: - Registrierung

    func testRegistrierungWirdNachNetzfehlerWiederholt() async throws {
        let bund = SpeicherSchluesselbund()
        let lader = SkriptLader([netzfehler(), antwort(201), antwort(200, configJson), antwort(200, freigabeJson)])
        let d = try dienst(lader, bund: bund)

        await d.aktualisiere(profilName: " Beispiel ", erzwingen: true)
        let erste = try gespeicherteKennung(bund)
        XCTAssertFalse(erste.registriert, "Netzfehler: noch nicht angemeldet")
        XCTAssertEqual(lader.aufrufe, 1)
        XCTAssertEqual(d.config, .standard)

        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let zweite = try gespeicherteKennung(bund)
        XCTAssertTrue(zweite.registriert)
        XCTAssertEqual(zweite.id, erste.id, "dieselbe Kennung, nie neu gewürfelt")
        XCTAssertEqual(zweite.geheimnis, erste.geheimnis)
        XCTAssertEqual(lader.anfragen.compactMap { $0.url?.path }, ["/konto", "/konto", "/config", "/lovea/freigabe"])
        XCTAssertEqual(lader.anfragen.map { $0.httpMethod }, ["POST", "POST", "GET", "GET"])
        let koerper = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(lader.anfragen[1].httpBody)) as? [String: String])
        XCTAssertEqual(koerper["id"], erste.id)
        XCTAssertEqual(koerper["name"], "Beispiel")
        XCTAssertEqual(koerper["version"], "0.0.1")
        XCTAssertEqual(lader.anfragen[2].value(forHTTPHeaderField: "X-Konto"), erste.id)
        XCTAssertEqual(lader.anfragen[2].value(forHTTPHeaderField: "X-Geheimnis"), erste.geheimnis)
        XCTAssertEqual(lader.anfragen[2].value(forHTTPHeaderField: "X-App-Key"), "app-test-schluessel")
        XCTAssertTrue(d.config.profilAnlegenErlaubt)
        XCTAssertTrue(d.loveaErlaubt)

        let danach = SkriptLader([antwort(200, configJson), antwort(200, freigabeJson)])
        let weiter = try dienst(danach, bund: bund)
        await weiter.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertEqual(danach.anfragen.compactMap { $0.url?.path }, ["/config", "/lovea/freigabe"], "eine angemeldete Kennung meldet sich nie nochmal an")
    }

    func testKennungHatDieFormDesServers() throws {
        let k = try XCTUnwrap(KontoKennung.neu())
        XCTAssertNotNil(k.id.range(of: "^[A-Za-z0-9_-]{16,64}$", options: .regularExpression))
        XCTAssertNotNil(k.geheimnis.range(of: "^[A-Za-z0-9_-]{32,128}$", options: .regularExpression))
        XCTAssertNotEqual(KontoKennung.neu()?.id, k.id)
    }

    func testOhneProfilnameWirdNichtAngemeldet() async throws {
        let lader = SkriptLader([antwort(201)])
        let d = try dienst(lader)
        await d.aktualisiere(profilName: nil, erzwingen: true)
        await d.aktualisiere(profilName: "   ", erzwingen: true)
        XCTAssertEqual(lader.aufrufe, 0, "der Server verlangt einen Namen")
    }

    func testGleicheIdAmServerPruefenWirMitDenEigenenKopfzeilen() async throws {
        // Antwort 201 ging verloren: der zweite Versuch bekommt 409, /config mit unseren Kopfzeilen sagt 200 = wir sind es.
        let bund = SpeicherSchluesselbund()
        let lader = SkriptLader([antwort(409), antwort(200, configJson), antwort(200, freigabeJson)])
        let d = try dienst(lader, bund: bund)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let k = try gespeicherteKennung(bund)
        XCTAssertTrue(k.registriert)
        XCTAssertEqual(lader.anfragen.compactMap { $0.url?.path }, ["/konto", "/config", "/lovea/freigabe"])
        XCTAssertTrue(d.config.profilAnlegenErlaubt)
    }

    func testEchteKollisionBekommtEineNeueKennung() async throws {
        let bund = SpeicherSchluesselbund()
        let lader = SkriptLader([antwort(409), antwort(401)])
        let d = try dienst(lader, bund: bund)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let neu = try gespeicherteKennung(bund)
        XCTAssertFalse(neu.registriert)
        let bodyId = try XCTUnwrap((try JSONSerialization.jsonObject(with: try XCTUnwrap(lader.anfragen[0].httpBody)) as? [String: String])?["id"])
        XCTAssertNotEqual(neu.id, bodyId)
    }

    func testUngueltigeAnmeldungWirdInDerSitzungNichtWiederholt() async throws {
        let lader = SkriptLader([antwort(400)])
        let d = try dienst(lader)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertEqual(lader.aufrufe, 1)
    }

    func testOhnePauseFragtDerDienstNichtDauernd() async throws {
        let uhr = TestUhr()
        let lader = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson), antwort(200, configJson), antwort(200, freigabeJson)])
        let d = try dienst(lader, uhr: uhr)
        await d.aktualisiere(profilName: "Beispiel")
        XCTAssertEqual(lader.aufrufe, 3)
        uhr.vor(sekunden: 60)
        await d.aktualisiere(profilName: "Beispiel")
        XCTAssertEqual(lader.aufrufe, 3, "innerhalb von fünf Minuten kein neuer Aufruf")
        uhr.vor(sekunden: KontoDienst.pause)
        await d.aktualisiere(profilName: "Beispiel")
        XCTAssertEqual(lader.aufrufe, 5)
    }

    // MARK: - Lovea-Freigabe

    func testLoveaNurBeiAusdruecklichemTrue() async throws {
        for (json, erwartet) in [(freigabeJson, true), (#"{"erlaubt":false}"#, false), (#"{"erlaubt":"true"}"#, false), (#"{"person":"x"}"#, false), ("kaputt", false)] {
            let d = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, json)]))
            await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
            XCTAssertEqual(d.loveaErlaubt, erwartet, json)
        }
    }

    func testAblehnungOderNetzfehlerNimmtDieFreigabeNichtZurueck() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let d = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson), antwort(401), antwort(403)]), bund: bund, ordner: ordner)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(d.loveaErlaubt)
        XCTAssertTrue(d.freigabeAktuell)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(d.loveaErlaubt, "401 ist kein Verbot")
        // Erst ein klares erlaubt:false nimmt sie zurück.
        let nein = try dienst(SkriptLader([antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#)]), bund: bund, ordner: ordner)
        XCTAssertFalse(nein.freigabeAktuell, "der gemerkte Stand ist nicht aktuell")
        await nein.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertFalse(nein.loveaErlaubt)
        XCTAssertTrue(nein.freigabeAktuell)
    }

    func testLoveaZugangNurMitFreigabeUndUeberDenProxy() async throws {
        let bund = SpeicherSchluesselbund()
        let gesperrt = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#)]), bund: bund)
        await gesperrt.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertNil(gesperrt.loveaZugang(), "ohne Freigabe gibt es keinen Zugang")

        let offen = try dienst(SkriptLader([antwort(200, configJson), antwort(200, freigabeJson)]), bund: bund)
        await offen.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let z = try XCTUnwrap(offen.loveaZugang())
        XCTAssertEqual(z.server.absoluteString, "https://lumen.example.invalid/lovea")
        let k = try gespeicherteKennung(bund)
        XCTAssertEqual(z.kopfzeilen["X-Konto"], k.id)
        XCTAssertEqual(z.kopfzeilen["X-App-Key"], "app-test-schluessel")
        XCTAssertNil(z.kopfzeilen["X-Lovea-Key"])
        let a = try XCTUnwrap(ProfilLoveaImport.anfrage(zugang: z, seit: 0))
        XCTAssertEqual(a.url?.path, "/lovea/agent/ops")
    }

    func testZugangAusPrivatenDaten() throws {
        let z = try XCTUnwrap(KontoZugang.lies(Data(#"{"version":1,"personen":[],"konto":{"server":"https://x.example.invalid","appKey":"k"}}"#.utf8)))
        XCTAssertEqual(z.server.host, "x.example.invalid")
        XCTAssertFalse("\(z)".contains("example") || "\(z)".contains("appKey"), "die Beschreibung nennt weder Server noch Schlüssel")
        XCTAssertNil(KontoZugang.lies(Data(#"{"version":1,"personen":[]}"#.utf8)), "ohne Block kein Zugang")
        XCTAssertNil(KontoZugang.lies(Data(#"{"konto":{"server":"https://x.example.invalid","appKey":""}}"#.utf8)))
        XCTAssertNil(KontoZugang.lies(Data(#"{"konto":{"server":"http://x.example.invalid","appKey":"k"}}"#.utf8)), "nur https")
    }

    // MARK: - Sperre Profil anlegen

    private func store(_ bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), uhr: TestUhr = TestUhr()) -> ProfilStore {
        ProfilStore(schluesselbund: bund, ereignisse: EreignisKanal(), runden: 1_000, uhr: uhr.uhr)
    }

    func testWeiteresProfilNurWennErlaubtDasErsteImmer() throws {
        let s = store()
        s.weitereProfileErlaubt = { false }
        try s.anlegen(name: "Eins", passwort: "abcd")
        XCTAssertThrowsError(try s.anlegen(name: "Zwei", passwort: "efgh")) { XCTAssertEqual($0 as? ProfilFehler, .nichtErlaubt) }
        XCTAssertEqual(s.profile.count, 1)
        s.weitereProfileErlaubt = { true }
        XCTAssertNoThrow(try s.anlegen(name: "Zwei", passwort: "efgh"))
        XCTAssertEqual(s.profile.count, 2)
    }

    func testWeiteresProfilAuchImHintergrundGesperrtUndNachAllesLoeschenGehtDasErsteWieder() async throws {
        let s = store()
        s.weitereProfileErlaubt = { false }
        let erstes = try await s.anlegenImHintergrund(name: "Eins", passwort: "abcd")
        do { _ = try await s.anlegenImHintergrund(name: "Zwei", passwort: "efgh"); XCTFail("gesperrt") } catch { XCTAssertEqual(error as? ProfilFehler, .nichtErlaubt) }
        XCTAssertTrue(s.setzeZurueck(erstes.id))
        XCTAssertNoThrow(try s.anlegen(name: "Neu", passwort: "abcd"), "ohne Profil ist das Anlegen das Onboarding und geht immer")
    }

    func testDieSperreFolgtDerServerConfigInDerUmgebung() async throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        u.sperreWeitereProfile()
        try u.profil.anlegen(name: "Eins", passwort: "abcd")
        XCTAssertFalse(u.konto.config.profilAnlegenErlaubt)
        XCTAssertThrowsError(try u.profil.anlegen(name: "Zwei", passwort: "efgh")) { XCTAssertEqual($0 as? ProfilFehler, .nichtErlaubt) }
    }

    // MARK: - Namensregel

    func testNamensregel() {
        func gut(_ roh: String, _ sauber: String? = nil, _ zeile: UInt = #line) {
            XCTAssertEqual(try? NamenRegel.pruefe(roh).get(), sauber ?? roh, roh, line: zeile)
        }
        func schlecht(_ roh: String, _ grund: NamenRegel.Fehler, _ zeile: UInt = #line) {
            if case .failure(let f) = NamenRegel.pruefe(roh) { XCTAssertEqual(f, grund, roh, line: zeile) } else { XCTFail("sollte scheitern: \(roh)", line: zeile) }
        }
        gut("Anna")
        gut("  Anna  ", "Anna")
        gut("Jörg")
        gut("Zoë")
        gut("Anne-Marie")
        gut("O'Neil")
        gut("O\u{2019}Neil")
        gut("Mary   Ann", "Mary Ann")
        gut("Al")
        gut("A" + String(repeating: "b", count: 19), nil)
        schlecht("", .leer)
        schlecht("     ", .leer)
        schlecht("\n\t", .leer)
        schlecht("A", .zuKurz)
        schlecht(String(repeating: "a", count: 21), .zuLang)
        schlecht("Anna2", .zeichen)
        schlecht("1234", .zeichen)
        schlecht("Anna!", .zeichen)
        schlecht("Anna_B", .zeichen)
        schlecht("😀😀", .zeichen)
        schlecht("Anna😀", .zeichen)
        schlecht("--", .zeichen)
        schlecht("-Anna", .zeichen)
        schlecht("Anna-", .zeichen)
        schlecht("Anna--Lena", .zeichen)
        schlecht("A.", .zeichen)
        schlecht("a\tb", .zeichen)
        schlecht("<b>x</b>", .zeichen)
    }

    func testAnlegenNutztDieselbeRegel() {
        let s = store()
        XCTAssertThrowsError(try s.anlegen(name: "Anna2", passwort: "abcd")) { XCTAssertEqual($0 as? ProfilFehler, .nameUngueltig(.zeichen)) }
        XCTAssertThrowsError(try s.anlegen(name: "A", passwort: "abcd")) { XCTAssertEqual($0 as? ProfilFehler, .nameUngueltig(.zuKurz)) }
        XCTAssertThrowsError(try s.anlegen(name: "   ", passwort: "abcd")) { XCTAssertEqual($0 as? ProfilFehler, .nameLeer) }
        XCTAssertEqual(try s.anlegen(name: " Mary   Ann ", passwort: "abcd").name, "Mary Ann")
        XCTAssertNil(s.aktiv?.nameGeaendert, "das Anlegen startet die Sperre nicht")
    }

    func testOnboardingZeigtDenHinweisUndSperrtWeiter() {
        let fluss = ProfilOnboardingFluss()
        XCTAssertNil(fluss.nameHinweis, "vor dem Tippen kein Hinweis")
        fluss.name = "A1"
        XCTAssertEqual(fluss.nameHinweis, NamenRegel.text(.zeichen))
        XCTAssertFalse(fluss.nameGueltig)
        fluss.name = "Anna"
        XCTAssertNil(fluss.nameHinweis)
        XCTAssertTrue(fluss.nameGueltig)
    }

    // MARK: - Sperre Namensänderung

    func testNameNurAlleSiebenTage() throws {
        let uhr = TestUhr()
        let s = store(uhr: uhr)
        try s.anlegen(name: "Eins", passwort: "abcd")
        XCTAssertEqual(s.aendereName("Zwei", sperreTage: 7), .geaendert, "die erste Änderung ist frei")
        XCTAssertEqual(s.aktiv?.nameGeaendert, uhr.lesen)

        uhr.vor(sekunden: 6 * 86_400)
        guard case .gesperrt(let bis) = s.aendereName("Drei", sperreTage: 7) else { return XCTFail("nach 6 Tagen noch gesperrt") }
        XCTAssertEqual(s.aktiv?.name, "Zwei")
        XCTAssertTrue(bis > uhr.lesen && bis <= uhr.lesen.addingTimeInterval(2 * 86_400), "wieder ab dem siebten Tag")

        uhr.vor(sekunden: 2 * 86_400)
        XCTAssertEqual(s.aendereName("Drei", sperreTage: 7), .geaendert)
        XCTAssertEqual(s.aktiv?.name, "Drei")
    }

    func testSperreNutztDieTageDesServersUndNullHeisstFrei() throws {
        let s = store()
        try s.anlegen(name: "Eins", passwort: "abcd")
        XCTAssertEqual(s.aendereName("Zwei", sperreTage: 0), .geaendert)
        XCTAssertEqual(s.aendereName("Drei", sperreTage: 0), .geaendert, "0 Tage: keine Sperre")
        XCTAssertEqual(s.aendereName("Vier", sperreTage: 30).isGesperrt, true, "30 Tage seit eben")
    }

    func testUngueltigerOderGleicherNameStartetDieSperreNicht() throws {
        let s = store()
        try s.anlegen(name: "Eins", passwort: "abcd")
        XCTAssertEqual(s.aendereName("Eins", sperreTage: 7), .unveraendert)
        XCTAssertEqual(s.aendereName("E1ns", sperreTage: 7), .ungueltig(.zeichen))
        XCTAssertEqual(s.aendereName("E", sperreTage: 7), .ungueltig(.zuKurz))
        XCTAssertNil(s.aktiv?.nameGeaendert)
        XCTAssertEqual(s.aendereName("Zwei", sperreTage: 7), .geaendert, "danach ist die Änderung noch frei")
    }

    func testEinDatumInDerZukunftSperrtNichtFuerImmer() {
        let jetzt = TestUhr().lesen
        XCTAssertNil(NamenRegel.freiAb(letzteAenderung: jetzt.addingTimeInterval(400 * 86_400), tage: 7, jetzt: jetzt), "verstellte Uhr")
        XCTAssertNil(NamenRegel.freiAb(letzteAenderung: nil, tage: 7, jetzt: jetzt))
        XCTAssertNil(NamenRegel.freiAb(letzteAenderung: jetzt.addingTimeInterval(-8 * 86_400), tage: 7, jetzt: jetzt))
        XCTAssertNotNil(NamenRegel.freiAb(letzteAenderung: jetzt, tage: 7, jetzt: jetzt))
    }
}

private extension NamenAenderung {
    var isGesperrt: Bool { if case .gesperrt = self { true } else { false } }
}
