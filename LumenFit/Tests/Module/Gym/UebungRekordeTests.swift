// Quelle: Lovea Tests/TrainingTests.swift (testRecordsPerExerciseAndNewRecordDetection)
import XCTest
@testable import LumenFit

final class UebungRekordeTests: XCTestCase {
    /// Mittwoch 23.09.2026, 18:00 Berlin.
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func op(_ art: String, _ d: some Encodable, zeit: Date, id: String = UUID().uuidString) -> Op {
        Op(id: id, art: art, von: .testA, zeit: zeit, d: (try? JSONEncoder().encode(d)) ?? Data())
    }

    private func satz(_ wdh: Int, _ kg: Double?) -> PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: false) }

    func testRecordsPerExerciseAndNewRecordDetection() {
        var a = satz(10, 60)
        a.ok = true
        var b = satz(8, 70)
        b.ok = true
        var warm = satz(10, 100)
        warm.typ = "w"
        warm.ok = true
        var f = TrainingFaltung()
        for o in [
            op("gym.checkin", GymD(session: "alt", start: t0 - 7 * 86400), zeit: t0 - 7 * 86400),
            op("gym.uebung", GymD(session: "alt", plan: "p", uebung: "X", status: "satz", saetze: [warm, a]), zeit: t0 - 7 * 86400 + 60),
            op("gym.checkin", GymD(session: "neu", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "neu", plan: "q", uebung: "X", status: "satz", saetze: [a, b]), zeit: t0 + 60),
        ] { f.anwenden(o) }
        let sessions = f.sessions(.testA)
        let tage = RekordLogik.tage(katalogId: "X", in: sessions)
        XCTAssertEqual(tage.map(\.id), ["alt", "neu"]) // älteste zuerst, anderer Plantag zählt mit
        XCTAssertEqual(tage[0].saetze, [a]) // Aufwärmsatz zählt nicht
        XCTAssertEqual(RekordLogik.rekord(tage, .gewicht), 70)
        XCTAssertEqual(RekordLogik.rekord(tage, .satzVolumen), 600)
        XCTAssertEqual(RekordLogik.rekord(tage, .sitzungsVolumen), 1160)
        XCTAssertEqual(RekordLogik.rekord(tage, .e1rm), 70 * (1 + 8.0 / 30))
        XCTAssertEqual(RekordLogik.rekord(tage, .wiederholungen), 10)
        XCTAssertEqual(RekordLogik.neue([b], gegen: [tage[0]]), [.gewicht, .e1rm])
        XCTAssertEqual(RekordLogik.neue([a], gegen: [tage[0]]), [])
        XCTAssertEqual(RekordLogik.neue([b], gegen: []), []) // das erste Mal ist kein Rekord
        XCTAssertEqual(RekordLogik.text(1160), "1.160 kg")
        XCTAssertEqual(RekordLogik.text(nil), "–")
    }

    func testEigeneUebungGiltNurUeberIhrenPlanEintrag() {
        var s = satz(10, 20)
        s.ok = true
        let lauf = UebungsLauf(plan: "mein-plan", uebung: PlanUebung.eigen, start: t0, ende: t0, fertig: true, saetze: [s])
        let einheit = GymSession(id: "e", tag: nil, start: t0, ende: nil, laeufe: [lauf])
        XCTAssertEqual(RekordLogik.tage(katalogId: PlanUebung.eigen, planId: "mein-plan", in: [einheit]).count, 1)
        XCTAssertTrue(RekordLogik.tage(katalogId: PlanUebung.eigen, planId: "anderer", in: [einheit]).isEmpty)
    }

    func testAnzahlZaehltUebungenMitRekord() {
        var alt = satz(10, 60)
        alt.ok = true
        let lauf = UebungsLauf(plan: "p", uebung: "X", start: t0, ende: t0, fertig: true, saetze: [alt])
        let frueher = [GymSession(id: "alt", tag: nil, start: t0 - 86400, ende: nil, laeufe: [lauf])]
        var neu = satz(8, 70)
        neu.ok = true
        let plan = PlanUebung(id: "q", uebung: "X", name: nil, saetze: [], minuten: nil)
        let mit = WorkoutUebung(planUebung: plan, saetze: [neu], vorher: [], extra: false)
        let ohne = WorkoutUebung(planUebung: plan, saetze: [alt], vorher: [], extra: false)
        XCTAssertEqual(RekordLogik.anzahl([mit], frueher: frueher), 1)
        XCTAssertEqual(RekordLogik.anzahl([ohne], frueher: frueher), 0)
        XCTAssertEqual(RekordLogik.anzahl([mit], frueher: []), 0)
    }
}
