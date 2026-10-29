import XCTest
@testable import LumenFit

/// Kraftkurve (Idee 31): bestes Gewicht, 1RM nach Epley und Volumen je Woche; Aufwärmsätze zählen nie.
final class KraftKurveTests: XCTestCase {
    /// Mittwoch 14.10.2026; die Woche beginnt am 12.10.
    private let heute = "2026-10-14"
    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
    private let laufband = Uebung(id: "band", name: "Laufband", en: "treadmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Maschine", neben: [])

    private func katalog(_ id: String) -> Uebung? { [bank.id: bank, laufband.id: laufband][id] }

    private func satz(_ kg: Double, _ wdh: Int, typ: String? = nil) -> PlanSatz {
        PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ)
    }

    private func einheit(_ id: String, _ tag: String, _ saetze: [PlanSatz], uebung: String = "bank", fertig: Bool = true) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let lauf = UebungsLauf(plan: "p", uebung: uebung, start: start, ende: start.addingTimeInterval(1200), fertig: fertig, saetze: saetze)
        return GymSession(id: id, tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: [lauf])
    }

    func testEinPunktJeWocheMitBestemGewichtUndVolumen() {
        let s = [
            einheit("a", "2026-10-05", [satz(60, 8), satz(65, 5)]),
            einheit("b", "2026-10-07", [satz(60, 10)]),       // gleiche Woche wie a
            einheit("c", "2026-10-13", [satz(70, 5)]),
        ]
        let p = KraftKurve.punkte(s, uebung: "bank", heute: heute)
        XCTAssertEqual(p.map(\.woche), ["2026-10-05", "2026-10-12"])
        XCTAssertEqual(p[0].gewicht, 65)
        XCTAssertEqual(p[0].volumen, 60 * 8 + 65 * 5 + 60 * 10)
        XCTAssertEqual(p[1].gewicht, 70)
    }

    func testEinerMaximumNachEpley() {
        let p = KraftKurve.punkte([einheit("a", "2026-10-13", [satz(60, 10), satz(100, 1)])], uebung: "bank", heute: heute)
        // 60 x 10 = 60 * (1 + 10/30) = 80; ein Wiederholung ist das Gewicht selbst = 100.
        XCTAssertEqual(p.first?.e1rm ?? 0, 100, accuracy: 0.001)
        let q = KraftKurve.punkte([einheit("b", "2026-10-13", [satz(60, 10)])], uebung: "bank", heute: heute)
        XCTAssertEqual(q.first?.e1rm ?? 0, 80, accuracy: 0.001)
    }

    func testAufwaermsaetzeZaehlenNicht() {
        let p = KraftKurve.punkte([einheit("a", "2026-10-13", [satz(100, 5, typ: "w"), satz(60, 8)])], uebung: "bank", heute: heute)
        XCTAssertEqual(p.first?.gewicht, 60)
        XCTAssertEqual(p.first?.volumen, 480)
        XCTAssertTrue(KraftKurve.punkte([einheit("b", "2026-10-13", [satz(40, 10, typ: "w")])], uebung: "bank", heute: heute).isEmpty)
    }

    func testOffeneLaeufeUndSaetzeOhneGewichtGebenKeinenPunkt() {
        XCTAssertTrue(KraftKurve.punkte([einheit("a", "2026-10-13", [satz(60, 8)], fertig: false)], uebung: "bank", heute: heute).isEmpty)
        let ohne = PlanSatz(wdh: 12, kg: nil, failure: false)
        XCTAssertTrue(KraftKurve.punkte([einheit("b", "2026-10-13", [ohne])], uebung: "bank", heute: heute).isEmpty)
    }

    func testNurDieWochenImFensterUndNurDieUebung() {
        let s = [einheit("alt", "2026-06-01", [satz(50, 8)]), einheit("neu", "2026-10-13", [satz(60, 8)]),
                 einheit("anders", "2026-10-13", [satz(30, 8)], uebung: "kurz")]
        let p = KraftKurve.punkte(s, uebung: "bank", heute: heute, wochen: 12)
        XCTAssertEqual(p.map(\.gewicht), [60], "die Woche im Juni liegt außerhalb der 12 Wochen")
        XCTAssertEqual(KraftKurve.punkte(s, uebung: "bank", heute: heute, wochen: 40).map(\.gewicht), [50, 60])
    }

    func testAussageNenntGewichtUndUnterschied() {
        let p = [KraftPunkt(woche: "2026-09-07", gewicht: 60, e1rm: 76, volumen: 1000), KraftPunkt(woche: "2026-10-12", gewicht: 70, e1rm: 90, volumen: 1200)]
        XCTAssertEqual(KraftKurve.aussage(name: "Bankdrücken", p), "Bankdrücken: 70 kg, plus 10")
        XCTAssertEqual(KraftKurve.aussage(name: "Bankdrücken", p.reversed()), "Bankdrücken: 60 kg, minus 10")
        XCTAssertEqual(KraftKurve.aussage(name: "Bankdrücken", [p[0], KraftPunkt(woche: "2026-10-12", gewicht: 60, e1rm: 70, volumen: 10)]), "Bankdrücken: 60 kg, unverändert")
        XCTAssertEqual(KraftKurve.aussage(name: "Bankdrücken", [p[1]]), "Bankdrücken: 70 kg")
        XCTAssertEqual(KraftKurve.aussage(name: "Kniebeuge", []), "Kniebeuge: noch keine Sätze mit Gewicht")
        XCTAssertEqual(KraftKurve.aussage(name: "Curl", [KraftPunkt(woche: "2026-10-12", gewicht: 12.5, e1rm: 15, volumen: 100), KraftPunkt(woche: "2026-10-19", gewicht: 15, e1rm: 18, volumen: 100)]), "Curl: 15 kg, plus 2,5")
    }

    func testKernzeileNenntAlleDreiWerte() {
        let z = KraftKurve.kernzeile([KraftPunkt(woche: "2026-10-12", gewicht: 70, e1rm: 90.4, volumen: 3200)])
        XCTAssertEqual(z, "Letzte Woche mit Training: bestes Gewicht 70 kg, 1RM 90 kg, Volumen 3.200 kg")
        XCTAssertTrue(KraftKurve.kernzeile([]).contains("Sätze mit Gewicht"))
    }

    func testUebungenSortiertNachHaeufigkeitOhneCardio() {
        let s = [einheit("a", "2026-10-05", [satz(60, 8)]), einheit("b", "2026-10-07", [satz(60, 8)]),
                 einheit("c", "2026-10-13", [satz(5, 8)], uebung: "band"), einheit("d", "2026-10-13", [satz(5, 8)], uebung: "unbekannt")]
        let u = KraftKurve.uebungen(s, katalog: katalog)
        XCTAssertEqual(u.map(\.id), ["bank"], "Cardio und Übungen außerhalb des Katalogs fehlen")
        XCTAssertEqual(u.first?.einheiten, 2)
        XCTAssertEqual(u.first?.name, "Bankdrücken")
    }
}
