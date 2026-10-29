// Quelle: Lovea Tests/KonsistenzLogikTests.swift
import XCTest
@testable import LumenFit

// Trainings-Konsistenz (W-038): Stufen, Zählen je Tag, Wochen-Spalten eines Jahres, Tipp auf eine Zelle.
final class KonsistenzLogikTests: XCTestCase {
    private func session(_ tag: String, stunde: Double = 12, ende: Double? = nil) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(stunde * 3600)
        return GymSession(id: UUID().uuidString, tag: nil, start: start, ende: ende.map { start.addingTimeInterval($0 * 60) }, laeufe: [])
    }

    func testStufen() {
        XCTAssertEqual(KonsistenzLogik.stufe(0), .kein)
        XCTAssertEqual(KonsistenzLogik.stufe(1), .eins)
        XCTAssertEqual(KonsistenzLogik.stufe(2), .mehr)
        XCTAssertEqual(KonsistenzLogik.stufe(5), .mehr)
    }

    func testZaehltWorkoutsJeTag() {
        let t = KonsistenzLogik.tage([session("2026-03-10"), session("2026-03-10", stunde: 19), session("2026-03-11")])
        XCTAssertEqual(t, ["2026-03-10": 2, "2026-03-11": 1])
    }

    func testJahr2026BeginntDonnerstag() {
        let j = KonsistenzLogik.jahr(2026, tage: ["2026-01-01": 1, "2026-12-31": 2], heute: "2026-10-25")
        XCTAssertNil(j.zelle(spalte: 0, zeile: 2))
        XCTAssertEqual(j.zelle(spalte: 0, zeile: 3)?.tag, "2026-01-01")
        XCTAssertEqual(j.zelle(spalte: 52, zeile: 3)?.tag, "2026-12-31")
        XCTAssertNil(j.zelle(spalte: 52, zeile: 4))
        XCTAssertEqual(j.zellen.compactMap { $0 }.count, 365)
        XCTAssertEqual(j.trainingstage, 2)
        XCTAssertEqual(j.workouts, 3)
        XCTAssertEqual(j.letzterTag, "2026-12-31")
    }

    func testSchaltjahrMontagStart() {
        let j = KonsistenzLogik.jahr(2024, tage: [:], heute: "2026-10-25")
        XCTAssertEqual(j.zelle(spalte: 0, zeile: 0)?.tag, "2024-01-01")
        XCTAssertEqual(j.zellen.compactMap { $0 }.count, 366)
        XCTAssertNil(j.letzterTag)
    }

    func testSonntagsJahrPasstInDieSpalten() {
        // 2023 beginnt an einem Sonntag: 1 + 364 Tage reichen bis Spalte 52.
        let j = KonsistenzLogik.jahr(2023, tage: [:], heute: "2026-10-25")
        XCTAssertEqual(j.zelle(spalte: 0, zeile: 6)?.tag, "2023-01-01")
        XCTAssertEqual(j.zellen.compactMap { $0 }.count, 365)
    }

    func testMonatsnamenStehenInDerWocheDesErsten() {
        let j = KonsistenzLogik.jahr(2026, tage: [:], heute: "2026-10-25")
        XCTAssertEqual(j.monate.count, 12)
        XCTAssertEqual(j.monate[0], .init(name: "Jan", spalte: 0))
        XCTAssertEqual(j.monate[1], .init(name: "Feb", spalte: 4)) // 1.2.2026 ist ein Sonntag
    }

    func testZukunftIstMarkiert() {
        let j = KonsistenzLogik.jahr(2026, tage: [:], heute: "2026-03-10")
        let zellen = j.zellen.compactMap { $0 }
        XCTAssertFalse(zellen.first { $0.tag == "2026-03-10" }!.zukunft)
        XCTAssertTrue(zellen.first { $0.tag == "2026-03-11" }!.zukunft)
    }

    func testGesamtReichtVomErstenTrainingsjahrBisHeute() {
        let t = ["2024-05-02": 1, "2026-01-05": 2]
        XCTAssertEqual(KonsistenzLogik.verfuegbar(tage: t, heute: "2026-10-25"), [2026, 2025, 2024])
        XCTAssertEqual(KonsistenzLogik.jahre(tage: t, heute: "2026-10-25", auswahl: nil).map(\.jahr), [2026, 2025, 2024])
        XCTAssertEqual(KonsistenzLogik.jahre(tage: t, heute: "2026-10-25", auswahl: 2025).map(\.jahr), [2025])
        XCTAssertEqual(KonsistenzLogik.verfuegbar(tage: [:], heute: "2026-10-25"), [2026])
    }

    func testTreffer() {
        let breite = 590.0 // Einheit 10
        XCTAssertNil(KonsistenzLogik.treffer(x: 5, y: 30, breite: breite)) // in der Beschriftung
        XCTAssertNil(KonsistenzLogik.treffer(x: 100, y: 5, breite: breite)) // in der Monatszeile
        let t = KonsistenzLogik.treffer(x: 55, y: 25, breite: breite)
        XCTAssertEqual(t?.spalte, 0)
        XCTAssertEqual(t?.zeile, 0)
        let u = KonsistenzLogik.treffer(x: 585, y: 85, breite: breite)
        XCTAssertEqual(u?.spalte, 53)
        XCTAssertEqual(u?.zeile, 6)
        XCTAssertNil(KonsistenzLogik.treffer(x: 100, y: 95, breite: breite))
    }

    func testZeileMitNameUhrzeitDauer() {
        XCTAssertEqual(KonsistenzLogik.zeile(session("2026-03-10", stunde: 18.5, ende: 45), name: "Push"), "Push · 18:30 · 45 min")
        XCTAssertEqual(KonsistenzLogik.zeile(session("2026-03-10", stunde: 9), name: nil), "Training · 09:00")
    }
}
