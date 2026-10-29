import XCTest
@testable import LumenFit

/// Gewichtsverlauf mit Trend (Idee 36): Ausgleichsgerade, Prognose nur bei Trend zum Ziel, Aussage und Kernzeile.
final class GewichtTrendTests: XCTestCase {
    private func mittel(_ tag: String, _ kg: Double) -> GewichtMittel { GewichtMittel(tag: tag, kg: kg) }

    private let woche3 = [GewichtMittel(tag: "2026-09-01", kg: 80), GewichtMittel(tag: "2026-09-08", kg: 79), GewichtMittel(tag: "2026-09-15", kg: 78)]

    func testSteigungInKiloJeWoche() throws {
        XCTAssertEqual(try XCTUnwrap(GewichtVerlauf.steigungProWoche(woche3)), -1.0, accuracy: 0.0001)
        let steigend = [mittel("2026-09-01", 70), mittel("2026-09-04", 70.3), mittel("2026-09-08", 70.7)]
        XCTAssertGreaterThan(try XCTUnwrap(GewichtVerlauf.steigungProWoche(steigend)), 0)
    }

    func testSteigungBrauchtDreiPunkteUndEineWocheSpanne() {
        XCTAssertNil(GewichtVerlauf.steigungProWoche([]))
        XCTAssertNil(GewichtVerlauf.steigungProWoche(Array(woche3.prefix(2))))
        let kurz = [mittel("2026-09-01", 80), mittel("2026-09-03", 79.9), mittel("2026-09-05", 79.8)]
        XCTAssertNil(GewichtVerlauf.steigungProWoche(kurz), "unter 7 Tagen Spanne")
    }

    func testPrognoseNurWennDerTrendZumZielZeigt() {
        XCTAssertEqual(GewichtVerlauf.prognose(aktuell: 78, ziel: 75, steigung: -1), 3)
        XCTAssertEqual(GewichtVerlauf.prognose(aktuell: 78, ziel: 75, steigung: -0.7), 5, "4,3 Wochen werden aufgerundet")
        XCTAssertEqual(GewichtVerlauf.prognose(aktuell: 70, ziel: 75, steigung: 0.5), 10)
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: 78, ziel: 82, steigung: -1), "Trend zeigt vom Ziel weg")
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: 70, ziel: 75, steigung: -0.5))
    }

    func testPrognoseOhneZielOhneTrendOderSchonAmZiel() {
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: 78, ziel: nil, steigung: -1))
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: 78, ziel: 75, steigung: nil))
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: nil, ziel: 75, steigung: -1))
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: 78, ziel: 75, steigung: -0.04), "unter 0,05 kg je Woche ist Schwankung")
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: 75.2, ziel: 75, steigung: -1), "innerhalb von 0,3 kg ist es das Ziel")
        XCTAssertNil(GewichtVerlauf.prognose(aktuell: 120, ziel: 70, steigung: -0.1), "mehr als zwei Jahre")
    }

    func testTrendRechnetAusDenTageswerten() throws {
        // 28 Tage, jeden Tag 100 g weniger: 80,0 kg am 1.9., 77,3 kg am 28.9.
        var werte: [String: Int] = [:]
        for i in 0..<28 { werte[Datum.addTage("2026-09-01", i)] = 800 - i }
        let t = GewichtVerlauf.trend(werte: werte, zielKg: 75, heute: "2026-09-28")
        XCTAssertEqual(t.reihe.count, 28)
        XCTAssertEqual(t.punkte.count, 28)
        XCTAssertEqual(t.punkte.last?.kg ?? 0, 77.3, accuracy: 0.001)
        XCTAssertEqual(t.aktuell ?? 0, 77.6, accuracy: 0.001, "Mittel der letzten sieben Tage")
        let s = try XCTUnwrap(t.kgProWoche)
        XCTAssertLessThan(s, -0.55)
        XCTAssertGreaterThan(s, -0.75)
        let wochen = try XCTUnwrap(t.prognoseWochen)
        XCTAssertTrue((3...6).contains(wochen), "\(wochen)")
        XCTAssertFalse(t.amZiel)
    }

    func testTrendSiehtNurDasFenster() {
        let werte = ["2026-05-01": 900, "2026-09-20": 800, "2026-09-27": 790]
        let t = GewichtVerlauf.trend(werte: werte, zielKg: nil, heute: "2026-09-28")
        XCTAssertEqual(t.punkte.map(\.tag), ["2026-09-20", "2026-09-27"])
        XCTAssertNil(t.kgProWoche, "zwei Punkte reichen nicht")
        XCTAssertNil(t.prognoseWochen)
    }

    func testAussage() {
        func t(aktuell: Double?, ziel: Double?, s: Double?, wochen: Int?) -> GewichtTrend {
            GewichtTrend(reihe: aktuell.map { [GewichtMittel(tag: "2026-09-28", kg: $0)] } ?? [], punkte: [], zielKg: ziel, kgProWoche: s, prognoseWochen: wochen)
        }
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: nil, ziel: 75, s: nil, wochen: nil)), "Noch kein Gewicht eingetragen")
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: 77.6, ziel: 75, s: -0.7, wochen: 9)), "In 9 Wochen am Ziel")
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: 77.6, ziel: 75, s: -0.7, wochen: 1)), "In 1 Woche am Ziel")
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: 75.1, ziel: 75, s: -0.2, wochen: nil)), "Du bist am Ziel: 75,1 kg")
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: 77.6, ziel: 75, s: 0.4, wochen: nil)), "Der Trend zeigt gerade vom Ziel weg")
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: 77.6, ziel: 75, s: 0.0, wochen: nil)), "Dein Gewicht bleibt stabil bei 77,6 kg")
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: 77.6, ziel: nil, s: -0.4, wochen: nil)), "Dein Gewicht sinkt langsam")
        XCTAssertEqual(GewichtVerlauf.aussage(t(aktuell: 77.6, ziel: nil, s: nil, wochen: nil)), "Gewicht 77,6 kg")
    }

    func testKernzeile() {
        let t = GewichtTrend(reihe: [GewichtMittel(tag: "2026-09-28", kg: 77.6)], punkte: [], zielKg: 75, kgProWoche: -0.7, prognoseWochen: 4)
        XCTAssertEqual(GewichtVerlauf.kernzeile(t), "Mittel 77,6 kg · -0,7 kg je Woche · Ziel 75 kg")
        let ohne = GewichtTrend(reihe: [], punkte: [], zielKg: nil, kgProWoche: nil, prognoseWochen: nil)
        XCTAssertTrue(GewichtVerlauf.kernzeile(ohne).contains("Gewicht ein"))
    }
}
