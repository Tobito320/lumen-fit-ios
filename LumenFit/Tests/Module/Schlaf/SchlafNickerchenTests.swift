import XCTest
@testable import LumenFit

/// Wach in der Nacht und Nickerchen (Lovea `SchlafCard`): aus den Health-Abschnitten, reine Logik.
final class SchlafNickerchenTests: XCTestCase {
    private func zeit(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        Datum.kalender.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde, minute: minute))!
    }

    private func roh(_ phase: SchlafPhase, _ von: Date, _ bis: Date) -> SchlafNachtLogik.Roh {
        SchlafNachtLogik.Roh(phase: phase, von: von, bis: bis)
    }

    func testNickerchenAmAufwachtagNebenDerNacht() throws {
        let liste = [
            roh(.kern, zeit(10, 23), zeit(11, 3)),
            roh(.kern, zeit(11, 3, 10), zeit(11, 6)),
            roh(.kern, zeit(11, 14), zeit(11, 14, 40)),
            roh(.kern, zeit(11, 16), zeit(11, 16, 10)),
        ]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertEqual(nacht.nickerchen?.count, 1)
        XCTAssertEqual(nacht.nickerchen?.first?.von, zeit(11, 14))
        XCTAssertEqual(nacht.wachPhasen.count, 1)
        XCTAssertEqual(nacht.wachPhasen.first?.von, zeit(11, 3))
    }

    func testOhneNickerchenIstLeer() throws {
        let liste = [roh(.kern, zeit(10, 23), zeit(11, 6))]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertEqual(nacht.nickerchen ?? [], [])
        XCTAssertTrue(nacht.wachPhasen.isEmpty)
    }

    func testKurzeLueckeUnterZweiMinutenZaehltNichtAlsWach() throws {
        let liste = [roh(.kern, zeit(10, 23), zeit(11, 3)), roh(.kern, zeit(11, 3, 1), zeit(11, 6))]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertTrue(nacht.wachPhasen.isEmpty)
    }

    func testAlteDateiOhneNickerchenLaedt() throws {
        let nacht = SchlafTestBau.nacht("2026-10-11", minuten: 420)
        let daten = try JSONEncoder().encode(nacht)
        XCTAssertFalse(String(decoding: daten, as: UTF8.self).contains("nickerchen"))
        let zurueck = try JSONDecoder().decode(SchlafNacht.self, from: daten)
        XCTAssertNil(zurueck.nickerchen)
        XCTAssertEqual(zurueck, nacht)
    }
}
