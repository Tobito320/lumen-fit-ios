import XCTest
@testable import LumenFit

final class ZyklusVerknuepfungTests: XCTestCase {
    private let start = "2026-09-01"

    private func plus(_ tag: String, _ n: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: n, to: Datum.datum(tag))!)
    }

    /// Eine Periode ab `start`, 5 Tage, Standard 28/5. `nummer` = Zyklustag (1 = erster Periodentag).
    private func hinweis(nummer: Int, modus: ZyklusModus = .zyklus) -> ZyklusHinweis? {
        let tage = (0..<5).map { ZyklusTag(id: plus(start, $0), blutung: .mittel) }
        let heute = plus(start, nummer - 1)
        var e = ZyklusEinstellung()
        e.modus = modus
        let logik = ZyklusLogik(tage: tage, einstellung: e, heute: heute)
        return ZyklusVerknuepfung.hinweis(logik: logik, am: heute)
    }

    func testPeriodeIstSanftMitEisen() {
        let h = hinweis(nummer: 2)
        XCTAssertEqual(h?.phase, .periode)
        XCTAssertEqual(h?.rat, .sanft)
        XCTAssertTrue(h?.ernaehrung.contains("Eisen") ?? false)
    }

    func testFollikelFruchtbarEisprungSindKraft() {
        for (nummer, phase) in [(7, ZyklusPhase.follikel), (12, .fruchtbar), (15, .eisprung)] {
            let h = hinweis(nummer: nummer)
            XCTAssertEqual(h?.phase, phase, "Tag \(nummer)")
            XCTAssertEqual(h?.rat, .kraft, "Tag \(nummer)")
        }
    }

    func testLutealFruehNormalSpaetSanft() {
        XCTAssertEqual(hinweis(nummer: 19)?.phase, .luteal)
        XCTAssertEqual(hinweis(nummer: 19)?.rat, .normal)
        XCTAssertEqual(hinweis(nummer: 25)?.rat, .sanft)
        XCTAssertTrue(hinweis(nummer: 25)?.ernaehrung.contains("Heißhunger") ?? false)
    }

    func testWasserZielJePhase() {
        XCTAssertEqual(ZyklusVerknuepfung.hinweis(phase: .follikel).wasserZielMl, 2000)
        XCTAssertEqual(ZyklusVerknuepfung.hinweis(phase: .periode).wasserZielMl, 2300)
        XCTAssertEqual(ZyklusVerknuepfung.hinweis(phase: .luteal).wasserZielMl, 2300)
    }

    func testJedePhaseHatAlleTexteUndSchritte() {
        for p in ZyklusPhase.allCases {
            let h = ZyklusVerknuepfung.hinweis(phase: p)
            XCTAssertEqual(h.phase, p)
            for t in [h.training, h.energie, h.schlaf, h.wasser, h.ernaehrung, h.schritte] { XCTAssertFalse(t.isEmpty) }
            XCTAssertGreaterThan(h.schrittZiel, 0)
        }
    }

    func testKeinHinweisOhnePhaseOderAusserhalbZyklusModus() {
        let leer = ZyklusLogik(tage: [], heute: start)
        XCTAssertNil(ZyklusVerknuepfung.hinweis(logik: leer, am: start))
        XCTAssertNil(hinweis(nummer: 7, modus: .schwanger))
    }

}
