import XCTest
@testable import LumenFit

/// Die Pause zwischen zwei Uploads der Zusammenfassung: 2 Minuten, im Gym 20 Sekunden (Mitlauf der Crew).
final class KontoPartnerPauseTests: XCTestCase {
    private func daten(imGym: Bool?) throws -> Data {
        var v = PartnerVerlauf(trainings: [])
        v.imGym = imGym
        return try LoveaVertrag.encoder().encode(CrewTestDaten.datei(verlauf: v))
    }

    func testImGymNurZwanzigSekunden() throws {
        XCTAssertEqual(KontoDienst.pauseFuer(try daten(imGym: true)), 20)
    }

    func testSonstZweiMinuten() throws {
        XCTAssertEqual(KontoDienst.pauseFuer(try daten(imGym: false)), 120)
        XCTAssertEqual(KontoDienst.pauseFuer(try daten(imGym: nil)), 120)
        let ohneVerlauf = try LoveaVertrag.encoder().encode(CrewTestDaten.datei(freigaben: [.schritte]))
        XCTAssertEqual(KontoDienst.pauseFuer(ohneVerlauf), 120, "ohne Freigabe verlauf kein Verlauf in der Datei")
    }

    func testUnlesbareDatenBleibenBeiZweiMinuten() {
        XCTAssertEqual(KontoDienst.pauseFuer(Data("{}".utf8)), 120)
        XCTAssertEqual(KontoDienst.pauseFuer(Data()), 120)
    }
}
