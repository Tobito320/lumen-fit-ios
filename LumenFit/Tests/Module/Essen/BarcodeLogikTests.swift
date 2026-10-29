// Quelle: Lovea Tests/BarcodeLogikTests.swift
import XCTest
@testable import LumenFit

final class BarcodeLogikTests: XCTestCase {
    private let skyr = Lebensmittel(id: "off-4311501679715", name: "Skyr", barcode: "4311501679715",
                                    pro100: Naehrwerte(kcal: 65, protein: 11, kohlenhydrate: 4, fett: 0.2))

    func testNormal() {
        XCTAssertEqual(BarcodeLogik.normal(" 4311501679715\n"), "4311501679715")
        XCTAssertEqual(BarcodeLogik.normal("012345678905"), "0012345678905")
        XCTAssertEqual(BarcodeLogik.normal("20123456"), "20123456")
    }

    func testIstBarcodeEingabe() {
        XCTAssertTrue(BarcodeLogik.istBarcodeEingabe("20123456")) // EAN-8
        XCTAssertTrue(BarcodeLogik.istBarcodeEingabe("012345678905")) // UPC-A
        XCTAssertTrue(BarcodeLogik.istBarcodeEingabe("4311501679715")) // EAN-13
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("2012345")) // zu kurz (7)
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("201234567")) // keine plausible Länge (9)
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("Skyr Natur")) // Text, keine Ziffern
        XCTAssertFalse(BarcodeLogik.istBarcodeEingabe("4311 501679715")) // Leerzeichen, kein reiner Ziffernstring
    }

    private func quellen(lokal: Lebensmittel? = nil, off: Result<Lebensmittel?, any Error & Sendable> = .success(nil),
                         aufrufe: EssenAufrufProtokoll = EssenAufrufProtokoll()) -> BarcodeQuellen {
        BarcodeQuellen(
            lokal: { _ in aufrufe.add("lokal"); return lokal },
            offLive: { _ in aufrufe.add("off"); return try off.get() })
    }

    func testReihenfolgeUndStopp() async {
        let p = EssenAufrufProtokoll()
        let r = await BarcodeKette.suchen("4311501679715", quellen(lokal: skyr, off: .success(nil), aufrufe: p))
        XCTAssertEqual(r, .gefunden(skyr))
        XCTAssertEqual(p.liste, ["lokal"], "Open Food Facts wird nicht gefragt, wenn der Speicher den Code kennt")
    }

    /// Lovea: Server aus, dann Open Food Facts. Hier gibt es keinen Server; der Fall ist "Speicher leer, Open Food Facts findet".
    func testSpeicherLeerDannOpenFoodFacts() async {
        let p = EssenAufrufProtokoll()
        let r = await BarcodeKette.suchen("4311501679715", quellen(off: .success(skyr), aufrufe: p))
        XCTAssertEqual(r, .gefunden(skyr))
        XCTAssertEqual(p.liste, ["lokal", "off"])
    }

    func testNichtsGefundenFuehrtZurEingabeVonHand() async {
        let r = await BarcodeKette.suchen("4311501679715", quellen())
        XCTAssertEqual(r, .unbekannt("4311501679715"))
    }

    func testKeinNetz() async {
        let r = await BarcodeKette.suchen("4311501679715", quellen(off: .failure(URLError(.notConnectedToInternet))))
        XCTAssertEqual(r, .offline("4311501679715"))
    }

    func testLimitUndServerfehlerSindNichtOffline() async {
        let limit = await BarcodeKette.suchen("4311501679715", quellen(off: .failure(OffFehler.limit(sekunden: 42))))
        XCTAssertEqual(limit, .limit("4311501679715", sekunden: 42))
        let fehler = await BarcodeKette.suchen("4311501679715", quellen(off: .failure(OffFehler.server(500))))
        XCTAssertEqual(fehler, .fehler("4311501679715"))
    }

    func testCodeWirdVorDerAbfrageNormalisiert() async {
        let gesehen = EssenAufrufProtokoll()
        let q = BarcodeQuellen(lokal: { code in gesehen.add(code); return nil }, offLive: { code in gesehen.add(code); return nil })
        _ = await BarcodeKette.suchen(" 012345678905\n", q)
        XCTAssertEqual(gesehen.liste, ["0012345678905", "0012345678905"])
    }
}

/// Sammelt Aufrufe aus `@Sendable`-Rückrufen.
final class EssenAufrufProtokoll: @unchecked Sendable { // @unchecked: alle Zugriffe laufen unter `sperre`
    private let sperre = NSLock()
    private var _liste: [String] = []
    var liste: [String] { sperre.withLock { _liste } }
    func add(_ s: String) { sperre.withLock { _liste.append(s) } }
}
