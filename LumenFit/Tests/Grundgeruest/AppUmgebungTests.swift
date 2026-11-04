import XCTest
@testable import LumenFit

@MainActor
final class AppUmgebungTests: XCTestCase {
    /// Zählt Aufrufe aus Rückrufen, die auf dem Hauptakteur laufen (ein Verweistyp, damit der Rückruf nichts Veränderliches einfangen muss).
    @MainActor private final class Merker {
        var eintraege: [String] = []
    }

    private func umgebung(ordner: URL, bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), leser: any HealthLeser = LeererHealthLeser(), uhr: TestUhr = TestUhr()) -> AppUmgebung {
        AppUmgebung(ordner: ordner, schluesselbund: bund, http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(), leser: leser,
                    healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
    }

    func testOhneProfilGibtEsKeinenDatenSatz() throws {
        let u = umgebung(ordner: try tempOrdner())
        XCTAssertFalse(u.profil.hatProfil)
        XCTAssertNil(u.daten)
        XCTAssertFalse(u.neuinstallationErkannt)
    }

    func testDatenSatzGehoertZumAktivenProfilUndWechseltMit() throws {
        let u = umgebung(ordner: try tempOrdner())
        let a = try u.profil.anlegen(name: "Eins", passwort: "abcd")
        let datenA = try XCTUnwrap(u.daten)
        XCTAssertEqual(datenA.profil, a.id)
        XCTAssertTrue(u.daten === datenA, "derselbe Satz, solange das Profil bleibt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: u.profilOrdner(a.id).path), "der Profilordner wird angelegt")

        let b = try u.profil.anlegen(name: "Zwei", passwort: "efgh")
        let datenB = try XCTUnwrap(u.daten)
        XCTAssertEqual(datenB.profil, b.id)
        XCTAssertFalse(datenB === datenA)
        XCTAssertNotEqual(datenA.ordner, datenB.ordner)

        XCTAssertTrue(u.profil.wechsle(zu: a.id, passwort: "abcd"))
        XCTAssertEqual(u.daten?.profil, a.id)
    }

    func testNeuinstallationWirdErkanntWennDasProfilImSchluesselbundIstUndDerOrdnerFehlt() throws {
        let bund = SpeicherSchluesselbund()
        let ordner = try tempOrdner()
        let erste = umgebung(ordner: ordner, bund: bund)
        let profil = try erste.profil.anlegen(name: "Beispiel", passwort: "abcd")
        _ = erste.daten   // legt den Profilordner an
        XCTAssertFalse(erste.neuinstallationErkannt)

        // Gleicher Schlüsselbund, gleiche Dateien: normaler Start.
        XCTAssertFalse(umgebung(ordner: ordner, bund: bund).neuinstallationErkannt)

        // Gleicher Schlüsselbund, leerer Speicherort (App gelöscht und neu installiert): Neuinstallation.
        let neu = umgebung(ordner: try tempOrdner(), bund: bund)
        XCTAssertEqual(neu.profil.aktiv?.id, profil.id)
        XCTAssertTrue(neu.neuinstallationErkannt)
        neu.neuinstallationQuittieren()
        XCTAssertFalse(neu.neuinstallationErkannt)
    }

    func testAbrufAufgabenLaufenNacheinanderUndMeldenDasEreignis() async throws {
        let u = umgebung(ordner: try tempOrdner())
        let merker = Merker()
        u.beiAbruf { merker.eintraege.append("eins") }
        u.beiAbruf { merker.eintraege.append("zwei") }
        let strom = u.ereignisse.strom()
        await u.fuehreAbrufAus()
        XCTAssertEqual(merker.eintraege, ["eins", "zwei"])
        var ereignis: Ereignis?
        for await e in strom { ereignis = e; break }
        guard case .healthAktualisiert? = ereignis else { return XCTFail("healthAktualisiert erwartet, bekam \(String(describing: ereignis))") }
    }

    func testAbrufLaedtHealthVorDenAufgaben() async throws {
        let uhr = TestUhr()
        let heute = Datum.text(uhr.lesen)
        let u = umgebung(ordner: try tempOrdner(), leser: FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 4321)]), uhr: uhr)
        try u.profil.anlegen(name: "Test", passwort: "abcd")
        u.daten?.einstellungen.aendere { $0.healthGefragt = true }
        let merker = Merker()
        u.beiAbruf { merker.eintraege.append("\(u.gesundheit.tage[heute]?.schritte ?? 0)") }
        await u.fuehreAbrufAus()
        XCTAssertEqual(merker.eintraege, ["4321"], "die Lovea-Datei im Hintergrund braucht die frischen Schritte")
    }

    func testEinmalSchalterLaesstGenauEinenDurch() {
        let einmal = EinmalSchalter()
        XCTAssertTrue(einmal.zuerst())
        XCTAssertFalse(einmal.zuerst())
        XCTAssertFalse(einmal.zuerst())
    }

    func testNeueHealthDatenLoesenDenAbrufAus() async throws {
        let leser = FakeHealthLeser()
        let u = umgebung(ordner: try tempOrdner(), leser: leser)
        let merker = Merker()
        u.beiAbruf { merker.eintraege.append("abruf") }
        try u.profil.anlegen(name: "Test", passwort: "abcd")   // ohne Profil ist noch kein Bereich gewählt und nichts wird beobachtet
        u.beobachteHealth()
        XCTAssertEqual(leser.beobachterAnzahl, 1)
        leser.melde()
        for _ in 0..<100 where merker.eintraege.isEmpty { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertEqual(merker.eintraege, ["abruf"])
    }

    func testVorschauHatNichtsAnDerAppUndKeinNetz() async throws {
        let u = AppUmgebung.vorschau()
        XCTAssertFalse(u.profil.hatProfil)
        let antwort = try await u.http.lade(URLRequest(url: try XCTUnwrap(URL(string: "https://example.org/api/etwas"))))
        XCTAssertEqual(antwort.1.statusCode, 404, "ohne Fixtures nie ins Netz")
        let erlaubt = await u.mitteiler.erlaubnisHolen()
        XCTAssertFalse(erlaubt)
        let zugriff = await u.healthLeser.zugriff(fuer: [.schritte])
        XCTAssertEqual(zugriff, .nichtVerfuegbar)
        XCTAssertEqual(u.bruecke.partner(jetzt: Date()), .nichtVerbunden)
    }

    func testVorschauMitFixturesLiefertDieDateiZumPfad() async throws {
        let ordner = try tempOrdner()
        try Data(#"{"ok":true}"#.utf8).write(to: ordner.appendingPathComponent("api_v2_product_123.json"))
        let u = AppUmgebung.vorschau(fixtures: ordner)
        let antwort = try await u.http.lade(URLRequest(url: try XCTUnwrap(URL(string: "https://example.org/api/v2/product/123"))))
        XCTAssertEqual(antwort.1.statusCode, 200)
        XCTAssertEqual(String(decoding: antwort.0, as: UTF8.self), #"{"ok":true}"#)
    }

    func testBandTageAusDemRaumFliessenInDenGesundheitsStand() async throws {
        let uhr = TestUhr()
        let u = umgebung(ordner: try tempOrdner(), uhr: uhr)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "abcd")
        let heute = Datum.text(uhr.lesen)
        let raum = try XCTUnwrap(u.daten?.raum)
        raum.senden("fit.band.tag", BandTagOp(tag: heute, schritte: 7000, meter: 5200))
        raum.senden("fit.band.tag", BandTagOp(tag: heute, schritte: 8000, meter: 6100))
        XCTAssertEqual(u.gesundheit.tage[heute]?.schritte, 8000, "die letzte Op je Tag gewinnt")
        XCTAssertEqual(u.gesundheit.tage[heute]?.distanzMeter, 6100)
    }
}
