// Quelle: Lovea Tests/SuchZusammenfuehrungTests.swift
import XCTest
@testable import LumenFit

/// Zusammenführen lokaler und Server-Suche (keine Sprünge, alte Antworten verworfen) und `haeufig`.
final class SuchZusammenfuehrungTests: XCTestCase {
    private func l(_ id: String, barcode: String? = nil) -> Lebensmittel {
        Lebensmittel(id: id, name: id, barcode: barcode, pro100: Naehrwerte(kcal: 1, protein: 0, kohlenhydrate: 0, fett: 0))
    }

    private func op(_ art: String, _ von: ProfilID, _ wert: some Encodable, _ sek: Double) throws -> Op {
        Op(id: UUID().uuidString, art: art, von: von, zeit: Date(timeIntervalSince1970: sek), d: try JSONEncoder().encode(wert))
    }

    func testAlteAntwortWirdVerworfen() {
        let s = SuchStand(nummer: 5, lokal: [l("a")], server: [], sichtbar: [l("a")])
        XCTAssertEqual(SuchZusammenfuehrung.server(s, antwort: [l("x")], nummer: 4), s)
    }

    func testAnhaengenOhneDoppelteUndOhneSpringen() {
        let s = SuchStand(nummer: 1, lokal: [l("bls-1"), l("off-2", barcode: "2")], server: [], sichtbar: [l("bls-1"), l("off-2", barcode: "2")])
        let neu = SuchZusammenfuehrung.server(s, antwort: [l("off-2", barcode: "2"), l("off-3", barcode: "3")], nummer: 1)
        XCTAssertEqual(neu.sichtbar.map(\.id), ["bls-1", "off-2", "off-3"])
    }

    func testGleicherNameUndMarkeIstDoppeltAuchMitAnderemCode() {
        func p(_ id: String, _ name: String, _ marke: String?, _ code: String) -> Lebensmittel {
            Lebensmittel(id: id, name: name, marke: marke, barcode: code, pro100: .null)
        }
        let vorn = [Lebensmittel(id: "bls-1", name: "Skyr", pro100: .null), p("off-1", "Skyr Natur", "Arla", "1")]
        let s = SuchStand(nummer: 1, lokal: vorn, server: [], sichtbar: vorn)
        let antwort = [p("off-2", "Skyr", nil, "2"), p("off-3", "skyr  natur", "ARLA", "3"), p("off-4", "Skyr Natur", "Ehrmann", "4"), p("off-5", "Skyr Natur", "Ehrmann", "5")]
        let neu = SuchZusammenfuehrung.server(s, antwort: antwort, nummer: 1)
        XCTAssertEqual(neu.sichtbar.map(\.id), ["bls-1", "off-1", "off-4"], "BLS und frühere Treffer bleiben, Doppelte raus")
    }

    func testHaeufigZaehlt() throws {
        var f = ErnaehrungFaltung()
        let kaffee = l("bls-k"), ei = l("bls-e")
        let heute = Datum.text(Date())
        for (i, x) in [kaffee, ei, kaffee, kaffee].enumerated() {
            let e = EssenEintrag(id: "e\(i)", datum: heute, mahlzeit: .fruehstueck, menge: 1, einheit: .g, lebensmittel: x, geloescht: nil)
            f.anwenden(try op("essen.setzen", .testA, e, Double(i)))
        }
        XCTAssertEqual(f.haeufig(.testA).map(\.id), ["bls-k", "bls-e"])
    }
}
