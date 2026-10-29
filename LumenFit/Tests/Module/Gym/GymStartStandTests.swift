// Quelle: Lovea Tests/WochenAbweichungTests.swift (testPlantagInVerlegterWoche, testGymStartStandZeigtVerlegtUndTestwoche)
import XCTest
@testable import LumenFit

/// Plantag-Karte und Startseite des Trainings in einer verlegten Woche und in der Testwoche. 2026-10-05 ist ein Montag.
final class GymStartStandTests: XCTestCase {
    private let mo = "2026-10-05", di = "2026-10-06", mi = "2026-10-07", don = "2026-10-08"
    private let fr = "2026-10-09", sa = "2026-10-10", so = "2026-10-11"
    private let naechsteMo = "2026-10-12", naechsteMi = "2026-10-14"

    private func tag(_ name: String, _ wochentage: [Int], uebungen: Int = 0) -> TrainingsTag {
        TrainingsTag(id: name, name: name, wochentage: wochentage, uebungen: (0..<uebungen).map {
            PlanUebung(id: "\(name)\($0)", uebung: "x", name: "U", saetze: [], minuten: nil)
        })
    }

    /// Push Mo, Pull Mi, Beine Fr; ids gleich Namen.
    private var plan: TrainingsPlan {
        TrainingsPlan(tage: [tag("Push", [1], uebungen: 2), tag("Pull", [3], uebungen: 1), tag("Beine", [5], uebungen: 3)],
                      ruhetage: [2, 4, 6, 7], splitName: "Upper Lower")
    }

    private func vorlage(_ einheiten: [(String, [Int])], name: String = "Testsplit") -> SplitVorlage {
        SplitVorlage(id: "t", name: name, gruppe: "m", level: "mittel", ziel: "fit", geraet: "studio", tage: einheiten.count,
                     einheiten: einheiten.map {
                         SplitVorlage.Einheit(name: $0.0, wochentage: $0.1, uebungen: [SplitVorlage.Zeile(uebung: "x", saetze: 3, von: 8, bis: 12)])
                     })
    }

    private func verlege(_ von: String, _ auf: String) throws -> TrainingsPlan {
        try XCTUnwrap(WochenLogik.verlegen(plan, von: von, auf: auf, heute: mo))
    }

    private func starteTest() throws -> TrainingsPlan {
        try XCTUnwrap(WochenLogik.testStarten(plan, vorlage: vorlage([("Oben", [2]), ("Unten", [4]), ("Core", [6])]), heute: mo, gemacht: []))
    }

    func testPlantagInVerlegterWoche() throws {
        let neu = try verlege(mi, don)
        let donnerstag = SplitFrei.plantag(neu, datum: don)
        XCTAssertEqual(donnerstag?.titel, "Tag 2 diese Woche: Pull")
        XCTAssertEqual(donnerstag?.heute, true)
        for frei in [di, mi] {
            let s = SplitFrei.plantag(neu, datum: frei)
            XCTAssertEqual(s?.titel, "Heute frei", frei)
            XCTAssertEqual(s?.unter, "Als Nächstes Tag 2: Pull, Donnerstag", frei)
        }
        XCTAssertEqual(SplitFrei.plantag(neu, datum: so)?.unter, "Als Nächstes Tag 1: Push, nächste Woche Montag")
        XCTAssertEqual(SplitFrei.plantag(neu, datum: naechsteMi)?.titel, "Tag 2 diese Woche: Pull")
    }

