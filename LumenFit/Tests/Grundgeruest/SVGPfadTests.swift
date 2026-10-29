import SwiftUI
import XCTest
@testable import LumenFit

final class SVGPfadTests: XCTestCase {
    private func box(_ daten: String) -> CGRect { SVGPfad.pfad(daten).boundingRect }

    func testLinienUndSchliessen() {
        let pfad = SVGPfad.pfad("M0 0 L10 0 L10 10 Z")
        XCTAssertFalse(pfad.isEmpty)
        XCTAssertEqual(pfad.boundingRect, CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    func testRelativeBefehle() {
        XCTAssertEqual(box("m5 5 l5 0 l0 5 z"), CGRect(x: 5, y: 5, width: 5, height: 5))
        XCTAssertEqual(box("M5 5 l5 0 0 5"), CGRect(x: 5, y: 5, width: 5, height: 5), "mehrere Paare nach einem l")
    }

    func testWeitereZahlenpaareNachMSindLinien() {
        XCTAssertEqual(box("M0 0 10 0 10 10"), CGRect(x: 0, y: 0, width: 10, height: 10))
        XCTAssertEqual(box("m1 1 3 0 0 3"), CGRect(x: 1, y: 1, width: 3, height: 3))
    }

    func testKommaMinusUndDezimalpunktOhneLeerzeichen() {
        XCTAssertEqual(box("M0,-5L10,-5"), CGRect(x: 0, y: -5, width: 10, height: 0))
        XCTAssertEqual(box("M.5.5L1.5.5"), CGRect(x: 0.5, y: 0.5, width: 1, height: 0), "zwei Dezimalpunkte trennen zwei Zahlen")
    }

    func testKurvenEndenAmZiel() {
        let kubisch = SVGPfad.pfad("M0 0 C0 10 10 10 10 0")
        XCTAssertEqual(kubisch.currentPoint, CGPoint(x: 10, y: 0))
        let quadratisch = SVGPfad.pfad("M0 0 Q5 10 10 0")
        XCTAssertEqual(quadratisch.currentPoint, CGPoint(x: 10, y: 0))
        let relativ = SVGPfad.pfad("M10 10 c0 5 5 5 5 0")
        XCTAssertEqual(relativ.currentPoint, CGPoint(x: 15, y: 10))
    }

    func testZweiTeilpfadeMitZ() {
        let pfad = SVGPfad.pfad("M0 0 L4 0 L4 4 Z M10 10 L12 10 L12 12 Z")
        XCTAssertEqual(pfad.boundingRect, CGRect(x: 0, y: 0, width: 12, height: 12))
    }

    func testLeerUndUnbekanntesGibtKeinenAbsturz() {
        XCTAssertTrue(SVGPfad.pfad("").isEmpty)
        XCTAssertTrue(SVGPfad.pfad("X1 2 3").isEmpty)
        _ = SVGPfad.pfad("L5 5")   // ohne vorheriges M: nur kein Absturz
    }
}
