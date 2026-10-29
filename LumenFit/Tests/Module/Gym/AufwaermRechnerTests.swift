import XCTest
@testable import LumenFit

/// Idee 25: Aufwärmsätze in Prozent vom Arbeitsgewicht.
final class AufwaermRechnerTests: XCTestCase {
    func testStandardstufenAufZweiEinhalbGerundet() {
        // 60 kg: 40 % = 24 -> 25, 60 % = 36 -> 35, 80 % = 48 -> 47,5
        let s = AufwaermRechner.saetze(arbeit: 60)
        XCTAssertEqual(s.map(\.kg), [25, 35, 47.5])
        XCTAssertEqual(s.map(\.wdh), [10, 5, 3])
        XCTAssertTrue(s.allSatisfy { $0.typ == "w" })
    }

    func testNieUnterZweiEinhalbUndOhneGewichtKeineSaetze() {
        XCTAssertEqual(AufwaermRechner.saetze(arbeit: 2.5).map(\.kg), [2.5, 2.5, 2.5])
        XCTAssertTrue(AufwaermRechner.saetze(arbeit: 0).isEmpty)
    }

    func testEigeneStufen() {
        let s = AufwaermRechner.saetze(arbeit: 100, stufen: [.init(prozent: 50, wdh: 8)])
        XCTAssertEqual(s.map(\.kg), [50])
        XCTAssertEqual(s.map(\.wdh), [8])
    }

    func testAufwaermsaetzeZaehlenNichtFuerVolumenUndRekorde() {
        var s = AufwaermRechner.saetze(arbeit: 100)
        for i in s.indices { s[i].ok = true }
        XCTAssertTrue(s.allSatisfy { !$0.zaehlt }) // `PlanSatz.zaehlt`: Aufwärmen nie
        let uebung = WorkoutUebung(planUebung: PlanUebung(id: "a", uebung: "x", name: "A", saetze: s, minuten: nil), saetze: s, vorher: [], extra: false)
        XCTAssertEqual(WorkoutLogik.volumen([uebung]), 0)
        XCTAssertEqual(RekordLogik.anzahl([uebung], frueher: []), 0)
    }

    func testEinfuegenVorDenArbeitssaetzenUndErsetztOffeneAufwaermsaetze() {
        let arbeit = [PlanSatz(wdh: 8, kg: 60, failure: false), PlanSatz(wdh: 8, kg: 60, failure: false)]
        let eins = AufwaermRechner.einfuegen(in: arbeit, arbeit: 60)
        XCTAssertEqual(eins.map(\.typ), ["w", "w", "w", nil, nil])
        let nochmal = AufwaermRechner.einfuegen(in: eins, arbeit: 80)
        XCTAssertEqual(nochmal.count, 5) // ersetzt, nicht verdoppelt
        XCTAssertEqual(nochmal[0].kg, 32.5) // 40 % von 80 = 32
        // Ist ein Aufwärmsatz schon abgehakt, bleibt alles wie es ist.
        var haken = eins
        haken[0].ok = true
        XCTAssertEqual(AufwaermRechner.einfuegen(in: haken, arbeit: 80), haken)
        XCTAssertEqual(AufwaermRechner.einfuegen(in: arbeit, arbeit: 0), arbeit)
    }

    func testZeile() {
        XCTAssertEqual(AufwaermRechner.zeile(PlanSatz(wdh: 10, kg: 25, failure: false, typ: "w"), prozent: 40), "40 % × 10: 25 kg")
    }
}
