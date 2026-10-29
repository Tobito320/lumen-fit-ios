import XCTest
@testable import LumenFit

final class LumiStufeTests: XCTestCase {
    func testStufenGrenzen() {
        let erwartet: [(Int, Int)] = [(-5, 1), (0, 1), (1, 2), (2, 2), (3, 3), (4, 3), (5, 4), (7, 4), (8, 5), (10, 5), (11, 6), (14, 6), (15, 7),
                                      (18, 7), (19, 8), (22, 8), (23, 9), (25, 9), (100, 9)]
        for (erreicht, stufe) in erwartet { XCTAssertEqual(LumiStufe.stufe(erreicht: erreicht), stufe, "\(erreicht) erreicht") }
    }

    func testNeunStufenSteigenStreng() {
        XCTAssertEqual(LumiStufe.schwellen.count, 9)
        XCTAssertEqual(LumiStufe.schwellen, LumiStufe.schwellen.sorted())
        XCTAssertEqual(Set(LumiStufe.schwellen).count, 9)
        XCTAssertEqual(LumiStufe.schwellen.first, 0)
    }

    func testFuenfStimmungen() {
        XCTAssertEqual(Set(LumiStimmung.allCases.map(\.rawValue)), ["bereit", "muede", "stolz", "schlaeft", "denkt"])
    }
}
