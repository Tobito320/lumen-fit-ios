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
}
