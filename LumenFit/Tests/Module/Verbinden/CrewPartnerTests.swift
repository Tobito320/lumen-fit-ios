import XCTest
@testable import LumenFit

/// "Eure Woche": geplante und trainierte Tage für dich und den Trainingspartner, nur mit Freigabe, alte Wochen zählen nicht.
final class CrewPartnerTests: XCTestCase {
    /// Mittwoch, 11.11.2026; die Woche beginnt am Montag, 09.11.
    private let heute = "2026-11-11"

    func testTrainiertSchlaegtGeplantHeuteMarkiert() {
        let w = CrewWocheLogik.woche(geplant: [1, 3, 5], trainiert: ["2026-11-09", "2026-11-10"], heute: heute)
        XCTAssertEqual(w.map(\.kurz), ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
        XCTAssertEqual(w.map(\.art), [.trainiert, .trainiert, .geplant, .frei, .geplant, .frei, .frei])
        XCTAssertEqual(w.filter(\.heute).map(\.tag), [heute])
        XCTAssertEqual(CrewWocheLogik.vorlesen("Du", w), "Du: Montag trainiert, Dienstag trainiert, Mittwoch geplant, Freitag geplant")
        XCTAssertEqual(CrewWocheLogik.vorlesen("Du", CrewWocheLogik.woche(geplant: [], trainiert: [], heute: heute)), "Du: nichts geplant")
    }

    func testMeinPlanUndMeineEinheitenDieserWoche() {
        let plan = TrainingsPlan(tage: [TrainingsTag(id: "a", name: "Push", wochentage: [1, 4], uebungen: []),
                                        TrainingsTag(id: "b", name: "Pull", wochentage: [2], uebungen: [])])
        XCTAssertEqual(CrewWocheLogik.geplant(plan: plan, heute: heute), [1, 2, 4])
        let s = { (tag: String) in GymSession(id: tag, tag: nil, start: Datum.datum(tag).addingTimeInterval(18 * 3600), ende: nil, laeufe: []) }
        XCTAssertEqual(CrewWocheLogik.trainiert(sessions: [s("2026-11-06"), s("2026-11-09"), s("2026-11-11")], heute: heute), ["2026-11-09", "2026-11-11"])
    }

    func testPersonNurMitFreigabeUndNurDieseWoche() {
        var tag = TagesZusammenfassung(tag: heute)
        tag.plan = PartnerPlan(name: nil, tage: [PartnerPlanTag(name: "Beine", wochentage: [3, 6, 9], uebungen: [])])
        tag.gymTage = ["2026-11-06", "2026-11-10"]
        let alles = ZusammenfassungDatei(version: 1, geschrieben: Datum.datum(heute), profilName: "Beispiel Freund A", freigaben: [.plan, .gym], heute: tag, ereignisse: [])
        XCTAssertEqual(CrewWocheLogik.geplant(alles), [3, 6], "nur Wochentage 1 bis 7")
        XCTAssertEqual(CrewWocheLogik.trainiert(alles, heute: heute), ["2026-11-10"], "letzte Woche zählt nicht")
        var ohne = alles
        ohne.freigaben = [.schritte]
        XCTAssertNil(CrewWocheLogik.geplant(ohne))
        XCTAssertNil(CrewWocheLogik.trainiert(ohne, heute: heute))
    }
}
