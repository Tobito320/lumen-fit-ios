import XCTest
@testable import LumenFit

/// Konstanz-Raster (Idee 35): 18 Wochen mal 7 Tage, vier Stufen, jede mit Name und Zahl, auch ohne Farbe lesbar.
final class KonstanzRasterTests: XCTestCase {
    /// Mittwoch 14.10.2026; die Woche beginnt am 12.10., das Raster am 15.06.2026.
    private let heute = "2026-10-14"

    private func einheit(_ id: String, _ tag: String, saetze: Int, warm: Int = 0) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let arbeit = (0..<saetze).map { _ in PlanSatz(wdh: 8, kg: 60, failure: false) }
        let waerm = (0..<warm).map { _ in PlanSatz(wdh: 8, kg: 20, failure: false, typ: "w") }
        let lauf = UebungsLauf(plan: "p", uebung: "x", start: start, ende: start.addingTimeInterval(1800), fertig: true, saetze: waerm + arbeit)
        return GymSession(id: id, tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: saetze + warm == 0 ? [] : [lauf])
    }

    private func zelle(_ g: KonstanzRaster.Gitter, _ tag: String) -> KonstanzRaster.Zelle? { g.zellen.first { $0.tag == tag } }

    func testRasterHatAchtzehnWochenMitSiebenTagen() {
        let g = KonstanzRaster.gitter([], gym: [:], heute: heute)
        XCTAssertEqual(g.spalten.count, 18)
        XCTAssertTrue(g.spalten.allSatisfy { $0.count == 7 })
        XCTAssertEqual(g.spalten.first?.first?.tag, "2026-06-15")
        XCTAssertEqual(g.spalten.last?.first?.tag, "2026-10-12", "die letzte Spalte ist die Woche von heute")
        XCTAssertEqual(g.spalten.last?.last?.tag, "2026-10-18")
        XCTAssertEqual(g.zellen.count, 126)
    }

    func testStufenVonKeinBisStark() {
        let s = [einheit("a", "2026-10-12", saetze: 10), einheit("b", "2026-10-13", saetze: 16),
                 einheit("c", "2026-10-09", saetze: 0, warm: 2)]
        let g = KonstanzRaster.gitter(s, gym: ["2026-10-08": 1], heute: heute)
        XCTAssertEqual(zelle(g, "2026-10-12")?.stufe, .training)
        XCTAssertEqual(zelle(g, "2026-10-13")?.stufe, .stark)
        XCTAssertEqual(zelle(g, "2026-10-09")?.stufe, .besuch, "nur Aufwärmsätze zählen als Besuch")
        XCTAssertEqual(zelle(g, "2026-10-08")?.stufe, .besuch, "nur das Gym-Häkchen")
        XCTAssertEqual(zelle(g, "2026-10-10")?.stufe, KonstanzRaster.Stufe.kein)
    }

    func testZweiEinheitenAmTagSindStark() {
        XCTAssertEqual(KonstanzRaster.stufe(saetze: 6, einheiten: 2, besuch: false), .stark)
        XCTAssertEqual(KonstanzRaster.stufe(saetze: 6, einheiten: 1, besuch: false), .training)
        XCTAssertEqual(KonstanzRaster.stufe(saetze: 0, einheiten: 2, besuch: false), .besuch)
        XCTAssertEqual(KonstanzRaster.stufe(saetze: 0, einheiten: 0, besuch: false), .kein)
        XCTAssertEqual(KonstanzRaster.stufe(saetze: 15, einheiten: 1, besuch: true), .training)
    }

    func testAufwaermsaetzeZaehlenNichtZumTag() {
        let g = KonstanzRaster.gitter([einheit("a", "2026-10-12", saetze: 3, warm: 20)], gym: [:], heute: heute)
        XCTAssertEqual(zelle(g, "2026-10-12")?.saetze, 3)
        XCTAssertEqual(zelle(g, "2026-10-12")?.stufe, .training)
    }

    func testZukunftIstMarkiertUndAelteresFehlt() {
        let g = KonstanzRaster.gitter([einheit("alt", "2026-05-01", saetze: 8)], gym: [:], heute: heute)
        XCTAssertEqual(zelle(g, "2026-10-14")?.zukunft, false)
        XCTAssertEqual(zelle(g, "2026-10-15")?.zukunft, true)
        XCTAssertNil(zelle(g, "2026-05-01"))
        XCTAssertEqual(g.trainingstage, 0)
    }

    func testAussageKernzeileUndSprechtext() {
        let leer = KonstanzRaster.gitter([], gym: [:], heute: heute)
        XCTAssertEqual(KonstanzRaster.aussage(leer), "Noch kein Training in den letzten 18 Wochen")
        XCTAssertEqual(KonstanzRaster.kernzeile(leer), "Tipp auf Starten, Lumi zählt mit.")
        let s = [einheit("a", "2026-10-12", saetze: 10), einheit("b", "2026-10-07", saetze: 5), einheit("c", "2026-09-21", saetze: 8)]
        let g = KonstanzRaster.gitter(s, gym: [:], heute: heute)
        XCTAssertEqual(KonstanzRaster.aussage(g), "3 Trainingstage in 18 Wochen")
        XCTAssertEqual(KonstanzRaster.kernzeile(g), "In 3 von 18 Wochen warst du dabei.")
        XCTAssertEqual(zelle(g, "2026-10-12")?.sprechtext, "Montag, 12. Oktober: Training, 10 Sätze")
        XCTAssertEqual(zelle(g, "2026-10-13")?.sprechtext, "Dienstag, 13. Oktober: kein Training")
        XCTAssertEqual(zelle(g, "2026-10-16")?.sprechtext, "Freitag, 16. Oktober: noch nicht dran")
        XCTAssertEqual(KonstanzRaster.aussage(KonstanzRaster.gitter([einheit("a", "2026-10-12", saetze: 4)], gym: [:], heute: heute)), "1 Trainingstag in 18 Wochen")
    }

    func testJedeStufeHatEinenEigenenNamenUndEineZahl() {
        XCTAssertEqual(KonstanzRaster.Stufe.allCases.map(\.rawValue), [0, 1, 2, 3])
        XCTAssertEqual(Set(KonstanzRaster.Stufe.allCases.map(\.name)).count, 4)
    }
}
