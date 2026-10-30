import XCTest
@testable import LumenFit

/// Geräte-Einstellungen (Datei im Profilordner) und die "So geht's"-Hinweise.
@MainActor
final class GeraeteEinstellungTests: XCTestCase {
    func testSetzenSichertImProfilordnerUndLeerLoescht() throws {
        let ordner = try tempOrdner()
        let s = GeraeteStore(ordner: ordner)
        s.setzen(GeraeteWerte(stufe: " 4 ", sitz: "", polster: nil, notiz: "Sitz ganz hoch"), studio: "Studio A", uebung: "x")
        let neu = GeraeteStore(ordner: ordner)
        XCTAssertEqual(neu.werte(studio: "studio a", uebung: "x")?.stufe, "4")
        XCTAssertNil(neu.werte(studio: "studio a", uebung: "x")?.sitz)
        XCTAssertNil(neu.werte(studio: "Studio B", uebung: "x"))
        s.setzen(GeraeteWerte(stufe: "  "), studio: "Studio A", uebung: "x")
        XCTAssertNil(GeraeteStore(ordner: ordner).werte(studio: "Studio A", uebung: "x"))
    }

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
