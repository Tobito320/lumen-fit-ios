import XCTest
@testable import LumenFit

/// Der Zyklus ist aus Lumen Fit entfernt (Wunsch 02.11.2026): keine Oberfläche, kein Bereich, nichts geht hinaus. Alte Daten, alte Links und alte Server-Antworten
/// mit "zyklus" dürfen nichts kippen.
@MainActor
final class ZyklusEntferntTests: XCTestCase {
    func testFreigabeListeBietetGenauDieZehnBereiche() {
        XCTAssertEqual(VerbindungBereich.allCases.count, 10)
        XCTAssertNil(VerbindungBereich(rawValue: "zyklus"))
        XCTAssertEqual(Set(VerbindungBereich.allCases.compactMap(\.freigabe)), Set(FreigabeArt.allCases), "jeder Bereich ist eine Freigabe")
        for b in VerbindungBereich.allCases { XCTAssertFalse(b.erklaerung.isEmpty, b.rawValue) }
    }

    func testAlteServerListeMitZyklusFaelltNichtUm() {
        let alle = VerbindungenAntwort(teilen: VerbindungBereich.allCases.map(\.rawValue) + ["zyklus"])
        XCTAssertEqual(VerbindungenLogik.hochladen(alle), Set(FreigabeArt.allCases))
    }

    func testZusammenfassungFuerLoveaEnthaeltKeinenZyklus() throws {
        let eingabe = ZusammenfassungBauer.Eingabe(name: "Profil", jetzt: Date(timeIntervalSince1970: 1_800_000_000), freigaben: Set(FreigabeArt.allCases),
                                                   schritte: 5000, gymTageWoche: 2, schlafMinuten: 420, kcal: 1800, ereignisse: [])
        let json = try XCTUnwrap(String(data: try LoveaVertrag.encoder().encode(ZusammenfassungBauer.baue(eingabe)), encoding: .utf8))
        XCTAssertFalse(json.contains("zyklus"), json)
    }

    func testAlterZyklusLinkOeffnetKeineZyklusSeite() throws {
        let url = try XCTUnwrap(URL(string: "lumenfit://profil?bereich=zyklus"))
        XCTAssertEqual(RouteURL.route(aus: url), .profil(.uebersicht), "unbekannter Bereich heißt der erste Fall")
        let router = Router()
        router.tab = .gym
        XCTAssertTrue(router.oeffne(url: url))
        XCTAssertEqual(router.blatt, .profil(.uebersicht))
    }

    func testZyklusOpsImLogBleibenUndStoerenDenStartNicht() throws {
        let ordner = try tempOrdner()
        let raum = LokalerRaum(ordner: ordner, profil: .testA)
        raum.senden("zyklus.tag", ["id": "2026-10-29"])
        raum.senden("zyklus.einstellung", ["zyklusLaenge": "28"])
        let satz = DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: { Date() })
        XCTAssertEqual(satz.raum.ops(arten: ["zyklus.tag", "zyklus.einstellung"]).count, 2, "nichts gelöscht, nichts umgeschrieben")
    }
}
