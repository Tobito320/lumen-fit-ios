import XCTest
@testable import LumenFit

final class RouteURLTests: XCTestCase {
    private let alleRouten: [Route] = {
        var liste: [Route] = [.heute, .verlauf, .gewichtEintragen, .coach(frage: nil), .coach(frage: "Wie viel Eiweiß brauche ich? Mehr & besser, +1 #x = ok"),
                              .uebung(id: "EIeI8Vf"), .uebung(id: "eigen/ä ö"), .freund(daten: nil), .freund(daten: "abc-_123xyz")]
        liste += [GymBereich.training, .plaene, .fortschritt].map { Route.gym($0) }
        liste += [EssenBereich.heute, .scan, .favoriten].map { Route.essen($0) }
        liste += [SchlafBereich.letzteNacht, .verlauf, .werte].map { Route.schlaf($0) }
        liste += [ProfilBereich.uebersicht, .einstellungen, .aussehen, .ziele, .verbindungen, .datensicherung, .quellen, .meilensteine, .lumi, .zyklus].map { Route.profil($0) }
        return liste
    }()

    func testJedeRouteKommtAusIhremLinkZurueck() throws {
        for route in alleRouten {
            let url = RouteURL.url(fuer: route)
            XCTAssertEqual(url.scheme, "lumenfit", "\(route)")
            XCTAssertEqual(RouteURL.route(aus: url), route, "\(route) -> \(url)")
            // Auch als Text (so liegt der Link im Spotlight-Index und in Mitteilungen).
            XCTAssertEqual(RouteURL.route(ausSpotlightKennung: url.absoluteString), route, "\(route)")
        }
    }

    func testGenauAussehendeLinks() {
        XCTAssertEqual(RouteURL.url(fuer: .heute).absoluteString, "lumenfit://heute")
        XCTAssertEqual(RouteURL.url(fuer: .gym(.training)).absoluteString, "lumenfit://gym")
        XCTAssertEqual(RouteURL.url(fuer: .gym(.plaene)).absoluteString, "lumenfit://gym?bereich=plaene")
        XCTAssertEqual(RouteURL.url(fuer: .essen(.scan)).absoluteString, "lumenfit://essen?bereich=scan")
        XCTAssertEqual(RouteURL.url(fuer: .schlaf(.werte)).absoluteString, "lumenfit://schlaf?bereich=werte")
        XCTAssertEqual(RouteURL.url(fuer: .profil(.datensicherung)).absoluteString, "lumenfit://profil?bereich=datensicherung")
        XCTAssertEqual(RouteURL.url(fuer: .gewichtEintragen).absoluteString, "lumenfit://gewicht")
        XCTAssertEqual(RouteURL.url(fuer: .uebung(id: "abc")).absoluteString, "lumenfit://uebung?id=abc")
        XCTAssertEqual(RouteURL.url(fuer: .coach(frage: "a b")).absoluteString, "lumenfit://coach?frage=a%20b")
    }

    func testUnbekannterBereichUndFehlendeAngabenGebenDenErstenFall() throws {
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://gym?bereich=gibtsnicht"))), .gym(.training))
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://essen"))), .essen(.heute))
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://schlaf?bereich="))), .schlaf(.letzteNacht))
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://profil"))), .profil(.uebersicht))
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://coach?frage="))), .coach(frage: nil))
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://freund"))), .freund(daten: nil))
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit:///"))), .heute, "ohne Host ist es Heute")
    }

    func testGrossUndKleinschreibungStoertNicht() throws {
        XCTAssertEqual(RouteURL.route(aus: try XCTUnwrap(URL(string: "LUMENFIT://Gym?bereich=plaene"))), .gym(.plaene))
    }

    func testFremdesSchemaUnbekannterHostUndUebungOhneIdSindKeineRoute() throws {
        XCTAssertNil(RouteURL.route(aus: try XCTUnwrap(URL(string: "https://example.org/gym"))))
        XCTAssertNil(RouteURL.route(aus: try XCTUnwrap(URL(string: "lovea://heute"))))
        XCTAssertNil(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://gibtsnicht"))))
        XCTAssertNil(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://uebung"))))
        XCTAssertNil(RouteURL.route(aus: try XCTUnwrap(URL(string: "lumenfit://uebung?id="))))
        XCTAssertNil(RouteURL.route(ausSpotlightKennung: "kein link"))
    }

    func testLeereTexteZaehlenAlsFehlend() {
        XCTAssertEqual(RouteURL.url(fuer: .coach(frage: "")).absoluteString, "lumenfit://coach")
        XCTAssertEqual(RouteURL.url(fuer: .freund(daten: "")).absoluteString, "lumenfit://freund")
    }
}
