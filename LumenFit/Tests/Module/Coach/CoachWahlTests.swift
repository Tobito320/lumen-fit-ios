import XCTest
@testable import LumenFit

/// Auswahl des Motors (Idee 61, 62): Modell, wenn bereit und gut, sonst Regeln. Fehler, Frist und Regelverstoß fallen auf die Regeln zurück.
final class CoachWahlTests: XCTestCase {
    private enum Verhalten: Sendable { case antwort(String), fehler, haengt }

    /// Ein Motor mit festem Verhalten und Zähler; `bereit` lässt sich zwischen zwei Fragen ändern.
    private final class Motor: CoachMotor, @unchecked Sendable {
        // @unchecked Sendable: Zähler und Schalter stehen nur unter dem Schloss.
        private let schloss = NSLock()
        private var _bereit: Bool
        private var _fragen: [CoachAnfrage] = []
        let name: String
        let verhalten: Verhalten

        init(_ name: String, bereit: Bool = true, _ verhalten: Verhalten) { self.name = name; _bereit = bereit; self.verhalten = verhalten }

        var bereit: Bool { get { schloss.withLock { _bereit } } set { schloss.withLock { _bereit = newValue } } }
        var fragen: [CoachAnfrage] { schloss.withLock { _fragen } }

        func verfuegbar() async -> Bool { bereit }

        func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort {
            schloss.withLock { _fragen.append(anfrage) }
            switch verhalten {
            case .antwort(let text): return CoachAntwort(text: text, chips: [])
            case .fehler: throw CoachMotorFehler.nichtBereit
            case .haengt:
                try await Task.sleep(for: .seconds(30))
                return CoachAntwort(text: "zu spät", chips: [])
            }
        }
    }

    private let frage = "Wie habe ich geschlafen?"
    private let gut = "Du hast gut siebeneinhalb Stunden geschlafen. Das passt zu deiner Bereitschaft von 72."

    private func wahl(_ modell: Motor, _ regeln: Motor, frist: TimeInterval = 5) -> CoachWahlMotor {
        CoachWahlMotor(modell: modell, regeln: regeln, frist: frist)
    }

    func testDasBereiteModellAntwortet() async throws {
        let modell = Motor("Modell", .antwort(gut)), regeln = Motor("Regeln", .antwort("Regel"))
        let antwort = try await wahl(modell, regeln).antworte(CoachTestBau.anfrage(frage))
        XCTAssertEqual(antwort.text, gut)
        XCTAssertEqual(modell.fragen.count, 1)
        XCTAssertEqual(regeln.fragen.count, 0, "die Regeln bleiben still, wenn das Modell gut antwortet")
    }

    func testNichtBereitesModellWirdNichtGefragt() async throws {
        let modell = Motor("Modell", bereit: false, .antwort(gut)), regeln = Motor("Regeln", .antwort("Regel"))
        let antwort = try await wahl(modell, regeln).antworte(CoachTestBau.anfrage(frage))
        XCTAssertEqual(antwort.text, "Regel")
        XCTAssertEqual(modell.fragen.count, 0)
    }

    func testFehlerDesModellsFaelltAufDieRegelnZurueck() async throws {
        let modell = Motor("Modell", .fehler), regeln = Motor("Regeln", .antwort("Regel"))
        let antwort = try await wahl(modell, regeln).antworte(CoachTestBau.anfrage(frage))
        XCTAssertEqual(antwort.text, "Regel")
        XCTAssertEqual(modell.fragen.count, 1)
    }

    func testRegelverstossDesModellsFaelltAufDieRegelnZurueck() async throws {
        let verstoesse = [
            "Haben Sie gut geschlafen?",
            "Als KI kann ich dir sagen, dass du gut geschlafen hast.",
            "Du hast vermutlich eine Entzündung und schläfst deshalb schlecht.",
            "Du solltest früher ins Bett gehen.",
            "Eins. Zwei. Drei. Vier. Fünf.",
        ]
        for text in verstoesse {
            let modell = Motor("Modell", .antwort(text)), regeln = Motor("Regeln", .antwort("Regel"))
            let antwort = try await wahl(modell, regeln).antworte(CoachTestBau.anfrage(frage))
            XCTAssertEqual(antwort.text, "Regel", "\(text) darf nicht durchgehen")
        }
    }

