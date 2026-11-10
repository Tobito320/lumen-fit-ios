// Quelle: Lovea Tests/ZeitSchaetzungTests.swift
import XCTest
@testable import LumenFit

/// Zeitschätzung je Trainingstag (10 min Aufwärmen + 3,5 min je Satz, Cardio extra), Kurzversion, Warnung über dem Studio-Slot, 45-Minuten-Pläne.
final class ZeitSchaetzungTests: XCTestCase {
    private func uebung(_ name: String, saetze: Int = 3, pause: Int? = nil, supersatz: Bool? = nil) -> PlanUebung {
        PlanUebung(id: name, uebung: "EIeI8Vf", name: name,
                   saetze: Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: saetze),
                   minuten: nil, pause: pause, supersatz: supersatz)
    }

    private func tag(_ uebungen: [PlanUebung]) -> TrainingsTag {
        TrainingsTag(id: "t", name: "Test", wochentage: [1], uebungen: uebungen)
    }

    private func namen(_ n: Int, saetze: Int = 3) -> [PlanUebung] {
        (0..<n).map { uebung(String(Character(UnicodeScalar(UInt8(65 + $0)))), saetze: saetze) }
    }

    func testLeererTagIstNullMinutenOhneWarnung() {
        XCTAssertEqual(ZeitSchaetzung.minuten(tag([])), 0)
        let u = ZeitSchaetzung.urteil(tag([]), slotMinuten: 45)
        XCTAssertEqual(u.minuten, 0)
        XCTAssertFalse(u.warnt)
        XCTAssertNil(u.tipp)
    }

    func testZehnMinutenAufwaermenPlusDreiEinhalbJeSatzAufFuenfGerundet() {
        // 10 min + 3 × 3,5 min = 20,5 min
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag(namen(1))), 600 + 3 * 210)
        XCTAssertEqual(ZeitSchaetzung.minuten(tag(namen(1))), 20)
        // 10 + 15 × 3,5 = 62,5 -> 65; 10 + 18 × 3,5 = 73 -> 75; 10 + 12 × 3,5 = 52 -> 50
        XCTAssertEqual(ZeitSchaetzung.minuten(tag(namen(5))), 65)
        XCTAssertEqual(ZeitSchaetzung.minuten(tag(namen(6))), 75)
        XCTAssertEqual(ZeitSchaetzung.minuten(tag(namen(4))), 50)
    }

    func testPauseImPlanStecktInDenDreiEinhalbMinuten() {
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", pause: 60)])), 600 + 3 * 210)
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", pause: 0)])), 600 + 3 * 210)
    }

    func testCardioZaehltNachPlanMinutenExtra() {
        let cardio = PlanUebung(id: "c", uebung: "j9Q5crt", name: nil, saetze: [], minuten: 20)
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([cardio])), 20 * 60, "Cardio allein braucht kein Aufwärmen")
        XCTAssertEqual(ZeitSchaetzung.minuten(tag([uebung("A"), cardio])), 40) // 20,5 + 20 = 40,5 -> 40
    }

    func testSupersatzTeiltSichDiePause() {
        // Paar: je Runde ein Satz (3,5 min) plus die zweite Übung ohne eigene Pause (1 min)
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", supersatz: true), uebung("B")])), 600 + 3 * 270)
        XCTAssertLessThan(ZeitSchaetzung.sekunden(tag([uebung("A", supersatz: true), uebung("B")])),
                          ZeitSchaetzung.sekunden(tag([uebung("A"), uebung("B")])))
        let mitPaar = tag([uebung("A", supersatz: true), uebung("B"), uebung("C"), uebung("D"), uebung("E")])
        XCTAssertEqual(ZeitSchaetzung.sekunden(mitPaar), 600 + 3 * 270 + 9 * 210)
        XCTAssertEqual(ZeitSchaetzung.minuten(mitPaar), 55)
    }

    func testSupersatzAnLetzterUebungOderCardioWirdIgnoriert() {
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", supersatz: true)])), 600 + 3 * 210)
        let cardio = PlanUebung(id: "c", uebung: "j9Q5crt", name: nil, saetze: [], minuten: 10)
        XCTAssertEqual(ZeitSchaetzung.sekunden(tag([uebung("A", supersatz: true), cardio])), 600 + 3 * 210 + 600)
    }

    func testWarnungErstUeberDerGrenze() {
        let fuenf = tag(namen(5))
        XCTAssertFalse(ZeitSchaetzung.urteil(fuenf, slotMinuten: 65).warnt, "genau 65 von 65 passt")
        let knapp = ZeitSchaetzung.urteil(fuenf, slotMinuten: 60)
        XCTAssertTrue(knapp.warnt)
        XCTAssertEqual(knapp.ueber, 5)
        XCTAssertEqual(knapp.titel, "ca. 65 min, 5 min über deinem Slot (60 min)")
        XCTAssertEqual(ZeitSchaetzung.urteil(fuenf, slotMinuten: 75).titel, "ca. 65 min, passt in deinen Slot (75 min)")
    }

    func testTippSupersatzWennEinPaarReicht() {
        // 6 × 3 Sätze = 75 min, Slot 70: ein Paar spart 3 × 2,5 min und reicht (65 min)
        let u = ZeitSchaetzung.urteil(tag(namen(6)), slotMinuten: 70)
        XCTAssertEqual(u.minuten, 75)
        XCTAssertEqual(u.tipp, .supersatz(erste: "A", zweite: "B", spart: 10))
        XCTAssertEqual(u.tipp?.text, "Tipp: A und B als Supersatz, spart ca. 10 min.")
    }

    func testTippStreichenWennKeinPaarReicht() {
        // 7 × 4 Sätze = 108 -> 110 min, Slot 90: ein Paar reicht nicht (100), die letzten zwei fallen weg (80)
        let u = ZeitSchaetzung.urteil(tag(namen(7, saetze: 4)), slotMinuten: 90)
        XCTAssertEqual(u.minuten, 110)
        XCTAssertEqual(u.titel, "ca. 110 min, 20 min über deinem Slot (90 min)")
        XCTAssertEqual(u.tipp, .streichen(namen: ["F", "G"], spart: 30))
        XCTAssertEqual(u.tipp?.text, "Tipp: F, G weglassen, spart ca. 30 min.")
    }

    func testKeinTippUnterDerGrenze() {
        XCTAssertNil(ZeitSchaetzung.urteil(tag(namen(5)), slotMinuten: 75).tipp)
    }

    func testOhneSlotKeineWarnung() {
        let u = ZeitSchaetzung.urteil(tag(namen(7, saetze: 4)), slotMinuten: nil)
        XCTAssertFalse(u.warnt)
        XCTAssertNil(u.tipp)
        XCTAssertEqual(u.titel, "ca. 110 min")
        XCTAssertFalse(ZeitSchaetzung.urteil(tag(namen(7, saetze: 4)), slotMinuten: 0).warnt)
    }

    func testSaetzeInMinutenIstDieUmkehrung() {
        XCTAssertEqual(ZeitSchaetzung.saetze(inMinuten: 45), 10) // 10 + 10 × 3,5 = 45
        XCTAssertEqual(ZeitSchaetzung.saetze(inMinuten: 30), 5)
        XCTAssertEqual(ZeitSchaetzung.saetze(inMinuten: 10), 0)
        XCTAssertEqual(ZeitSchaetzung.saetze(inMinuten: 5), 0)
    }

    func testKurzversionNimmtDieErstenUebungenBisDreissigMinuten() {
        let k = ZeitSchaetzung.kurzversion(tag(namen(5)))
        XCTAssertEqual(k.uebungen.map(\.id), ["A", "B"], "6 Sätze: 10 + 21 = 31 -> 30 min")
        XCTAssertEqual(ZeitSchaetzung.minuten(k), 30)
        XCTAssertEqual(k.id, "t")
        XCTAssertEqual(k.name, "Test")
    }

    func testKurzversionBehaeltMindestensEineUebungUndPaare() {
        XCTAssertEqual(ZeitSchaetzung.kurzversion(tag([uebung("A", saetze: 8), uebung("B")])).uebungen.map(\.id), ["A"])
        let paar = tag([uebung("A", supersatz: true), uebung("B"), uebung("C")])
        XCTAssertEqual(ZeitSchaetzung.kurzversion(paar).uebungen.map(\.id), ["A", "B"], "Paar bleibt zusammen (25 min), C wäre 35")
        XCTAssertEqual(ZeitSchaetzung.kurzversion(tag([])).uebungen, [])
        let kurz = tag(namen(1))
        XCTAssertEqual(ZeitSchaetzung.kurzversion(kurz), kurz)
    }

    func testSlotNurMitFesterUhrzeit() {
        XCTAssertEqual(ZeitSchaetzung.slot(StudioProfil(name: "Testhalle", slotStart: 5 * 60, dauer: 45)), 45)
        XCTAssertNil(ZeitSchaetzung.slot(.standard)) // ohne feste Uhrzeit gibt es nichts zu überschreiten
        XCTAssertEqual(ZeitSchaetzung.slot(StudioProfil(name: "Testhalle", slotStart: 18 * 60, dauer: 60)), 60)
        XCTAssertNil(ZeitSchaetzung.slot(StudioProfil(name: "Testhalle", slotStart: 300, dauer: 0)))
    }

    func testSupersatzBleibtImPlanDerVorlage() {
        let v = SplitVorlage(id: "x", name: "X", gruppe: "m", level: "mittel", ziel: "muskeln", geraet: "studio", tage: 1, einheiten: [
            .init(name: "A", wochentage: [1], uebungen: [.init(uebung: "EIeI8Vf", saetze: 3, von: 8, bis: 12, supersatz: true), .init(uebung: "qXTaZnJ", saetze: 3, von: 8, bis: 12)]),
        ])
        let plan = SplitLogik.alsPlan(v)
        XCTAssertEqual(plan.tage[0].uebungen.map(\.supersatz), [true, nil])
    }

    func testKurzplaeneSindDa() {
        XCTAssertEqual(SplitLogik.treffer(SplitLogik.fuer(.maennlich), art: SplitLogik.kurzArt, tage: nil, suche: "").count, 3)
        XCTAssertGreaterThanOrEqual(SplitLogik.treffer(SplitLogik.fuer(.weiblich), art: SplitLogik.kurzArt, tage: nil, suche: "").count, 1)
        XCTAssertFalse(SplitLogik.fuer(.maennlich).filter(SplitLogik.istKurzplan).contains(where: SplitLogik.istEigen), "Für dich bleibt bei den 15 Eigenen")
    }

    func testKurzplaeneSparenMitSupersaetzen() {
        // Mit 10 min + 3,5 min je Satz passt kein Kurzplan mehr in 45 min (Meldung an finalizer); Supersätze sparen weiter.
        let kurz = SplitKatalog.alle.filter(SplitLogik.istKurzplan)
        XCTAssertFalse(kurz.isEmpty)
        for v in kurz {
            let plan = SplitLogik.alsPlan(v)
            XCTAssertFalse(plan.tage.isEmpty, v.id)
            for t in plan.tage {
                var ohnePaare = t
                ohnePaare.uebungen = t.uebungen.map { var u = $0; u.supersatz = nil; return u }
                XCTAssertLessThan(ZeitSchaetzung.sekunden(t), ZeitSchaetzung.sekunden(ohnePaare), "\(v.id) \(t.name)")
                XCTAssertGreaterThanOrEqual(ZeitSchaetzung.minuten(t), 30, "\(v.id) \(t.name): zu kurz für einen Slot")
                XCTAssertTrue(t.uebungen.contains { $0.supersatz == true }, "\(v.id) \(t.name): ohne Supersatz")
            }
        }
        let fuenf = SplitKatalog.alle.first { $0.id == "m-kurz45-3" }
        XCTAssertEqual(fuenf?.einheiten.map(\.uebungen.count), [5, 5, 5], "Kurzplan mit fünf Übungen")
    }

    func testUmfangNutztDieSchaetzung() {
        let t = tag([uebung("A", saetze: 4), PlanUebung(id: "b", uebung: "rjiM4L3", name: nil, saetze: [], minuten: 20)])
        XCTAssertEqual(ZeitSchaetzung.umfang(t), "2 Übungen · etwa 45 min") // 10 + 14 + 20 = 44 -> 45
    }
}
