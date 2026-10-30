import XCTest
@testable import LumenFit

/// Plan-Editor in der Tiefe: Doppeln, Satz für Satz, von Tag kopieren, Variante.
final class PlanEditorTiefeTests: XCTestCase {
    private func tag(_ id: String, _ namen: [String]) -> TrainingsTag {
        TrainingsTag(id: id, name: id, wochentage: [], uebungen: namen.map {
            PlanUebung(id: $0, uebung: PlanUebung.eigen, name: $0, saetze: [PlanSatz(wdh: 10, kg: 20, failure: false), PlanSatz(wdh: 8, kg: 25, failure: false)], minuten: nil)
        })
    }

    func testDuplizierenSetztDieKopieDahinterMitNeuerIdOhneKopplung() {
        var t = tag("a", ["u1", "u2"])
        t.uebungen[0].supersatz = true
        let neu = PlanEditor.duplizieren(t, id: "u1", neueId: { "k" })
        XCTAssertEqual(neu.uebungen.map(\.id), ["u1", "k", "u2"])
        XCTAssertNil(neu.uebungen[0].supersatz)
        XCTAssertEqual(neu.uebungen[1].saetze, t.uebungen[0].saetze)
        XCTAssertEqual(PlanEditor.duplizieren(t, id: "weg"), t)
    }

    func testSatzAendernNurDiesenSatzMitGrenzen() {
        let u = tag("a", ["u1"]).uebungen[0]
        let a = PlanEditor.satzAendern(u, 1, wdh: 500, kg: .some(nil), versagen: true)
        XCTAssertEqual(a.saetze[0], u.saetze[0])
        XCTAssertEqual(a.saetze[1].wdh, 100)
        XCTAssertNil(a.saetze[1].kg)
        XCTAssertTrue(a.saetze[1].failure)
        XCTAssertEqual(PlanEditor.satzAendern(u, 1, kg: 30).saetze[1].kg, 30)
        XCTAssertEqual(PlanEditor.satzAendern(u, 1, wdh: 0).saetze[1].wdh, 1)
        XCTAssertEqual(PlanEditor.satzAendern(u, 9, wdh: 5), u)
    }

    func testVonTagKopierenHaengtAnMitNeuenIds() {
        var zaehler = 0
        let ziel = tag("z", ["z1"])
        let quelle = tag("q", ["q1", "q2"])
        let alle = PlanEditor.vonTagKopieren(ziel, quelle: quelle, neueId: { zaehler += 1; return "n\(zaehler)" })
        XCTAssertEqual(alle.uebungen.map(\.id), ["z1", "n1", "n2"])
        let eine = PlanEditor.vonTagKopieren(ziel, quelle: quelle, nur: ["q2"], neueId: { "x" })
        XCTAssertEqual(eine.uebungen.map(\.id), ["z1", "x"])
        XCTAssertEqual(eine.uebungen[1].name, "q2")
    }

    func testVarianteTauschtNurDieUebungUndBehaeltDieSaetze() throws {
        guard let k = UebungsKatalog.alle.first(where: { !$0.istCardio }) else { return XCTFail("kein Katalog") }
        let t = tag("a", ["u1"])
        let neu = PlanEditor.variante(t, id: "u1", zu: k)
        XCTAssertEqual(neu.uebungen[0].uebung, k.id)
        XCTAssertNil(neu.uebungen[0].name)
        XCTAssertEqual(neu.uebungen[0].saetze, t.uebungen[0].saetze)
        XCTAssertEqual(PlanEditor.variante(t, id: "weg", zu: k), t)
    }
}
