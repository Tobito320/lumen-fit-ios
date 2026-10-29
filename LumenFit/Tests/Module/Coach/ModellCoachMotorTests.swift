import XCTest
@testable import LumenFit

/// Apples Modell (Idee 61, 62, 70): Prompt, Übersetzung der Knöpfe und Verhalten ohne Modell. Der Teil mit `FoundationModels` kann nur der
/// Compiler und ein Gerät mit Apple Intelligence beweisen; die Tests hier laufen ohne Framework. Dass die Datei überhaupt übersetzt, ist der
/// Compile-Beleg für `ModellCoachMotor`.
final class ModellCoachMotorTests: XCTestCase {
    // MARK: - Prompt

    func testPromptNenntEchteZahlenUndDieFrage() {
        let prompt = CoachModellPrompt.bauen(CoachTestBau.anfrage("Wie war mein Schlaf?"))
        XCTAssertTrue(prompt.contains("Schlaf heute Nacht: 7 h 30 min"))
        XCTAssertTrue(prompt.contains("Bereitschaft: 72 von 100"))
        XCTAssertTrue(prompt.contains("Schritte heute: 6.200"))
        XCTAssertTrue(prompt.contains("Letztes Training: Push, gestern, 52 Minuten, 14 Sätze"))
        XCTAssertTrue(prompt.hasSuffix("Frage der Person: Wie war mein Schlaf?"))
    }

    func testFehlendesStehtAlsUnbekanntDamitDasModellNachfragt() {
        let kontext = CoachTestBau.kontext(bereitschaft: nil, schlafMinuten: nil, schritte: nil, letztesTraining: nil)
        let prompt = CoachModellPrompt.bauen(CoachTestBau.anfrage("Wie war mein Schlaf?", kontext: kontext))
        for zeile in ["Schlaf heute Nacht: unbekannt", "Bereitschaft: unbekannt", "Schritte heute: unbekannt", "Letztes Training: unbekannt"] {
            XCTAssertTrue(prompt.contains(zeile), zeile)
        }
        XCTAssertTrue(prompt.contains("frage kurz nach, statt zu raten"))
    }

    func testPromptMarktSchwereTageUndTraegtMerkzettelUndVorliebe() {
        let verlauf = [CoachTestBau.nachricht("a", .coach, "Eins. Zwei! Drei. Vier.", Date(timeIntervalSince1970: 1), daumen: false)]
        let kontext = CoachTestBau.kontext(stimmung: .muede, merkzettel: ["Linkes Knie vorsichtig belasten"])
        let prompt = CoachModellPrompt.bauen(CoachTestBau.anfrage("Und heute?", verlauf: verlauf, kontext: kontext))
        XCTAssertTrue(prompt.contains("(schwerer Tag)"))
        XCTAssertTrue(prompt.contains("- Linkes Knie vorsichtig belasten"))
        XCTAssertTrue(prompt.contains("Vorliebe der Person:"))
    }

    func testPromptKuerztDasGespraechUndEntferntMarker() {
        let lang = String(repeating: "wort ", count: 200)
        let verlauf = (0..<10).map { CoachTestBau.nachricht("n\($0)", $0 % 2 == 0 ? .nutzer : .coach, "Nachricht \($0) \(lang)[[weiter: Mehr]]", Date(timeIntervalSince1970: Double($0))) }
        let prompt = CoachModellPrompt.bauen(CoachTestBau.anfrage("Frage", verlauf: verlauf))
        XCTAssertFalse(prompt.contains("[[weiter"), "Marker gehören nicht in den Prompt")
        XCTAssertFalse(prompt.contains("Nachricht 3 "), "nur die letzten \(CoachModellPrompt.verlaufNachrichten) Nachrichten")
        XCTAssertTrue(prompt.contains("Nachricht 9 "))
        XCTAssertLessThan(prompt.count, 3_500, "der Kontext des Modells ist klein")
    }

    // MARK: - Chips des Modells

    func testGueltigeKnoepfeWerdenZuChips() {
        let chips = CoachModellUebersetzer.chips([
            CoachRohChip(text: "Mach ich", art: "mach_ich", ziel: "Dehnen"),
            CoachRohChip(text: "Morgen leicht", art: "morgen_leicht", ziel: ""),
        ])
        XCTAssertEqual(chips.map(\.aktion), [.gewohnheitAnlegen(name: "Dehnen"), .planMorgenLeicht])
        XCTAssertEqual(chips.map(\.text), ["Mach ich", "Morgen leicht"])
    }

