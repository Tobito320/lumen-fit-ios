// Quelle: Lovea Health/Ernaehrung/FastenView.swift (Entscheidungen der Seite, neu getestet)
import XCTest
@testable import LumenFit

final class EssenFastenAnzeigeTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func fenster(_ id: String, stunden: Double?, plan: FastenPlan = .sechzehn, tagVersatz: Double = 0) -> FastenEintrag {
        let s = start.addingTimeInterval(tagVersatz * 86_400)
        return FastenEintrag(id: id, start: s, ende: stunden.map { s.addingTimeInterval($0 * 3600) }, plan: plan.rawValue, geloescht: nil)
    }

    func testLetzteSiebenAeltestesZuerst() {
        // Eingabe: neuester Start zuerst, wie FastenLogik.beendete sie liefert.
        let beendete = (0..<9).map { fenster("f\($0)", stunden: 16, tagVersatz: Double(-$0)) }
        let letzte = EssenFastenAnzeige.letzte(beendete)
        XCTAssertEqual(letzte.count, 7)
        XCTAssertEqual(letzte.first?.id, "f6")
        XCTAssertEqual(letzte.last?.id, "f0")
        XCTAssertTrue(EssenFastenAnzeige.letzte([]).isEmpty)
    }

    func testRingPlanLaufendesFensterBehaeltStartPlan() {
        let laufend = fenster("a", stunden: nil, plan: .achtzehn)
        XCTAssertEqual(EssenFastenAnzeige.ringPlan(laufend: laufend, aktuell: .zwoelf), .achtzehn)
        XCTAssertEqual(EssenFastenAnzeige.ringPlan(laufend: nil, aktuell: .zwoelf), .zwoelf)
    }

    func testAnzeigeEintragLaufendVorNeuestem() {
        let alt = fenster("alt", stunden: 16, tagVersatz: -1)
        let laufend = fenster("jetzt", stunden: nil)
        XCTAssertEqual(EssenFastenAnzeige.anzeigeEintrag(laufend: laufend, alle: [laufend, alt])?.id, "jetzt")
        XCTAssertEqual(EssenFastenAnzeige.anzeigeEintrag(laufend: nil, alle: [alt])?.id, "alt")
        XCTAssertNil(EssenFastenAnzeige.anzeigeEintrag(laufend: nil, alle: []))
    }

    func testEndeText() {
        XCTAssertEqual(EssenFastenAnzeige.endeText(nil, plan: .sechzehn), "–")
        let laufend = fenster("a", stunden: nil)
        XCTAssertTrue(EssenFastenAnzeige.endeText(laufend, plan: .sechzehn).hasSuffix("(geplant)"))
        let beendet = fenster("b", stunden: 16)
        XCTAssertEqual(EssenFastenAnzeige.endeText(beendet, plan: .sechzehn), FastenLogik.zeitpunktText(beendet.ende ?? start))
    }

    func testZielText() {
        XCTAssertEqual(EssenFastenAnzeige.zielText(fenster("a", stunden: 16)), "16 von 16 Stunden, geschafft")
        XCTAssertEqual(EssenFastenAnzeige.zielText(fenster("b", stunden: 12.5)), "12,5 von 16 Stunden, nicht ganz")
    }
}
