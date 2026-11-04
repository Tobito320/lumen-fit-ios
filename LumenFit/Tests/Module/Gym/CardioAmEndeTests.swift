import UIKit
import XCTest
@testable import LumenFit

/// Die Cardio-Knöpfe am Ende des Trainings zeigen auf Cardio-Übungen im Katalog und haben ein echtes Symbol.
final class CardioAmEndeTests: XCTestCase {
    func testJedesGeraetIstEineCardioUebungMitSymbol() {
        XCTAssertEqual(CardioAmEnde.wahl.count, 4)
        for g in CardioAmEnde.wahl {
            XCTAssertEqual(UebungsKatalog.nachId[g.id]?.istCardio, true, g.id)
            XCTAssertNotNil(UIImage(systemName: g.symbol), g.symbol)
        }
    }
}