    func testZeigMirNurZuBekanntenSeiten() {
        let gut = CoachModellUebersetzer.chips([CoachRohChip(text: "Zeig mir", art: "zeig_mir", ziel: " Training ")])
        XCTAssertEqual(gut.first?.aktion, .oeffne(.gym(.training)))
        XCTAssertEqual(CoachModellUebersetzer.route(fuer: "heute"), .heute)
        XCTAssertEqual(CoachModellUebersetzer.route(fuer: "schlaf"), .schlaf(.letzteNacht))
        XCTAssertNil(CoachModellUebersetzer.route(fuer: "einstellungen"))
        XCTAssertEqual(CoachModellUebersetzer.chips([CoachRohChip(text: "Zeig mir", art: "zeig_mir", ziel: "wecker")]), [], "unbekanntes Ziel fällt still weg")
    }

    func testUngueltigeKnoepfeFallenWegHoechstensZwei() {
        let roh = [
            CoachRohChip(text: "", art: "mach_ich", ziel: "Dehnen"),
            CoachRohChip(text: "Wecker", art: "wecker_stellen", ziel: "7 Uhr"),
            CoachRohChip(text: "Mach ich", art: "mach_ich", ziel: "x"),
            CoachRohChip(text: "Mach ich", art: "mach_ich", ziel: "zwei\nZeilen"),
            CoachRohChip(text: "Eins", art: "mach_ich", ziel: "Dehnen"),
            CoachRohChip(text: "Doppelt", art: "mach_ich", ziel: "Dehnen"),
            CoachRohChip(text: "Zwei", art: "mach_ich", ziel: "Spazieren"),
            CoachRohChip(text: "Drei", art: "morgen_leicht", ziel: ""),
        ]
        let chips = CoachModellUebersetzer.chips(roh)
        XCTAssertEqual(chips.map(\.text), ["Eins", "Zwei"], "ohne Text, unbekannte Art, zu kurzer Name, Zeilenumbruch, doppelt und mehr als zwei fallen weg")
    }

    func testKnopftextWirdAufVierundzwanzigZeichenGekuerzt() {
        let chips = CoachModellUebersetzer.chips([CoachRohChip(text: String(repeating: "a", count: 60), art: "morgen_leicht", ziel: "")])
        XCTAssertEqual(chips.first?.text.count, 24)
    }

    // MARK: - Antwort

    func testAntwortOhneMarkerMitChipsAusDemMarker() throws {
        let antwort = try CoachModellUebersetzer.antwort(text: "Du hast gut geschlafen. [[gehe: schlaf | Schlaf öffnen]]", chips: [])
        XCTAssertEqual(antwort.text, "Du hast gut geschlafen.")
        XCTAssertEqual(antwort.chips.map(\.aktion), [.oeffne(.schlaf(.letzteNacht))])
    }

    func testChipsDesModellsKommenVorDenenAusMarkernHoechstensZwei() throws {
        let roh = [CoachRohChip(text: "Mach ich", art: "mach_ich", ziel: "Dehnen")]
        let antwort = try CoachModellUebersetzer.antwort(text: "Text. [[gehe: schlaf | A]] [[gehe: essen | B]]", chips: roh)
        XCTAssertEqual(antwort.chips.count, 2)
        XCTAssertEqual(antwort.chips.first?.aktion, .gewohnheitAnlegen(name: "Dehnen"))
    }

    func testLeereAntwortIstEinFehler() {
        XCTAssertThrowsError(try CoachModellUebersetzer.antwort(text: "  [[weiter: Mehr]] ", chips: [])) { fehler in
            XCTAssertEqual(fehler as? CoachMotorFehler, .leer)
        }
    }

    // MARK: - Motor ohne Modell

    func testDerMotorHatEinenNamenUndFragtOhneBereitesModellNichts() async {
        let motor = ModellCoachMotor(nachladen: .leer)
        XCTAssertEqual(motor.name, "Apple Intelligence")
        let bereit = await motor.verfuegbar()
        guard !bereit else { return }
        do {
            _ = try await motor.antworte(CoachTestBau.anfrage("Wie war mein Schlaf?"))
            XCTFail("ohne Modell muss der Motor nichtBereit melden")
        } catch let fehler as CoachMotorFehler {
            XCTAssertEqual(fehler, .nichtBereit)
        } catch {
            XCTFail("falscher Fehler: \(error)")
        }
    }

    @MainActor
    func testNachladenLiestAusDenStoresUndMeldetLeereStaende() async throws {
        let (u, _, _) = try CoachTestBau.umgebung()
        let nachladen = CoachNachladen.live(u)
        XCTAssertEqual(nachladen.training(3), "Noch kein Training eingetragen.")
        XCTAssertEqual(nachladen.rekorde(3), "Keine neuen Rekorde in den letzten 14 Tagen.")
        XCTAssertEqual(nachladen.schlaf(3), "Keine Schlafdaten.")
        XCTAssertEqual(nachladen.essen(3), "Nichts im Essens-Log.")
        XCTAssertEqual(CoachNachladen.leer.training(1), "")
    }
}
