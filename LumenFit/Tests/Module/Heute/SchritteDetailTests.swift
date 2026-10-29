import XCTest
@testable import LumenFit

final class SchritteDetailTests: XCTestCase {
    /// Mittwoch, 23.09.2026.
    private let heute = "2026-09-23"

    private func tage() -> [String: TagesWerte] {
        [
            "2026-09-21": TagesWerte(tag: "2026-09-21", schritte: 12_000, distanzMeter: 9_000, etagen: 10),
            "2026-09-22": TagesWerte(tag: "2026-09-22", schritte: 6_000, distanzMeter: 4_500, etagen: 4),
            "2026-09-23": TagesWerte(tag: "2026-09-23", schritte: 8_412, distanzMeter: 6_300, etagen: 6),
            "2026-09-14": TagesWerte(tag: "2026-09-14", schritte: 15_000, distanzMeter: 11_000, etagen: 2),
            "2026-08-30": TagesWerte(tag: "2026-08-30", schritte: 9_000, distanzMeter: 7_000, etagen: 1),
        ]
    }

    func testTagMitDistanzUndEtagen() {
        let s = SchritteDetailLogik.stand(zeitraum: .tag, anker: heute, heute: heute, tage: tage(), ziel: 10_000)
        XCTAssertEqual(s.summe, 8_412)
        XCTAssertEqual(s.schnitt, 8_412)
        XCTAssertEqual(s.distanzKm, 6.3, accuracy: 0.0001)
        XCTAssertEqual(s.etagen, 6)
        XCTAssertEqual(s.zielTage, 0)
        XCTAssertEqual(s.titel, "Mittwoch, 23. September")
        XCTAssertEqual(s.punkte.map(\.tag).last, heute, "das Diagramm zeigt sieben Tage bis heute")
        XCTAssertEqual(s.punkte.count, 7)
    }

    func testWocheSummeSchnittBesteTageUndZielTage() {
        let s = SchritteDetailLogik.stand(zeitraum: .woche, anker: heute, heute: heute, tage: tage(), ziel: 10_000)
        XCTAssertEqual(s.summe, 26_412)
        XCTAssertEqual(s.schnitt, 8_804)
        XCTAssertEqual(s.tageMitDaten, 3)
        XCTAssertEqual(s.zielTage, 1)
        XCTAssertEqual(s.beste.map(\.tag), ["2026-09-21", "2026-09-23", "2026-09-22"])
        XCTAssertEqual(s.distanzKm, 19.8, accuracy: 0.0001)
        XCTAssertEqual(s.etagen, 20)
        XCTAssertEqual(s.titel, "21.09. bis 27.09.")
        XCTAssertEqual(s.punkte.map(\.tag), ["2026-09-21", "2026-09-22", "2026-09-23"], "Tage nach heute fehlen im Diagramm")
        XCTAssertEqual(s.hoechster, 12_000)
    }

    func testMonatNimmtAlleTageDesMonats() {
        let s = SchritteDetailLogik.stand(zeitraum: .monat, anker: heute, heute: heute, tage: tage(), ziel: 10_000)
        XCTAssertEqual(s.summe, 41_412, "der 30.08. gehört nicht zum September")
        XCTAssertEqual(s.tageMitDaten, 4)
        XCTAssertEqual(s.beste.first?.tag, "2026-09-14")
        XCTAssertEqual(s.beste.count, 3)
        XCTAssertEqual(s.titel, "September 2026")
    }

    func testTageOhneDatenUndTageNachHeuteZaehlenNicht() {
        let s = SchritteDetailLogik.stand(zeitraum: .woche, anker: heute, heute: heute, tage: ["2026-09-25": TagesWerte(tag: "2026-09-25", schritte: 9_000)], ziel: 10_000)
        XCTAssertNil(s.summe)
        XCTAssertNil(s.schnitt)
        XCTAssertEqual(s.tageMitDaten, 0)
        XCTAssertTrue(s.beste.isEmpty)
        XCTAssertEqual(s.hoechster, 10_000, "ohne Daten bleibt die Zielmarke die Obergrenze des Diagramms")
    }

    func testNullSchritteGeltenAlsKeinWert() {
        let s = SchritteDetailLogik.stand(zeitraum: .tag, anker: heute, heute: heute, tage: [heute: TagesWerte(tag: heute, schritte: 0)], ziel: 10_000)
        XCTAssertNil(s.summe)
        XCTAssertEqual(s.tageMitDaten, 0)
    }

    func testBesteTageBeiGleichstandNachDatum() {
        let gleich: [String: TagesWerte] = ["2026-09-22": TagesWerte(tag: "2026-09-22", schritte: 7_000), "2026-09-21": TagesWerte(tag: "2026-09-21", schritte: 7_000)]
        let s = SchritteDetailLogik.stand(zeitraum: .woche, anker: heute, heute: heute, tage: gleich, ziel: 10_000)
        XCTAssertEqual(s.beste.map(\.tag), ["2026-09-21", "2026-09-22"])
    }

    func testKurzDatum() {
        XCTAssertEqual(SchritteDetailLogik.kurz("2026-09-05"), "05.09.")
        XCTAssertEqual(SchritteDetailLogik.kurz("kaputt"), "kaputt")
    }
}
