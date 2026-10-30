import XCTest
@testable import LumenFit

final class FreitextChipsTests: XCTestCase {
    func testTexteUndSymbole() {
        let liste: [FreitextEintrag] = [.wasser(glaeser: 1), .wasser(glaeser: 3), .creatin(klicks: 2)]
        let chips = FreitextChips.chips(liste)
        XCTAssertEqual(chips.map(\.id), [0, 1, 2])
        XCTAssertEqual(chips[0].text, "Wasser +1 Glas (250 ml)")
        XCTAssertEqual(chips[1].text, "Wasser +3 Gläser (750 ml)")
        XCTAssertEqual(chips[2].text, "Creatin +2 Klicks (7,0 g)")
        XCTAssertEqual(chips[2].symbol, "pills.fill")
    }

    func testSchlafText() {
        let auf = Datum.kalender.date(bySettingHour: 5, minute: 30, second: 0, of: Datum.datum("2026-10-30"))!
        let bett = auf.addingTimeInterval(-6.5 * 3600)
        XCTAssertEqual(FreitextChips.text(.schlaf(bett: bett, auf: auf)), "Schlaf 23:00 bis 05:30, 6 h 30 min")
    }

    func testNachherGewichtErsetztZaehlerAddieren() {
        let vorher = FreitextChips.Werte(gewicht: 800, wasser: 2, creatin: 0)
        let nachher = FreitextChips.nachher([.gewicht(zehntel: 784), .wasser(glaeser: 3), .creatin(klicks: 1)], vorher: vorher)
        XCTAssertEqual(nachher, FreitextChips.Werte(gewicht: 784, wasser: 5, creatin: 1))
    }

    func testSchlafAendertWerteNicht() {
        let jetzt = Date()
        let vorher = FreitextChips.Werte(gewicht: 800, wasser: 2, creatin: 1)
        XCTAssertEqual(FreitextChips.nachher([.schlaf(bett: jetzt, auf: jetzt)], vorher: vorher), vorher)
    }
}

final class GefuehlBatterieTests: XCTestCase {
    func testStufenUndGrenzen() {
        XCTAssertEqual(GefuehlBatterie.symbol(1), "battery.0percent")
        XCTAssertEqual(GefuehlBatterie.symbol(3), "battery.50percent")
        XCTAssertEqual(GefuehlBatterie.symbol(5), "battery.100percent")
        XCTAssertEqual(GefuehlBatterie.symbol(0), "battery.0percent")
        XCTAssertEqual(GefuehlBatterie.symbol(9), "battery.100percent")
    }
}
