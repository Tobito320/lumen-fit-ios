import XCTest
@testable import LumenFit

#if DEBUG
/// Die erfundene Demo-Crew (`-lumenFitDemo`) zeigt alle drei Ideen: Reihenfolge, Mitlauf-Satz und einen Rekord mit Übung und Wert.
final class GymCrewDemoTests: XCTestCase {
    private let jetzt = CrewTestDaten.jetzt

    func testZeilenInDerRichtigenReihenfolgeMitMitlauf() {
        let e = GymCrewDemo.eintraege(jetzt: jetzt)
        let z = GymCrewLogik.zeilen(eintraege: e, datum: CrewTestDaten.heute, heute: CrewTestDaten.heute, jetzt: jetzt)
        XCTAssertEqual(z.map(\.zustand), [.imGym, .heuteDa, .noch])
        XCTAssertEqual(z.first?.mitlauf?.uebung, "Bankdrücken")
        XCTAssertEqual(z.first?.mitlauf?.satzNr, 3)
    }

    func testPinnwandHatMindestensEinenRekordMitUebungUndWert() {
        let p = GymRekordPinnwandLogik.pinnwand(eintraege: GymCrewDemo.eintraege(jetzt: jetzt), jetzt: jetzt)
        XCTAssertEqual(p.first?.uebung, "Kniebeuge")
        XCTAssertEqual(p.first?.kg, 120)
    }
}
#endif
