import XCTest
@testable import LumenFit

final class TageLoveaLogikTests: XCTestCase {
    func testMonateSindNieWenigerAlsZwoelf() {
        XCTAssertEqual(TageLoveaLogik.monate(aeltesterTag: nil, heute: "2026-10-31"), 12)
        XCTAssertEqual(TageLoveaLogik.monate(aeltesterTag: "2026-09-02", heute: "2026-10-31"), 12)
    }

    func testMonateReichenBisZurAeltestenEinheitHoechstensSechzig() {
        XCTAssertEqual(TageLoveaLogik.monate(aeltesterTag: "2024-10-05", heute: "2026-10-31"), 25)
        XCTAssertEqual(TageLoveaLogik.monate(aeltesterTag: "2000-01-01", heute: "2026-10-31"), 60)
    }

    func testSerieEinheitEinzahlUndMehrzahl() {
        XCTAssertEqual(TageLoveaLogik.serieEinheit(1), "Woche")
        XCTAssertEqual(TageLoveaLogik.serieEinheit(0), "Wochen")
        XCTAssertEqual(TageLoveaLogik.serieEinheit(5), "Wochen")
    }

    func testRekordTextOhneFruehereEinheitUndOhneHakenIstNil() {
        var satz = PlanSatz(wdh: 8, kg: 100, failure: false)
        satz.ok = true
        XCTAssertNil(TageLoveaLogik.rekordText([satz], 0, frueher: []))
        XCTAssertNil(TageLoveaLogik.rekordText([satz], 3, frueher: []))
        let alt = UebungTag(id: "a", datum: Date(timeIntervalSince1970: 1_700_000_000), saetze: [PlanSatz(wdh: 8, kg: 60, failure: false)])
        satz.ok = nil
        XCTAssertNil(TageLoveaLogik.rekordText([satz], 0, frueher: [alt]))
    }

    func testRekordTextNenntNeuesGewicht() {
        var satz = PlanSatz(wdh: 8, kg: 100, failure: false)
        satz.ok = true
        let alt = UebungTag(id: "a", datum: Date(timeIntervalSince1970: 1_700_000_000), saetze: [PlanSatz(wdh: 8, kg: 60, failure: false)])
        let text = TageLoveaLogik.rekordText([satz], 0, frueher: [alt])
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("Gewicht") == true)
    }
}
