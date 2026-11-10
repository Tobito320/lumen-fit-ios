import XCTest
@testable import LumenFit

/// Karte "Übersicht": Trainings insgesamt, je Monat und Woche, Gewicht in 30 Tagen, Lumi-Satz. "Heute" ist Mittwoch 11.11.2026 (Woche ab 09.11.).
final class FortUebersichtTests: XCTestCase {
    private let heute = "2026-11-11"

    private func einheit(_ tag: String, beendet: Bool = true) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        return GymSession(id: "e-\(tag)", tag: nil, start: start, ende: beendet ? start.addingTimeInterval(3600) : nil, laeufe: [])
    }

    func testMonatZaehltDieLetztenVierMonate() {
        let s = ["2026-07-30", "2026-08-03", "2026-10-01", "2026-10-20", "2026-11-02", "2026-11-10"].map { einheit($0) }
        let d = FortUebersicht.daten(s, plan: .leer, gewicht: [:], heute: heute, zeitraum: .monat)
        XCTAssertEqual(d.insgesamt, 6)
        XCTAssertEqual(d.balken.map(\.id), ["2026-08", "2026-09", "2026-10", "2026-11"])
        XCTAssertEqual(d.balken.map(\.anzahl), [1, 0, 2, 2])
        XCTAssertEqual(d.balken.map(\.aktuell), [false, false, false, true])
        XCTAssertEqual(d.imZeitraum, 2)
        XCTAssertNil(d.geplant)
    }

    func testWocheZaehltAchtWochenUndLaufendeEinheitNicht() {
        let s = [einheit("2026-11-09"), einheit("2026-11-11", beendet: false), einheit("2026-11-03"), einheit("2026-09-14")]
        let d = FortUebersicht.daten(s, plan: .leer, gewicht: [:], heute: heute, jetzt: Datum.datum(heute).addingTimeInterval(18.5 * 3600), zeitraum: .woche)
        XCTAssertEqual(d.balken.count, 8)
        XCTAssertEqual(d.balken.first?.id, "2026-09-21")
        XCTAssertEqual(d.balken.last?.id, "2026-11-09")
        XCTAssertEqual(d.balken.suffix(2).map(\.anzahl), [1, 1])
        XCTAssertEqual(d.imZeitraum, 1)
        XCTAssertEqual(d.insgesamt, 3)
    }

    func testGewichtDreissigTage() {
        // Zehntel-kg: vor 31 Tagen 83,6, vor 10 Tagen 83,0, heute 82,4.
        let werte = [Datum.addTage(heute, -31): 836, Datum.addTage(heute, -10): 830, heute: 824]
        XCTAssertEqual(FortUebersicht.gewicht30(werte, heute: heute) ?? 0, -1.2, accuracy: 0.001)
        // Nur jüngere Einträge: der älteste zählt.
        XCTAssertEqual(FortUebersicht.gewicht30([Datum.addTage(heute, -5): 800, heute: 805], heute: heute) ?? 0, 0.5, accuracy: 0.001)
        XCTAssertNil(FortUebersicht.gewicht30([heute: 800], heute: heute))
        XCTAssertNil(FortUebersicht.gewicht30([:], heute: heute))
        XCTAssertEqual(FortUebersicht.gewichtText(-1.2), "−1,2")
        XCTAssertEqual(FortUebersicht.gewichtText(0.01), "±0")
    }

    func testMehrAlsSonst() {
        func v(_ n: Int, _ schnitt: Double) -> TrainingsWochenVergleich {
            TrainingsWochenVergleich(einheiten: n, einheitenSchnitt: schnitt, volumen: 0, volumenSchnitt: 0, saetze: 0, saetzeSchnitt: 0, gestiegen: 0, hauptuebungen: 0)
        }
        XCTAssertTrue(FortUebersicht.mehrAlsSonst(v(3, 2.5)))
        XCTAssertTrue(FortUebersicht.mehrAlsSonst(v(2, 2)))
        XCTAssertFalse(FortUebersicht.mehrAlsSonst(v(1, 2.5)))
        XCTAssertFalse(FortUebersicht.mehrAlsSonst(v(0, 0)))
    }
}
