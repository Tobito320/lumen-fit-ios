import XCTest
@testable import LumenFit

final class WochenVergleichTests: XCTestCase {
    private func naechte(_ minuten: [Int?], ab: String) -> [SchlafNacht] {
        minuten.enumerated().compactMap { eintrag in
            eintrag.element.map { SchlafTestBau.nacht(Datum.addTage(ab, eintrag.offset), minuten: $0) }
        }
    }

    func testSiebenBalkenSchnittUndKurzeNaechte() {
        // 17. bis 23.09.2026, eine Nacht fehlt (20.09.), zwei unter 6 Stunden.
        let n = naechte([420, 300, 480, nil, 350, 450, 440], ab: "2026-09-17")
        let w = WochenVergleich.berechne(naechte: n, heute: "2026-09-23")
        XCTAssertEqual(w.tage.map(\.tag), SchlafTestBau.tage(ab: "2026-09-17", 7))
        XCTAssertEqual(w.tage.map(\.minuten), [420, 300, 480, nil, 350, 450, 440])
        XCTAssertEqual(w.diese.naechte, 6)
        XCTAssertEqual(w.diese.schnittMinuten, 407)
        XCTAssertEqual(w.diese.unterSechsStunden, 2)
    }

    func testDieseGegenLetzteWoche() {
        let letzte = naechte([400, 400, 400, 400, 400, 400, 400], ab: "2026-09-10")
        let diese = naechte([430, 430, 430, 430, 430, 430, 430], ab: "2026-09-17")
        let w = WochenVergleich.berechne(naechte: letzte + diese, heute: "2026-09-23")
        XCTAssertEqual(w.letzte.schnittMinuten, 400)
        XCTAssertEqual(w.unterschiedMinuten, 30)
        XCTAssertEqual(w.vergleichSatz, "Diese Woche schläfst du im Schnitt 30 min länger als letzte Woche.")
    }

    func testKuerzerUndEtwaGleich() {
        let kurz = WochenVergleich.berechne(naechte: naechte([480, 480, 480], ab: "2026-09-10") + naechte([420, 420, 420], ab: "2026-09-17"), heute: "2026-09-23")
        XCTAssertEqual(kurz.vergleichSatz, "Diese Woche schläfst du im Schnitt 1 h 00 min kürzer als letzte Woche.")
        let gleich = WochenVergleich.berechne(naechte: naechte([480, 480], ab: "2026-09-10") + naechte([482, 483], ab: "2026-09-17"), heute: "2026-09-23")
        XCTAssertEqual(gleich.vergleichSatz, "Diese Woche schläfst du etwa so lang wie letzte Woche.")
    }

    func testOhneGenugNaechteKeinVergleich() {
        let w = WochenVergleich.berechne(naechte: naechte([400], ab: "2026-09-10") + naechte([450, 450, 450], ab: "2026-09-17"), heute: "2026-09-23")
        XCTAssertNil(w.unterschiedMinuten)
        XCTAssertNil(w.vergleichSatz)
        XCTAssertNotNil(w.diese.schnittMinuten, "die eigene Woche wird trotzdem gezeigt")
    }

    func testWochenendeGegenWerktag() {
        // 12., 13., 19., 20.09.2026 sind Samstag und Sonntag: 9 Stunden. Alle anderen Tage: 7 Stunden.
        var n: [SchlafNacht] = []
        for tag in SchlafTestBau.tage(ab: "2026-09-10", 14) {
            n.append(SchlafTestBau.nacht(tag, minuten: SchlafLogik.istWochenende(tag) ? 540 : 420))
        }
        let w = WochenVergleich.berechne(naechte: n, heute: "2026-09-23")
        XCTAssertEqual(w.werktagSchnitt, 420)
        XCTAssertEqual(w.wochenendeSchnitt, 540)
        XCTAssertEqual(w.wochenendeSatz, "Am Wochenende schläfst du im Schnitt 2 h 00 min länger als unter der Woche.")
    }

    func testWochenendeBrauchtZweiNaechtePlusWerktage() {
        let n = naechte([420, 420, 420], ab: "2026-09-21")
        let w = WochenVergleich.berechne(naechte: n, heute: "2026-09-23")
        XCTAssertNil(w.werktagSchnitt)
        XCTAssertNil(w.wochenendeSatz)
    }

    func testKeineDatenGibtLeereWoche() {
        let w = WochenVergleich.berechne(naechte: [], heute: "2026-09-23")
        XCTAssertEqual(w.tage.count, 7)
        XCTAssertNil(w.diese.schnittMinuten)
        XCTAssertEqual(w.diese.naechte, 0)
        XCTAssertEqual(w.diese.unterSechsStunden, 0)
    }

    func testWocheUeberDenMonatswechselUndDieZeitumstellung() {
        // Sieben Tage bis 28.10.2026 beginnen am 22.10.; die Umstellung (25.10.) liegt mittendrin und verschiebt keinen Tag.
        let w = WochenVergleich.berechne(naechte: naechte([400, 400, 400, 400, 400, 400, 400], ab: "2026-10-22"), heute: "2026-10-28")
        XCTAssertEqual(w.tage.first?.tag, "2026-10-22")
        XCTAssertEqual(w.tage.last?.tag, "2026-10-28")
        XCTAssertEqual(w.diese.naechte, 7)
        let monat = WochenVergleich.berechne(naechte: naechte([400, 410], ab: "2026-10-31"), heute: "2026-11-02")
        XCTAssertEqual(monat.tage.first?.tag, "2026-10-27")
        XCTAssertEqual(monat.diese.naechte, 2)
    }
}
