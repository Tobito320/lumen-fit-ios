import XCTest
@testable import LumenFit

/// Das Theme Lovea gibt es nur für Konten, die der Server freigibt (`KontoDienst.loveaErlaubt`), nie nach dem getippten Namen.
@MainActor
final class ThemaLoveaTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")
    private let configJson = #"{"config":{}}"#
    private let freigabeJson = #"{"erlaubt":true,"person":"person-a","importErledigt":true}"#

    private func antwort(_ status: Int, _ json: String = "{}") -> SkriptLader.Antwort { .init(status: status, daten: Data(json.utf8), fehler: nil) }

    private func dienst(_ lader: SkriptLader, bund: SpeicherSchluesselbund, ordner: URL) -> KontoDienst {
        KontoDienst(zugang: zugang, schluesselbund: bund, http: lader, ordner: ordner, uhr: TestUhr().uhr, version: "0.0.1")
    }

    func testOhneFreigabeGibtEsSechsThemesMitFreigabeSieben() {
        let ohne = ProfilThemaWahl.verfuegbar(loveaErlaubt: false)
        XCTAssertEqual(ohne.count, 6)
        XCTAssertFalse(ohne.contains(.lovea))
        XCTAssertEqual(ProfilThemaWahl.verfuegbar(loveaErlaubt: true).count, 7)
        XCTAssertTrue(ProfilThemaWahl.verfuegbar(loveaErlaubt: true).contains(.lovea))
        XCTAssertEqual(ProfilThemaWahl.kombinationen(loveaErlaubt: false).count, 12)
        XCTAssertEqual(ProfilThemaWahl.kombinationen(loveaErlaubt: true).count, 14)
    }

    func testGespeichertesLoveaOhneFreigabeFaelltOhneAbsturzAufMonochromZurueck() throws {
        let e = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"lovea"}"#.utf8))
        XCTAssertEqual(e.thema, .lovea, "gespeichert wird nichts umgeschrieben")
        XCTAssertEqual(ProfilThemaWahl.wirksam(e.thema, loveaErlaubt: false), .monochrom)
        XCTAssertEqual(ProfilThemaWahl.wirksam(e.thema, loveaErlaubt: true), .lovea, "kommt die Freigabe wieder, gilt die Wahl wieder")
        for thema in ThemaID.allCases where thema != .lovea {
            XCTAssertEqual(ProfilThemaWahl.wirksam(thema, loveaErlaubt: false), thema, "\(thema) bleibt, wie es ist")
        }
        // Die Palette des Rückfalls ist die von Monochrom, nicht die von Lovea.
        let wirksam = ProfilThemaWahl.wirksam(.lovea, loveaErlaubt: false)
        XCTAssertEqual(LumenFarben.tokens(thema: wirksam, dunkel: false).akzent, LumenFarben.tokens(thema: .monochrom, dunkel: false).akzent)
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
        XCTAssertEqual(ProfilThemaWahl.wirksam(.lovea, loveaErlaubt: offline.loveaErlaubt), .lovea)
    }

    func testLoveaFarbenFolgenDenSystemFlaechen() {
        let hell = LumenFarben.tokens(thema: .lovea, dunkel: false)
        let dunkel = LumenFarben.tokens(thema: .lovea, dunkel: true)
        // Lovea malt mit systemBackground und secondarySystemBackground (UIKit-Tabelle).
        XCTAssertEqual(hell.grund, 0xFFFFFF)
        XCTAssertEqual(hell.flaeche, 0xF2F2F7)
        XCTAssertEqual(dunkel.grund, 0x000000)
        XCTAssertEqual(dunkel.flaeche, 0x1C1C1E)
        XCTAssertEqual(dunkel.akzent, 0xFF3B5C, "Lovea-Akzent im Dunkeln unverändert")
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
