import XCTest
@testable import LumenFit

final class SchlafSchuldTests: XCTestCase {
    private func naechte(_ minuten: [Int], ab: String = "2026-09-17") -> [SchlafNacht] {
        minuten.enumerated().map { SchlafTestBau.nacht(Datum.addTage(ab, $0.offset), minuten: $0.element) }
    }

    func testNurFehlendeMinutenZaehlen() {
        XCTAssertEqual(SchlafSchuld.minuten(nachtMinuten: [420, 500, 360], ziel: 480), 60 + 120)
    }

    func testUeberschussGleichtNichtsAus() {
        // Loveas Schuld hätte hier 60 - 60 + 80 gerechnet.
        XCTAssertEqual(SchlafSchuld.minuten(nachtMinuten: [420, 540, 400], ziel: 480), 60 + 80)
        XCTAssertEqual(SchlafSchuld.minuten(nachtMinuten: [600, 600, 600], ziel: 480), 0)
        XCTAssertEqual(SchlafSchuld.minuten(nachtMinuten: [], ziel: 480), 0)
    }

    func testSiebenTageBisHeuteUndNaechteOhneDatenZaehlenNicht() {
        // 17. bis 23.09. (sieben Tage), dazu eine ältere Nacht am 15.09., die nicht zählt.
        var n = naechte([420, 480, 400, 480, 450, 480, 360])
        n.append(SchlafTestBau.nacht("2026-09-15", minuten: 100))
        let e = SchlafSchuld.berechne(naechte: n, heute: "2026-09-23", ziel: 480)
        XCTAssertEqual(e?.minuten, 60 + 80 + 30 + 120)
        XCTAssertEqual(e?.naechte, 7)
        let luecke = SchlafSchuld.berechne(naechte: [SchlafTestBau.nacht("2026-09-21", minuten: 420), SchlafTestBau.nacht("2026-09-22", minuten: 420),
                                                    SchlafTestBau.nacht("2026-09-23", minuten: 420)], heute: "2026-09-23", ziel: 480)
        XCTAssertEqual(luecke?.minuten, 180, "fehlende Tage sind keine Nächte mit 0 Minuten")
        XCTAssertEqual(luecke?.naechte, 3)
    }

    func testUnterDreiNaechtenZuWenigDaten() {
        let n = [SchlafTestBau.nacht("2026-09-22", minuten: 300), SchlafTestBau.nacht("2026-09-23", minuten: 300)]
        XCTAssertNil(SchlafSchuld.berechne(naechte: n, heute: "2026-09-23", ziel: 480))
        XCTAssertNil(SchlafSchuld.berechne(naechte: naechte([420, 420, 420]), heute: "2026-09-19", ziel: 0), "ohne Ziel keine Schuld")
    }

    func testVorschlagRundetAufUndDeckeltBei45() {
        XCTAssertNil(SchlafSchuld.vorschlag(schuldMinuten: 0))
        XCTAssertNil(SchlafSchuld.vorschlag(schuldMinuten: 14))
        XCTAssertEqual(SchlafSchuld.vorschlag(schuldMinuten: 15), 15)
        XCTAssertEqual(SchlafSchuld.vorschlag(schuldMinuten: 16), 30)
        XCTAssertEqual(SchlafSchuld.vorschlag(schuldMinuten: 45), 45)
        XCTAssertEqual(SchlafSchuld.vorschlag(schuldMinuten: 180), 45)
    }

    func testSaetze() {
        let viel = SchlafSchuld.berechne(naechte: naechte([420, 420, 420, 420]), heute: "2026-09-20", ziel: 480)
        XCTAssertEqual(viel?.satz, "Schlafschuld: 4 h 00 min in den letzten 7 Tagen.")
        XCTAssertEqual(viel?.vorschlagSatz, "Heute 45 Minuten früher ins Bett.")
        let keine = SchlafSchuld.berechne(naechte: naechte([480, 500, 490]), heute: "2026-09-19", ziel: 480)
        XCTAssertEqual(keine?.satz, "Keine Schlafschuld: Du hast dein Ziel in jeder gemessenen Nacht erreicht.")
        XCTAssertNil(keine?.vorschlagSatz)
        let wenig = SchlafSchuld.berechne(naechte: naechte([470, 480, 476]), heute: "2026-09-19", ziel: 480)
        XCTAssertEqual(wenig?.satz, "Kaum Schlafschuld: 14 min in den letzten 7 Tagen.")
    }
}
