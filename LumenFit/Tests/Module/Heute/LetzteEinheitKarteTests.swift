import XCTest
@testable import LumenFit

final class LetzteEinheitKarteTests: XCTestCase {
    /// Mittwoch 23.09.2026, 18:00 Berlin.
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func satz(_ wdh: Int, _ kg: Double?, typ: String? = nil) -> PlanSatz {
        PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ, ok: true)
    }

    private func uebung(_ id: String, _ name: String) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: name, saetze: [PlanSatz(wdh: 8, kg: nil, failure: false)])
    }

    private func lauf(_ id: String, _ saetze: [PlanSatz]) -> UebungsLauf {
        UebungsLauf(plan: id, uebung: "x\(id)", start: nil, ende: nil, fertig: true, saetze: saetze.filter(\.zaehlt), stand: saetze)
    }

    private func einheit(_ id: String, vorTagen: Int, minuten: Int? = 75, laeufe: [UebungsLauf]) -> GymSession {
        let start = t0.addingTimeInterval(-Double(vorTagen) * 86_400)
        return GymSession(id: id, tag: "t", start: start, ende: minuten.map { start.addingTimeInterval(Double($0) * 60) }, laeufe: laeufe)
    }

    private var tag: TrainingsTag {
        TrainingsTag(id: "t", name: "Pull", wochentage: [3], uebungen: [uebung("a", "Latzug"), uebung("b", "Klimmzug"), uebung("c", "Curl")])
    }

    private func bauen(_ sessions: [GymSession]) -> LetzteEinheit? {
        LetzteEinheitLogik.bauen(sessions: sessions) { $0 == "t" ? self.tag : nil }
    }

    func testLetzteBeendeteEinheitNeuesteZuerstOhneLaufende() {
        let satzA = [lauf("a", [satz(8, 60)])]
        let alt = einheit("alt", vorTagen: 7, laeufe: satzA)
        let neu = einheit("neu", vorTagen: 2, laeufe: satzA)
        let leer = einheit("leer", vorTagen: 1, laeufe: [])
        let laufend = einheit("laufend", vorTagen: 0, minuten: nil, laeufe: satzA)
        XCTAssertEqual(bauen([laufend, leer, neu, alt])?.sessionId, "neu", "laufende und leere Einheiten zählen nicht, die neueste beendete gilt")
        XCTAssertEqual(bauen([alt, neu])?.sessionId, "neu", "die Reihenfolge der Eingabe ist egal")
        XCTAssertNil(bauen([laufend, leer]))
        XCTAssertNil(bauen([]))
    }

    func testZeilenJeUebungMitBestemSatz() {
        let frueher = einheit("frueher", vorTagen: 7, laeufe: [lauf("a", [satz(8, 60)])])
        let heute = einheit("heute", vorTagen: 0, laeufe: [
            lauf("a", [satz(10, 20, typ: "w"), satz(10, 55), satz(8, 60), satz(8, 62.5)]),
            lauf("b", [satz(12, nil), satz(10, nil), satz(8, nil)]),
        ])
        let k = try? XCTUnwrap(bauen([frueher, heute]))
        XCTAssertEqual(k?.titel, "Pull")
        XCTAssertEqual(k?.zeilen.map(\.text), ["3 × Latzug", "3 × Klimmzug"], "Aufwärmsatz und nicht gemachte Übung zählen nicht")
        XCTAssertEqual(k?.zeilen.map(\.bester), ["62,5 kg × 8", "12 Wdh"])
        XCTAssertEqual(k?.zeilen.map(\.rekord), [true, false], "Latzug übertrifft die 60 kg von früher, Klimmzug war nie dran")
        XCTAssertEqual(k?.rekorde, 1)
        XCTAssertEqual(k?.saetze, 7, "Sätze wie im Abschluss und beim Nachlesen: jeder abgehakte, auch der Aufwärmsatz")
        XCTAssertEqual(k?.volumenText, "1.530 kg")
        XCTAssertEqual(k?.dauer, "1:15 h")
        XCTAssertEqual(k?.kopfzeile, "Mittwoch, 23. September, 18:00–19:15")
    }

    func testFreiesTrainingUndCardioOhneAbsturz() {
        let cardio = UebungsLauf(plan: "k", uebung: "xk", start: nil, ende: nil, fertig: true, saetze: nil)
        let s = GymSession(id: "f", tag: nil, start: t0, ende: t0.addingTimeInterval(1800), laeufe: [cardio])
        let k = LetzteEinheitLogik.bauen(sessions: [s]) { _ in nil }
        XCTAssertEqual(k?.titel, "Freies Training")
        XCTAssertEqual(k?.saetze, 0)
        XCTAssertEqual(k?.dauer, "30 min")
    }

    func testEinheitUeberMitternachtZeigtBeideUhrzeitenUndPositiveDauer() {
        let start = Datum.datum("2026-09-23").addingTimeInterval(23 * 3600 + 40 * 60)
        let s = GymSession(id: "nacht", tag: "t", start: start, ende: start.addingTimeInterval(40 * 60), laeufe: [lauf("a", [satz(8, 60)])])
        let k = bauen([s])
        XCTAssertEqual(k?.kopfzeile, "Mittwoch, 23. September, 23:40–00:20", "der Tag ist der des Starts")
        XCTAssertEqual(k?.dauer, "40 min")
    }

    func testDauerWirdNieNegativBeiKaputtemEnde() {
        // Ein Ende vor dem Start (schlechte Daten, falsch eingetragene Uhrzeit) darf nicht "-20 min" ergeben.
        let s = GymSession(id: "kaputt", tag: "t", start: t0, ende: t0.addingTimeInterval(-20 * 60), laeufe: [lauf("a", [satz(8, 60)])])
        let k = bauen([s])
        XCTAssertEqual(k?.dauer, "0 min")
        XCTAssertFalse(k?.dauer.contains("-") ?? true)
        XCTAssertFalse(k?.dauer.contains("−") ?? true)
    }
}
