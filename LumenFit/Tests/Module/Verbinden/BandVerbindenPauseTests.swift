import XCTest
@testable import LumenFit

final class BandVerbindenPauseTests: XCTestCase {
    func testWartetLaengerJeFehlversuchUndBleibtBeiFuenfMinuten() {
        XCTAssertEqual((1...6).map { BandVerbindenPause.sekunden(fehlversuche: $0) }, [5, 15, 60, 300, 300, 300])
        XCTAssertEqual(BandVerbindenPause.sekunden(fehlversuche: 0), 5)
    }
}
