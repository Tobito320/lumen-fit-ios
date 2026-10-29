import XCTest
@testable import LumenFit

/// Das Beispiel `Fixtures/Coach/coach-kontext-beispiel.json` (erfundene Zahlen): so sieht der Tag aus, den der Coach bekommt. Es muss lesbar bleiben,
/// jede Regel des Coachs läuft darüber, und der Prompt trägt genau diese Zahlen.
final class CoachKontextFixtureTests: XCTestCase {
    private func lade() throws -> CoachKontext {
        try JSONDecoder().decode(CoachKontext.self, from: FixtureOrt.daten("Coach", "coach-kontext-beispiel.json"))
    }

    func testDasBeispielLaesstSichAlsKontextLesen() throws {
        let k = try lade()
        XCTAssertEqual(k.tag, "2026-09-23")
        XCTAssertEqual(k.bereitschaft, 72)
        XCTAssertEqual(k.schlafMinuten, 450)
        XCTAssertEqual(k.schritte, 6200)
        XCTAssertEqual(k.letztesTraining, "Push, gestern, 52 Minuten, 14 Sätze")
        XCTAssertEqual(k.stimmung, .bereit)
        XCTAssertEqual(k.ziele, Ziele())
        XCTAssertEqual(k.merkzettel.count, 2)
        XCTAssertFalse(CoachPersona.schwererTag(k), "ein normaler Tag")
    }

    func testDerPromptTraegtDieZahlenDesBeispiels() throws {
        let prompt = CoachModellPrompt.bauen(CoachTestBau.anfrage("Wie war mein Schlaf?", kontext: try lade()))
        for teil in ["Schlaf heute Nacht: 7 h 30 min", "Bereitschaft: 72 von 100", "Schritte heute: 6.200", "- Linkes Knie vorsichtig belasten"] {
            XCTAssertTrue(prompt.contains(teil), teil)
        }
    }

    func testDerRegelcoachAntwortetAufDemBeispielPersonaTreu() async throws {
        let kontext = try lade()
        let motor = RegelCoachMotor(eingabe: { CoachEingabe(heute: kontext.tag) })
        for frage in ["Wie war mein Schlaf?", "Wie läuft mein Training?", "Wie fühle ich mich?", "Was soll ich heute essen?", "Tagesbericht"] {
            let antwort = try await motor.antworte(CoachTestBau.anfrage(frage, kontext: kontext))
            XCTAssertEqual(CoachAntwortPruefung.pruefe(antwort.text, frage: frage, kontext: kontext), [], "\(frage): \(antwort.text)")
        }
    }
}