    func testBeschwerdeOhneArztHinweisGehtNichtDurch() async throws {
        let modell = Motor("Modell", .antwort("Das klingt nach Muskelkater, ruh dich aus.")), regeln = Motor("Regeln", .antwort("Regel"))
        let antwort = try await wahl(modell, regeln).antworte(CoachTestBau.anfrage("Mein Knie tut weh"))
        XCTAssertEqual(antwort.text, "Regel")
    }

    func testZuLangsamesModellWirdNachDerFristErsetzt() async throws {
        let modell = Motor("Modell", .haengt), regeln = Motor("Regeln", .antwort("Regel"))
        let start = Date()
        let antwort = try await wahl(modell, regeln, frist: 0.2).antworte(CoachTestBau.anfrage(frage))
        XCTAssertEqual(antwort.text, "Regel")
        XCTAssertLessThan(Date().timeIntervalSince(start), 5, "die Frist, nicht das Modell, bestimmt die Wartezeit")
    }

    func testMitFristMeldetZeitueberschreitungAuchBeiUnabbrechbarerArbeit() async {
        do {
            _ = try await CoachWahlMotor.mitFrist(0.1) {
                // Wartet ohne Abbruch zu beachten; die Frist muss trotzdem greifen.
                let ende = Date().addingTimeInterval(1)
                while Date() < ende { await Task.yield() }
                return CoachAntwort(text: "spät", chips: [])
            }
            XCTFail("hätte die Frist melden müssen")
        } catch let fehler as CoachMotorFehler {
            XCTAssertEqual(fehler, .zeitUeberschritten)
        } catch {
            XCTFail("falscher Fehler: \(error)")
        }
    }

    func testMitFristLiefertDieAntwortOhneWarten() async throws {
        let antwort = try await CoachWahlMotor.mitFrist(5) { CoachAntwort(text: "da", chips: []) }
        XCTAssertEqual(antwort.text, "da")
    }

    func testDieWahlWechseltMitDerVerfuegbarkeitUndDasGespraechGehtMit() async throws {
        let modell = Motor("Modell", bereit: false, .antwort(gut)), regeln = Motor("Regeln", .antwort("Regel"))
        let motor = wahl(modell, regeln)
        let erste = try await motor.antworte(CoachTestBau.anfrage(frage))
        XCTAssertEqual(erste.text, "Regel")

        modell.bereit = true
        let verlauf = [CoachTestBau.nachricht("a", .nutzer, frage, Date(timeIntervalSince1970: 1)),
                       CoachTestBau.nachricht("b", .coach, "Regel", Date(timeIntervalSince1970: 2))]
        let zweite = try await motor.antworte(CoachTestBau.anfrage("Und gestern?", verlauf: verlauf))
        XCTAssertEqual(zweite.text, gut)
        XCTAssertEqual(modell.fragen.first?.verlauf.map(\.id), ["a", "b"], "beim Wechsel mitten im Gespräch geht der Verlauf mit")
    }

    func testGleicheNamenBedeutenKeinModell() async throws {
        let modell = Motor("Gleich", .antwort(gut)), regeln = Motor("Gleich", .antwort("Regel"))
        let antwort = try await wahl(modell, regeln).antworte(CoachTestBau.anfrage(frage))
        XCTAssertEqual(antwort.text, "Regel")
        XCTAssertEqual(modell.fragen.count, 0)
    }

    func testWahlNimmtModellNurWennVerfuegbar() async {
        let modell = Motor("Modell", .fehler), regeln = Motor("Regeln", .fehler)
        let gewaehlt = await CoachWahl.motor(modell: modell, regeln: regeln)
        XCTAssertEqual(gewaehlt.name, "Modell")
        modell.bereit = false
        let danach = await CoachWahl.motor(modell: modell, regeln: regeln)
        XCTAssertEqual(danach.name, "Regeln")
    }

    func testDieFristDesModellsIstKuerzerAlsDieTippanzeige() {
        XCTAssertEqual(CoachWahl.frist, 12)
        XCTAssertLessThan(CoachWahl.frist, CoachLokal.denkGrenze, "Platz für den Regelcoach, bevor der Fehlertext käme")
    }
}
