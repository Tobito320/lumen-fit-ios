import XCTest
@testable import LumenFit

/// Zyklus gehört nur in Lovea (Ahmed, 01.11.2026): Lumen Fit bietet ihn bei den Verbindungen nicht an, lädt ihn nicht hoch und schreibt ihn nicht in
/// die Zusammenfassung für Lovea. Ein alter Link auf die Zyklus-Seite landet auf Heute.
@MainActor
final class ZyklusNurInLoveaTests: XCTestCase {
    func testFreigabeListeBietetGenauDieZehnBereicheOhneZyklus() {
        XCTAssertEqual(VerbindungBereich.allCases.count, 10)
        XCTAssertFalse(VerbindungBereich.allCases.map(\.rawValue).contains("zyklus"))
        XCTAssertNil(VerbindungBereich(rawValue: "zyklus"))
        XCTAssertEqual(Set(VerbindungBereich.allCases.compactMap(\.freigabe)), Set(FreigabeArt.allCases), "jeder Bereich ist eine Freigabe")
        for b in VerbindungBereich.allCases { XCTAssertFalse(b.erklaerung.isEmpty, b.rawValue) }
    }

    func testHochladenNenntNieDenZyklus() {
        let alle = VerbindungenAntwort(teilen: VerbindungBereich.allCases.map(\.rawValue) + ["zyklus"])
        XCTAssertEqual(VerbindungenLogik.hochladen(alle), Set(FreigabeArt.allCases))
    }

    func testZusammenfassungFuerLoveaEnthaeltKeinenZyklus() throws {
        let eingabe = ZusammenfassungBauer.Eingabe(name: "Profil", jetzt: Date(timeIntervalSince1970: 1_800_000_000), freigaben: Set(FreigabeArt.allCases),
                                                   schritte: 5000, gymTageWoche: 2, schlafMinuten: 420, kcal: 1800, ereignisse: [])
        let datei = ZusammenfassungBauer.baue(eingabe)
        XCTAssertNil(datei.heute.zyklus)
        let json = try XCTUnwrap(String(data: try LoveaVertrag.encoder().encode(datei), encoding: .utf8))
        XCTAssertFalse(json.contains("zyklus"), json)
    }

    func testAlterZyklusLinkLandetAufHeute() {
        let router = Router()
        router.tab = .gym
        XCTAssertTrue(router.oeffne(url: RouteURL.url(fuer: .profil(.zyklus))))
        XCTAssertEqual(router.tab, .heute)
        XCTAssertNil(router.blatt, "kein Blatt mit der alten Zyklus-Seite")
        XCTAssertEqual(router.pfade[.heute] ?? [], [])
    }
}
