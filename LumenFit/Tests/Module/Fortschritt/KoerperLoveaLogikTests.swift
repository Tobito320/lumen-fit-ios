import XCTest
@testable import LumenFit

/// Die Körper-Seite im Lovea-Aufbau: Reihenfolge der Abschnitte und die Farben aus Lovea.
final class KoerperLoveaLogikTests: XCTestCase {
    func testOhneBefragungSteigtDieZielKarteInDieReiheUndNaechstesFehlt() {
        XCTAssertEqual(KoerperLoveaLogik.abschnitte(zieleGesetzt: false, hatNaechstes: true), [.streifen, .figur, .zielKarte, .felder])
    }

    func testMitBefragungUndPlanKommtNaechstesZuletzt() {
        XCTAssertEqual(KoerperLoveaLogik.abschnitte(zieleGesetzt: true, hatNaechstes: true), [.streifen, .figur, .felder, .naechstes])
    }

    func testMitBefragungOhnePlanBleibenStreifenFigurUndFelder() {
        XCTAssertEqual(KoerperLoveaLogik.abschnitte(zieleGesetzt: true, hatNaechstes: false), [.streifen, .figur, .felder])
    }

    func testFeldFarbenSindDieVonLovea() {
        XCTAssertEqual(KoerperLoveaFarbe.feldHex(.erholt), 0x30D158)
        XCTAssertEqual(KoerperLoveaFarbe.feldHex(.fast), 0xFF7A59)
        XCTAssertEqual(KoerperLoveaFarbe.feldHex(.muede), 0xFF3B5C)
    }

    func testFigurFarbenSindJeNachSchemaGetrennt() {
        for stufe in SilhouetteStufe.allCases {
            XCTAssertNotEqual(KoerperLoveaFarbe.figurHex(stufe, dunkel: false), KoerperLoveaFarbe.figurHex(stufe, dunkel: true))
        }
        XCTAssertEqual(KoerperLoveaFarbe.figurHex(.muede, dunkel: false), 0xE0284A)
        XCTAssertEqual(KoerperLoveaFarbe.figurHex(.leer, dunkel: true), 0x4A4A50)
    }

    func testBilanzLaesstEineArtOhnePlanUndTrainingWeg() {
        XCTAssertEqual(KoerperWoche(tage: [], beine: 0, oben: 2, pausen: 1).bilanz, "Oberkörper 2 von 2 · 1 Pause")
        XCTAssertEqual(KoerperWoche(tage: [], beine: 1, oben: 0, pausen: 0).bilanz, "Beine 1 von 1 · 0 Pausen")
        XCTAssertTrue(KoerperWoche(tage: [], beine: 0, oben: 0, pausen: 0).bilanz.hasPrefix("Noch kein Training"))
    }
}
