import XCTest
@testable import LumenFit

/// Der Crew-Dienst ohne Netz: Cache lesen, kaputter Cache kippt nichts, neue Herausforderung nach den Regeln des Servers, Demo nur in DEBUG.
@MainActor
final class CrewDienstTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")
    private let hexId = String(repeating: "a", count: 32)

    /// Ein Netz, das nach Methode und Pfad antwortet (Status 0 = kein Netz); alles Unbekannte ist 404. Merkt jede Anfrage.
    private final class PfadLader: HTTPLader, @unchecked Sendable {
        // @unchecked Sendable: jeder Zugriff auf die Felder läuft über `schloss`.
        private let schloss = NSLock()
        private var antworten: [String: (status: Int, daten: Data)] = [
            "POST /konto": (201, Data("{}".utf8)), "GET /config": (200, Data(#"{"config":{}}"#.utf8)), "GET /lovea/freigabe": (200, Data("{}".utf8)),
        ]
        private var _anfragen: [String] = []

        func setze(_ methode: String, _ pfad: String, _ status: Int, _ daten: Data = Data("{}".utf8)) {
            schloss.withLock { antworten["\(methode) \(pfad)"] = (status, daten) }
        }

        var anfragen: [String] { schloss.withLock { _anfragen } }

        func lade(_ anfrage: URLRequest) async throws -> (Data, HTTPURLResponse) {
            let schluessel = "\(anfrage.httpMethod ?? "GET") \(anfrage.url?.path ?? "")"
            let antwort: (status: Int, daten: Data) = schloss.withLock {
                _anfragen.append(schluessel)
                return antworten[schluessel] ?? (404, Data())
            }
            if antwort.status == 0 { throw URLError(.notConnectedToInternet) }
            guard let http = HTTPURLResponse(url: anfrage.url ?? URL(fileURLWithPath: "/"), statusCode: antwort.status, httpVersion: "HTTP/1.1", headerFields: nil) else { throw HTTPFehler.keineAntwort }
            return (antwort.daten, http)
        }
    }

    /// Eine Umgebung mit angemeldetem Konto und einem Profil "Beispiel" (aktiv).
    private func umgebungMitKonto(_ lader: PfadLader) async throws -> AppUmgebung {
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: lader, mitteiler: StilleMitteilung(),
                            leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: { CrewTestDaten.jetzt },
                            passwortRunden: 1_000, kontoZugang: zugang)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "")
        await u.konto.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertNotNil(u.konto.registrierteKennung(), "das Konto ist angemeldet")
        return u
    }

    /// Legt einen Auftrag in die Warteschlange (wie nach einem Start ohne Netz) und lässt den Dienst einmal abgleichen. Rückgabe: was danach noch wartet.
    private func ausstehendNachAbgleich(status: Int) async throws -> [CrewAuftrag] {
        let lader = PfadLader()
        let pfad = "/freunde/herausforderungen/\(hexId)/annehmen"
        lader.setze("POST", pfad, status)
        let u = try await umgebungMitKonto(lader)
        try FileManager.default.createDirectory(at: u.konto.ordner, withIntermediateDirectories: true)
        try JSONEncoder().encode([CrewAuftrag(pfad: pfad, methode: "POST", koerper: nil)]).write(to: u.konto.ordner.appendingPathComponent(CrewDienst.ausstehendName))
        let dienst = CrewDienst(umgebung: u)
        XCTAssertEqual(dienst.ausstehend.count, 1)
        await dienst.laden(erzwingen: true)
        XCTAssertEqual(lader.anfragen.filter { $0 == "POST \(pfad)" }.count, 1, "der Auftrag wurde versucht")
        return dienst.ausstehend
    }

    func testAusstehendBleibtLiegenBeiKeinNetz429Und5xx() async throws {
        for status in [0, 429, 500, 502, 503] {
            let rest = try await ausstehendNachAbgleich(status: status)
            XCTAssertEqual(rest.count, 1, "Status \(status): Annehmen oder Reaktion darf nicht verloren gehen")
        }
    }

    func testAusstehendFaelltBeiAntwortenDesServersWeg() async throws {
        for status in [200, 201, 400, 403, 404, 409] {
            let rest = try await ausstehendNachAbgleich(status: status)
            XCTAssertTrue(rest.isEmpty, "Status \(status): der Server hat entschieden")
        }
    }

    func testWerteGehenNurFuerDasProfilDesKontosRaus() async throws {
        let lader = PfadLader()
        let u = try await umgebungMitKonto(lader)
        let erstes = try XCTUnwrap(u.profil.aktiv)
        u.konto.gehoertZuProfil(erstes.id)   // wie der Abgleich beim Start
        // Ich bin dabei, der Server kennt 5 Sätze; ohne Einheiten im Profil rechnet die App 0 und würde 0 melden.
        let h = CrewHerausforderung(id: hexId, mass: .saetze, modus: .gegen, start: Datum.datum("2025-10-27"), ende: Datum.datum("2025-11-03"),
                                    teilnehmer: [CrewTeilnehmer(id: "ich-x", ich: true, name: "Du", wert: 5), CrewTeilnehmer(id: "v0", name: "Freund", wert: 0)])
        lader.setze("GET", "/freunde", 200, try LoveaVertrag.encoder().encode(CrewAntwort(herausforderungen: [h])))
        lader.setze("PUT", "/freunde/werte", 200)
        let dienst = CrewDienst(umgebung: u)

        _ = try u.profil.anlegen(name: "Zweit", passwort: "")   // aktiv ist jetzt ein anderes Profil
        XCTAssertNotEqual(u.profil.aktiv?.id, erstes.id)
        await dienst.laden(erzwingen: true)
        XCTAssertTrue(lader.anfragen.contains("GET /freunde"))
        XCTAssertFalse(lader.anfragen.contains("PUT /freunde/werte"), "die Werte des zweiten Profils gehören nicht dem Konto")

        XCTAssertTrue(u.profil.wechsle(zu: erstes.id, passwort: ""))
        await dienst.laden(erzwingen: true)
        XCTAssertEqual(lader.anfragen.filter { $0 == "PUT /freunde/werte" }.count, 1, "mit dem Profil des Kontos geht es raus")
    }

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

    /// Offline zuerst: ohne Netz wartet Annehmen in der Warteschlange und überlebt einen Neustart (Likes gibt es seit Build 19 nicht mehr, W-034).
    func testOhneNetzWartetAnnehmenUndUeberlebtNeustart() async {
        let umgebung = AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)
        let dienst = CrewDienst(umgebung: umgebung)
        let id = String(repeating: "a", count: 32)
        let fehler = await dienst.annehmen(id)
        XCTAssertNil(fehler)
        XCTAssertEqual(dienst.ausstehend.map(\.pfad), ["/freunde/herausforderungen/\(id)/annehmen"])
        XCTAssertEqual(CrewDienst(umgebung: umgebung).ausstehend.count, 1)
    }

    /// "Für dich" und die Zahl am Tab: nur wer über meine Einladung neu verbunden ist, keine Reaktionen mehr.
    func testNeueSindNeuVerbundeneNichtReaktionen() {
        let umgebung = AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)
        let jetzt = umgebung.uhr()
        umgebung.konto.verbindungen.setze(VerbindungenAntwort(verbindungen: [
            VerbindungEintrag(id: "neu", name: "Freund A", erstellt: jetzt.addingTimeInterval(-60), eingeladen: true),
            VerbindungEintrag(id: "selbst", name: "Freund B", erstellt: jetzt.addingTimeInterval(-60), eingeladen: false),
        ]))
        let dienst = CrewDienst(umgebung: umgebung)
        XCTAssertEqual(dienst.neue(seit: nil).map(\.id), ["neu"])
        XCTAssertEqual(dienst.neue(seit: jetzt).map(\.id), [])
    }

    #if DEBUG
    func testDemoHatZweiHerausforderungenUndDreiReaktionenOhneEchteNamen() {
        let a = CrewDemo.antwort(jetzt: CrewTestDaten.jetzt)
        XCTAssertEqual(a.herausforderungen.count, 2)
        XCTAssertEqual(a.reaktionen.count, 3)
        XCTAssertTrue(a.reaktionen.allSatisfy { $0.name.hasPrefix("Beispiel Freund") })
        XCTAssertTrue(a.herausforderungen.allSatisfy { CrewLogik.istId($0.id) })
        let umgebung = AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)
        XCTAssertEqual(CrewDienst(umgebung: umgebung, demo: true).antwort?.herausforderungen.count, 2)
    }
    #endif
}
