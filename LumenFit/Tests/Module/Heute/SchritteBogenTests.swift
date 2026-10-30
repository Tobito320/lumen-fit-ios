import XCTest
@testable import LumenFit

final class SchritteBogenTests: XCTestCase {
    func testErsteRundeBisZiel() {
        XCTAssertEqual(SchritteBogenLogik.laeufe(anzahl: 5_000, ziel: 10_000), .init(erste: 0.5, zweite: 0, prozent: 50))
        XCTAssertEqual(SchritteBogenLogik.laeufe(anzahl: nil, ziel: 10_000), .init(erste: 0, zweite: 0, prozent: 0))
        XCTAssertFalse(SchritteBogenLogik.laeufe(anzahl: 9_999, ziel: 10_000).erreicht)
    }

    func testZweiteRundeDarueber() {
        let l = SchritteBogenLogik.laeufe(anzahl: 14_000, ziel: 10_000)
        XCTAssertEqual(l.erste, 1)
        XCTAssertEqual(l.zweite, 0.4, accuracy: 0.0001)
        XCTAssertEqual(l.prozent, 140)
        XCTAssertTrue(l.erreicht)
    }

    func testNachZweiRundenBleibtDerBogenVoll() {
        let l = SchritteBogenLogik.laeufe(anzahl: 35_000, ziel: 10_000)
        XCTAssertEqual(l.zweite, 1)
        XCTAssertEqual(l.erste, 1)
    }

    func testZielNullTeiltNicht() {
        XCTAssertEqual(SchritteBogenLogik.laeufe(anzahl: 10, ziel: 0).erste, 1)
    }

    func testStundenText() {
        XCTAssertEqual(SchritteBogenLogik.stundenText(125), "2:05")
        XCTAssertEqual(SchritteBogenLogik.stundenText(0), "0:00")
    }

    func testStandHatKcalAktivZeitUndPeriodenZiel() {
        let tage = [
            "2026-10-26": TagesWerte(tag: "2026-10-26", schritte: 5_000, aktiveKcal: 300.4, trainingMinuten: 20),
            "2026-10-27": TagesWerte(tag: "2026-10-27", schritte: 7_000, aktiveKcal: 250.2, trainingMinuten: 45),
        ]
        let s = SchritteDetailLogik.stand(zeitraum: .woche, anker: "2026-10-28", heute: "2026-10-28", tage: tage, ziel: 10_000)
        XCTAssertEqual(s.kcal, 551)
        XCTAssertEqual(s.aktivMinuten, 65)
        XCTAssertEqual(s.periodenZiel, 70_000)
        let t = SchritteDetailLogik.stand(zeitraum: .tag, anker: "2026-10-28", heute: "2026-10-28", tage: tage, ziel: 10_000)
        XCTAssertEqual(t.periodenZiel, 10_000)
        XCTAssertEqual(t.kcal, 0)
        let m = SchritteDetailLogik.stand(zeitraum: .monat, anker: "2026-10-28", heute: "2026-10-28", tage: tage, ziel: 10_000)
        XCTAssertEqual(m.periodenZiel, 310_000)
    }
}
