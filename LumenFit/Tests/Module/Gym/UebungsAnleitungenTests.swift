import XCTest
@testable import LumenFit

/// Die Erklärungen gehören zu echten Katalog-Übungen und decken alle beliebten ab.
final class UebungsAnleitungenTests: XCTestCase {
    func testJedeErklaerungGehoertZuEinerKatalogUebungUndHatText() {
        for (id, a) in UebungsAnleitungen.alle {
            XCTAssertNotNil(UebungsKatalog.nachId[id], id)
            XCTAssertFalse(a.ablauf.isEmpty, id)
            XCTAssertFalse(a.fehler.isEmpty, id)
        }
    }

    func testAlleBeliebtenUebungenHabenEineErklaerung() {
        for id in UebungsKatalog.beliebt {
            XCTAssertNotNil(UebungsAnleitungen.finden(id), id)
        }
        XCTAssertNil(UebungsAnleitungen.finden("gibt-es-nicht"))
    }
}
