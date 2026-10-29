// Quelle: Lovea Tests/GymLueckenTests.swift
import XCTest
@testable import LumenFit

/// Lücken im Gym-Bereich (Nachtschicht 02.10.): reine Logik, ohne Oberfläche.
final class GymLueckenTests: XCTestCase {
    /// Mittwoch 23.09.2026, 18:00 Berlin.
    private let t0 = Datum.datum("2026-09-23").addingTimeInterval(18 * 3600)

    private func satz(_ wdh: Int, _ kg: Double?, ok: Bool = false) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: false)
        if ok { s.ok = true }
        return s
    }

    private func uebung(_ id: String, saetze: [PlanSatz] = [], minuten: Int? = nil) -> PlanUebung {
        PlanUebung(id: id, uebung: "x\(id)", name: "Übung \(id)", saetze: saetze, minuten: minuten)
    }

    private func leereSession(tag: String? = "t", laeufe: [UebungsLauf] = []) -> GymSession {
        GymSession(id: "s", tag: tag, start: t0, ende: nil, laeufe: laeufe)
    }

    private func op(_ art: String, _ d: some Encodable, zeit: Date, id: String = UUID().uuidString) -> Op {
        Op(id: id, art: art, von: .testA, zeit: zeit, d: try! JSONEncoder().encode(d))
    }

    private func session(_ ops: [Op]) -> GymSession {
        var f = TrainingFaltung()
        for o in ops { f.anwenden(o) }
        return f.sessions(.testA)[0]
    }

    func testRecentExercisesNewestFirstWithoutDuplicates() {
        func katalogUebung(_ id: String) -> Uebung {
            Uebung(id: id, name: "Übung \(id)", en: id, muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
        }
        let katalog = Dictionary(uniqueKeysWithValues: ["a", "b", "c", "d"].map { ($0, katalogUebung($0)) })
        func lauf(_ id: String, fertig: Bool = true) -> UebungsLauf {
            UebungsLauf(plan: "p\(id)", uebung: id, start: t0, ende: t0, fertig: fertig, saetze: fertig ? [satz(10, 50, ok: true)] : nil)
        }
        let alt = GymSession(id: "alt", tag: nil, start: t0 - 86400, ende: t0 - 80000, laeufe: [lauf("a"), lauf("b")])
        let neu = GymSession(id: "neu", tag: nil, start: t0, ende: t0 + 3600, laeufe: [lauf("c"), lauf("a"), lauf("d", fertig: false), lauf("eigen")])
        // Neueste Einheit zuerst, darin die zuletzt gemachte zuerst; "d" ohne Sätze und "eigen" (nicht im Katalog) fehlen.
        XCTAssertEqual(UebungsKatalog.zuletzt([alt, neu], in: katalog).map(\.id), ["a", "c", "b"])
        XCTAssertEqual(UebungsKatalog.zuletzt([alt, neu], in: katalog, limit: 2).map(\.id), ["a", "c"])
        XCTAssertTrue(UebungsKatalog.zuletzt([], in: katalog).isEmpty)
    }

    func testEarliestStartKeepsSessionRunning() {
        let frueh = TrainingLogik.fruehesterStart(jetzt: t0)
        XCTAssertTrue(TrainingLogik.laufend(GymSession(id: "s", tag: nil, start: frueh, ende: nil, laeufe: []), jetzt: t0))
        let zuFrueh = frueh.addingTimeInterval(-61)
        XCTAssertFalse(TrainingLogik.laufend(GymSession(id: "s", tag: nil, start: zuFrueh, ende: nil, laeufe: []), jetzt: t0))
    }

}
