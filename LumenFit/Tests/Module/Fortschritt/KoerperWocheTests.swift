// Quelle: Lovea Tests/WochenAbweichungTests.swift (testWochenleisteZeigtVerlegtenTagAmNeuenTag; die übrigen Fälle liegen im Grundgerüst)
import XCTest
@testable import LumenFit

/// Die Wochenleiste folgt dem verlegten Tag. 2026-10-05 ist ein Montag.
final class KoerperWocheTests: XCTestCase {
    private let mo = "2026-10-05", mi = "2026-10-07", fr = "2026-10-09", naechsteMo = "2026-10-12"

    private func katalogWoche(_ id: String) -> Uebung? {
        Uebung(id: id, name: id, en: id, muskel: id == "Kniebeuge" ? "Quadrizeps" : "Brust", koerper: "", geraet: "", neben: [])
    }

    func testWochenleisteZeigtVerlegtenTagAmNeuenTag() throws {
        let beine = TrainingsTag(id: "Beine", name: "Beine", wochentage: [3], uebungen: [PlanUebung(id: "b0", uebung: "Kniebeuge", name: nil, saetze: [], minuten: nil)])
        let push = TrainingsTag(id: "Push", name: "Push", wochentage: [1], uebungen: [PlanUebung(id: "p0", uebung: "Bank", name: nil, saetze: [], minuten: nil)])
        let p = TrainingsPlan(tage: [push, beine], ruhetage: [2, 4, 5, 6, 7])
        let neu = try XCTUnwrap(WochenLogik.verlegen(p, von: mi, auf: fr, heute: mo))
        let woche = KoerperWoche.bauen(sessions: [], plan: neu, heute: mo, katalog: katalogWoche)
        XCTAssertNil(woche.tage[2].geplant, "Mittwoch ist frei")
        XCTAssertEqual(woche.tage[4].geplant, KoerperLogik.Art.beine)
        XCTAssertNotNil(woche.tage[4].planWort)
        XCTAssertNil(woche.tage[2].planWort)
        XCTAssertEqual(woche.tage[4].sprechtext, "Freitag 9., Beine geplant")
        let danach = KoerperWoche.bauen(sessions: [], plan: neu, heute: naechsteMo, katalog: katalogWoche)
        XCTAssertEqual(danach.tage[2].geplant, KoerperLogik.Art.beine, "nächste Woche wieder Mittwoch")
        XCTAssertNil(danach.tage[4].geplant)
    }

    func testGemachtSchlaegtPlanUndPausenZaehlenNurVergangenes() {
        let push = TrainingsTag(id: "Push", name: "Push", wochentage: [1, 3], uebungen: [PlanUebung(id: "p0", uebung: "Bank", name: nil, saetze: [], minuten: nil)])
        let plan = TrainingsPlan(tage: [push])
        let montag = GymSession(id: "s", tag: "Push", start: Datum.datum(mo).addingTimeInterval(18 * 3600), ende: nil, laeufe: [])
        let woche = KoerperWoche.bauen(sessions: [montag], plan: plan, heute: mi, katalog: katalogWoche)
        XCTAssertEqual(woche.tage[0].anzeige, .fertig)
        XCTAssertEqual(woche.tage[2].anzeige, .heute(.oben))
        XCTAssertEqual(woche.tage[1].anzeige, .ruhe)
        XCTAssertEqual(woche.pausen, 1, "nur der Dienstag liegt vor heute ohne Einheit")
        XCTAssertEqual(woche.oben, 1)
    }
}