    func testGymStartStandZeigtVerlegtUndTestwoche() throws {
        let jetzt = Datum.datum(mo).addingTimeInterval(36000)
        let stand = GymStartStand.bauen(sessions: [], plan: try verlege(mi, don), gewaehlt: don, jetzt: jetzt)
        XCTAssertTrue(stand.verlegt)
        XCTAssertEqual(stand.tag?.id, "Pull")
        XCTAssertEqual(stand.ziele.map(\.datum), [mo, di, mi, fr, sa, so])
        XCTAssertNil(stand.testHinweis)

        let testet = try starteTest()
        let teststand = GymStartStand.bauen(sessions: [], plan: testet, gewaehlt: mi, jetzt: jetzt)
        XCTAssertEqual(teststand.testHinweis, "Testwoche: Testsplit, ab Montag wieder Upper Lower")
        XCTAssertEqual(teststand.tag?.name, "Unten")
        XCTAssertFalse(teststand.verlegt)

        let spaeter = Datum.datum(naechsteMo).addingTimeInterval(36000)
        let danach = GymStartStand.bauen(sessions: [], plan: testet, gewaehlt: naechsteMo, jetzt: spaeter)
        XCTAssertNil(danach.testHinweis)
        XCTAssertEqual(danach.tag?.name, "Push")
    }

    func testWochenleisteZeigtGeplantesUndGemachtes() {
        let jetzt = Datum.datum(mi).addingTimeInterval(36000)
        let gemacht = GymSession(id: "m", tag: "Push", start: Datum.datum(mo).addingTimeInterval(18 * 3600), ende: nil, laeufe: [])
        let stand = GymStartStand.bauen(sessions: [gemacht], plan: plan, gewaehlt: mi, jetzt: jetzt)
        XCTAssertEqual(stand.woche.map(\.datum), [mo, di, mi, don, fr, sa, so])
        XCTAssertEqual(stand.woche.map(\.kuerzel), ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
        XCTAssertEqual(stand.woche.map(\.geplant), ["Push", nil, "Pull", nil, "Beine", nil, nil])
        XCTAssertEqual(stand.woche.map(\.gemacht), [true, false, false, false, false, false, false])
        XCTAssertEqual(stand.woche.filter(\.heute).map(\.datum), [mi])
        XCTAssertEqual(stand.woche.filter(\.gewaehlt).map(\.datum), [mi])
        XCTAssertEqual(stand.woche[0].sprechtext, "Montag, 5. Oktober, trainiert")
        XCTAssertEqual(stand.woche[1].sprechtext, "Dienstag, 6. Oktober, Ruhetag")
        XCTAssertEqual(stand.woche[2].sprechtext, "Mittwoch, 7. Oktober, Pull geplant")
    }

    func testKnopfNurHeuteUndJeNachLaufenderEinheit() {
        let jetzt = Datum.datum(mi).addingTimeInterval(36000)
        XCTAssertEqual(GymStartStand.bauen(sessions: [], plan: plan, gewaehlt: mi, jetzt: jetzt).knopf, .starten)
        XCTAssertNil(GymStartStand.bauen(sessions: [], plan: plan, gewaehlt: fr, jetzt: jetzt).knopf)
        let laeuft = GymSession(id: "l", tag: "Pull", start: jetzt - 600, ende: nil, laeufe: [])
        XCTAssertEqual(GymStartStand.bauen(sessions: [laeuft], plan: plan, gewaehlt: mi, jetzt: jetzt).knopf, .weiter)
        let gerade = GymSession(id: "g", tag: "Pull", start: jetzt - 3600, ende: jetzt - 600, laeufe: [])
        XCTAssertEqual(GymStartStand.bauen(sessions: [gerade], plan: plan, gewaehlt: mi, jetzt: jetzt).knopf, .fortsetzen)
        XCTAssertEqual(GymStartKnopf.starten.titel, "Starten")
        XCTAssertEqual(GymStartKnopf.fortsetzen.symbolName, "arrow.uturn.backward")
    }

    func testAbweichungHeuteBeineStattPush() {
        let push = tag("Push", [1]), beine = tag("Beine", [5])
        XCTAssertEqual(GymStartStand.abweichung(geplant: push, gewaehlt: beine), "Heute Beine statt Push")
        XCTAssertNil(GymStartStand.abweichung(geplant: push, gewaehlt: push))
        XCTAssertNil(GymStartStand.abweichung(geplant: nil, gewaehlt: beine), "an einem Ruhetag gibt es nichts, wovon man abweicht")
        XCTAssertNil(GymStartStand.abweichung(geplant: push, gewaehlt: nil))
    }
}
