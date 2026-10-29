import XCTest
@testable import LumenFit

/// Zustand des Coach-Tabs: Fluss einer Frage (Senden, Tippanzeige, Antwort, Fehler mit gemerkter Frage), Daumen, Merkliste, Schnellfragen.
@MainActor
final class CoachModellTests: XCTestCase {
    /// Wirft immer: das Modell ist weg, der Zug ist ab.
    private struct WerfenderMotor: CoachMotor {
        var name: String { "Werfend" }
        func verfuegbar() async -> Bool { true }
        func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort { throw CoachMotorFehler.nichtBereit }
    }

    /// Antwortet nie in der Frist.
    private struct HaengenderMotor: CoachMotor {
        var name: String { "Haengend" }
        func verfuegbar() async -> Bool { true }
        func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
            try await Task.sleep(for: .seconds(30))
            return CoachAntwort(text: "zu spät", chips: [])
        }
    }

    private func warte(_ modell: CoachModell, sekunden: Double = 10) async {
        let ende = Date().addingTimeInterval(sekunden)
        while modell.denkt, Date() < ende { try? await Task.sleep(for: .milliseconds(10)) }
    }

    // MARK: - Fluss

    func testFrageUndAntwortStehenImVerlaufUndDerEntwurfIstLeer() async throws {
        let motor = FakeCoachMotor(texte: ["Du hast gut geschlafen."])
        let (u, _, _) = try CoachTestBau.umgebung(motor: motor)
        let modell = CoachModell(umgebung: u)
        modell.entwurf = "  Wie war mein Schlaf? "
        modell.senden()
        XCTAssertTrue(modell.denkt)
        XCTAssertEqual(modell.entwurf, "")
        await warte(modell)
        XCTAssertFalse(modell.denkt)
        XCTAssertNil(modell.denkBeginn)
        XCTAssertEqual(modell.verlauf.map(\.rolle), [.nutzer, .coach])
        XCTAssertEqual(modell.verlauf.map(\.text), ["Wie war mein Schlaf?", "Du hast gut geschlafen."])
        XCTAssertNil(modell.einstellungen?.stand.wartendeFrage)
        XCTAssertEqual(motor.anfragen, 1)
    }

    func testLeereUndZuLangeFragenGehenNichtDurch() throws {
        let motor = FakeCoachMotor()
        let (u, _, _) = try CoachTestBau.umgebung(motor: motor)
        let modell = CoachModell(umgebung: u)
        modell.entwurf = "   \n "
        modell.senden()
        modell.senden(String(repeating: "a", count: CoachModell.maxZeichen + 1))
        XCTAssertFalse(modell.denkt)
        XCTAssertTrue(modell.verlauf.isEmpty)
        XCTAssertEqual(motor.anfragen, 0)
    }

    func testEineFrageNachDerAnderenWaehrendDerCoachDenktPassiertNichts() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: HaengenderMotor())
        let modell = CoachModell(umgebung: u, frist: 0.3)
        modell.senden("Erste Frage?")
        modell.senden("Zweite Frage?")
        XCTAssertEqual(modell.verlauf.filter { $0.rolle == .nutzer }.map(\.text), ["Erste Frage?"])
        await warte(modell)
    }

    func testDasGespraechGehtMitDemKontextAnDenMotor() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: FakeCoachMotor(texte: ["Eins.", "Zwei."]))
        let modell = CoachModell(umgebung: u)
        modell.senden("Erste Frage?")
        await warte(modell)
        modell.senden("Zweite Frage?")
        await warte(modell)
        XCTAssertEqual(modell.verlauf.map(\.text), ["Erste Frage?", "Eins.", "Zweite Frage?", "Zwei."])
    }

    // MARK: - Fehler (Idee 61, 62: ruhig, nie ein rohes Fehlerwort)

    func testFehlerGibtRuhigenTextMitNochmalChipUndMerktDieFrage() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: WerfenderMotor())
        let modell = CoachModell(umgebung: u)
        modell.senden("Wie war mein Schlaf?")
        await warte(modell)
        let letzte = try XCTUnwrap(modell.verlauf.last)
        XCTAssertEqual(letzte.rolle, .coach)
        XCTAssertEqual(letzte.text, "Gerade nicht erreichbar, ich merke mir deine Frage.")
        XCTAssertEqual(letzte.chips.map(\.text), ["Nochmal"])
        XCTAssertEqual(modell.einstellungen?.stand.wartendeFrage, "Wie war mein Schlaf?")
        XCTAssertFalse(letzte.text.lowercased().contains("error"))
        XCTAssertFalse(letzte.text.contains("CoachMotorFehler"))
    }

    func testDieTippanzeigeStehtHoechstensBisZurFrist() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: HaengenderMotor())
        let modell = CoachModell(umgebung: u, frist: 0.3)
        let start = Date()
        modell.senden("Wie war mein Schlaf?")
        XCTAssertNotNil(modell.denkBeginn)
        await warte(modell)
        XCTAssertFalse(modell.denkt)
        XCTAssertLessThan(Date().timeIntervalSince(start), 8, "nicht auf das Modell warten")
        XCTAssertEqual(modell.verlauf.last?.text, CoachPersona.fehlerText)
        XCTAssertEqual(CoachModell(umgebung: u).frist, CoachLokal.denkGrenze, "Standard sind 15 Sekunden")
    }

    func testHaengtDasModellAntwortenDieRegelnStattDesFehlertextes() async throws {
        let regeln = FakeCoachMotor(name: "Regeln", texte: ["Die Regeln antworten."])
        let wahl = CoachWahlMotor(modell: HaengenderMotor(), regeln: regeln, frist: 0.2)
        let (u, _, _) = try CoachTestBau.umgebung(motor: wahl)
        let modell = CoachModell(umgebung: u, frist: 3)
        modell.senden("Wie war mein Schlaf?")
        await warte(modell)
        XCTAssertEqual(modell.verlauf.last?.text, "Die Regeln antworten.", "die Frist des Modells ist kürzer als die der Tippanzeige")
        XCTAssertNil(modell.einstellungen?.stand.wartendeFrage)
        XCTAssertEqual(regeln.anfragen, 1)
    }

    func testGemerkteFrageWirdBeimNaechstenVordergrundNocheinmalGestellt() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: WerfenderMotor())
        let modell = CoachModell(umgebung: u)
        modell.senden("Wie war mein Schlaf?")
        await warte(modell)
        XCTAssertEqual(modell.einstellungen?.stand.wartendeFrage, "Wie war mein Schlaf?")

        let gut = FakeCoachMotor(texte: ["Du hast gut geschlafen."])
        u.coachMotor = gut
        modell.beiVordergrund()
        XCTAssertTrue(modell.denkt)
        await warte(modell)
        XCTAssertEqual(modell.verlauf.last?.text, "Du hast gut geschlafen.")
        XCTAssertNil(modell.einstellungen?.stand.wartendeFrage, "nach der Antwort ist nichts mehr gemerkt")
        XCTAssertEqual(gut.anfragen, 1)

        modell.beiVordergrund()
        XCTAssertFalse(modell.denkt, "ohne gemerkte Frage passiert nichts")
    }

    func testNochmalChipStelltDieFrageNeu() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: WerfenderMotor())
        let modell = CoachModell(umgebung: u)
        modell.senden("Wie war mein Schlaf?")
        await warte(modell)
        let fehler = try XCTUnwrap(modell.verlauf.last)
        let chip = try XCTUnwrap(fehler.chips.first)

        u.coachMotor = FakeCoachMotor(texte: ["Gut."])
        modell.tippe(chip, in: fehler)
        await warte(modell)
        XCTAssertEqual(modell.verlauf.last?.text, "Gut.")
    }

    func testFolgefrageChipSendetDieFrage() async throws {
        let motor = FakeCoachMotor(texte: ["Antwort."])
        let (u, _, _) = try CoachTestBau.umgebung(motor: motor)
        let modell = CoachModell(umgebung: u)
        let chip = CoachChip(id: "f", text: "Und mein Schlaf?", aktion: .antworten("Und mein Schlaf?"))
        modell.tippe(chip, in: CoachTestBau.nachricht("n", .coach, "Text", u.uhr(), chips: [chip]))
        await warte(modell)
        XCTAssertEqual(modell.verlauf.first?.text, "Und mein Schlaf?")
        XCTAssertEqual(motor.anfragen, 1)
    }

    // MARK: - Merken im Gespräch (Idee 64)

    func testMerkWunschGehtInDenMerkzettelOhneDenMotorZuFragen() throws {
        let motor = FakeCoachMotor()
        let (u, daten, _) = try CoachTestBau.umgebung(motor: motor)
        let modell = CoachModell(umgebung: u)
        modell.senden("Merk dir, dass ich abends trainiere")
        XCTAssertFalse(modell.denkt)
        XCTAssertEqual(motor.anfragen, 0)
        XCTAssertEqual(daten.coach.merkzettel, ["ich abends trainiere"])
        XCTAssertEqual(modell.verlauf.last?.text, "Gemerkt: ich abends trainiere. Im Gedächtnis kannst du es jederzeit löschen.")
    }

    func testBeschwerdenMerktDerCoachNieVonAllein() async throws {
        let (u, daten, _) = try CoachTestBau.umgebung(motor: FakeCoachMotor())
        let modell = CoachModell(umgebung: u)
        modell.senden("Mein Knie tut weh")
        await warte(modell)
        XCTAssertEqual(daten.coach.merkzettel, [])
    }

    // MARK: - Daumen und Merkliste (Idee 69)

    private func modellMitAntwort() async throws -> (CoachModell, CoachNachricht, AppUmgebung) {
        let (u, _, _) = try CoachTestBau.umgebung(motor: FakeCoachMotor(texte: ["Antwort."]))
        let modell = CoachModell(umgebung: u)
        modell.senden("Frage?")
        await warte(modell)
        return (modell, try XCTUnwrap(modell.verlauf.last), u)
    }

    func testDaumenHochRunterUndZurueck() async throws {
        let (modell, antwort, _) = try await modellMitAntwort()
        modell.setzeDaumen(true, an: antwort)
        XCTAssertEqual(modell.verlauf.last?.daumen, true)
        XCTAssertEqual(modell.verlauf.count, 2, "derselbe Eintrag, keine neue Nachricht")
        modell.setzeDaumen(false, an: modell.verlauf.last!)
        XCTAssertEqual(modell.verlauf.last?.daumen, false)
        modell.setzeDaumen(false, an: modell.verlauf.last!)
        XCTAssertNil(modell.verlauf.last?.daumen, "derselbe Daumen noch einmal nimmt ihn zurück")
    }

    func testDaumenNurFuerAntwortenDesCoachs() async throws {
        let (modell, _, _) = try await modellMitAntwort()
        let frage = try XCTUnwrap(modell.verlauf.first)
        modell.setzeDaumen(true, an: frage)
        XCTAssertNil(modell.verlauf.first?.daumen)
    }

    func testMerklisteSchaltetUndBleibtNachDemNeustart() async throws {
        let (modell, antwort, u) = try await modellMitAntwort()
        XCTAssertFalse(modell.istGemerkt(antwort))
        modell.schalteMerkliste(antwort)
        XCTAssertTrue(modell.istGemerkt(antwort))
        XCTAssertEqual(modell.merkliste.map(\.id), [antwort.id])

        let neu = CoachModell(umgebung: u)
        XCTAssertEqual(neu.merkliste.map(\.id), [antwort.id], "coach.json hält die Merkliste")
        neu.schalteMerkliste(antwort)
        XCTAssertTrue(neu.merkliste.isEmpty)
        XCTAssertFalse(neu.istGemerkt(antwort))
    }

    func testDieMerklisteLiegtInDerDateiDesProfils() async throws {
        let (modell, antwort, u) = try await modellMitAntwort()
        modell.schalteMerkliste(antwort)
        let ordner = try XCTUnwrap(u.daten?.ordner)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("coach.json").path))
    }

    // MARK: - Schnellfragen und Tage (Idee 68)

    func testSchnellfragenFolgenDerTageszeitUndVerschwindenNachDerErstenFrage() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(stunde: 8, motor: FakeCoachMotor())
        let modell = CoachModell(umgebung: u)
        let morgens = modell.schnellfragen
        XCTAssertFalse(morgens.isEmpty)
        XCTAssertLessThanOrEqual(morgens.count, 4)
        XCTAssertTrue(morgens.contains(CoachLokal.gefuehl), "morgens zuerst das Gefühl")

        modell.senden(morgens[0])
        await warte(modell)
        XCTAssertTrue(modell.schnellfragen.isEmpty, "ab der ersten eigenen Nachricht des Tages sind sie weg")
    }

    func testAbendsAndereSchnellfragenAlsMorgens() throws {
        let morgens = try CoachTestBau.umgebung(stunde: 8).umgebung
        let abends = try CoachTestBau.umgebung(stunde: 20).umgebung
        XCTAssertNotEqual(CoachModell(umgebung: morgens).schnellfragen, CoachModell(umgebung: abends).schnellfragen)
        XCTAssertTrue(CoachModell(umgebung: abends).schnellfragen.contains(CoachLokal.nochEssen))
    }

    func testHeuteZeigtNurHeuteUndFruehereTageStehenImVerlauf() throws {
        let (u, daten, uhr) = try CoachTestBau.umgebung()
        let gestern = uhr.lesen.addingTimeInterval(-24 * 3600)
        daten.coach.haenge(CoachTestBau.nachricht("g", .nutzer, "Gestern gefragt", gestern))
        daten.coach.haenge(CoachTestBau.nachricht("h", .nutzer, "Heute gefragt", uhr.lesen))
        let modell = CoachModell(umgebung: u)
        XCTAssertEqual(modell.heute.map(\.id), ["h"])
        XCTAssertEqual(modell.vergangeneTage.flatMap(\.nachrichten).map(\.id), ["g"])
    }

    func testOhneProfilIstAllesLeerUndNichtsPassiert() {
        let modell = CoachModell(umgebung: AppUmgebung.vorschau())
        modell.senden("Frage?")
        XCTAssertFalse(modell.denkt)
        XCTAssertTrue(modell.verlauf.isEmpty)
        XCTAssertNil(modell.einstellungen)
        XCTAssertNil(modell.gedaechtnis)
        XCTAssertTrue(modell.merkliste.isEmpty)
    }
}
