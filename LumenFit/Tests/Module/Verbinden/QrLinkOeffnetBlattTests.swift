import XCTest
@testable import LumenFit

/// Der QR-Code ist ein `lumenfit://`-Link: aus der System-Kamera öffnet er die App direkt beim Bestätigen-Schritt ("Mit NAME verbinden?"), egal welche Bereiche an sind.
@MainActor
final class QrLinkOeffnetBlattTests: XCTestCase {
    private let token = String(repeating: "aB3_-", count: 8) + "xyz"   // 43 Zeichen

    func testKameraLinkOeffnetDasBlattMitDemToken() throws {
        let router = Router()
        XCTAssertTrue(router.oeffne(url: VerbindungenLogik.link(token: token)))
        XCTAssertEqual(router.tab, .freunde)
        guard case .freund(let daten)? = router.blatt else { return XCTFail("erwartet das Freund-Blatt, ist \(String(describing: router.blatt))") }
        XCTAssertEqual(VerbindungenLogik.token(aus: daten), token, "RouteAnsicht gibt es als Token an das Scan-Blatt weiter")
    }

    func testKameraLinkGehtAuchMitAusgeschaltetemGymUndEssen() {
        var werte = Einstellungen()
        werte.setze(.gym, an: false)
        werte.setze(.essen, an: false)
        let router = Router()
        router.setze(einstellungen: werte)
        XCTAssertTrue(router.oeffne(url: VerbindungenLogik.link(token: token)))
        XCTAssertNotNil(router.blatt, "das Blatt gehört keinem Bereich")
    }

    func testLinkOhneTokenOeffnetNurDieFreundeSeite() {
        let router = Router()
        XCTAssertTrue(router.oeffne(url: URL(string: "lumenfit://freund")!))
        XCTAssertEqual(router.tab, .freunde, "ohne Token ist die Freunde-Seite der Tab selbst")
        XCTAssertNil(router.blatt)
    }
}
