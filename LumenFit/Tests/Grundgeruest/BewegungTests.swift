import SwiftUI
import XCTest
@testable import LumenFit

/// Bewegung nur bei Ereignissen und nur, wenn sie erlaubt ist (SPEC 6, `design.md` 3.7 und 9): "Bewegung reduzieren" und Stromsparmodus.
@MainActor
final class BewegungTests: XCTestCase {
    func testRuhigWennBewegungReduziertOderStromsparmodus() {
        XCTAssertFalse(BewegungsRegel.ruhig(reduziert: false, stromsparmodus: false))
        XCTAssertTrue(BewegungsRegel.ruhig(reduziert: true, stromsparmodus: false))
        XCTAssertTrue(BewegungsRegel.ruhig(reduziert: false, stromsparmodus: true))
        XCTAssertTrue(BewegungsRegel.ruhig(reduziert: true, stromsparmodus: true))
    }

    func testLumiHuepftZweimalImStromsparmodusEinmalUndOhneBewegungGarNicht() {
        XCTAssertEqual(BewegungsRegel.huepfer(reduziert: false, stromsparmodus: false), 2)
        XCTAssertEqual(BewegungsRegel.huepfer(reduziert: false, stromsparmodus: true), 1)
        XCTAssertEqual(BewegungsRegel.huepfer(reduziert: true, stromsparmodus: false), 0)
        XCTAssertEqual(BewegungsRegel.huepfer(reduziert: true, stromsparmodus: true), 0, "Bewegung reduzieren gewinnt gegen den Stromsparmodus")
    }

    func testBalkenErsetzenDieBoegenErstAbDenSchriftstufenFuerBedienungshilfen() {
        for stufe in [DynamicTypeSize.xSmall, .large, .xxxLarge] { XCTAssertFalse(BewegungsRegel.nutztBalken(stufe), "\(stufe)") }
        for stufe in [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5] { XCTAssertTrue(BewegungsRegel.nutztBalken(stufe), "\(stufe)") }
    }

    func testDerBeobachterStartetMitDemWertDesSystems() {
        XCTAssertEqual(StromsparBeobachter.geteilt.an, ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    func testDasEinfahrenSchaltetSichUeberDenGemeinsamenWertAus() {
        var werte = EnvironmentValues()
        XCTAssertFalse(werte.bewegungAus, "Standard: Bewegung an")
        XCTAssertFalse(werte.stromsparmodus)
        werte.bewegungAus = true
        werte.stromsparmodus = true
        XCTAssertTrue(werte.bewegungAus)
        XCTAssertTrue(werte.stromsparmodus)
    }
}
