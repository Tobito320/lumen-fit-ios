import XCTest
@testable import LumenFit

/// Defekt-Notizen: Alter, "Noch defekt?" nach 30 Tagen, alte Dateien lesbar, Zurück zu Original.
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
