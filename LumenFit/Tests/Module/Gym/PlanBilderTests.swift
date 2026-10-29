import XCTest
@testable import LumenFit

/// Die Bilder der Plan-Übungen werden vorab geholt (Idee 26), nicht erst beim ersten Ansehen im Studio.
@MainActor
final class PlanBilderTests: XCTestCase {
    private func plan(_ ids: [String]) -> TrainingsPlan {
        TrainingsPlan(tage: [TrainingsTag(id: "t1", name: "Push", wochentage: [1],
                                          uebungen: ids.map { PlanUebung(id: UUID().uuidString, uebung: $0, name: nil, saetze: [], minuten: nil) })])
    }

    func testDieIdsKommenOhneWiederholungOhneEigeneUndOhneUebungenOhneBild() {
        let p = plan(["EIeI8Vf", "ns0SIbU", "EIeI8Vf", PlanUebung.eigen, "lv-face-pull"])
        XCTAssertEqual(PlanBilder.ids(p), ["EIeI8Vf", "ns0SIbU"])
        XCTAssertEqual(PlanBilder.ids(.leer), [])
    }

    func testNurWasImCacheFehltWirdGeholt() async {
        let p = plan(["EIeI8Vf", "ns0SIbU", "3TZduzM"])
        XCTAssertEqual(PlanBilder.fehlend(p, vorhanden: { $0 == "ns0SIbU" }), ["EIeI8Vf", "3TZduzM"])

        var geholt: [String] = []
        let versucht = await PlanBilder.holeFehlende(p, vorhanden: { $0 == "ns0SIbU" }, laden: { geholt = $0 })
        XCTAssertEqual(geholt, ["EIeI8Vf", "3TZduzM"])
        XCTAssertEqual(versucht, 2)
    }

    func testIstAllesDaWirdNichtsGeladen() async {
        let p = plan(["EIeI8Vf"])
        var aufrufe = 0
        let versucht = await PlanBilder.holeFehlende(p, vorhanden: { _ in true }, laden: { _ in aufrufe += 1 })
        XCTAssertEqual(versucht, 0)
        XCTAssertEqual(aufrufe, 0, "kein Netzaufruf, wenn nichts fehlt")
    }
}
