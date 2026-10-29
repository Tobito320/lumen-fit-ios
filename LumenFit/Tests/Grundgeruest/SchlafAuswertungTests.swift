import XCTest
@testable import LumenFit

final class SchlafAuswertungTests: XCTestCase {
    private func zeit(_ tag: String, _ stunde: Int, _ minute: Int = 0) -> Date {
        Datum.datum(tag).addingTimeInterval(TimeInterval(stunde * 3600 + minute * 60))
    }

    func testNachtMitPhasenDerUhr() {
        let roh = [
            SchlafNachtLogik.Roh(phase: .kern, von: zeit("2026-09-22", 22, 30), bis: zeit("2026-09-23", 2)),
            SchlafNachtLogik.Roh(phase: .tief, von: zeit("2026-09-23", 2), bis: zeit("2026-09-23", 4)),
            SchlafNachtLogik.Roh(phase: .rem, von: zeit("2026-09-23", 4), bis: zeit("2026-09-23", 6, 30)),
        ]
        let naechte = SchlafAuswertung.naechte(roh, von: "2026-09-23", bis: "2026-09-23")
        XCTAssertEqual(naechte.count, 1)
        XCTAssertEqual(naechte.first?.tag, "2026-09-23")
        XCTAssertEqual(naechte.first?.schlafMinuten ?? 0, 480, accuracy: 10)
        XCTAssertEqual(naechte.first?.abschnitte.count, 3)
    }

    func testIPhoneAlleinOhnePhasenGibtEinenAbschnittSchlaf() {
        let roh = [SchlafNachtLogik.Roh(phase: .unbestimmt, von: zeit("2026-09-22", 23), bis: zeit("2026-09-23", 7))]
        let naechte = SchlafAuswertung.naechte(roh, von: "2026-09-23", bis: "2026-09-23")
        XCTAssertEqual(naechte.count, 1)
        XCTAssertEqual(naechte.first?.abschnitte.map(\.phase), [.unbestimmt])
        XCTAssertEqual(naechte.first?.schlafMinuten ?? 0, 480, accuracy: 10)
    }

    func testMehrereTageUndLeereTageUndFalscheBereiche() {
        let roh = [
            SchlafNachtLogik.Roh(phase: .unbestimmt, von: zeit("2026-09-21", 23), bis: zeit("2026-09-22", 7)),
            SchlafNachtLogik.Roh(phase: .unbestimmt, von: zeit("2026-09-23", 23), bis: zeit("2026-09-24", 6)),
        ]
        let naechte = SchlafAuswertung.naechte(roh, von: "2026-09-22", bis: "2026-09-24")
        XCTAssertEqual(naechte.map(\.tag), ["2026-09-22", "2026-09-24"], "der 23. hat keine Nacht")
        XCTAssertTrue(SchlafAuswertung.naechte(roh, von: "2026-09-24", bis: "2026-09-22").isEmpty, "von nach bis")
        XCTAssertTrue(SchlafAuswertung.naechte(roh, von: "kaputt", bis: "2026-09-22").isEmpty)
        XCTAssertTrue(SchlafAuswertung.naechte([], von: "2026-09-22", bis: "2026-09-24").isEmpty)
    }
}
