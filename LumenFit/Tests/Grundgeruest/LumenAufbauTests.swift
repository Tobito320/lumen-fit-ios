import XCTest
@testable import LumenFit

/// Der Aufbau der Health-Seiten folgt dem Theme und der Freigabe des Servers: Lovea mit Freigabe heißt Lovea-Aufbau, alles andere der heutige Aufbau.
@MainActor
final class LumenAufbauTests: XCTestCase {
    func testLoveaMitFreigabeHatDenLoveaAufbau() {
        XCTAssertEqual(LumenAufbau.wahl(.lovea, loveaErlaubt: true), .lovea)
    }

    func testLoveaOhneFreigabeIstMonochromMitDemHeutigenAufbau() {
        XCTAssertEqual(LumenAufbau.wahl(.lovea, loveaErlaubt: false), .lumen)
        XCTAssertEqual(ProfilThemaWahl.wirksam(.lovea, loveaErlaubt: false), .monochrom, "gleiche Regel wie das Aussehen")
    }

    func testAndereThemesBehaltenDenHeutigenAufbauMitUndOhneFreigabe() {
        for thema in ThemaID.allCases where thema != .lovea {
            XCTAssertEqual(LumenAufbau.wahl(thema, loveaErlaubt: true), .lumen, "\(thema)")
            XCTAssertEqual(LumenAufbau.wahl(thema, loveaErlaubt: false), .lumen, "\(thema)")
        }
    }

    func testEineSeiteAufDemHeuteStapelWechseltDenTabNicht() {
        let router = Router()
        router.tab = .heute
        router.schiebe(.gym(.training))
        router.schiebe(.verlauf)
        XCTAssertEqual(router.tab, .heute)
        XCTAssertEqual(router.pfade[.heute] ?? [], [.gym(.training), .verlauf])
        XCTAssertNil(router.pfade[.gym], "der Gym-Tab bleibt unberührt")
    }

    func testDerAlteWegWechseltWeiterDenTab() {
        let router = Router()
        router.oeffne(.gym(.training))
        XCTAssertEqual(router.tab, .gym)
    }
}
