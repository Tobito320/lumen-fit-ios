import XCTest
@testable import LumenFit

/// Die Freigabe für Lovea (`KontoDienst.loveaErlaubt`) kommt vom Server, nie nach dem getippten Namen; ein Theme Lovea gibt es nicht mehr (ein Theme, Auftrag 09.11.).
@MainActor
final class ThemaLoveaTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")
    private let configJson = #"{"config":{}}"#
    private let freigabeJson = #"{"erlaubt":true,"person":"person-a","importErledigt":true}"#

    private func antwort(_ status: Int, _ json: String = "{}") -> SkriptLader.Antwort { .init(status: status, daten: Data(json.utf8), fehler: nil) }

    private func dienst(_ lader: SkriptLader, bund: SpeicherSchluesselbund, ordner: URL) -> KontoDienst {
        KontoDienst(zugang: zugang, schluesselbund: bund, http: lader, ordner: ordner, uhr: TestUhr().uhr, version: "0.0.1")
    }

    func testGespeichertesLoveaFaelltOhneAbsturzAufDasEineThemeZurueck() throws {
        let e = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"lovea"}"#.utf8))
        XCTAssertEqual(e.thema, .lovea, "gespeichert wird nichts umgeschrieben")
        for thema in ThemaID.allCases {
            XCTAssertEqual(ProfilThemaWahl.wirksam(thema, loveaErlaubt: false), .schlicht, "\(thema)")
            XCTAssertEqual(ProfilThemaWahl.wirksam(thema, loveaErlaubt: true), .schlicht, "\(thema)")
        }
    }

    func testDieFreigabeBleibtNachImportEndeUndOhneNetz() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let online = dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson)]), bund: bund, ordner: ordner)
        await online.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(online.loveaErlaubt)
        XCTAssertFalse(online.loveaImportOffen, "der Import ist durch")

        let offline = dienst(SkriptLader([antwort(200, configJson), .init(status: 0, daten: Data(), fehler: .notConnectedToInternet)]), bund: bund, ordner: ordner)
        XCTAssertTrue(offline.loveaErlaubt, "der gemerkte Stand gilt schon vor der ersten Antwort")
        await offline.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(offline.loveaErlaubt, "Netzfehler nimmt die Freigabe nicht zurück")
    }

    func testDasEineThemeMaltMitSystemFlaechen() {
        let hell = LumenFarben.tokens(thema: .lovea, dunkel: false)
        let dunkel = LumenFarben.tokens(thema: .lovea, dunkel: true)
        XCTAssertEqual(hell.grund, 0xFFFFFF)
        XCTAssertEqual(hell.flaeche, 0xF2F2F7)
        XCTAssertEqual(dunkel.grund, 0x000000)
        XCTAssertEqual(dunkel.flaeche, 0x1C1C1E)
        XCTAssertEqual(dunkel.akzent, LumenFarben.tokens(thema: .schlicht, dunkel: true).akzent, "kein eigener Akzent mehr")
    }

    func testFeierKommtNurEinmalProTagUndAnlass() {
        let speicher = UserDefaults(suiteName: "ThemaLoveaTests.feier")!
        speicher.removePersistentDomain(forName: "ThemaLoveaTests.feier")
        let tag = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(LoveaTagesMoment.einmalHeute("ziel", jetzt: tag, speicher: speicher))
        XCTAssertFalse(LoveaTagesMoment.einmalHeute("ziel", jetzt: tag, speicher: speicher), "zweites Mal am selben Tag nicht")
        XCTAssertTrue(LoveaTagesMoment.einmalHeute("anderes", jetzt: tag, speicher: speicher), "anderer Anlass zählt für sich")
        XCTAssertTrue(LoveaTagesMoment.einmalHeute("ziel", jetzt: tag.addingTimeInterval(86_400 * 2), speicher: speicher), "am nächsten Tag wieder")
    }
}
