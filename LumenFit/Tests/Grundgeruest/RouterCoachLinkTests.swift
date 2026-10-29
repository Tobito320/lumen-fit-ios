import XCTest
@testable import LumenFit

/// Ein Link von außen darf dem Coach keine Frage stellen (Annahme 34): er füllt höchstens das Eingabefeld.
@MainActor
final class RouterCoachLinkTests: XCTestCase {
    private let link = URL(string: "lumenfit://coach?frage=Wie%20lief%20meine%20Woche")!

    func testFremderLinkWirdZumEntwurfUndOeffnetNurDenTab() {
        let router = Router()
        XCTAssertTrue(router.oeffne(url: link))
        XCTAssertEqual(router.coachEntwurf, "Wie lief meine Woche")
        XCTAssertEqual(router.tab, .coach)
        XCTAssertEqual(router.pfade[.coach] ?? [], [], "keine Route mit Frage, die beim Öffnen gesendet würde")
    }

    func testVertrauterStartGehtDenAltenWegMitFrage() {
        let router = Router()
        XCTAssertTrue(router.oeffne(url: link, vertraut: true))
        XCTAssertNil(router.coachEntwurf)
        XCTAssertEqual(router.pfade[.coach] ?? [], [.coach(frage: "Wie lief meine Woche")])
    }

    func testInterneRouteMitFrageBleibtUnveraendert() {
        let router = Router()
        router.oeffne(.coach(frage: "Warum so müde?"))
        XCTAssertNil(router.coachEntwurf)
        XCTAssertEqual(router.pfade[.coach] ?? [], [.coach(frage: "Warum so müde?")])
    }

    func testLinkOhneFrageOeffnetNurDenCoach() {
        let router = Router()
        XCTAssertTrue(router.oeffne(url: URL(string: "lumenfit://coach")!))
        XCTAssertNil(router.coachEntwurf)
        XCTAssertEqual(router.tab, .coach)
    }
}
