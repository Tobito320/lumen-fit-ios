import XCTest
@testable import LumenFit

/// Morgen-Check (Idee 67): nur beim Öffnen des Tabs, 5 bis 11 Uhr, einmal am Tag, schreibt Lumis Stimmung, nie eine Mitteilung.
final class MorgenCheckTests: XCTestCase {
    private func eintrag(_ tag: String, _ wert: Int = 3) -> StimmungsEintrag { CoachMorgenCheck.eintrag(tag: tag, wert: wert) }

    // MARK: - Reine Regeln

    func testFuenfStufenMitTextUndSymbol() {
        XCTAssertEqual(CoachMorgenCheck.stufen.map(\.wert), [1, 2, 3, 4, 5])
        XCTAssertEqual(CoachMorgenCheck.stufen.map(\.name), ["Schwer", "Müde", "Okay", "Gut", "Top"])
        XCTAssertTrue(CoachMorgenCheck.stufen.allSatisfy { !$0.symbol.isEmpty })
        XCTAssertTrue(CoachMorgenCheck.frage.hasSuffix("?"))
    }

    func testNurAmMorgenVonFuenfBisElfUhr() {
        for stunde in 0..<24 {
            XCTAssertEqual(CoachMorgenCheck.istMorgen(stunde: stunde), (5..<11).contains(stunde), "Stunde \(stunde)")
        }
    }

    func testFaelligNurAmMorgenOhneAntwortOhneUeberspringen() {
        XCTAssertTrue(CoachMorgenCheck.faellig(stunde: 8, tag: "2026-09-23", stimmungen: [], uebersprungen: nil))
        XCTAssertFalse(CoachMorgenCheck.faellig(stunde: 14, tag: "2026-09-23", stimmungen: [], uebersprungen: nil), "nachmittags nie")
        XCTAssertFalse(CoachMorgenCheck.faellig(stunde: 8, tag: "2026-09-23", stimmungen: [eintrag("2026-09-23")], uebersprungen: nil), "einmal am Tag")
        XCTAssertTrue(CoachMorgenCheck.faellig(stunde: 8, tag: "2026-09-23", stimmungen: [eintrag("2026-09-22")], uebersprungen: nil), "gestern zählt nicht")
        XCTAssertFalse(CoachMorgenCheck.faellig(stunde: 8, tag: "2026-09-23", stimmungen: [], uebersprungen: "2026-09-23"), "Heute nicht gilt für heute")
        XCTAssertTrue(CoachMorgenCheck.faellig(stunde: 8, tag: "2026-09-23", stimmungen: [], uebersprungen: "2026-09-22"))
    }

    func testStimmungFolgtDerZahl() {
        XCTAssertEqual([1, 2, 3, 4, 5].map(CoachMorgenCheck.stimmung(fuer:)), [.muede, .muede, .bereit, .bereit, .stolz])
    }

    func testEintragBegrenztAufEinsBisFuenf() {
        XCTAssertEqual(CoachMorgenCheck.eintrag(tag: "2026-09-23", wert: 0).wert, 1)
        XCTAssertEqual(CoachMorgenCheck.eintrag(tag: "2026-09-23", wert: 9).wert, 5)
        XCTAssertEqual(CoachMorgenCheck.eintrag(tag: "2026-09-23", wert: 4), StimmungsEintrag(tag: "2026-09-23", wert: 4, stimmung: .bereit))
    }

    func testJedeAntwortHaeltDiePersonaEin() {
        let kontexte = [CoachTestBau.kontext(), CoachTestBau.kontext(bereitschaft: 30, schlafMinuten: 300), CoachTestBau.kontext(schlafMinuten: nil)]
        for kontext in kontexte {
            for wert in 1...5 {
                let antwort = CoachMorgenCheck.antwort(wert: wert, kontext: kontext)
                XCTAssertEqual(CoachAntwortPruefung.pruefe(antwort.text, frage: "", kontext: kontext), [], "Wert \(wert): \(antwort.text)")
                XCTAssertEqual(antwort.chips.count, 1)
            }
        }
    }

    func testSchwereMorgenBietenLeichteresAnGuteDasTraining() {
        let kontext = CoachTestBau.kontext()
        for wert in [1, 2] { XCTAssertEqual(CoachMorgenCheck.antwort(wert: wert, kontext: kontext).chips.first?.aktion, .planMorgenLeicht) }
        XCTAssertEqual(CoachMorgenCheck.antwort(wert: 3, kontext: kontext).chips.first?.aktion, .oeffne(.heute))
        for wert in [4, 5] { XCTAssertEqual(CoachMorgenCheck.antwort(wert: wert, kontext: kontext).chips.first?.aktion, .oeffne(.gym(.training))) }
    }

