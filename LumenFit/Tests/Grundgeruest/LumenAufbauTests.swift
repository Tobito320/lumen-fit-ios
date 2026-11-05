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
        XCTAssertNil(router.pfade[.training], "der Training-Tab bleibt unberührt")
    }

    func testDerAlteWegWechseltWeiterDenTab() {
        let router = Router()
        router.oeffne(.gym(.training))
        XCTAssertEqual(router.tab, .training)
    }

    func testStufenfarbeFolgtDenSchwellen70Und45() {
        XCTAssertEqual(LoveaDaten.stufe(70), .green)
        XCTAssertEqual(LoveaDaten.stufe(69.9), .orange)
        XCTAssertEqual(LoveaDaten.stufe(45), .orange)
        XCTAssertEqual(LoveaDaten.stufe(44.9), .red)
    }

    func testDatenfarbeNurImLoveaAufbau() {
        XCTAssertEqual(LumenAufbau.lovea.farbe(.pink, sonst: .gray), .pink)
        XCTAssertEqual(LumenAufbau.lumen.farbe(.pink, sonst: .gray), .gray)
    }

    func testJedeSchlafphaseHatEineLoveaFarbe() {
        XCTAssertEqual(LoveaDaten.schlaf(.wach), .orange)
        XCTAssertEqual(LoveaDaten.schlaf(.kern), .indigo)
        for phase in SchlafPhase.allCases { _ = LoveaDaten.schlaf(phase) }
    }
}
