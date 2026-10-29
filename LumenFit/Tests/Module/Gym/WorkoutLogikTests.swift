// Quelle: Lovea Tests/WorkoutBedienungTests.swift, GymLueckenTests.swift, TrainingTests.swift, SatzzeitTests.swift (die Tests zu WorkoutLogik)
import XCTest
@testable import LumenFit

final class WorkoutLogikTests: XCTestCase {
    /// Mittwoch 23.09.2026, 18:00 Berlin.
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func satz(_ wdh: Int, _ kg: Double?, ok: Bool = false, failure: Bool = false) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: failure)
        if ok { s.ok = true }
        return s
    }

    private func uebung(_ id: String, saetze: [PlanSatz] = [], minuten: Int? = nil) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: "Übung \(id)", saetze: saetze, minuten: minuten)
    }

    private func leereSession(tag: String? = "t", laeufe: [UebungsLauf] = []) -> GymSession {
        GymSession(id: "s", tag: tag, start: t0, ende: nil, laeufe: laeufe)
    }

    private func op(_ art: String, _ d: some Encodable, zeit: Date, id: String = UUID().uuidString) -> Op {
        Op(id: id, art: art, von: .testA, zeit: zeit, d: (try? JSONEncoder().encode(d)) ?? Data())
    }

    private func sessions(_ ops: [Op]) -> [GymSession] {
        var f = TrainingFaltung()
        for o in ops { f.anwenden(o) }
        return f.sessions(.testA)
    }

    // MARK: - Bedienung (WorkoutBedienungTests)

    func testCopyInsertsBelowWithoutTicksAndKeepsTypeAndValues() {
        var erster = PlanSatz(wdh: 8, kg: 60, failure: false, typ: "d", rpe: 9)
        erster.ok = true
        erster.sek = 40
        erster.pause = 90
        let zweiter = PlanSatz(wdh: 6, kg: 70, failure: true)
        let neu = WorkoutLogik.kopieren([erster, zweiter], 0)
        XCTAssertEqual(neu.count, 3)
        XCTAssertEqual(neu[1], PlanSatz(wdh: 8, kg: 60, failure: false, typ: "d"))
        XCTAssertNil(neu[1].ok)
        XCTAssertEqual(neu[2], zweiter)
        XCTAssertEqual(WorkoutLogik.kopieren([zweiter], 5), [zweiter])
    }

    func testEffortBandsFollowRirAndRpeIsTenMinusRir() {
        XCTAssertEqual(Anstrengung.allCases.map(\.rpe), [10, 9.5, 9, 8, 7, 6])
        for stufe in Anstrengung.allCases {
            XCTAssertEqual(Anstrengung.stufe(rpe: stufe.rpe), stufe)
        }
        XCTAssertEqual(Anstrengung.stufe(rpe: 8.5), .zweiNoch)
        XCTAssertEqual(Anstrengung.stufe(rpe: 10), .versagen)
        XCTAssertEqual(Anstrengung.stufe(rpe: 3), .leicht)
        XCTAssertEqual(Anstrengung.leicht.rirText, "4+")
        XCTAssertEqual(Anstrengung.fastVersagen.rirText, "0,5")
    }

    func testRestTargetStepsByFifteenAndNeverDropsBelowFifteen() {
        XCTAssertEqual(WorkoutLogik.pauseZiel(120, um: 15), 135)
        XCTAssertEqual(WorkoutLogik.pauseZiel(120, um: -15), 105)
        XCTAssertEqual(WorkoutLogik.pauseZiel(20, um: -15), 15)
    }

    // MARK: - Satzzeilen, Vorher, nächster Satz (TrainingTests)

    func testWorkoutRowsPreviousExtrasAndNext() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [
            uebung("a", saetze: [satz(10, 50), satz(10, 50)]),
            uebung("b", saetze: [satz(12, 20)]),
        ])
        let alt1 = satz(10, 55, ok: true), alt2 = satz(9, 55, ok: true)
        let frueher = sessions([
            op("gym.checkin", GymD(session: "alt", tag: "t", start: t0 - 86400), zeit: t0 - 86400),
            op("gym.uebung", GymD(session: "alt", plan: "a", uebung: "xa", status: "satz", saetze: [alt1, alt2]), zeit: t0 - 86000),
        ])
        let neu = satz(10, 57.5, ok: true)
        let jetzt = sessions([
            op("gym.checkin", GymD(session: "s", tag: "t", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "xa", status: "satz", saetze: [neu, satz(9, 55)]), zeit: t0 + 60),
            op("gym.uebung", GymD(session: "s", plan: "z", uebung: "eigen", status: "satz", saetze: [satz(10, nil)], name: "Dips"), zeit: t0 + 90),
        ])[0]
        let liste = WorkoutLogik.uebungen(jetzt, tag: tag, frueher: frueher)
        XCTAssertEqual(liste.map(\.id), ["a", "b", "z"])
        XCTAssertEqual(liste[0].vorher, [alt1, alt2])
        XCTAssertEqual(liste[0].fertigZahl, 1)
        XCTAssertEqual(liste[1].saetze, [satz(12, 20)]) // nie gemacht: Planwerte
        XCTAssertTrue(liste[2].extra)
        XCTAssertEqual(liste[2].planUebung.anzeigeName, "Dips")
        XCTAssertEqual(WorkoutLogik.dran(liste)?.uebung, 0)
        XCTAssertEqual(WorkoutLogik.dran(liste)?.satz, 1)
        XCTAssertEqual(WorkoutLogik.volumen(liste), 575)
        XCTAssertEqual(WorkoutLogik.saetzeZahl(liste), 1)
        // Noch nichts getippt: die Planzeilen mit den Werten vom letzten Mal.
        let frisch = WorkoutLogik.uebungen(GymSession(id: "n", tag: "t", start: t0, ende: nil, laeufe: []), tag: tag, frueher: frueher)
        XCTAssertEqual(frisch[0].saetze, [satz(10, 55), satz(9, 55)])
    }

    func testPlanQuestionOnlyOnStructureAndCalculators() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [uebung("a", saetze: [satz(10, 50), satz(10, 50)])])
        var liste = WorkoutLogik.uebungen(leereSession(), tag: tag, frueher: [])
        liste[0].saetze[0].kg = 60
        XCTAssertNil(WorkoutLogik.neuerTag(tag, liste)) // nur das Gewicht ist anders: keine Frage
        liste[0].saetze.append(satz(8, 60))
        XCTAssertEqual(WorkoutLogik.neuerTag(tag, liste)?.uebungen[0].saetze.count, 3)

        XCTAssertEqual(WorkoutLogik.scheiben(kg: 80), [25, 5])
        XCTAssertEqual(WorkoutLogik.scheiben(kg: 20), [])
        let warm = WorkoutLogik.aufwaermen(arbeit: 60)
        XCTAssertEqual(warm.map(\.kg), [25, 35, 47.5])
        XCTAssertEqual(warm.map(\.kuerzel), ["W", "W", "W"])
        let saetze = [warm[0], satz(10, 60), satz(8, 60, failure: true)]
        XCTAssertEqual([0, 1, 2].map { WorkoutLogik.nummer(saetze, $0) }, ["W", "1", "F"])
        XCTAssertEqual(WorkoutLogik.satzText(satz(12, 32)), "32 kg × 12")
        XCTAssertEqual(WorkoutLogik.zeitText(118), "1:58")
    }

    // MARK: - Lücken (GymLueckenTests)

    func testSkippedExerciseIsNotActiveAndDranMovesOn() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [
            uebung("a", saetze: [satz(10, 50), satz(10, 50)]),
            uebung("b", saetze: [satz(12, 20)]),
        ])
        let s = sessions([
            op("gym.checkin", GymD(session: "s", tag: "t", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "xa", status: "satz", saetze: []), zeit: t0 + 60),
        ])[0]
        XCTAssertNil(s.aktiv) // ausgelassen: die Figur zeigt sie nicht als laufende Übung
        XCTAssertFalse(s.erledigt("a"))
        let liste = WorkoutLogik.uebungen(s, tag: tag, frueher: [])
        XCTAssertTrue(liste[0].ausgelassen)
        XCTAssertFalse(liste[1].ausgelassen)
        XCTAssertEqual(WorkoutLogik.dran(liste)?.uebung, 1)
        // "weg" nimmt die Übung wieder auf: frische Zeilen aus dem Plan.
        let wieder = sessions([
            op("gym.checkin", GymD(session: "s", tag: "t", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "xa", status: "satz", saetze: []), zeit: t0 + 60),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "xa", status: "weg"), zeit: t0 + 120),
        ])[0]
        let neu = WorkoutLogik.uebungen(wieder, tag: tag, frueher: [])
        XCTAssertFalse(neu[0].ausgelassen)
        XCTAssertEqual(neu[0].saetze.count, 2)
        XCTAssertEqual(WorkoutLogik.dran(neu)?.uebung, 0)
    }

    func testSkippedCardioDranMovesOn() {
        let tag = TrainingsTag(id: "t", name: "Cardio", wochentage: [], uebungen: [uebung("c", minuten: 20), uebung("b", saetze: [satz(12, 20)])])
        let s = sessions([
            op("gym.checkin", GymD(session: "s", tag: "t", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "c", uebung: "xc", status: "satz", saetze: []), zeit: t0 + 60),
        ])[0]
        let liste = WorkoutLogik.uebungen(s, tag: tag, frueher: [])
        XCTAssertTrue(liste[0].ausgelassen)
        XCTAssertEqual(WorkoutLogik.dran(liste)?.uebung, 1)
    }

    func testPlanQuestionKeepsPlanSetsOfSkippedExercise() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [
            uebung("a", saetze: [satz(10, 50), satz(10, 50)]),
            uebung("b", saetze: [satz(12, 20)]),
        ])
        var liste = WorkoutLogik.uebungen(leereSession(), tag: tag, frueher: [])
        liste[0].saetze = []
        liste[0].ausgelassen = true
        XCTAssertNil(WorkoutLogik.neuerTag(tag, liste)) // nichts anderes geändert: keine Frage
        liste[1].saetze.append(satz(10, 20))
        let neu = WorkoutLogik.neuerTag(tag, liste)
        XCTAssertEqual(neu?.uebungen[0].saetze.count, 2) // der Plan behält die Sätze der ausgelassenen Übung
        XCTAssertEqual(neu?.uebungen[1].saetze.count, 2)
    }

    func testFreeTrainingBecomesFlexibleDayKeepingExerciseIds() {
        let gemacht = WorkoutUebung(planUebung: uebung("a"), saetze: [satz(10, 50, ok: true), satz(8, 50)], vorher: [], extra: true)
        let offen = WorkoutUebung(planUebung: uebung("b"), saetze: [satz(10, 20)], vorher: [], extra: true)
        let tag = WorkoutLogik.alsTag([gemacht, offen], name: "  Freitag  ", id: "neu")
        XCTAssertEqual(tag?.id, "neu")
        XCTAssertEqual(tag?.name, "Freitag")
        XCTAssertEqual(tag?.wochentage, []) // flexibel: an jedem Tag trainierbar
        XCTAssertEqual(tag?.uebungen.map(\.id), ["a"]) // gleiche id: Vorher und Rekorde bleiben verbunden
        XCTAssertEqual(tag?.uebungen[0].saetze.count, 2)
        XCTAssertEqual(tag?.uebungen[0].saetze.allSatisfy { $0.ok == nil }, true) // wie im Plan, ohne Haken
        XCTAssertNil(WorkoutLogik.alsTag([offen], name: "Leer")) // nichts abgehakt: nichts zu speichern
        XCTAssertEqual(WorkoutLogik.alsTag([gemacht], name: " ")?.name, "Freies Training")
    }

    func testManualTickInFinishedSessionHasNoTimes() {
        var fertig = satz(10, 50, ok: true)
        fertig.sek = 40
        fertig.pause = 90
        let saetze = [fertig, satz(8, 50)]
        let weg = WorkoutLogik.hakenNachtrag(saetze, 0)
        XCTAssertNil(weg[0].ok)
        XCTAssertNil(weg[0].sek) // der Haken weg: auch die Zeiten weg, wie beim Training
        XCTAssertNil(weg[0].pause)
        let da = WorkoutLogik.hakenNachtrag(saetze, 1)
        XCTAssertEqual(da[1].ok, true)
        XCTAssertNil(da[1].sek) // von Hand: es gibt keine gemessene Zeit
        XCTAssertTrue(da[1].zaehlt)
        XCTAssertEqual(WorkoutLogik.hakenNachtrag(saetze, 5), saetze) // Index außerhalb: nichts ändert sich
    }

    func testDayCanOnlyBeSwitchedBeforeAnySetIsTicked() {
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [uebung("a", saetze: [satz(10, 50), satz(10, 50)])])
        var liste = WorkoutLogik.uebungen(leereSession(), tag: tag, frueher: [])
        XCTAssertTrue(WorkoutLogik.tagWechselbar(liste))
        liste[0].saetze[0].ok = true
        XCTAssertFalse(WorkoutLogik.tagWechselbar(liste))
    }

    func testSwitchingDayTakesOutOnlyRunsOfTheOldDay() {
        let alt = TrainingsTag(id: "t", name: "Push", wochentage: [], uebungen: [uebung("a"), uebung("b")])
        let s = leereSession(laeufe: [
            UebungsLauf(plan: "a", uebung: "xa", start: t0, ende: nil, fertig: false, saetze: nil),
            UebungsLauf(plan: "z", uebung: "eigen", start: t0, ende: nil, fertig: false, saetze: nil, name: "Dips"),
        ])
        XCTAssertEqual(WorkoutLogik.laeufeDesTages(s, alt).map(\.plan), ["a"])
        XCTAssertTrue(WorkoutLogik.laeufeDesTages(s, nil).isEmpty)
    }

    // MARK: - Satz-Zeit (SatzzeitTests, ohne UserDefaults: der Schalter ist ein Parameter)

    func testZeitenTextZeigtSatzzeitNurMitSchalter() {
        XCTAssertEqual(WorkoutLogik.zeitenText(sek: 42, pause: 118, satzzeit: false), "Pause 1:58")
        XCTAssertNil(WorkoutLogik.zeitenText(sek: 42, pause: nil, satzzeit: false))
        XCTAssertEqual(WorkoutLogik.zeitenText(sek: 42, pause: 118, satzzeit: true), "Satz 0:42 · Pause 1:58")
        XCTAssertEqual(WorkoutLogik.zeitenText(sek: 42, pause: nil, satzzeit: true), "Satz 0:42")
    }

    func testGespeicherteWerteBleibenUnveraendert() {
        var s = satz(8, nil)
        s.sek = 30
        _ = WorkoutLogik.zeitenText(sek: s.sek, pause: s.pause, satzzeit: false)
        XCTAssertEqual(s.sek, 30)
    }

    func testPauseTextUndAufwaermsaetzeZaehlenNichtFuerVolumen() {
        XCTAssertEqual(WorkoutLogik.pauseText(0), "aus")
        XCTAssertEqual(WorkoutLogik.pauseText(120), "2:00")
        var warm = satz(10, 100, ok: true)
        warm.typ = "w"
        let liste = [WorkoutUebung(planUebung: uebung("a"), saetze: [warm, satz(5, 60, ok: true)], vorher: [], extra: false)]
        XCTAssertEqual(WorkoutLogik.volumen(liste), 300) // nur 5 × 60, der Aufwärmsatz zählt nicht
    }
}
