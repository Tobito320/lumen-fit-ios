import XCTest
@testable import LumenFit

final class WasserProtokollTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func op(_ min: Int, _ wert: Int, tag: String = "2026-10-30", art: String = Habit.wasser.id, von: ProfilID = .testA) -> Op {
        let d = (try? JSONEncoder().encode(HabitSetzenD(art: art, datum: tag, wert: wert))) ?? Data()
        return Op(id: "o\(min)\(wert)\(tag)\(art)", art: "habit.setzen", von: von, zeit: t0.addingTimeInterval(Double(min) * 60), d: d)
    }

    func testErhoehungenMitZeit() {
        let e = WasserProtokoll.eintraege(ops: [op(0, 1), op(30, 2), op(90, 5)], profil: .testA, tag: "2026-10-30")
        XCTAssertEqual(e.map(\.glaeser), [1, 1, 3])
        XCTAssertEqual(e[1].zeit, t0.addingTimeInterval(1800))
    }

    func testZuruecknehmenZaehltSpaeterNeu() {
        let e = WasserProtokoll.eintraege(ops: [op(0, 3), op(10, 2), op(20, 3)], profil: .testA, tag: "2026-10-30")
        XCTAssertEqual(e.map(\.glaeser), [3, 1])
    }

    func testFremdesUndAndereTageUndGewohnheitenFallenWeg() {
        let ops = [op(0, 1, tag: "2026-10-29"), op(1, 1, art: "gym"), op(2, 1, von: .testB), op(3, 2)]
        XCTAssertEqual(WasserProtokoll.eintraege(ops: ops, profil: .testA, tag: "2026-10-30").map(\.glaeser), [2])
    }

    func testText() {
        XCTAssertTrue(WasserProtokoll.text(WasserEintrag(zeit: t0, glaeser: 1)).hasSuffix("+1 Glas"))
        XCTAssertTrue(WasserProtokoll.text(WasserEintrag(zeit: t0, glaeser: 2)).hasSuffix("+2 Gläser"))
    }
}
