import XCTest
@testable import LumenFit

/// 12-Wochen-Ausblick: Vergangenheit ab der ersten Woche mit Wert, Lücken mit dem letzten Wert, danach alle zwei Wochen ein Schritt.
final class FortAusblickTests: XCTestCase {
    private func zeile(_ wochen: [Double?]) -> GewichtZeile {
        GewichtZeile(uebungId: "bp", name: "Beinpresse", muskel: "Beine", wochen: wochen, aktuell: wochen.compactMap { $0 }.last ?? 0, aenderung4Wochen: 0)
    }

    func testAchtWochenGebenVierWochenAusblick() throws {
        let a = try XCTUnwrap(FortAusblickLogik.ausblick(zeile([132.5, 135, 135, 137.5, 140, 140, 145, 150])))
        XCTAssertEqual(a.punkte.count, 12)
        XCTAssertEqual(a.heute, 7)
        XCTAssertEqual(a.woche, 8)
        XCTAssertEqual(a.schritt, 2.5)
        XCTAssertEqual(Array(a.punkte.suffix(4)), [152.5, 152.5, 155, 155])
    }

    func testLueckenUndSpaeterStart() throws {
        let a = try XCTUnwrap(FortAusblickLogik.ausblick(zeile([nil, nil, nil, nil, nil, 10, nil, 12])))
        XCTAssertEqual(a.heute, 2)
        XCTAssertEqual(Array(a.punkte.prefix(3)), [10, 10, 12])
        XCTAssertEqual(a.schritt, 1)
        XCTAssertEqual(a.punkte[3], 13)
        XCTAssertEqual(a.punkte[11], 12 + 5)
    }

    func testOhneWertKeinAusblick() {
        XCTAssertNil(FortAusblickLogik.ausblick(zeile(Array(repeating: nil, count: 8))))
        XCTAssertEqual(FortAusblickLogik.hauptuebungen([zeile(Array(repeating: nil, count: 8)), zeile([1, 2])]).count, 1)
    }
}
