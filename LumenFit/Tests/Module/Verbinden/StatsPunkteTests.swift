import XCTest
@testable import LumenFit

/// Punkte für Stats und Erfolge: Training +10 je Tag, Set +1 ohne Aufwärmen, Rekord +5 je Übung mit neuem schwersten Gewicht.
/// Feste Uhr Donnerstag 2026-11-12, 12 Uhr (Woche ab Montag 09.11.).
final class StatsPunkteTests: XCTestCase {
    private let jetzt = Datum.datum("2026-11-12").addingTimeInterval(12 * 3600)

    private func satz(_ wdh: Int, _ kg: Double?, _ typ: String? = nil) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ)
        s.ok = true
        return s
    }

    /// Eine fertige Einheit am Tag `tag` um `stunde` Uhr; je Übung (Katalog-Id oder `PlanUebung.eigen`, Plan-Eintrag, Sätze) ein Lauf.
    private func einheit(_ tag: String, stunde: Double = 18, _ uebungen: [(id: String, plan: String, saetze: [PlanSatz])]) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(stunde * 3600)
        let laeufe = uebungen.map { u in
            UebungsLauf(plan: u.plan, uebung: u.id, start: start, ende: start.addingTimeInterval(600), fertig: true, saetze: u.saetze)
        }
        return GymSession(id: "s-\(tag)-\(stunde)", tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: laeufe)
    }

    private func einheit(_ tag: String, stunde: Double = 18, _ id: String, _ saetze: [PlanSatz]) -> GymSession {
        einheit(tag, stunde: stunde, [(id: id, plan: "p-\(id)", saetze: saetze)])
    }

    func testPunkteFormelWieDerServer() {
        XCTAssertEqual(StatsPunkte.punkte(trainings: 3, sets: 40, rekorde: 2), 80)
        XCTAssertEqual(StatsZahlen(trainings: 3, sets: 40, rekorde: 1, serie: 4).punkte, 75, "gleich wie server/stats.test.js")
    }

    func testWocheZaehltTageSetsUndRekordeGesamtAlles() {
        let sessions = [
            einheit("2026-11-08", "kniebeuge", [satz(5, 100)]),                                           // Sonntag davor
            einheit("2026-11-09", stunde: 7, "kniebeuge", [satz(10, 60, "w"), satz(5, 110), satz(5, 110)]), // Rekord, Aufwärmen zählt nicht
            einheit("2026-11-09", stunde: 18, "bank", [satz(8, 80)]),                                     // zweites Training am Tag, erstes Mal kein Rekord
            einheit("2026-11-11", "kniebeuge", [satz(5, 105)]),                                           // leichter: kein Rekord
        ]
        let z = StatsPunkte.zahlen(sessions, jetzt: jetzt)
        XCTAssertEqual(z, StatsZahlen(trainings: 2, sets: 4, rekorde: 1, serie: 2))
        XCTAssertEqual(z.punkte, 29)
        XCTAssertEqual(StatsPunkte.woche(sessions, jetzt: jetzt), 29)
        XCTAssertEqual(StatsPunkte.gesamt(sessions), 3 * 10 + 5 + 5)
        XCTAssertEqual(StatsPunkte.gesamt([]), 0)
        XCTAssertEqual(StatsPunkte.zahlen([], jetzt: jetzt), StatsZahlen())
    }

    func testEinheitNurMitAufwaermenIstKeinTraining() {
        let sessions = [einheit("2026-11-10", "kniebeuge", [satz(10, 40, "w")])]
        XCTAssertEqual(StatsPunkte.zahlen(sessions, jetzt: jetzt), StatsZahlen())
        XCTAssertEqual(StatsPunkte.gesamt(sessions), 0)
    }

    func testRekordEinmalJeUebungUndEinheitNurMitGewicht() {
        var sessions = [
            einheit("2026-11-02", [(id: "kniebeuge", plan: "a", saetze: [satz(5, 100)]), (id: "klimmzug", plan: "b", saetze: [satz(10, nil)])]),
            einheit("2026-11-10", [(id: "kniebeuge", plan: "a", saetze: [satz(5, 105), satz(3, 110)]), (id: "klimmzug", plan: "b", saetze: [satz(12, nil)])]),
        ]
        XCTAssertEqual(StatsPunkte.zahlen(sessions, jetzt: jetzt).rekorde, 1, "zwei schwerere Sätze in einer Einheit sind ein Rekord, ohne Gewicht keiner")
        sessions.append(einheit("2026-11-12", stunde: 8, "kniebeuge", [satz(2, 112.5)]))
        XCTAssertEqual(StatsPunkte.zahlen(sessions, jetzt: jetzt).rekorde, 2, "jede Einheit mit neuem Höchstgewicht zählt")
    }

    func testEigeneUebungenZaehlenUeberIhrenPlanEintrag() {
        let eigen = PlanUebung.eigen
        let sessions = [
            einheit("2026-11-03", [(id: eigen, plan: "a", saetze: [satz(8, 50)]), (id: eigen, plan: "b", saetze: [satz(8, 80)])]),
            einheit("2026-11-10", [(id: eigen, plan: "a", saetze: [satz(8, 60)]), (id: eigen, plan: "b", saetze: [satz(8, 70)])]),
        ]
        XCTAssertEqual(StatsPunkte.zahlen(sessions, jetzt: jetzt).rekorde, 1)
    }

    func testSerieLaufendeWocheBrichtNichtLueckeSchon() {
        let zweiWochen = [einheit("2026-10-27", "bank", [satz(5, 60)]), einheit("2026-11-06", "bank", [satz(5, 60)])]
        XCTAssertEqual(StatsPunkte.serie(zweiWochen, jetzt: jetzt), 2, "diese Woche noch ohne Training: Serie bleibt")
        XCTAssertEqual(StatsPunkte.serie(zweiWochen + [einheit("2026-11-12", stunde: 7, "bank", [satz(5, 60)])], jetzt: jetzt), 3)
        let luecke = [einheit("2026-10-20", "bank", [satz(5, 60)]), einheit("2026-11-06", "bank", [satz(5, 60)])]
        XCTAssertEqual(StatsPunkte.serie(luecke, jetzt: jetzt), 1)
        XCTAssertEqual(StatsPunkte.serie([einheit("2026-10-27", "bank", [satz(5, 60)])], jetzt: jetzt), 0, "letzte Woche ohne Training: vorbei")
        XCTAssertEqual(StatsPunkte.serie([], jetzt: jetzt), 0)
        let jahreswechsel = [einheit("2026-12-30", "bank", [satz(5, 60)]), einheit("2027-01-04", "bank", [satz(5, 60)])]
        XCTAssertEqual(StatsPunkte.serie(jahreswechsel, jetzt: Datum.datum("2027-01-06").addingTimeInterval(12 * 3600)), 2)
    }
}
