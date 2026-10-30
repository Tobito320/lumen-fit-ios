import XCTest
@testable import LumenFit

/// Der Tipp auf die Körperkarte trifft die Fläche unter dem Finger, knapp daneben die nächste, weit weg keine.
final class SilhouetteTrefferTests: XCTestCase {
    /// Rahmen 1:1 im Raum 100 x 200, damit Punkte und Formen dieselben Zahlen haben.
    private let rahmen = CGRect(x: 0, y: 0, width: 100, height: 200)

    func testMitteDerFlaecheTrifftSie() {
        let bauch = SilhouetteBild.vorne.first { $0.id == "vorne-bauch" }
        XCTAssertNotNil(bauch)
        XCTAssertEqual(SilhouetteTreffer.flaeche(.vorne, bei: CGPoint(x: 50, y: 78), in: rahmen)?.id, "vorne-bauch")
        XCTAssertEqual(SilhouetteTreffer.flaeche(.hinten, bei: CGPoint(x: 50, y: 85), in: rahmen)?.gruppe, .ruecken)
    }

    func testKnappDanebenTrifftNochDenNaechstenMuskel() {
        // Bizeps vorne liegt bei x 15...26; 8 pt links daneben (x 7) liegt im Fingerradius.
        XCTAssertEqual(SilhouetteTreffer.flaeche(.vorne, bei: CGPoint(x: 7, y: 67), in: rahmen)?.gruppe, .bizeps)
    }

    func testWeitWegTrifftNichts() {
        XCTAssertNil(SilhouetteTreffer.flaeche(.vorne, bei: CGPoint(x: 95, y: 20), in: rahmen))
        XCTAssertNil(SilhouetteTreffer.flaeche(.vorne, bei: CGPoint(x: 5, y: 195), in: rahmen))
    }

    func testJedeFlaecheIstAnIhrerMitteTippbar() {
        for f in SilhouetteBild.alle {
            let mitte = f.formen[0].pfad(in: rahmen).boundingRect
            let punkt = CGPoint(x: mitte.midX, y: mitte.midY)
            XCTAssertNotNil(SilhouetteTreffer.flaeche(f.seite, bei: punkt, in: rahmen), f.id)
        }
    }
}
