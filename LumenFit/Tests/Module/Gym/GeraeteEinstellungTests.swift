import XCTest
@testable import LumenFit

/// Geräte-Einstellungen (Schlüssel) und die "So geht's"-Hinweise.
@MainActor
final class GeraeteEinstellungTests: XCTestCase {
    func testEigeneUebungHatDenNamenAlsSchluessel() {
        var u = PlanUebung(id: "1", uebung: PlanUebung.eigen, name: "Mein Gerät", saetze: [], minuten: nil)
        XCTAssertEqual(GeraeteEinstellungDatei.uebungsSchluessel(u), "Mein Gerät")
        u.uebung = "abc"
        XCTAssertEqual(GeraeteEinstellungDatei.uebungsSchluessel(u), "abc")
    }

    func testHinweiseSindEingebettetUndDasSpeziellsteGewinnt() {
        XCTAssertFalse(EinstellHinweise.alle.isEmpty)
        let schraeg = EinstellHinweise.finden(name: "Schrägbankdrücken")
        let flach = EinstellHinweise.finden(name: "Bankdrücken")
        XCTAssertNotNil(schraeg)
        XCTAssertNotNil(flach)
        XCTAssertNotEqual(schraeg, flach)
        XCTAssertNil(EinstellHinweise.finden(name: "Qwertzuiop"))
    }

    func testKeinHinweisHatEinenStudioTipp() {
        // Die Studio-Tipps der Vorlage sind bewusst weggelassen: Studios stehen nicht im Quelltext.
        for h in EinstellHinweise.alle { XCTAssertFalse(h.anleitung.isEmpty || h.einstellung.isEmpty || h.fehler.isEmpty) }
    }
}
