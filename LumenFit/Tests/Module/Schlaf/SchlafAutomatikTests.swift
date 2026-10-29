import XCTest
@testable import LumenFit

/// Aus Lovea `SchlafAutomatikTests`: das Schlafziel mit flexiblen Tagen und der Vorrang der Quellen (Band vor Uhr vor Handy, dort Armband vor Watch).
/// Nicht mitgenommen sind die Tests zum Punktesystem (Bewegung, Handy aus, Wecker aus) und zum eigenen Eintrag: beides bleibt in Lovea,
/// Lumen Fit schätzt keinen Schlaf aus Signalen und kennt keinen handgeschriebenen Schlaf.
final class SchlafAutomatikTests: XCTestCase {
    // MARK: - Schlafziel mit flexiblen Tagen

    func testSchlafZielAnFlexiblenTagen() {
        let extraTage = (1 << 5) | (1 << 6) // Samstag (Bit 5) + Sonntag (Bit 6)
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: 60, extraTage: extraTage, wochentag: 6), 540, "Samstag")
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: 60, extraTage: extraTage, wochentag: 1), 480, "Montag ohne Extra")
        XCTAssertEqual(SchlafLogik.ziel(basis: 480, extraMinuten: -600, extraTage: extraTage, wochentag: 7), 0, "nie unter 0")
    }

    func testExtraTageAlsBitmaskeMontagBisSonntag() {
        XCTAssertTrue(SchlafLogik.istExtraTag(1, 1), "Montag ist Bit 0")
        XCTAssertTrue(SchlafLogik.istExtraTag(1 << 6, 7), "Sonntag ist Bit 6")
        XCTAssertFalse(SchlafLogik.istExtraTag(0, 3))
    }

    // MARK: - Vorrang der Quellen

    func testBandGewinntVorUhrUndHandy() {
        let uhr = SchlafTestBau.nacht("2026-09-23", minuten: 400, phasen: true)
        let b = BandSchlafOp(tag: "2026-09-23", start: uhr.von, ende: uhr.bis.addingTimeInterval(1800), phasen: uhr.abschnitte)
        let liste = SchlafQuellenWahl.waehle(health: [uhr.tag: uhr], band: [b])
        XCTAssertEqual(liste.first?.quelle, .band)
        XCTAssertEqual(SchlafQuellenWahl.waehle(health: [uhr.tag: uhr], band: []).first?.quelle, .uhr, "ohne Band bleibt alles wie vorher")
    }

    func testQuellenNamenSindStabil() {
        XCTAssertEqual(SchlafQuelle.band.rawValue, "band")
        XCTAssertEqual(SchlafQuelle.uhr.rawValue, "uhr")
        XCTAssertEqual(SchlafQuelle.handy.rawValue, "handy")
        XCTAssertEqual(SchlafQuelle.allCases.map(\.name), ["Uhr", "Handy", "Band"])
    }

    func testUnterDreiStundenIstKeineNacht() {
        XCTAssertEqual(SchlafLogik.mindestNacht, 180)
    }
}
