import XCTest
@testable import LumenFit

/// Bereiche wählen (Gym, Essen, Schlaf): Einstellungen, Tabs und Links.
@MainActor
final class BereicheTests: XCTestCase {
    /// Einstellungen mit den genannten Bereichen aus (der Rest bleibt an).
    private func aus(_ bereiche: AppBereich...) -> Einstellungen {
        var e = Einstellungen()
        for b in bereiche { e.setze(b, an: false) }
        return e
    }

    // MARK: Einstellungen

    func testStandardZeigtAllesUndAlteDateiAuchOhneDieFelder() throws {
        XCTAssertTrue(AppBereich.allCases.allSatisfy { Einstellungen().zeigt($0) })
        let alt = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"wald"}"#.utf8))
        XCTAssertTrue(alt.gymAn && alt.essenAn && alt.schlafAn, "Bestandsprofile behalten alles")
    }

    func testBereicheUeberlebenSpeichernUndLaden() throws {
        let neu = try JSONDecoder().decode(Einstellungen.self, from: JSONEncoder().encode(aus(.schlaf)))
        XCTAssertFalse(neu.schlafAn)
        XCTAssertTrue(neu.gymAn && neu.essenAn)
    }

    func testDerLetzteBereichBleibtAn() {
        var e = aus(.gym, .essen)
        XCTAssertFalse(e.setze(.schlaf, an: false))
        XCTAssertTrue(e.schlafAn)
        XCTAssertTrue(e.setze(.gym, an: true))
        XCTAssertTrue(e.setze(.schlaf, an: false), "mit einem zweiten an darf Schlaf aus")
    }

    func testEineDateiMitAllemAusZeigtWiederAlles() throws {
        let e = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"gymAn":false,"essenAn":false,"schlafAn":false}"#.utf8))
        XCTAssertTrue(e.gymAn && e.essenAn && e.schlafAn)
    }

    func testTabsUndRoutenFolgenDenBereichen() {
        let e = aus(.schlaf, .essen)
        XCTAssertTrue(e.zeigt(LumenFitTab.heute) && e.zeigt(LumenFitTab.gym))
        XCTAssertFalse(e.zeigt(LumenFitTab.schlaf) || e.zeigt(LumenFitTab.essen))
        XCTAssertFalse(e.zeigt(Route.schlaf(.letzteNacht)))
        XCTAssertTrue(e.zeigt(Route.gym(.training)) && e.zeigt(Route.heute) && e.zeigt(Route.profil(.einstellungen)))
    }

    // MARK: Router

    func testAusgeschalteterBereichFuehrtAufHeuteUndDerGemerkteTabWechselt() {
        let router = Router()
        router.tab = .schlaf
        router.pfade[.schlaf] = [.schlaf(.letzteNacht)]
        router.setze(einstellungen: aus(.schlaf))
        XCTAssertEqual(router.tab, .heute)
        XCTAssertNil(router.pfade[.schlaf], "der Pfad ist weg, die Daten nicht")

        router.oeffne(.schlaf(.letzteNacht))
        XCTAssertEqual(router.tab, .heute)
        router.oeffne(.essen(.heute))
        XCTAssertEqual(router.tab, .essen, "Essen ist an: der Tab öffnet")
    }

    func testLinkUndSchiebenAufAusgeschaltetenBereichOeffnenHeute() {
        let router = Router()
        router.setze(einstellungen: aus(.gym))
        router.tab = .essen
        XCTAssertTrue(router.oeffne(url: URL(string: "lumenfit://gym")!))
        XCTAssertEqual(router.tab, .heute)
        router.schiebe(.gym(.training))
        XCTAssertTrue(router.pfade[.heute]?.isEmpty ?? true, "nichts landet auf dem Stapel von Heute")
    }
}