    func testSchlafStehtNurMitDatenImText() {
        XCTAssertTrue(CoachMorgenCheck.antwort(wert: 3, kontext: CoachTestBau.kontext(schlafMinuten: 450)).text.contains("geschlafen"))
        XCTAssertFalse(CoachMorgenCheck.antwort(wert: 3, kontext: CoachTestBau.kontext(schlafMinuten: nil)).text.contains("geschlafen"), "keine erfundene Zahl")
    }

    func testKeinDruckKeineWeckerWoerter() {
        for wert in 1...5 {
            let klein = CoachMorgenCheck.antwort(wert: wert, kontext: CoachTestBau.kontext()).text.lowercased()
            for verboten in ["wecker", "erinner", "du musst", "durchziehen"] { XCTAssertFalse(klein.contains(verboten), "\(verboten) in \(klein)") }
        }
    }

    // MARK: - Ablauf im Tab

    @MainActor
    func testKarteErscheintBeimOeffnenAmMorgenUndNurEinmal() throws {
        let (u, daten, _) = try CoachTestBau.umgebung(stunde: 8)
        let modell = CoachModell(umgebung: u)
        XCTAssertFalse(modell.morgenCheckSichtbar, "ohne Öffnen des Tabs nichts")
        modell.pruefeMorgenCheck()
        XCTAssertTrue(modell.morgenCheckSichtbar)

        modell.morgenCheckBeantworten(2)
        XCTAssertFalse(modell.morgenCheckSichtbar)
        let heute = try XCTUnwrap(CoachDaten.stimmungHeute(daten, tag: "2026-09-23"), "Op fit.lumi.stimmung geschrieben")
        XCTAssertEqual(heute.wert, 2)
        XCTAssertEqual(heute.stimmung, .muede)

        modell.pruefeMorgenCheck()
        XCTAssertFalse(modell.morgenCheckSichtbar, "einmal am Tag")
        XCTAssertFalse(CoachModell(umgebung: u).morgenCheckSichtbar)
        let zweites = CoachModell(umgebung: u)
        zweites.pruefeMorgenCheck()
        XCTAssertFalse(zweites.morgenCheckSichtbar, "auch nach einem Neustart des Tabs")
    }

    @MainActor
    func testAntwortStehtImVerlaufMitVorschlagChip() throws {
        let (u, _, _) = try CoachTestBau.umgebung(stunde: 8)
        let modell = CoachModell(umgebung: u)
        modell.morgenCheckBeantworten(1)
        let verlauf = modell.verlauf
        XCTAssertEqual(verlauf.map(\.rolle), [.nutzer, .coach])
        XCTAssertEqual(verlauf.first?.text, "Heute früh: Schwer (1 von 5)")
        XCTAssertEqual(verlauf.last?.chips.first?.aktion, .planMorgenLeicht)
    }

    @MainActor
    func testNachmittagsKeineKarte() throws {
        let (u, _, _) = try CoachTestBau.umgebung(stunde: 15)
        let modell = CoachModell(umgebung: u)
        modell.pruefeMorgenCheck()
        XCTAssertFalse(modell.morgenCheckSichtbar)
    }

    @MainActor
    func testHeuteNichtGiltNurFuerHeute() throws {
        let (u, _, uhr) = try CoachTestBau.umgebung(stunde: 8)
        let modell = CoachModell(umgebung: u)
        modell.pruefeMorgenCheck()
        modell.morgenCheckUeberspringen()
        XCTAssertFalse(modell.morgenCheckSichtbar)
        modell.pruefeMorgenCheck()
        XCTAssertFalse(modell.morgenCheckSichtbar)
        XCTAssertTrue(modell.verlauf.isEmpty, "Überspringen schreibt nichts in den Verlauf")

        uhr.setze(Datum.datum("2026-09-24").addingTimeInterval(8 * 3600))
        modell.pruefeMorgenCheck()
        XCTAssertTrue(modell.morgenCheckSichtbar, "am nächsten Morgen wieder")
    }

    @MainActor
    func testOhneProfilKeineKarte() {
        let modell = CoachModell(umgebung: AppUmgebung.vorschau())
        modell.pruefeMorgenCheck()
        XCTAssertFalse(modell.morgenCheckSichtbar)
    }
}
