import XCTest
@testable import LumenFit

/// Der Coach antwortet wirklich: echtes Modell am Server, ehrlicher Text statt Scheinantwort, Knopftext statt Bezeichner, keine leere Leiste.
final class CoachServerTests: XCTestCase {
    // Die Frage aus dem Bildschirmfoto vom 31.10.: lang, mit "protein" darin, aber nichts, was ein Stichwort-Regelcoach beantworten könnte.
    private let langeFrage = "Wenn ich montag bis Dienstag 120g protein esse nehme ich muskeln ab?"

    private enum Verhalten: Sendable { case antwort(String), fehler, haengt }

    private final class Motor: CoachMotor, @unchecked Sendable {
        // @unchecked Sendable: Zähler und Schalter stehen nur unter dem Schloss.
        private let schloss = NSLock()
        private var _fragen = 0
        private var _bereit: Bool
        let name: String
        let verhalten: Verhalten

        init(_ name: String, bereit: Bool = true, _ verhalten: Verhalten) { self.name = name; _bereit = bereit; self.verhalten = verhalten }

        var fragen: Int { schloss.withLock { _fragen } }
        func verfuegbar() async -> Bool { schloss.withLock { _bereit } }

        func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
            schloss.withLock { _fragen += 1 }
            switch verhalten {
            case .antwort(let text): return CoachAntwort(text: text, chips: [])
            case .fehler: throw CoachMotorFehler.nichtBereit
            case .haengt:
                try await Task.sleep(for: .seconds(30))
                return CoachAntwort(text: "zu spät", chips: [])
            }
        }
    }

    private func wahl(server: Motor?, apple: Motor, regeln: Motor, serverFrist: TimeInterval = 5) -> CoachWahlMotor {
        CoachWahlMotor(modell: apple, regeln: regeln, frist: 5, server: server, serverFrist: serverFrist)
    }

    // MARK: - Motorwahl

    func testMitServerAntwortetNurDasServerModell() async throws {
        let server = Motor("Server", .antwort("Zwei Tage ändern daran nichts.")), apple = Motor("Apple", .antwort("Apple")), regeln = Motor("Regeln", .antwort("Regel"))
        let antwort = try await wahl(server: server, apple: apple, regeln: regeln).antworte(CoachTestBau.anfrage(langeFrage))
        XCTAssertEqual(antwort.text, "Zwei Tage ändern daran nichts.")
        XCTAssertEqual(server.fragen, 1)
        XCTAssertEqual(apple.fragen, 0, "das kleine Modell auf dem Gerät antwortet nicht, wenn der Server es kann")
        XCTAssertEqual(regeln.fragen, 0)
    }

    func testFaelltDerServerAusGibtEsKeineScheinantwortZurLangenFrage() async {
        for verhalten in [Verhalten.fehler, .haengt] {
            let server = Motor("Server", verhalten), apple = Motor("Apple", .antwort("Heute fühlst du dich bereit.")), regeln = Motor("Regeln", .antwort("Regel"))
            do {
                _ = try await wahl(server: server, apple: apple, regeln: regeln, serverFrist: 0.2).antworte(CoachTestBau.anfrage(langeFrage))
                XCTFail("hätte ehrlich scheitern müssen")
            } catch {
                XCTAssertEqual(error as? CoachMotorFehler, .nichtVerstanden)
            }
            XCTAssertEqual(apple.fragen, 0)
            XCTAssertEqual(regeln.fragen, 0, "die Regeln raten nicht bei einer Frage, die sie nicht verstehen")
        }
    }

    func testFaelltDerServerAusAntwortenDieRegelnAufFesteFragen() async throws {
        let server = Motor("Server", .fehler), regeln = Motor("Regeln", .antwort("Regel"))
        let antwort = try await wahl(server: server, apple: Motor("Apple", .antwort("Apple")), regeln: regeln).antworte(CoachTestBau.anfrage("Tagesbericht"))
        XCTAssertEqual(antwort.text, "Regel")
        XCTAssertEqual(regeln.fragen, 1)
    }

    func testServerNichtFreigegebenNimmtAppleUndOhneBeidesKeinRaten() async throws {
        let server = Motor("Server", bereit: false, .antwort("Server")), apple = Motor("Apple", .antwort("Apple")), regeln = Motor("Regeln", .antwort("Regel"))
        let antwort = try await wahl(server: server, apple: apple, regeln: regeln).antworte(CoachTestBau.anfrage(langeFrage))
        XCTAssertEqual(antwort.text, "Apple")
        XCTAssertEqual(server.fragen, 0)

        let ohne = Motor("Apple", bereit: false, .antwort("Apple"))
        do {
            _ = try await wahl(server: nil, apple: ohne, regeln: regeln).antworte(CoachTestBau.anfrage(langeFrage))
            XCTFail("ohne Modell keine Antwort auf diese Frage")
        } catch {
            XCTAssertEqual(error as? CoachMotorFehler, .nichtVerstanden)
        }
        XCTAssertEqual(regeln.fragen, 0)
    }

    func testDieServerFristIstKuerzerAlsDieTippanzeige() {
        XCTAssertLessThan(CoachWahl.serverFrist, CoachLokal.denkGrenze)
    }

    // MARK: - Was die Regeln wirklich verstehen

    func testRegelnVerstehenFesteFragenAberNichtDieFrageAusDemBildschirmfoto() {
        for frage in ["Tagesbericht", "Wie läuft mein Training?", "Was soll ich heute essen?", CoachLokal.wochenrueckblick, CoachLokal.luecken,
                      CoachLokal.gefuehl, CoachLokal.nochEssen, "Wie war mein Schlaf?", "Hallo", "Danke", "Mein Knie tut weh"] {
            XCTAssertTrue(CoachAbsicht.versteht(frage), frage)
        }
        for frage in [langeFrage, "Erkläre mir bitte in einfachen Worten meine Erholung heute. Die App sagt: Du hast dein Schlafziel erreicht.",
                      "Wie viel Protein brauche ich für Muskelaufbau?", "Was ist die Hauptstadt von Frankreich?", ""] {
            XCTAssertFalse(CoachAbsicht.versteht(frage), frage)
        }
    }

    // MARK: - Knopftext

    func testKnopftextIstNieDerBezeichner() {
        XCTAssertEqual(CoachModellUebersetzer.knopfText("morgen_leicht", art: "morgen_leicht"), "Morgen leicht")
        XCTAssertEqual(CoachModellUebersetzer.knopfText("  ", art: "mach_ich"), "", "leer bleibt leer, der Knopf fällt weg")
        XCTAssertEqual(CoachModellUebersetzer.knopfText("zeig_mir", art: "zeig_mir"), "Zeig mir")
        XCTAssertEqual(CoachModellUebersetzer.knopfText("Schlaf ansehen", art: "zeig_mir"), "Schlaf ansehen")
        let chips = CoachModellUebersetzer.chips([CoachRohChip(text: "morgen_leicht", art: "morgen_leicht", ziel: "")])
        XCTAssertEqual(chips.map(\.text), ["Morgen leicht"])
        XCTAssertEqual(chips.first?.aktion, .planMorgenLeicht)
    }

    // MARK: - Leere Leiste

    func testDieEintragsKarteStehtNurMitInhalt() {
        XCTAssertFalse(CoachLokal.eintragsKarteSichtbar(bestaetigt: 0, nichtGeklappt: false, vorschlag: 0), "sonst bleibt eine leere Leiste über dem Eingabefeld")
        XCTAssertTrue(CoachLokal.eintragsKarteSichtbar(bestaetigt: 1, nichtGeklappt: false, vorschlag: 0))
        XCTAssertTrue(CoachLokal.eintragsKarteSichtbar(bestaetigt: 0, nichtGeklappt: true, vorschlag: 0))
        XCTAssertTrue(CoachLokal.eintragsKarteSichtbar(bestaetigt: 0, nichtGeklappt: false, vorschlag: 2))
    }

    // MARK: - Chat zeigt den ehrlichen Text

    @MainActor
    func testNichtVerstandenZeigtDenEhrlichenTextOhneMerkenUndOhneChip() async throws {
        let wahl = CoachWahlMotor(modell: Motor("Apple", bereit: false, .fehler), regeln: Motor("Regeln", .antwort("Regel")), frist: 1)
        let (u, _, _) = try CoachTestBau.umgebung(motor: wahl)
        let modell = CoachModell(umgebung: u)
        modell.senden(langeFrage)
        while modell.denkt { await Task.yield() }
        let letzte = try XCTUnwrap(modell.verlauf.last)
        XCTAssertEqual(letzte.text, CoachPersona.nichtVerstandenText)
        XCTAssertTrue(letzte.chips.isEmpty)
        XCTAssertNil(modell.einstellungen?.stand.wartendeFrage, "ein Wiederholen würde nichts ändern")
        XCTAssertTrue(CoachPersona.istFehler(letzte.text))
        XCTAssertFalse(letzte.text.contains("Heute fühlst du dich bereit"))
    }

    // MARK: - Schlaf aus allen Quellen

    @MainActor
    func testCoachKenntDieNachtVonHandWieDerSchlafTab() throws {
        let (u, daten, _) = try CoachTestBau.umgebung(stunde: 14)
        XCTAssertNil(CoachDaten.kontext(u, daten).schlafMinuten, "noch keine Nacht")
        let tag = "2026-09-23"
        daten.raum.senden(SchlafHandLogik.art, SchlafHandD(tag: tag, bett: Datum.datum("2026-09-22").addingTimeInterval(23 * 3600), auf: Datum.datum(tag).addingTimeInterval(7 * 3600)))
        XCTAssertEqual(CoachDaten.kontext(u, daten).schlafMinuten, 480)
        XCTAssertEqual(CoachDaten.eingabe(u, daten).schlaf[tag], 480)
    }

    // MARK: - Anfrage an den Server

    func testAnfrageEnthaeltFrageVerlaufUndDieZahlenDerLetztenTage() throws {
        var e = CoachEingabe(heute: "2026-10-31")
        e.essenKcal = ["2026-10-26": 2400, "2026-10-27": 2300, "2026-09-01": 1000]
        e.essenProtein = ["2026-10-26": 120, "2026-10-27": 118.4, "2026-09-01": 50]
        e.gewicht = ["2026-10-27": 784]
        e.schritte = ["2026-10-30": 9000]
        e.schlaf = ["2026-10-31": 450]
        let verlauf = [CoachTestBau.nachricht("a", .nutzer, "Hi", Date(timeIntervalSince1970: 1)), CoachTestBau.nachricht("b", .coach, "Hallo [[morgen_leicht]]", Date(timeIntervalSince1970: 2))]
        let a = CoachServerMotor.anfrageBauen(CoachTestBau.anfrage(langeFrage, verlauf: verlauf, kontext: CoachTestBau.kontext(tag: "2026-10-31")), eingabe: e)
        XCTAssertEqual(a.frage, langeFrage)
        XCTAssertEqual(a.verlauf.map(\.rolle), ["du", "coach"])
        XCTAssertFalse(a.verlauf[1].text.contains("[["), "Marker gehen nicht an den Server")
        XCTAssertEqual(a.kontext.essen, [CoachServerMotor.ServerEssenTag(tag: "2026-10-27", kcal: 2300, protein: 118), CoachServerMotor.ServerEssenTag(tag: "2026-10-26", kcal: 2400, protein: 120)])
        XCTAssertEqual(a.kontext.gewicht, [CoachServerMotor.ServerGewichtTag(tag: "2026-10-27", kg: 78.4)])
        XCTAssertEqual(a.kontext.schlafTage, [CoachServerMotor.ServerSchlafTag(tag: "2026-10-31", minuten: 450)])
        XCTAssertEqual(a.kontext.schlafMinuten, 450)
        XCTAssertEqual(a.kontext.schritteTage.first?.n, 9000)
    }

    private struct Zugang: EssenKiZugang {
        let v: EssenKiVerbindung?
        func verbindung() -> EssenKiVerbindung? { v }
    }

    private let verbindung = EssenKiVerbindung(server: URL(string: "https://example.invalid/api")!, kopfzeilen: ["X-App-Key": "k", "X-Konto": "konto"])

    @MainActor
    private func serverMotor(_ lader: SkriptLader, verbunden: Bool = true, schluessel: String) -> CoachServerMotor {
        let zugang = Zugang(v: verbunden ? verbindung : nil)
        let freigabe = EssenKiFreigabe(zugang: zugang, lader: lader, uhr: { Date(timeIntervalSince1970: 1_000) }, schalter: "kiCoachErlaubt")
        return CoachServerMotor(zugang: zugang, lader: lader, freigabe: freigabe, eingabe: { nil }, merkSchluessel: schluessel)
    }

    @MainActor
    func testServerMotorSendetAnKiCoachUndUebersetztDieAntwort() async throws {
        let json = #"{"ok":true,"text":"Zwei Tage ändern daran nichts.","knoepfe":[{"text":"morgen_leicht","art":"morgen_leicht","ziel":""}],"rest":29}"#
        let lader = SkriptLader(status: 200, daten: Data(json.utf8))
        let antwort = try await serverMotor(lader, schluessel: "test.\(UUID().uuidString)").antworte(CoachTestBau.anfrage(langeFrage))
        XCTAssertEqual(antwort.text, "Zwei Tage ändern daran nichts.")
        XCTAssertEqual(antwort.chips.map(\.text), ["Morgen leicht"], "nie der rohe Bezeichner")
        let r = try XCTUnwrap(lader.anfragen.first)
        XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertEqual(r.url?.path, "/api/ki/coach")
        XCTAssertEqual(r.value(forHTTPHeaderField: "X-Konto"), "konto")
        let body = try XCTUnwrap(r.httpBody)
        let j = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(j["frage"] as? String, langeFrage)
        XCTAssertNotNil(j["kontext"] as? [String: Any])
    }

    @MainActor
    func testServerMotorMeldetFehlerStattZuRaten() async throws {
        for status in [403, 429, 502, 503] {
            let motor = serverMotor(SkriptLader(status: status, daten: Data("{}".utf8)), schluessel: "test.\(UUID().uuidString)")
            do {
                _ = try await motor.antworte(CoachTestBau.anfrage(langeFrage))
                XCTFail("Status \(status) ist keine Antwort")
            } catch {
                XCTAssertEqual(error as? CoachMotorFehler, .nichtBereit)
            }
        }
        do {
            _ = try await serverMotor(SkriptLader.fehler(.notConnectedToInternet), schluessel: "test.\(UUID().uuidString)").antworte(CoachTestBau.anfrage(langeFrage))
            XCTFail("ohne Netz keine Antwort")
        } catch {
            XCTAssertEqual(error as? CoachMotorFehler, .nichtBereit)
        }
        do {
            _ = try await serverMotor(SkriptLader(status: 200, daten: Data(#"{"ok":true,"text":"  "}"#.utf8)), schluessel: "test.\(UUID().uuidString)").antworte(CoachTestBau.anfrage(langeFrage))
            XCTFail("leerer Text ist keine Antwort")
        } catch {
            XCTAssertEqual(error as? CoachMotorFehler, CoachMotorFehler.leer)
        }
    }

    @MainActor
    func testServerMotorIstNurMitFreigabeVerfuegbarUndMerktSichDenStand() async {
        let schluessel = "test.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: schluessel) }
        let an = serverMotor(SkriptLader(status: 200, daten: Data(#"{"config":{"kiCoachErlaubt":true}}"#.utf8)), schluessel: schluessel)
        let ersteAntwort = await an.verfuegbar()
        XCTAssertTrue(ersteAntwort)
        // Funkloch beim nächsten Start: der letzte sichere Stand gilt weiter.
        let offline = serverMotor(SkriptLader.fehler(.notConnectedToInternet), schluessel: schluessel)
        let ohneNetz = await offline.verfuegbar()
        XCTAssertTrue(ohneNetz)
        // Der Foto-Schalter öffnet den Coach nicht; ein Verbot des Servers schließt ihn.
        let nurFoto = serverMotor(SkriptLader(status: 200, daten: Data(#"{"config":{"kiFotoErlaubt":true}}"#.utf8)), schluessel: "test.\(UUID().uuidString)")
        let foto = await nurFoto.verfuegbar()
        XCTAssertFalse(foto)
        let verboten = serverMotor(SkriptLader(status: 403, daten: Data()), schluessel: schluessel)
        let danach = await verboten.verfuegbar()
        XCTAssertFalse(danach)
    }
}
