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

    // MARK: Schlaf nur mit Erlaubnis des Servers

    func testOhneErlaubnisKeinSchlafTabUndSchlafRoutenLandenAufHeute() {
        let router = Router()
        XCTAssertFalse(router.schlafSichtbar, "Standard: aus")
        XCTAssertFalse(router.zeigt(.schlaf))
        XCTAssertTrue(router.zeigt(.gym) && router.zeigt(.essen) && router.zeigt(.heute))
        router.oeffne(.schlaf(.werte))
        XCTAssertEqual(router.tab, .heute)
        router.schiebe(.schlaf(.letzteNacht))
        XCTAssertTrue(router.pfade[.heute]?.isEmpty ?? true)
        XCTAssertTrue(router.oeffne(url: URL(string: "lumenfit://schlaf?bereich=verlauf")!))
        XCTAssertEqual(router.tab, .heute)
    }

    func testMitErlaubnisOeffnetSchlafUndDasWegnehmenSchicktZurueckAufHeute() {
        let router = Router()
        router.setzeSchlafSichtbar(true)
        XCTAssertTrue(router.zeigt(.schlaf))
        router.oeffne(.schlaf(.werte))
        XCTAssertEqual(router.tab, .schlaf)
        XCTAssertEqual(router.pfade[.schlaf], [.schlaf(.werte)])
        router.setzeSchlafSichtbar(false)
        XCTAssertEqual(router.tab, .heute, "ein offener Schlaf-Tab verlässt die Seite")
        XCTAssertNil(router.pfade[.schlaf])
    }

    func testErlaubnisUndEigeneWahlGeltenBeide() {
        let router = Router()
        router.setzeSchlafSichtbar(true)
        router.setze(einstellungen: aus(.schlaf))
        XCTAssertFalse(router.zeigt(.schlaf), "erlaubt, aber selbst ausgeschaltet")
    }

    func testWirksameBereicheBlendenSchlafOhneErlaubnisAusUndLassenImmerEinenAn() {
        XCTAssertFalse(Einstellungen().wirksam(schlafSichtbar: false).schlafAn)
        XCTAssertTrue(Einstellungen().wirksam(schlafSichtbar: true).schlafAn)
        XCTAssertTrue(Einstellungen().wirksam(schlafSichtbar: false).gymAn)
        var nurSchlaf = Einstellungen()
        nurSchlaf.gymAn = false
        nurSchlaf.essenAn = false
        let w = nurSchlaf.wirksam(schlafSichtbar: false)
        XCTAssertTrue(w.gymAn || w.essenAn, "nie ein Profil ohne sichtbaren Bereich")
        XCTAssertTrue(nurSchlaf.schlafAn, "die gespeicherte Wahl bleibt unverändert")
        XCTAssertEqual(ProfilBereiche.waehlbar(schlafSichtbar: false), [.gym, .essen])
        XCTAssertEqual(ProfilBereiche.waehlbar(schlafSichtbar: true), [.gym, .essen, .schlaf])
    }
}
