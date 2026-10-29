import XCTest
@testable import LumenFit

/// Idee 28: Supersätze (Kopplung `supersatz` an `PlanUebung`).
final class SupersatzTests: XCTestCase {
    private func uebung(_ id: String, saetze: Int = 2, supersatz: Bool? = nil, cardio: Bool = false) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: id,
                   saetze: cardio ? [] : Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: saetze),
                   minuten: cardio ? 20 : nil, supersatz: supersatz)
    }

    private func workout(_ uebungen: [PlanUebung]) -> [WorkoutUebung] {
        uebungen.map { WorkoutUebung(planUebung: $0, saetze: $0.saetze, vorher: [], extra: false) }
    }

    func testBloeckeBildenPaareVonVorn() {
        XCTAssertEqual(SupersatzLogik.bloecke([uebung("a", supersatz: true), uebung("b"), uebung("c")]), [[0, 1], [2]])
        XCTAssertEqual(SupersatzLogik.bloecke([uebung("a", supersatz: true), uebung("b", supersatz: true), uebung("c")]), [[0, 1], [2]])
        XCTAssertEqual(SupersatzLogik.bloecke([uebung("a"), uebung("b")]), [[0], [1]])
        XCTAssertEqual(SupersatzLogik.bloecke([]), [])
    }

    func testCardioUndLetzteUebungBildenNieEinPaar() {
        XCTAssertEqual(SupersatzLogik.bloecke([uebung("a", supersatz: true), uebung("c", cardio: true)]), [[0], [1]])
        XCTAssertEqual(SupersatzLogik.bloecke([uebung("c", supersatz: true, cardio: true), uebung("b")]), [[0], [1]])
        XCTAssertEqual(SupersatzLogik.bloecke([uebung("a"), uebung("b", supersatz: true)]), [[0], [1]])
    }

    func testKoppelnUndLoesen() {
        let liste = [uebung("a"), uebung("b"), uebung("c", cardio: true)]
        XCTAssertEqual(SupersatzLogik.koppeln(liste, 0, an: true)[0].supersatz, true)
        XCTAssertNil(SupersatzLogik.koppeln(SupersatzLogik.koppeln(liste, 0, an: true), 0, an: false)[0].supersatz)
        XCTAssertNil(SupersatzLogik.koppeln(liste, 1, an: true)[1].supersatz, "vor Cardio geht es nicht")
        XCTAssertNil(SupersatzLogik.koppeln(liste, 2, an: true)[2].supersatz, "die letzte Übung hat keinen Partner")
        XCTAssertEqual(SupersatzLogik.koppeln(liste, 9, an: true), liste)
    }

    func testPaarSucheLiefertDenBlock() {
        let liste = [uebung("a", supersatz: true), uebung("b"), uebung("c")]
        XCTAssertEqual(SupersatzLogik.paar(1, in: liste), [0, 1])
        XCTAssertEqual(SupersatzLogik.paar(2, in: liste), [2])
    }

    func testDranWechseltImPaarAb() {
        var liste = workout([uebung("a", supersatz: true), uebung("b"), uebung("c")])
        XCTAssertEqual(SupersatzLogik.dran(liste)?.uebung, 0)
        XCTAssertEqual(SupersatzLogik.dran(liste)?.satz, 0)
        liste[0].saetze[0].ok = true // A Satz 1 fertig: jetzt B
        XCTAssertEqual(SupersatzLogik.dran(liste)?.uebung, 1)
        XCTAssertEqual(SupersatzLogik.dran(liste)?.satz, 0)
        liste[1].saetze[0].ok = true // B Satz 1 fertig: wieder A, Satz 2
        XCTAssertEqual(SupersatzLogik.dran(liste)?.uebung, 0)
        XCTAssertEqual(SupersatzLogik.dran(liste)?.satz, 1)
        // Zum Vergleich: ohne Supersatz bliebe `WorkoutLogik.dran` bei A.
        XCTAssertEqual(WorkoutLogik.dran(liste)?.uebung, 0)
    }

    func testDranGehtWeiterWennEineUebungDesPaaresFertigOderAusgelassenIst() {
        var liste = workout([uebung("a", saetze: 3, supersatz: true), uebung("b", saetze: 1), uebung("c")])
        liste[0].saetze[0].ok = true
        liste[1].saetze[0].ok = true // B ist fertig
        liste[0].saetze[1].ok = true
        XCTAssertEqual(SupersatzLogik.dran(liste)?.uebung, 0, "A hat noch Sätze übrig")
        XCTAssertEqual(SupersatzLogik.dran(liste)?.satz, 2)
        liste[0].saetze[2].ok = true
        XCTAssertEqual(SupersatzLogik.dran(liste)?.uebung, 2) // Paar fertig: weiter mit C
        liste[2].ausgelassen = true
        XCTAssertNil(SupersatzLogik.dran(liste))
    }

    func testDranOhneSupersatzGleichWorkoutLogik() {
        var liste = workout([uebung("a"), uebung("b")])
        liste[0].saetze[0].ok = true
        XCTAssertEqual(SupersatzLogik.dran(liste)?.uebung, WorkoutLogik.dran(liste)?.uebung)
        XCTAssertEqual(SupersatzLogik.dran(liste)?.satz, WorkoutLogik.dran(liste)?.satz)
    }
}
