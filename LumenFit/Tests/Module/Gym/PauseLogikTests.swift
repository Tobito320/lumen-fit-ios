import XCTest
@testable import LumenFit

/// Idee 23: Pausen-Timer, der von selbst startet.
final class PauseLogikTests: XCTestCase {
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func uebung(_ id: String, pause: Int? = nil, supersatz: Bool? = nil) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: id, saetze: [PlanSatz(wdh: 10, kg: nil, failure: false)], minuten: nil, pause: pause, supersatz: supersatz)
    }

    private func stand(ziel: Int, seit: Date? = nil) -> GymPauseStand {
        GymPauseStand(session: "s", plan: "a", satz: 0, seit: seit ?? t0, ziel: ziel)
    }

    func testStandardpauseUndEigenePauseJeUebung() {
        XCTAssertEqual(PauseLogik.standard, 120)
        XCTAssertEqual(PauseLogik.ziel(fuer: uebung("a")), 120)
        XCTAssertEqual(PauseLogik.ziel(fuer: uebung("a", pause: 60)), 60)
        XCTAssertEqual(PauseLogik.ziel(fuer: uebung("a", pause: 0)), 0) // 0 = ohne Ziel
    }

    func testPlusMinusFuenfzehnNieUnterFuenfzehn() {
        XCTAssertEqual(PauseLogik.geaendert(120, um: 15), 135)
        XCTAssertEqual(PauseLogik.geaendert(120, um: -15), 105)
        XCTAssertEqual(PauseLogik.geaendert(20, um: -15), 15)
        XCTAssertEqual(PauseLogik.aendern(stand(ziel: 90), um: 15).ziel, 105)
        XCTAssertEqual(PauseLogik.aendern(stand(ziel: 0), um: 15).ziel, 0) // ohne Ziel gibt es nichts zu ändern
    }

    func testEndeRestUndVorbei() {
        let s = stand(ziel: 90)
        XCTAssertEqual(s.ende, t0 + 90)
        XCTAssertEqual(PauseLogik.rest(s, jetzt: t0 + 30), 60)
        XCTAssertEqual(PauseLogik.rest(s, jetzt: t0 + 30.2), 60) // aufgerundet: die Anzeige springt nie früh auf 0
        XCTAssertEqual(PauseLogik.rest(s, jetzt: t0 + 500), 0)
        XCTAssertFalse(PauseLogik.vorbei(s, jetzt: t0 + 89))
        XCTAssertTrue(PauseLogik.vorbei(s, jetzt: t0 + 90))
        XCTAssertNil(stand(ziel: 0).ende)
        XCTAssertNil(PauseLogik.rest(stand(ziel: 0), jetzt: t0))
        XCTAssertFalse(PauseLogik.vorbei(stand(ziel: 0), jetzt: t0 + 999))
    }

    func testZeitraumFuerDenSystemTimer() {
        let s = stand(ziel: 90)
        XCTAssertEqual(PauseLogik.zeitraum(s, jetzt: t0 + 30), (t0 + 30)...(t0 + 90))
        XCTAssertNil(PauseLogik.zeitraum(s, jetzt: t0 + 90)) // vorbei: kein Zeitraum
        XCTAssertNil(PauseLogik.zeitraum(stand(ziel: 0), jetzt: t0))
    }

    func testGedauertRechnetAbDemStart() {
        XCTAssertEqual(PauseLogik.gedauert(stand(ziel: 90), jetzt: t0 + 100), 100)
        XCTAssertEqual(PauseLogik.gedauert(stand(ziel: 90), jetzt: t0 - 5), 0)
    }

    func testEinzelneUebungPausiertNachJedemSatz() {
        let liste = [uebung("a", pause: 90), uebung("b")]
        XCTAssertEqual(PauseLogik.nach(uebung: 0, in: liste), 90)
        XCTAssertEqual(PauseLogik.nach(uebung: 1, in: liste), 120)
        XCTAssertNil(PauseLogik.nach(uebung: 5, in: liste))
    }

    func testSupersatzWechseltOhnePauseUndPausiertNachDerZweitenUebung() {
        let liste = [uebung("a", pause: 60, supersatz: true), uebung("b", pause: 90), uebung("c")]
        XCTAssertNil(PauseLogik.nach(uebung: 0, in: liste)) // A zu B: keine Pause
        XCTAssertEqual(PauseLogik.nach(uebung: 1, in: liste), 90) // nach B die längere der beiden: einmal je Runde
        XCTAssertEqual(PauseLogik.nach(uebung: 2, in: liste), 120)
    }

    func testSupersatzMitPauseNullHatKeinZiel() {
        let liste = [uebung("a", pause: 0, supersatz: true), uebung("b", pause: 90)]
        XCTAssertEqual(PauseLogik.nach(uebung: 1, in: liste), 0)
    }

    func testPauseStandRundlaufUndEinfacheFelder() throws {
        let s = stand(ziel: 90)
        let daten = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(GymPauseStand.self, from: daten), s)
    }
}
