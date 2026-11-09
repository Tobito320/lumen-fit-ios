import XCTest
@testable import LumenFit

/// `TrainingStore.sessions` merkt sich die abgeleiteten Einheiten bis zur nächsten gym-Op: dieselbe Antwort ohne Neuberechnung, eine frische nach jeder Op.
@MainActor
final class TrainingStoreMerkenTests: XCTestCase {
    func testSessionsFolgenJederGymOpUndBleibenSonstGleich() throws {
        let satz = DatenSatz(profil: .testA, ordner: try tempOrdner(), ereignisse: EreignisKanal(), uhr: { Date() })
        XCTAssertTrue(satz.training.sessions.isEmpty)
        let id = satz.training.einchecken(tag: nil)
        XCTAssertEqual(satz.training.sessions.map(\.id), [id], "die neue Op macht den gemerkten Stand ungültig")
        XCTAssertNil(satz.training.sessions.first?.ende)
        satz.training.auschecken(id)
        XCTAssertNotNil(satz.training.sessions.first?.ende)
        satz.raum.senden("fit.test", ["a": 1])   // eine fremde Op ändert an den Einheiten nichts
        XCTAssertEqual(satz.training.sessions.map(\.id), [id])
    }

    func testZweiOpsInDerselbenMillisekundeGiltDieSpaetere() throws {
        let uhr = Date(timeIntervalSince1970: 1_794_250_000)   // steht still: beide Ops bekommen dieselbe Zeit
        let satz = DatenSatz(profil: .testA, ordner: try tempOrdner(), ereignisse: EreignisKanal(), uhr: { uhr })
        let id = satz.training.einchecken(tag: nil)
        let u = PlanUebung(id: "a", uebung: "EIeI8Vf", name: nil, saetze: [PlanSatz(wdh: 8, kg: 60, failure: false)], minuten: nil)
        satz.training.saetzeSenden(id, u, [PlanSatz(wdh: 8, kg: 60, failure: false, ok: true)])
        satz.training.saetzeSenden(id, u, [PlanSatz(wdh: 6, kg: 65, failure: false, ok: true)])
        XCTAssertEqual(satz.training.sessions.first?.laeufe.first?.stand?.first?.kg, 65, "Reihenfolge des Eingangs entscheidet, nicht der Zufall")
        let neu = DatenSatz(profil: .testA, ordner: satz.ordner, ereignisse: EreignisKanal(), uhr: { uhr })
        XCTAssertEqual(neu.training.sessions.first?.laeufe.first?.stand?.first?.kg, 65, "auch nach dem Neuladen aus der Datei")
    }
}
