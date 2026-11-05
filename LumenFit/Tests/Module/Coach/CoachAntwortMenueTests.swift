import XCTest
@testable import LumenFit

/// Langes Drücken auf eine Antwort bietet Merken, Kopieren und Teilen; "Neu fragen" nur bei der letzten, wenn der Coach frei ist.
final class CoachAntwortMenueTests: XCTestCase {
    func testLetzteAntwortBietetMerkenKopierenUndNeu() {
        XCTAssertEqual(CoachAntwortMenue.punkte(letzte: true, gemerkt: false, denkt: false, pausiert: false),
                       [.kopieren, .teilen, .merken(gemerkt: false), .nochmal])
    }

    func testAeltereAntwortOhneNeu() {
        XCTAssertEqual(CoachAntwortMenue.punkte(letzte: false, gemerkt: true, denkt: false, pausiert: false),
                       [.kopieren, .teilen, .merken(gemerkt: true)])
    }

    func testKeinNeuSolangeDerCoachDenktOderPausiert() {
        XCTAssertFalse(CoachAntwortMenue.punkte(letzte: true, gemerkt: false, denkt: true, pausiert: false).contains(.nochmal))
        XCTAssertFalse(CoachAntwortMenue.punkte(letzte: true, gemerkt: false, denkt: false, pausiert: true).contains(.nochmal))
    }
}
