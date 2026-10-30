import XCTest
@testable import LumenFit

/// Import aus Lovea: alles mit erfundenen Daten und einem `SkriptLader`; es gibt keine echte Verbindung.
@MainActor
final class ProfilLoveaImportTests: XCTestCase {
    private let zugang = ProfilLoveaZugang(server: URL(string: "https://lovea.example.invalid/basis/")!,
                                           kopfzeilen: ["X-App-Key": "app-test-schluessel", "X-Konto": "konto-test", "X-Geheimnis": "geheim-test"])
    private let start = TestUhr().lesen

    // MARK: - Hilfen

    /// Ein Eintrag, wie `GET /agent/ops` ihn liefert (`d` als Objekt, `zeit` als ISO-Text).
    private func eintrag(_ op: Op, seq: Int) throws -> [String: Any] {
        var j = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(op)) as? [String: Any])
        j["seq"] = seq
        return j
    }

    private func eintrag(_ art: String, _ d: [String: Any], seq: Int, id: String? = nil, zeit: String = "2026-09-23T10:00:00.123Z") -> [String: Any] {
        ["seq": seq, "id": id ?? "id-\(seq)", "art": art, "von": "person-a", "zeit": zeit, "d": d]
    }

    private func seite(_ eintraege: [[String: Any]], mehr: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["ops": eintraege, "mehr": mehr])
    }

    private func lader(_ seiten: [Data]) -> SkriptLader {
        SkriptLader(seiten.map { SkriptLader.Antwort(status: 200, daten: $0, fehler: nil) })
    }

    private func leeresProfil() throws -> (AppUmgebung, DatenSatz) {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "efgh")
        return (u, try XCTUnwrap(u.daten))
    }

    // MARK: - Freigabe

    func testFreigabeNurWennDerServerSieGibt() {
        XCTAssertFalse(LoveaFreigabe.erlaubt(freigegeben: false, demo: false), "ohne Antwort des Servers gesperrt")
        XCTAssertTrue(LoveaFreigabe.erlaubt(freigegeben: true, demo: false))
        XCTAssertTrue(LoveaFreigabe.erlaubt(freigegeben: false, demo: true), "nur die Debug-Demo darf es erzwingen")
    }

    func testOhneFreigabeKeinePostenKeinNetz() async throws {
        let (_, daten) = try leeresProfil()
        let l = lader([try seite([])])
        do {
            _ = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: l, freigegeben: false, bestaetigt: true)
            XCTFail("sollte nicht freigegeben sein")
        } catch let f as ProfilLoveaFehler {
            XCTAssertEqual(f, .nichtErlaubt)
        }
        XCTAssertEqual(l.aufrufe, 0)
    }

    // MARK: - Holen

    func testAnfrageTraegtPfadFilterUndKopfzeilen() async throws {
        let l = lader([try seite([])])
        _ = try await ProfilLoveaImport.hole(zugang: zugang, lader: l)
        let a = try XCTUnwrap(l.anfragen.first)
        let url = try XCTUnwrap(a.url)
        XCTAssertEqual(a.httpMethod, "GET", "nur lesen")
        XCTAssertEqual(url.path, "/basis/agent/ops")
        let q = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertNil(q["von"], "die Person setzt der Server aus dem Konto")
        XCTAssertEqual(q["seit"], "0")
        XCTAssertEqual(q["limit"], "200")
        XCTAssertEqual(q["aufsteigend"], "1")
        XCTAssertEqual(q["voll"], "1", "ohne voll=1 kürzt der Server große Rümpfe")
        XCTAssertEqual(a.value(forHTTPHeaderField: "X-App-Key"), "app-test-schluessel")
        XCTAssertEqual(a.value(forHTTPHeaderField: "X-Konto"), "konto-test")
        XCTAssertEqual(a.value(forHTTPHeaderField: "X-Geheimnis"), "geheim-test")
        XCTAssertNil(a.value(forHTTPHeaderField: "X-Lovea-Key"), "der Lovea-Schlüssel bleibt am Server")
    }

    func testSeitenFolgenDerHoechstenSeqUndBleibenInReihenfolge() async throws {
        let erste = try seite([eintrag("habit.setzen", ["art": "wasser"], seq: 5), eintrag("habit.setzen", ["art": "gym"], seq: 3)], mehr: true)
        let zweite = try seite([eintrag("habit.setzen", ["art": "koffein"], seq: 9)])
        let l = lader([erste, zweite])
        let abzug = try await ProfilLoveaImport.hole(zugang: zugang, lader: l)
        XCTAssertEqual(abzug.ops.map(\.seq), [3, 5, 9])
        XCTAssertEqual(l.aufrufe, 2)
        let zweiteUrl = try XCTUnwrap(l.anfragen.last?.url?.absoluteString)
        XCTAssertTrue(zweiteUrl.contains("seit=5"))
    }

    func testSeiteOhneFortschrittBrichtAb() async throws {
        let haengt = try seite([], mehr: true)
        let l = lader([haengt])
        do {
            _ = try await ProfilLoveaImport.hole(zugang: zugang, lader: l)
            XCTFail("sollte abbrechen")
        } catch let f as ProfilLoveaFehler {
            XCTAssertEqual(f, .antwortKaputt)
        }
        XCTAssertEqual(l.aufrufe, 1)
    }

    func testUnlesbareEintraegeWerdenGezaehltNichtVerworfen() async throws {
        let kaputt: [String: Any] = ["seq": 2, "art": "habit.setzen"]   // ohne id und zeit
        let l = lader([try seite([eintrag("habit.setzen", ["art": "gym"], seq: 1), kaputt])])
        let abzug = try await ProfilLoveaImport.hole(zugang: zugang, lader: l)
        XCTAssertEqual(abzug.ops.count, 1)
        XCTAssertEqual(abzug.unlesbar, 1)
    }

    func testFehlerSindFestUndEnthaltenWederSchluesselNochAdresse() async throws {
        let faelle: [(SkriptLader, ProfilLoveaFehler)] = [
            (SkriptLader.fehler(.notConnectedToInternet), .netz),
            (SkriptLader(status: 401, daten: Data()), .abgelehnt),
            (SkriptLader(status: 500, daten: Data()), .server(500)),
            (SkriptLader(status: 200, daten: Data("kein json".utf8)), .antwortKaputt),
        ]
        for (l, erwartet) in faelle {
            do {
                _ = try await ProfilLoveaImport.hole(zugang: zugang, lader: l)
                XCTFail("sollte scheitern")
            } catch let f as ProfilLoveaFehler {
                XCTAssertEqual(f, erwartet)
                let text = f.titel + f.hilfe
                XCTAssertFalse(text.contains("geheim-test") || text.contains("example.invalid"))
            }
        }
        XCTAssertTrue(ProfilLoveaFehler.netz.wiederholbar)
        XCTAssertFalse(ProfilLoveaFehler.abgelehnt.wiederholbar)
    }

    // MARK: - Tabelle: Filter und Abbildung je Art

    func testTabelleJeArt() {
        let leer = Data("{}".utf8)
        func b(_ art: String) -> ProfilLoveaBehandlung { ProfilLoveaArten.behandlung(art: art, d: leer) }
        for art in ["gym.plan", "gym.checkin", "gym.uebung", "gym.checkout", "gym.loeschen", "cardio.setzen", "essen.setzen", "lebensmittel.favorit",
                    "koerper.setzen", "habit.setzen", "habit.anlegen", "habit.loeschen",
                    "schlaf.setzen", "schlaf.zeiten", "schritte.setzen", "stimmung.setzen", "zyklus.tag", "zyklus.einstellung"] { XCTAssertEqual(b(art), .uebernehmen, art) }
        for art in ["coach.nachricht"] { XCTAssertEqual(b(art), .rohBehalten, art) }
        XCTAssertEqual(b("nachricht.neu"), .ausschliessen("Chat"))
        XCTAssertEqual(b("entwurf.setzen"), .ausschliessen("Chat"))
        XCTAssertEqual(b("notizbuch.setzen"), .ausschliessen("Notizen"))
        XCTAssertEqual(b("termin.setzen"), .ausschliessen("Kalender und Orte"))
        XCTAssertEqual(b("wecker.setzen"), .ausschliessen("Wecker und Erinnerungen"))
        XCTAssertEqual(b("figur.aussehen"), .ausschliessen("Figuren und Shop"))
        XCTAssertEqual(b("spiel.ergebnis"), .ausschliessen("Spiele"))
        XCTAssertEqual(b("zeichnung.op"), .ausschliessen("Zeichnen und Galerie"))
        XCTAssertEqual(b("irgendwas.neues"), .unbekannt)
    }

    func testEinstellungenNachSchluessel() {
        func b(_ schluessel: String) -> ProfilLoveaBehandlung {
            ProfilLoveaArten.behandlung(art: "einstellung.setzen", d: Data(#"{"schluessel":"\#(schluessel)","wert":1}"#.utf8))
        }
        XCTAssertEqual(b("ziel.ernaehrung.kcal"), .uebernehmen)
        XCTAssertEqual(b("ziel.prio.brust"), .uebernehmen)
        XCTAssertEqual(b("coach.name"), .uebernehmen)
        guard case .ausschliessen = b("chat.backdrop") else { return XCTFail("Chat-Einstellung gehört nicht zu Health") }
        guard case .ausschliessen = b("zimmer.tee") else { return XCTFail("Zimmer gehört nicht zu Health") }
    }

    // MARK: - Planen

    func testPlanTrenntNachTabelleUndBehaeltOriginalIdUndZeit() {
        let leer = Data("{}".utf8)
        let abzug = ProfilLoveaAbzug(ops: [
            ProfilLoveaOp(seq: 1, id: "a", art: "habit.setzen", zeit: "2026-09-23T10:00:00.250Z", d: leer),
            ProfilLoveaOp(seq: 2, id: "b", art: "nachricht.neu", zeit: "2026-09-23T10:00:01Z", d: leer),
            ProfilLoveaOp(seq: 3, id: "c", art: "schritte.setzen", zeit: "2026-09-23T10:00:02Z", d: leer),
            ProfilLoveaOp(seq: 4, id: "d", art: "neu.unbekannt", zeit: "2026-09-23T10:00:03Z", d: leer),
            ProfilLoveaOp(seq: 5, id: "e", art: "habit.setzen", zeit: "kaputt", d: leer),
        ], unlesbar: 1)
        let plan = ProfilLoveaImport.plane(abzug, fuer: TestDaten.profilID)
        XCTAssertEqual(plan.ops.map(\.id), ["a", "c"])
        XCTAssertEqual(plan.ops.map(\.von), [TestDaten.profilID, TestDaten.profilID])
        XCTAssertEqual(plan.ops[0].zeit.timeIntervalSince1970 - plan.ops[1].zeit.timeIntervalSince1970, -1.75, accuracy: 0.001, "mit und ohne Bruchteil")
        XCTAssertEqual(plan.abdeckung.uebernommen, ["habit.setzen": 2, "schritte.setzen": 1])
        XCTAssertEqual(plan.abdeckung.roh, [:])
        XCTAssertEqual(plan.abdeckung.ausgeschlossen, ["Chat": ["nachricht.neu": 1]])
        XCTAssertEqual(plan.abdeckung.unbekannt, ["neu.unbekannt": 1])
        XCTAssertEqual(plan.abdeckung.unlesbar, 2, "ein unlesbarer Eintrag aus dem Holen und eine kaputte Zeit")
    }

    // MARK: - Einspielen

    private func gymUndEssenAbzug() throws -> ProfilLoveaAbzug {
        let ops = TestDaten.gymOps(start: start) + TestDaten.essenOps(datum: "2026-09-23", zeit: start)
        var seq = 0
        var abzug = ProfilLoveaAbzug()
        for op in ops {
            seq += 1
            abzug.ops.append(ProfilLoveaOp(seq: seq, id: op.id, art: op.art, zeit: "2026-09-23T10:00:00Z", d: op.d))
        }
        abzug.ops.append(ProfilLoveaOp(seq: 99, id: "chat-1", art: "nachricht.neu", zeit: "2026-09-23T10:00:00Z", d: Data("{}".utf8)))
        return abzug
    }

    func testEinspielenInLeeresProfilZaehltTrainingsUndEssen() async throws {
        let (_, daten) = try leeresProfil()
        let plan = ProfilLoveaImport.plane(try gymUndEssenAbzug(), fuer: daten.profil)
        let e = try await ProfilLoveaImport.spieleEin(plan, in: daten)
        XCTAssertEqual(e.neu, 6)
        XCTAssertEqual(e.schonDa, 0)
        XCTAssertEqual(e.trainings, 1)
        XCTAssertEqual(e.essenstage, 1)
        XCTAssertEqual(e.abdeckung.ausgeschlossenGesamt, 1, "Chat wird nicht übernommen")
        XCTAssertEqual(ProfilSicherungLogik.alleOps(daten).map(\.id), plan.ops.map(\.id), "Originalreihenfolge im Log")
    }

    func testZweiterImportVerdoppeltNichts() async throws {
        let (_, daten) = try leeresProfil()
        let plan = ProfilLoveaImport.plane(try gymUndEssenAbzug(), fuer: daten.profil)
        _ = try await ProfilLoveaImport.spieleEin(plan, in: daten)
        let zweiter = try await ProfilLoveaImport.spieleEin(plan, in: daten)
        XCTAssertEqual(zweiter.neu, 0)
        XCTAssertEqual(zweiter.schonDa, 6)
        XCTAssertEqual(zweiter.trainings, 1)
        XCTAssertEqual(ProfilSicherungLogik.alleOps(daten).count, 6)
    }

    func testReihenfolgeEntscheidetBeiGleicherHabitZeile() async throws {
        let (_, daten) = try leeresProfil()
        let d1 = try JSONEncoder().encode(HabitSetzenD(art: "wasser", datum: "2026-09-23", wert: 2))
        let d2 = try JSONEncoder().encode(HabitSetzenD(art: "wasser", datum: "2026-09-23", wert: 7))
        let abzug = ProfilLoveaAbzug(ops: [
            ProfilLoveaOp(seq: 1, id: "h1", art: "habit.setzen", zeit: "2026-09-23T08:00:00Z", d: d1),
            ProfilLoveaOp(seq: 2, id: "h2", art: "habit.setzen", zeit: "2026-09-23T09:00:00Z", d: d2),
        ])
        _ = try await ProfilLoveaImport.spieleEin(ProfilLoveaImport.plane(abzug, fuer: daten.profil), in: daten)
        XCTAssertEqual(daten.habits.wert("wasser", "2026-09-23"), 7)
    }

    func testNichtLeeresProfilBrauchtBestaetigung() async throws {
        let (_, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let l = lader([try seite([])])
        do {
            _ = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: l, freigegeben: true, bestaetigt: false)
            XCTFail("sollte nachfragen")
        } catch let f as ProfilLoveaFehler {
            XCTAssertEqual(f, .profilNichtLeer)
        }
        XCTAssertEqual(l.aufrufe, 0, "vor der Bestätigung wird nichts geholt")
        let e = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: l, freigegeben: true, bestaetigt: true)
        XCTAssertEqual(e.neu, 0)
    }

    func testNichtLeeresProfilBehaeltNeuerePlaene() async throws {
        let (_, daten) = try leeresProfil()
        let neu = TestDaten.op("gym.plan", ["x": 1], von: daten.profil, zeit: start + 1000, id: "plan-neu")
        daten.raum.einreihen(neu)
        let abzug = ProfilLoveaAbzug(ops: [ProfilLoveaOp(seq: 1, id: "plan-alt", art: "gym.plan", zeit: "2026-09-23T10:00:00Z", d: Data(#"{"x":0}"#.utf8))])
        let e = try await ProfilLoveaImport.spieleEin(ProfilLoveaImport.plane(abzug, fuer: daten.profil), in: daten)
        XCTAssertEqual(e.uebersprungen, 1)
        XCTAssertEqual(e.neu, 0)
    }

    func testNetzfehlerLaesstDasProfilLeerUndLaesstSichWiederholen() async throws {
        let (_, daten) = try leeresProfil()
        let kaputt = SkriptLader.fehler(.timedOut)
        do {
            _ = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: kaputt, freigegeben: true, bestaetigt: false)
            XCTFail("sollte scheitern")
        } catch let f as ProfilLoveaFehler {
            XCTAssertEqual(f, .netz)
        }
        XCTAssertFalse(ProfilSicherungLogik.hatDaten(daten), "nichts geschrieben, das Profil ist weiter leer")
        let gut = lader([try seite([eintrag("habit.setzen", ["art": "gym", "datum": "2026-09-23", "wert": 1], seq: 1)])])
        let e = try await ProfilLoveaImport.fuehreAus(zugang: zugang, in: daten, lader: gut, freigegeben: true, bestaetigt: false)
        XCTAssertEqual(e.neu, 1)
    }

    // MARK: - Beleg

    func testBelegZaehltJedeArtUndFindetAllesWiederUndIstVollstaendig() async throws {
        let (_, daten) = try leeresProfil()
        var abzug = try gymUndEssenAbzug()
        abzug.hoechsteSeq = 99
        let plan = ProfilLoveaImport.plane(abzug, fuer: daten.profil)
        let e = try await ProfilLoveaImport.spieleEin(plan, in: daten)
        let beleg = ProfilLoveaBeleg.baue(e, zeit: start)
        XCTAssertTrue(beleg.vollstaendig)
        XCTAssertEqual(beleg.arten["nachricht.neu"]?.geholt, 1)
        XCTAssertEqual(beleg.arten["nachricht.neu"]?.ausgeschlossen, 1)
        XCTAssertEqual(beleg.arten["nachricht.neu"]?.grund, "Chat")
        XCTAssertEqual(beleg.arten.values.map(\.geplant).reduce(0, +), 6)
        XCTAssertEqual(beleg.arten.values.map(\.wiedergefunden).reduce(0, +), 6, "echtes Zurücklesen aus dem Speicher")
        XCTAssertEqual(beleg.seqMax, 99)
        // Zweiter Lauf: alles schon da, trotzdem wiedergefunden.
        let zweiter = try await ProfilLoveaImport.spieleEin(plan, in: daten)
        XCTAssertEqual(ProfilLoveaBeleg.baue(zweiter, zeit: start).arten.values.map(\.wiedergefunden).reduce(0, +), 6)
        XCTAssertEqual(zweiter.neu, 0)
    }

    func testBelegIstUnvollstaendigBeiUnbekanntemFehlenderZeitOderFehlendemZuruecklesen() {
        let leer = Data("{}".utf8)
        let abzug = ProfilLoveaAbzug(ops: [
            ProfilLoveaOp(seq: 1, id: "a", art: "habit.setzen", zeit: "2026-09-23T10:00:00Z", d: leer),
            ProfilLoveaOp(seq: 2, id: "b", art: "neu.unbekannt", zeit: "2026-09-23T10:00:03Z", d: leer),
        ], hoechsteSeq: 2)
        let plan = ProfilLoveaImport.plane(abzug, fuer: TestDaten.profilID)
        var e = ProfilLoveaErgebnis(neu: 1, schonDa: 0, uebersprungen: 0, trainings: 0, essenstage: 0, abdeckung: plan.abdeckung,
                                    geplant: ["habit.setzen": 1], wiedergefunden: ["habit.setzen": 1])
        XCTAssertFalse(ProfilLoveaBeleg.baue(e, zeit: start).vollstaendig, "eine unbekannte Art")
        e.abdeckung.unbekannt = [:]
        e.abdeckung.geholt["neu.unbekannt"] = nil
        XCTAssertTrue(ProfilLoveaBeleg.baue(e, zeit: start).vollstaendig)
        e.wiedergefunden = ["habit.setzen": 0]
        XCTAssertFalse(ProfilLoveaBeleg.baue(e, zeit: start).vollstaendig, "weniger im Speicher als geplant")
        e.wiedergefunden = ["habit.setzen": 1]
        e.abdeckung.unlesbar = 1
        XCTAssertFalse(ProfilLoveaBeleg.baue(e, zeit: start).vollstaendig, "unlesbarer Eintrag")
    }

    func testBelegNenntNurFesteWorteUndZahlen() throws {
        let leer = Data("{}".utf8)
        let abzug = ProfilLoveaAbzug(ops: [ProfilLoveaOp(seq: 1, id: "a", art: "Seltsame Art!", zeit: "2026-09-23T10:00:00Z", d: leer)], hoechsteSeq: 1)
        let plan = ProfilLoveaImport.plane(abzug, fuer: TestDaten.profilID)
        let e = ProfilLoveaErgebnis(neu: 0, schonDa: 0, uebersprungen: 0, trainings: 0, essenstage: 0, abdeckung: plan.abdeckung)
        let beleg = ProfilLoveaBeleg.baue(e, zeit: start)
        XCTAssertEqual(Array(beleg.arten.keys), ["andere.art"], "ein Name, den der Server nicht annimmt, läuft im Sammelpunkt zusammen")
        let json = String(decoding: try JSONEncoder().encode(beleg), as: UTF8.self)
        XCTAssertFalse(json.contains("Seltsame"))
        XCTAssertEqual(ProfilLoveaFehler.netz.belegName, "netz")
        XCTAssertEqual(ProfilLoveaFehler.server(500).belegName, "server")
    }

    func testHoleMerktWieWeitGeladenWurdeAuchBeimFehler() async throws {
        let stand = ProfilLoveaLadeStand()
        let erste = try seite([eintrag("habit.setzen", [:], seq: 7)], mehr: true)
        let l = SkriptLader([.init(status: 200, daten: erste, fehler: nil), .init(status: 0, daten: Data(), fehler: .notConnectedToInternet)])
        do {
            _ = try await ProfilLoveaImport.hole(zugang: zugang, lader: l, stand: stand)
            XCTFail("sollte scheitern")
        } catch let f as ProfilLoveaFehler {
            XCTAssertEqual(f, .netz)
        }
        XCTAssertEqual(stand.geladen, 1)
        XCTAssertEqual(stand.bisSeq, 7)
    }

    func testLetzteGewinntBeiEinstellungenJeSchluessel() async throws {
        let (_, daten) = try leeresProfil()
        daten.raum.einreihen(TestDaten.op("einstellung.setzen", ["schluessel": "ziel.prio.brust", "wert": "1"], von: daten.profil, zeit: start + 1000, id: "lokal"))
        let alt = Data(#"{"schluessel":"ziel.schritte","wert":9000}"#.utf8)
        let abzug = ProfilLoveaAbzug(ops: [ProfilLoveaOp(seq: 1, id: "lovea-ziel", art: "einstellung.setzen", zeit: "2026-09-23T10:00:00Z", d: alt)], hoechsteSeq: 1)
        let e = try await ProfilLoveaImport.spieleEin(ProfilLoveaImport.plane(abzug, fuer: daten.profil), in: daten)
        XCTAssertEqual(e.neu, 1, "ein anderes Ziel wird nicht von einem neueren überdeckt")
        XCTAssertEqual(e.wiedergefunden["einstellung.setzen"], 1)
    }

    func testTabelleEssensVorraeteUndKonsistenzGehenNichtVerloren() {
        let leer = Data("{}".utf8)
        for art in ["einkauf.liste", "kuehl.setzen", "kuehl.weg"] { XCTAssertEqual(ProfilLoveaArten.behandlung(art: art, d: leer), .rohBehalten, art) }
        XCTAssertEqual(ProfilLoveaArten.behandlung(art: "einstellung.setzen", d: Data(#"{"schluessel":"konsistenz.kategorien","wert":"x"}"#.utf8)), .uebernehmen)
    }
}
