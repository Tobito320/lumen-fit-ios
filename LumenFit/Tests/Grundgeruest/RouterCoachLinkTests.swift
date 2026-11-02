import XCTest
@testable import LumenFit

/// Ein Link von außen darf dem Coach keine Frage stellen (Annahme 34): er füllt höchstens das Eingabefeld.
@MainActor
final class RouterCoachLinkTests: XCTestCase {
    private let link = URL(string: "lumenfit://coach?frage=Wie%20lief%20meine%20Woche")!

    func testFremderLinkWirdZumEntwurfUndOeffnetNurDenTab() {
        let router = Router()
        router.coachSichtbar = true
        XCTAssertTrue(router.oeffne(url: link))
        XCTAssertEqual(router.coachEntwurf, "Wie lief meine Woche")
        XCTAssertEqual(router.tab, .coach)
        XCTAssertEqual(router.pfade[.coach] ?? [], [], "keine Route mit Frage, die beim Öffnen gesendet würde")
    }

    func testVertrauterStartGehtDenAltenWegMitFrage() {
        let router = Router()
        router.coachSichtbar = true
        XCTAssertTrue(router.oeffne(url: link, vertraut: true))
        XCTAssertNil(router.coachEntwurf)
        XCTAssertEqual(router.pfade[.coach] ?? [], [.coach(frage: "Wie lief meine Woche")])
    }

    func testInterneRouteMitFrageBleibtUnveraendert() {
        let router = Router()
        router.coachSichtbar = true
        router.oeffne(.coach(frage: "Warum so müde?"))
        XCTAssertNil(router.coachEntwurf)
        XCTAssertEqual(router.pfade[.coach] ?? [], [.coach(frage: "Warum so müde?")])
    }

    func testLinkOhneFrageOeffnetNurDenCoach() {
        let router = Router()
        router.coachSichtbar = true
        XCTAssertTrue(router.oeffne(url: URL(string: "lumenfit://coach")!))
        XCTAssertNil(router.coachEntwurf)
        XCTAssertEqual(router.tab, .coach)
    }

    func testOhneSichtbarkeitFuehrtJederCoachWegAufHeute() {
        let router = Router()
        router.oeffne(.gym(.training))
        XCTAssertTrue(router.oeffne(url: link))
        XCTAssertEqual(router.tab, .heute)
        XCTAssertNil(router.coachEntwurf, "kein Entwurf für einen Coach, den es nicht gibt")
        XCTAssertTrue(router.oeffne(url: link, vertraut: true))
        XCTAssertEqual(router.tab, .heute)
        router.oeffne(.coach(frage: "x"))
        router.schiebe(.coach(frage: nil))
        XCTAssertEqual(router.pfade[.heute] ?? [], [])
        XCTAssertNil(router.pfade[.coach])
    }

    func testWirdDerCoachWeggenommenVerlaesstEinGemerkterTabDieSeite() {
        let router = Router()
        router.setzeCoachSichtbar(true)
        router.oeffne(.coach(frage: nil))
        XCTAssertEqual(router.tab, .coach)
        router.setzeCoachSichtbar(false)
        XCTAssertEqual(router.tab, .heute)
    }
}
