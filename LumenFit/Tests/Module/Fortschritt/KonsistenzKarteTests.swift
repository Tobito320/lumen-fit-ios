import XCTest
@testable import LumenFit

/// Die Hilfen der Konsistenz-Karte: deutsche Monatsnamen, Monatssummen, Aussage und Zeitraum.
final class KonsistenzKarteTests: XCTestCase {
    func testMonateSindDeutsch() {
        XCTAssertEqual(KonsistenzKarteLogik.monatsKurz.count, 12)
        let j = KonsistenzLogik.jahr(2026, tage: [:], heute: "2026-12-31")
        let namen = j.monate.map(KonsistenzKarteLogik.monatName)
        XCTAssertEqual(namen[2], "Mär")
        XCTAssertEqual(namen[4], "Mai")
        XCTAssertEqual(namen[9], "Okt")
        XCTAssertEqual(namen[11], "Dez")
    }

    func testMonatsSummenZaehlenNurBisHeute() {
        let tage = ["2026-01-05": 1, "2026-01-06": 2, "2026-03-10": 1, "2026-12-24": 1]
        let j = KonsistenzLogik.jahr(2026, tage: tage, heute: "2026-03-31")
        let s = KonsistenzKarteLogik.monatsSummen(j)
        XCTAssertEqual(s.map(\.monat), ["Jan", "Feb", "Mär"])
        XCTAssertEqual(s.map(\.workouts), [3, 0, 1])
    }

    func testAussageUndZeitraum() {
        let tage = ["2026-01-05": 1, "2026-02-06": 2]
        let jahre = KonsistenzLogik.jahre(tage: tage, heute: "2026-10-30", auswahl: 2026)
        XCTAssertEqual(KonsistenzKarteLogik.aussage(jahre, auswahl: 2026), "2 Trainingstage in 2026")
        XCTAssertEqual(KonsistenzKarteLogik.aussage(jahre, auswahl: nil), "2 Trainingstage insgesamt")
        XCTAssertEqual(KonsistenzKarteLogik.zeitraumText(nil), "Gesamt")
        XCTAssertEqual(KonsistenzKarteLogik.zeitraumText(2025), "2025")
    }

    func testEinTrainingstagHatDieEinzahl() {
        let jahre = KonsistenzLogik.jahre(tage: ["2026-01-05": 1], heute: "2026-10-30", auswahl: 2026)
        XCTAssertEqual(KonsistenzKarteLogik.aussage(jahre, auswahl: 2026), "1 Trainingstag in 2026")
    }
}
