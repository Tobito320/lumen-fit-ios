import XCTest
@testable import LumenFit

/// Das Blatt "Messung erfassen": leere Felder bleiben unberührt, Tippfehler werden nicht gespeichert.
final class MessErfassungTests: XCTestCase {
    func testLeereFelderBleibenUnberuehrt() {
        let e = MessErfassung.pruefe([.gewicht: "78,4", .taille: "", .brust: "  "])
        XCTAssertEqual(e.gueltig, [MessWert(art: .gewicht, zehntel: 784)])
        XCTAssertTrue(e.ungueltig.isEmpty)
    }

    func testKommaUndPunktUndMehrereWerteProTag() {
        let e = MessErfassung.pruefe([.gewicht: "78.4", .taille: "82,5", .koerperfett: "18"])
        XCTAssertEqual(e.gueltig.map(\.art), [.gewicht, .koerperfett, .taille])
        XCTAssertEqual(e.gueltig.map(\.zehntel), [784, 180, 825])
    }

    func testTippfehlerUndTextWerdenAbgelehnt() {
        let e = MessErfassung.pruefe([.gewicht: "7,8", .taille: "abc", .koerperfett: "80", .bizeps: "7840", .brust: "100"])
        XCTAssertTrue(e.gueltig.contains(MessWert(art: .brust, zehntel: 1000)))
        XCTAssertEqual(Set(e.ungueltig), [.gewicht, .taille, .koerperfett, .bizeps])
    }

    func testGrenzenSindEingeschlossen() {
        XCTAssertEqual(MessErfassung.pruefe([.gewicht: "30"]).gueltig.count, 1)
        XCTAssertEqual(MessErfassung.pruefe([.gewicht: "249,9"]).gueltig.count, 1)
        XCTAssertEqual(MessErfassung.pruefe([.gewicht: "250"]).ungueltig, [.gewicht])
    }

    func testAenderungGegenDenVorherigenWert() {
        let punkte = [MessPunkt(tag: "2026-09-28", zehntel: 790), MessPunkt(tag: "2026-10-05", zehntel: 786)]
        XCTAssertEqual(MessErfassung.aenderung(punkte, art: .gewicht), "-0,4 kg seit 28.09.")
        XCTAssertEqual(MessErfassung.aenderung([MessPunkt(tag: "2026-09-28", zehntel: 825), MessPunkt(tag: "2026-10-05", zehntel: 840)], art: .taille), "+1,5 cm seit 28.09.")
        XCTAssertNil(MessErfassung.aenderung([punkte[0]], art: .gewicht))
        XCTAssertNil(MessErfassung.aenderung([], art: .gewicht))
    }
}
