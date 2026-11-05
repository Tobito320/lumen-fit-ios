import XCTest
@testable import LumenFit

/// Die drei Stufen beim Teilen: Wenig (Standard), Crew (fürs Gym) und Alles.
final class FreigabenTests: XCTestCase {
    func testDreiStufenInDerReihenfolgeDerAuswahl() {
        XCTAssertEqual(FreigabeStufe.allCases, [.wenig, .crew, .alles])
        XCTAssertEqual(FreigabeStufe.allCases.map(\.name), ["Wenig", "Crew", "Alles"])
    }

    func testCrewZeigtNurGymPlanUndVerlauf() {
        XCTAssertEqual(FreigabeStufe.crew.bereiche, [.gym, .plan, .verlauf])
        for b in [VerbindungBereich.schlaf, .essen, .koerper, .tagebuch, .stimmung, .gewohnheiten, .schritte] {
            XCTAssertFalse(FreigabeStufe.crew.bereiche.contains(b), "\(b) gehört nicht zur Crew")
        }
    }

    func testVonErkenntCrewUndStandardBleibtWenig() {
        XCTAssertEqual(FreigabeStufe.von([.gym, .plan, .verlauf]), .crew)
        XCTAssertEqual(FreigabeStufe.von(VerbindungenLogik.standardZeigt), .wenig)
        XCTAssertNil(FreigabeStufe.von([.gym, .plan]), "eigene Auswahl bleibt, wie sie ist")
        XCTAssertEqual(Set(FreigabeStufe.allCases.map(\.bereiche)).count, 3, "keine zwei Stufen mit gleichen Bereichen")
    }

    func testCrewFeldFuerDenServerIstSortiert() {
        XCTAssertEqual(FreigabeStufe.felder(FreigabeStufe.crew.bereiche)["zeigt"] as? [String], ["gym", "plan", "verlauf"])
    }

    func testHilfetextNurFuerCrew() {
        XCTAssertEqual(FreigabeStufe.crew.hilfe, "Training, Plan und Gewichte der letzten Einheiten. Nie Schlaf, Essen, Körper.")
        XCTAssertNil(FreigabeStufe.wenig.hilfe)
        XCTAssertNil(FreigabeStufe.alles.hilfe)
    }

    func testCrewBereicheErgebenFreigabenFuerDieZusammenfassung() {
        // Das Hochladen hängt an `freigabe`; alle drei Bereiche der Crew haben eine.
        XCTAssertEqual(Set(FreigabeStufe.crew.bereiche.compactMap(\.freigabe)), [.gym, .plan, .verlauf])
    }
}
