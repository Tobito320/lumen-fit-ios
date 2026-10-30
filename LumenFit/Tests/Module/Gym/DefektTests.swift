import XCTest
@testable import LumenFit

/// Defekt-Notizen: Alter, "Noch defekt?" nach 30 Tagen, je Studio, Datei im Profilordner, Zurück zu Original.
@MainActor
final class DefektTests: XCTestCase {
    func testAlterUndText() {
        let n = DefektNotiz(gemeldetAm: "2026-10-10")
        XCTAssertEqual(DefektLogik.alterText(n, heute: "2026-10-10"), "heute")
        XCTAssertEqual(DefektLogik.alterText(n, heute: "2026-10-11"), "gestern")
        XCTAssertEqual(DefektLogik.alterText(n, heute: "2026-10-13"), "vor 3 Tagen")
        XCTAssertFalse(DefektLogik.veraltet(n, heute: "2026-11-09"))
        XCTAssertTrue(DefektLogik.veraltet(n, heute: "2026-11-10"))
    }

    func testMeldenErledigenBestaetigenUndJeStudio() throws {
        let ordner = try tempOrdner()
        let s = DefektStore(ordner: ordner)
        s.melden(text: "  wackelt  ", studio: "Studio A", uebung: "x", am: "2026-10-01")
        XCTAssertEqual(s.offen(studio: "studio a ", uebung: "x")?.text, "wackelt") // Schreibweise egal
        XCTAssertNil(s.offen(studio: "Studio B", uebung: "x"))
        s.bestaetigen(studio: "Studio A", uebung: "x", am: "2026-11-15")
        XCTAssertEqual(s.offen(studio: "Studio A", uebung: "x")?.gemeldetAm, "2026-11-15")
        s.erledigen(studio: "Studio A", uebung: "x", am: "2026-11-16")
        XCTAssertNil(s.offen(studio: "Studio A", uebung: "x"))
    }

    func testDieNotizenUeberlebenEinenNeustartUndLeererTextIstOhneText() throws {
        let ordner = try tempOrdner()
        DefektStore(ordner: ordner).melden(text: "   ", studio: "", uebung: "y", am: "2026-10-01")
        let neu = DefektStore(ordner: ordner)
        XCTAssertNotNil(neu.offen(studio: "", uebung: "y"))
        XCTAssertNil(neu.offen(studio: "", uebung: "y")?.text)
    }

    func testAlteDateiOhneFelderIstLesbar() throws {
        let d = try JSONDecoder().decode(DefektNotiz.self, from: Data("{}".utf8))
        XCTAssertTrue(d.istOffen)
        XCTAssertEqual(DefektLogik.alter(d, heute: "2026-10-01"), 0)
    }

    func testZurueckZumOriginalLoeschtDenErsatzVermerk() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner(), healthSchreiben: false)
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        let original = AusweichLogik.original(a.sitzung.liste[0])
        guard let alt = AusweichLogik.alternativen(fuer: UebungsKatalog.nachId[original]!).first else { return XCTFail("keine Alternative") }
        a.sitzung.ausweichen(0, zu: alt)
        XCTAssertEqual(a.sitzung.liste[0].ersatzFuer, original)
        a.sitzung.ausweichen(0, zu: UebungsKatalog.nachId[original]!)
        XCTAssertNil(a.sitzung.liste[0].ersatzFuer)
        XCTAssertEqual(a.sitzung.liste[0].planUebung.uebung, original)
    }
}
