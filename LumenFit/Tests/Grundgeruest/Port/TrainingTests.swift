// Quelle: Lovea Tests/TrainingTests.swift
import XCTest
@testable import LumenFit

final class TrainingTests: XCTestCase {
    /// Wednesday 23.09.2026, 18:00 Berlin.
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func op(_ art: String, _ d: some Encodable, zeit: Date, von: ProfilID = .testA, id: String = UUID().uuidString) -> Op {
        Op(id: id, art: art, von: von, zeit: zeit, d: try! JSONEncoder().encode(d))
    }

    private func satz(_ wdh: Int, _ kg: Double?, failure: Bool = false) -> PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: failure) }

    private func planUebung(_ id: String, minuten: Int? = nil, saetze: [PlanSatz] = []) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: "Übung \(id)", saetze: saetze, minuten: minuten)
    }

    private func faltung(_ ops: [Op]) -> TrainingFaltung {
        var f = TrainingFaltung()
        for o in ops { f.anwenden(o) }
        return f
    }

    func testSameOpTwiceCountsOnce() {
        let checkin = op("gym.checkin", GymD(session: "s", tag: "push", start: t0), zeit: t0, id: "c1")
        let start = op("gym.uebung", GymD(session: "s", plan: "p1", uebung: "EIeI8Vf", status: "start"), zeit: t0 + 60, id: "u1")
        let confirmed = start // dieselbe Op ein zweites Mal (Wiedereinspielung)
        let sessions = faltung([checkin, start, confirmed]).sessions(.testA)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].laeufe.count, 1)
        XCTAssertEqual(sessions[0].aktiv?.uebung, "EIeI8Vf")
        XCTAssertEqual(sessions[0].tag, "push")
    }

    func testStartingAnotherEndsThePreviousWithoutTicking() {
        let s = faltung([
            op("gym.checkin", GymD(session: "s", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "start"), zeit: t0 + 60),
            op("gym.uebung", GymD(session: "s", plan: "b", uebung: "B", status: "start"), zeit: t0 + 600),
        ]).sessions(.testA)[0]
        XCTAssertEqual(s.laeufe.count, 2)
        XCTAssertEqual(s.laeufe[0].ende, t0 + 600)
        XCTAssertFalse(s.laeufe[0].fertig)
        XCTAssertEqual(s.aktiv?.plan, "b")
        XCTAssertFalse(s.erledigt("a"))
    }

    func testFinishWithSetsTickWithoutStartAndUndo() {
        let saetze = [satz(10, 60), satz(8, 62.5)]
        let s = faltung([
            op("gym.checkin", GymD(session: "s", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "start"), zeit: t0 + 60),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "fertig", saetze: saetze), zeit: t0 + 400),
            op("gym.uebung", GymD(session: "s", plan: "b", uebung: "B", status: "fertig"), zeit: t0 + 500),
            op("gym.uebung", GymD(session: "s", plan: "b", uebung: "B", status: "offen"), zeit: t0 + 510),
        ]).sessions(.testA)[0]
        XCTAssertTrue(s.erledigt("a"))
        XCTAssertEqual(s.laeufe[0].dauer, 340)
        XCTAssertEqual(s.laeufe[0].saetze, saetze)
        XCTAssertNil(s.laeufe[1].start)
        XCTAssertFalse(s.erledigt("b"))
        XCTAssertNil(s.aktiv)
    }

    func testCorrectedTimesNewestWinsAndDeletedIsGone() {
        let f = faltung([
            op("gym.checkin", GymD(session: "s", tag: "push", start: t0), zeit: t0),
            op("gym.checkout", GymD(session: "s", ende: t0 + 5 * 3600), zeit: t0 + 5 * 3600),
            op("gym.checkin", GymD(session: "s", tag: "push", start: t0 - 1800), zeit: t0 + 6 * 3600),
            op("gym.checkout", GymD(session: "s", ende: t0 + 5400), zeit: t0 + 6 * 3600 + 1),
            op("gym.checkin", GymD(session: "weg", start: t0 + 86400), zeit: t0 + 86400),
            op("gym.loeschen", GymD(session: "weg"), zeit: t0 + 86500),
        ])
        let sessions = f.sessions(.testA)
        XCTAssertEqual(sessions.map(\.id), ["s"])
        XCTAssertEqual(sessions[0].start, t0 - 1800)
        XCTAssertEqual(sessions[0].ende, t0 + 5400)
        XCTAssertTrue(f.sessions(.testB).isEmpty)
    }

    func testAuscheckenRueckgaengig() {
        let checkin = op("gym.checkin", GymD(session: "s", tag: "push", start: t0), zeit: t0, id: "c1")
        let raus = op("gym.checkout", GymD(session: "s", ende: t0 + 3600), zeit: t0 + 3600, id: "o1")
        let zurueck = op("gym.checkout", GymD(session: "s", status: "wieder"), zeit: t0 + 3700, id: "o2")
        XCTAssertNil(faltung([checkin, raus, zurueck]).sessions(.testA)[0].ende, "Rückgängig: läuft wieder")
        let nochmal = op("gym.checkout", GymD(session: "s", ende: t0 + 5400), zeit: t0 + 5400, id: "o3")
        XCTAssertEqual(faltung([checkin, raus, zurueck, nochmal]).sessions(.testA)[0].ende, t0 + 5400)
    }

    func testFortsetzbarNurFrischBeendetUndNeueste() {
        let fertig = GymSession(id: "s", tag: nil, start: t0, ende: t0 + 3240, laeufe: [])
        XCTAssertEqual(TrainingLogik.fortsetzbar([fertig], jetzt: t0 + 3300)?.id, "s", "gerade beendet")
        XCTAssertNil(TrainingLogik.fortsetzbar([fertig], jetzt: t0 + 3 * 3600), "danach nicht mehr laufend (langNach)")
        let kurz = GymSession(id: "k", tag: nil, start: t0, ende: t0 + 600, laeufe: [])
        XCTAssertNil(TrainingLogik.fortsetzbar([kurz], jetzt: t0 + 600 + 2 * 3600), "vor über 2 h beendet")
        let offen = GymSession(id: "o", tag: nil, start: t0, ende: nil, laeufe: [])
        XCTAssertNil(TrainingLogik.fortsetzbar([offen], jetzt: t0 + 60), "läuft noch")
        let neu = GymSession(id: "n", tag: nil, start: t0 + 3300, ende: nil, laeufe: [])
        XCTAssertNil(TrainingLogik.fortsetzbar([fertig, neu], jetzt: t0 + 3400), "eine neuere Einheit läuft schon")
        XCTAssertNil(TrainingLogik.fortsetzbar([], jetzt: t0))
    }

    func testRunningAndForgotten() {
        let s = GymSession(id: "s", tag: nil, start: t0, ende: nil, laeufe: [])
        XCTAssertTrue(TrainingLogik.laufend(s, jetzt: t0 + 2 * 3600))
        XCTAssertNil(TrainingLogik.vergessen([s], jetzt: t0 + 2 * 3600))
        XCTAssertFalse(TrainingLogik.laufend(s, jetzt: t0 + 3.5 * 3600))
        XCTAssertEqual(TrainingLogik.vergessen([s], jetzt: t0 + 3.5 * 3600)?.id, "s")
        XCTAssertEqual(TrainingLogik.vergessen([s], jetzt: t0 + 26 * 3600)?.id, "s")   // Thursday 20:00
        XCTAssertNil(TrainingLogik.vergessen([s], jetzt: t0 + 40 * 3600))              // Friday 10:00
        var fertig = s
        fertig.ende = t0 + 3600
        XCTAssertFalse(TrainingLogik.laufend(fertig, jetzt: t0 + 1800 + 3600))
        XCTAssertNil(TrainingLogik.vergessen([fertig], jetzt: t0 + 4 * 3600))
        XCTAssertTrue(TrainingLogik.zuLang(start: t0, ende: t0 + 3 * 3600 + 60))
        XCTAssertFalse(TrainingLogik.zuLang(start: t0, ende: t0 + 2 * 3600))
    }

    func testNewestPlanWins() {
        let neu = TrainingsPlan(tage: [TrainingsTag(id: "t", name: "Push", wochentage: [1], uebungen: [])])
        let f = faltung([
            op("gym.plan", neu, zeit: t0 + 100),
            op("gym.plan", TrainingsPlan.leer, zeit: t0),
            op("gym.plan", TrainingsPlan.leer, zeit: t0 + 50, von: .testB),
        ])
        XCTAssertEqual(f.plaene[.testA], neu)
        XCTAssertEqual(f.plaene[.testB], .leer)
    }

    func testDayForDateNextAndWeekdaysMoveBetweenDays() {
        let push = TrainingsTag(id: "push", name: "Push", wochentage: [1, 3], uebungen: [planUebung("a"), planUebung("b")])
        let beine = TrainingsTag(id: "beine", name: "Beine", wochentage: [2], uebungen: [])
        let plan = TrainingsPlan(tage: [push, beine])
        XCTAssertEqual(TrainingLogik.tag(plan, datum: "2026-09-23")?.id, "push")   // Mittwoch
        XCTAssertEqual(TrainingLogik.tag(plan, datum: "2026-09-22")?.id, "beine")  // Dienstag
        XCTAssertNil(TrainingLogik.tag(plan, datum: "2026-09-24"))                 // Donnerstag: Ruhetag

        var s = GymSession(id: "s", tag: "push", start: t0, ende: nil, laeufe: [])
        XCTAssertEqual(TrainingLogik.naechste(push, s)?.id, "a")
        s.laeufe = [UebungsLauf(plan: "a", uebung: "xa", start: nil, ende: t0, fertig: true, saetze: nil)]
        XCTAssertEqual(TrainingLogik.naechste(push, s)?.id, "b")

        var beineNeu = beine
        beineNeu.wochentage = [2, 3]
        let neu = TrainingLogik.tagSetzen(plan, beineNeu)
        XCTAssertEqual(neu.tage.first { $0.id == "push" }?.wochentage, [1])
        XCTAssertEqual(neu.tage.first { $0.id == "beine" }?.wochentage, [2, 3])
        let mitNeuemTag = TrainingLogik.tagSetzen(plan, TrainingsTag(id: "pull", name: "Pull", wochentage: [5], uebungen: []))
        XCTAssertEqual(mitNeuemTag.tage.map(\.id), ["push", "beine", "pull"])
    }

    func testFinishedSetsBecomePlanValues() {
        let plan = TrainingsPlan(tage: [TrainingsTag(id: "t", name: "Push", wochentage: [1], uebungen: [planUebung("a", saetze: [satz(10, 60)])])])
        let neu = TrainingLogik.uebernehmen(plan, planUebung: "a", saetze: [satz(10, 62.5), satz(8, 62.5, failure: true)])
        XCTAssertEqual(neu.tage[0].uebungen[0].saetze, [satz(10, 62.5), satz(8, 62.5, failure: true)])
        XCTAssertEqual(TrainingLogik.uebernehmen(plan, planUebung: "zz", saetze: []), plan)
    }

    func testTexts() {
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", saetze: [satz(10, 60), satz(10, 60), satz(10, 60)])), "3 × 10 · 60 kg")
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", saetze: [satz(12, 40), satz(10, 45), satz(8, 50, failure: true)])), "3 Sätze · 40–50 kg · F")
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", saetze: [satz(15, nil)])), "1 × 15")
        XCTAssertEqual(TrainingLogik.saetzeText(planUebung("a", minuten: 20)), "20 min")
        XCTAssertEqual(TrainingLogik.kgText(62.5), "62,5")
        XCTAssertEqual(TrainingLogik.dauerText(3900), "1:05 h")
        XCTAssertEqual(TrainingLogik.dauerText(2520), "42 min")
        XCTAssertEqual(TrainingLogik.wochentageText([5, 1, 3]), "Mo, Mi, Fr")
        XCTAssertEqual(TrainingLogik.wochentageText([]), "kein Tag")
        XCTAssertEqual(TrainingLogik.tagText(t0, jetzt: t0 + 3600), "heute")
        XCTAssertEqual(TrainingLogik.tagText(t0, jetzt: t0 + 20 * 3600), "gestern")
    }

    func testCardioDeviceAndNewPlanEntries() {
        let laufband = Uebung(id: "l", name: "Gehen auf dem Laufband", en: "walking on incline treadmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Körpergewicht", neben: [])
        let stepper = Uebung(id: "s", name: "Gehen am Stepper", en: "walking on stepmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Stepper", neben: [])
        let bank = Uebung(id: "b", name: "Bankdrücken mit Langhantel", en: "barbell bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
        XCTAssertEqual(TrainingLogik.cardioGeraet(laufband), "laufband")
        XCTAssertEqual(TrainingLogik.cardioGeraet(stepper), "stairmaster")
        XCTAssertNil(TrainingLogik.cardioGeraet(bank))
        XCTAssertEqual(PlanUebung.neu(laufband).minuten, 20)
        XCTAssertTrue(PlanUebung.neu(laufband).saetze.isEmpty)
        XCTAssertEqual(PlanUebung.neu(bank).saetze.count, 3)
        XCTAssertEqual(PlanUebung.eigene("Kabelturm").anzeigeName, "Kabelturm")
    }

    func testGymPayloadDecodesWithMissingAndUnknownFields() throws {
        let d = try JSONDecoder().decode(GymD.self, from: Data(#"{"session":"s","neu":"egal"}"#.utf8))
        XCTAssertEqual(d, GymD(session: "s"))
    }

    // MARK: - Wie Hevy: Satzzeilen

    func testWeekStreak() {
        func s(_ tag: String) -> GymSession { GymSession(id: tag, tag: nil, start: Datum.datum(tag).addingTimeInterval(18 * 3600), ende: nil, laeufe: []) }
        // 23.09.2026 ist ein Mittwoch. Trainings in den drei Wochen davor, diese Woche noch keins.
        let liste = [s("2026-09-01"), s("2026-09-08"), s("2026-09-10"), s("2026-09-15")]
        XCTAssertEqual(TrainingLogik.serieWochen(liste, heute: "2026-09-23"), 3)
        XCTAssertEqual(TrainingLogik.dieseWoche(liste, heute: "2026-09-23"), 0)
        XCTAssertEqual(TrainingLogik.serieWochen(liste + [s("2026-09-22")], heute: "2026-09-23"), 4)
        XCTAssertEqual(TrainingLogik.dieseWoche(liste + [s("2026-09-21"), s("2026-09-22")], heute: "2026-09-23"), 2)
        XCTAssertEqual(TrainingLogik.serieWochen([s("2026-09-01")], heute: "2026-09-23"), 0) // Lücke
        XCTAssertEqual(TrainingLogik.serieWochen([], heute: "2026-09-23"), 0)
    }

    /// Der Status "ende" (Mitteilung an den Partner) ändert nichts am Falten: die Einheit ist beendet.
    func testCheckoutWithEndStatusStillEndsTheSession() {
        let s = faltung([
            op("gym.checkin", GymD(session: "s", start: t0), zeit: t0),
            op("gym.checkout", GymD(session: "s", ende: t0 + 3480, status: "ende", minuten: 58, zahl: 12), zeit: t0 + 3480),
        ]).sessions(.testA)[0]
        XCTAssertEqual(s.ende, t0 + 3480)
        XCTAssertNil(s.kcal)
        // Mit Messung stehen Kalorien und Puls an der Einheit.
        let mit = faltung([
            op("gym.checkin", GymD(session: "s", start: t0), zeit: t0),
            op("gym.checkout", GymD(session: "s", ende: t0 + 3480, status: "ende", kcal: 310, puls: 118), zeit: t0 + 3480),
        ]).sessions(.testA)[0]
        XCTAssertEqual(mit.kcal, 310)
        XCTAssertEqual(mit.puls, 118)
    }

    /// Pläne und Ops aus älteren Builds haben die neuen Felder nicht und müssen weiter lesbar sein.
    func testOldSetAndPlanJsonStillDecode() throws {
        let s = try JSONDecoder().decode(PlanSatz.self, from: Data(#"{"wdh":8,"kg":60,"failure":true}"#.utf8))
        XCTAssertEqual(s, satz(8, 60, failure: true))
        XCTAssertEqual(s.kuerzel, "F")
        let u = try JSONDecoder().decode(PlanUebung.self, from: Data(#"{"id":"a","uebung":"eigen","name":"X","saetze":[]}"#.utf8))
        XCTAssertNil(u.pause)
        XCTAssertNil(u.notiz)
    }

    func testSetStateCountsTickedSetsWithoutWarmup() {
        var warm = satz(10, 20)
        warm.typ = "w"
        warm.ok = true
        var a = satz(10, 60)
        a.ok = true
        let b = satz(8, 60)
        let ops = [
            op("gym.checkin", GymD(session: "s", start: t0), zeit: t0),
            op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "satz", saetze: [warm, a, b]), zeit: t0 + 60),
        ]
        let lauf = faltung(ops).sessions(.testA)[0].laeufe[0]
        XCTAssertEqual(lauf.stand?.count, 3)
        XCTAssertEqual(lauf.saetze, [a])
        XCTAssertTrue(lauf.fertig)
        XCTAssertNil(lauf.ende)
        // Der neueste Stand gilt; alle abgehakt beendet die Übung.
        var b2 = b
        b2.ok = true
        let spaeter = op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "satz", saetze: [warm, a, b2]), zeit: t0 + 120)
        let s2 = faltung(ops + [spaeter]).sessions(.testA)[0]
        XCTAssertEqual(s2.laeufe.count, 1)
        XCTAssertEqual(s2.laeufe[0].saetze?.count, 2)
        XCTAssertEqual(s2.laeufe[0].ende, t0 + 120)
        // "weg" nimmt die Übung wieder heraus.
        let weg = op("gym.uebung", GymD(session: "s", plan: "a", uebung: "A", status: "weg"), zeit: t0 + 180)
        XCTAssertTrue(faltung(ops + [spaeter, weg]).sessions(.testA)[0].laeufe.isEmpty)
    }

}
