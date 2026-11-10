import XCTest
@testable import LumenFit

/// Alte und fremde Dateien der Foto-Aufträge müssen lesbar bleiben (Felder, die später dazukamen, fehlen).
final class AlteDateienLadenEssenKiTests: XCTestCase {
    private let id = "11111111-2222-3333-4444-555555555555"

    func testMinimalerAuftragNurMitPflichtfeldern() throws {
        let json = #"[{"id":"\#(id)","erstellt":0,"mahlzeit":"mittag","datum":"2026-10-10"}]"#
        let liste = try XCTUnwrap(EssenKiAuftragLogik.lesen(Data(json.utf8)))
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste[0].status, .laeuft)
        XCTAssertEqual(liste[0].hinweis, "")
        XCTAssertNil(liste[0].analyse)
        XCTAssertFalse(liste[0].autoNochmal)
        XCTAssertFalse(liste[0].wiederholt)
    }

    func testUnbekannteZusatzfelderStoeren_nicht() throws {
        let json = #"[{"id":"\#(id)","erstellt":0,"mahlzeit":"abend","datum":"2026-10-10","status":"fertig","zukunft":{"x":1}}]"#
        let liste = try XCTUnwrap(EssenKiAuftragLogik.lesen(Data(json.utf8)))
        XCTAssertEqual(liste.first?.status, .fertig)
        XCTAssertEqual(liste.first?.mahlzeit, .abend)
    }

    func testKaputteDateiIstNilStattLeereListe() {
        XCTAssertNil(EssenKiAuftragLogik.lesen(Data(#"[{"id":"nein"}]"#.utf8)))
        XCTAssertNil(EssenKiAuftragLogik.lesen(Data()))
    }
    // MARK: - Zustimmung zur Foto-Schätzung (zustimmung.json, neu am 10.11.2026)

    func testZustimmungFehltOderKaputtHeisstNichtErlaubt() {
        XCTAssertEqual(EssenKiZustimmung.lesen(nil), EssenKiZustimmung())
        XCTAssertFalse(EssenKiZustimmung.lesen(nil).erlaubt, "alte Installation ohne Datei: erst fragen")
        XCTAssertFalse(EssenKiZustimmung.lesen(Data("kaputt".utf8)).erlaubt)
        XCTAssertFalse(EssenKiZustimmung.lesen(Data("{}".utf8)).erlaubt)
        XCTAssertFalse(EssenKiZustimmung.lesen(Data(#"{"erlaubt":"ja"}"#.utf8)).erlaubt, "falscher Typ zählt nicht als Ja")
    }

    func testZustimmungOhneDatumUndMitUnbekanntenFeldern() throws {
        let z = EssenKiZustimmung.lesen(Data(#"{"erlaubt":true,"zukunft":{"x":1}}"#.utf8))
        XCTAssertTrue(z.erlaubt)
        XCTAssertNil(z.seit)
        let mitDatum = EssenKiZustimmung(erlaubt: true, seit: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertEqual(EssenKiZustimmung.lesen(try JSONEncoder().encode(mitDatum)), mitDatum)
    }
}
