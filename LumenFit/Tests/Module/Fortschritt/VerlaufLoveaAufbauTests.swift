import XCTest
@testable import LumenFit

/// Reihenfolge und Zeichen der Verlauf-Seite im Lovea-Aufbau.
final class VerlaufLoveaAufbauTests: XCTestCase {
    func testVerlaufReihenfolgeMitAllem() {
        XCTAssertEqual(VerlaufLovea.verlaufBloecke(highlights: true, trainingDa: true),
                       [.konsistenz, .highlights, .alleTrainingstage, .konstanzRaster, .gewicht, .stimmung, .rueckblick])
    }

    func testVerlaufOhneHighlightsUndTraining() {
        XCTAssertEqual(VerlaufLovea.verlaufBloecke(highlights: false, trainingDa: false),
                       [.konsistenz, .alleTrainingstage, .gewicht, .stimmung, .rueckblick])
    }

    func testLoveaBloeckeStehenVorDenLumenKarten() {
        let b = VerlaufLovea.verlaufBloecke(highlights: true, trainingDa: true)
        XCTAssertLessThan(b.firstIndex(of: .alleTrainingstage)!, b.firstIndex(of: .gewicht)!)
    }

    func testErholungszeichenHabenJeStufeEineForm() {
        let formen = Set([ErholungsStufe.erholt, .fast, .muede].map(VerlaufLovea.zeichen))
        XCTAssertEqual(formen.count, 3)
    }

    func testTeilText() {
        XCTAssertEqual(VerlaufLoveaGruppe.teilText(4, 95), VerlaufLogik.saetzeText(4))
        XCTAssertEqual(VerlaufLoveaGruppe.teilText(4, 60), "\(VerlaufLogik.saetzeText(4)) · 60 %")
    }
}
