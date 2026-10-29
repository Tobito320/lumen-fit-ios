// Quelle: Lovea Tests/VerlaufOhneSaetzeTests.swift
import XCTest
@testable import LumenFit

/// W-009 "Verlauf zeigt 0 Sätze": die Zählung stimmt für den ganzen Katalog, die 0 kam von Training ohne
/// gezählten Satz. Der Hinweis (`VerlaufLogik.ohneSaetze`) sagt das jetzt, aus denselben Läufen wie die Kacheln.
final class VerlaufOhneSaetzeTests: XCTestCase {
    /// Dienstag 13.10.2026; die Woche geht vom 12. bis 18.10.
    private let heute = "2026-10-13"
    private let jetzt = Datum.datum("2026-10-13").addingTimeInterval(20 * 3600)
    private let alle = UebungsKatalog.laden(Bundle(for: BundleAnker.self))
    private lazy var kat = Dictionary(alle.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    // MARK: - Helfer

    private func op(_ art: String, _ d: GymD, _ zeit: Date) -> Op {
        Op(id: UUID().uuidString, art: art, von: .testA, zeit: zeit, d: (try? JSONEncoder().encode(d)) ?? Data())
    }

    private func satz(ok: Bool? = true, typ: String? = nil) -> PlanSatz {
        var s = PlanSatz(wdh: 10, kg: 60, failure: false)
        s.ok = ok
        s.typ = typ
        return s
    }

    /// Eine Einheit um 05:00 am `tag`, je Übung ein "satz"-Op wie in der Trainingsansicht.
    private func einheit(_ id: String, am tag: String = "2026-10-13", beendet: Bool = true,
                         mit uebungen: [(uebung: String, saetze: [PlanSatz])] = []) -> [Op] {
        let start = Datum.datum(tag).addingTimeInterval(5 * 3600)
        var ops = [op("gym.checkin", GymD(session: id, start: start), start)]
        for (i, u) in uebungen.enumerated() {
            ops.append(op("gym.uebung", GymD(session: id, plan: "p\(i)", uebung: u.uebung, status: "satz", saetze: u.saetze), start + Double(60 * (i + 1))))
        }
        if beendet { ops.append(op("gym.checkout", GymD(session: id, ende: start + 2700), start + 2700)) }
        return ops
    }

    private func sessions(_ ops: [Op]) -> [GymSession] {
        var f = TrainingFaltung()
        for o in ops { f.anwenden(o) }
        return f.sessions(.testA)
    }

    private func ohne(_ s: [GymSession], gym: [String: Int] = [:], heute: String? = nil, jetzt: Date? = nil) -> [VerlaufLogik.TagOhneSaetze] {
        VerlaufLogik.ohneSaetze(s, gym: gym, heute: heute ?? self.heute, jetzt: jetzt ?? self.jetzt, katalog: { self.kat[$0] })
    }

    private func tag(_ t: String, _ art: VerlaufLogik.TagOhneSaetze.Art) -> VerlaufLogik.TagOhneSaetze {
        VerlaufLogik.TagOhneSaetze(tag: t, art: art)
    }

    // MARK: - Zählung: Katalog und Rücken

    func testJedeKraftuebungDesKatalogsLandetInEinerGruppe() {
        XCTAssertGreaterThanOrEqual(alle.count, 1300, "Katalog nicht im Bundle")
        for u in alle where !u.istCardio {
            XCTAssertFalse(MuskelLogik.teile(u).isEmpty, "\(u.name) (\(u.muskel)) hat keine Muskelgruppe")
        }
    }

    func testJedeRueckenUebungZaehltFuerDieGruppeRuecken() {
        let ruecken = alle.filter { $0.koerper == "Rücken" }
        XCTAssertGreaterThanOrEqual(ruecken.count, 150, "Rücken-Übungen nicht im Bundle")
        for u in ruecken {
            XCTAssertTrue(MuskelLogik.teile(u).contains { $0.teil.gruppe == .ruecken }, "\(u.name) zählt nicht für Rücken")
        }
    }

    func testRueckenTrainingAusDenOpsZaehltInDerWoche() {
        // Latzug (Latissimus) und Rudern an der Maschine (oberer Rücken), je drei abgehakte Sätze.
        let s = sessions(einheit("pull", mit: [
            (uebung: "qdRxqCj", saetze: [satz(), satz(), satz()]),
            (uebung: "7I6LNUG", saetze: [satz(), satz(), satz()]),
        ]))
        let z = VerlaufLogik.gruppen(VerlaufLogik.laeufe(s, katalog: { self.kat[$0] }), heute: heute)[.ruecken]
        XCTAssertEqual(z?.woche.saetze, 6)
        XCTAssertEqual(z?.woche.einheiten, 1)
        XCTAssertTrue(ohne(s, gym: [heute: 1]).isEmpty, "Training mit Sätzen braucht keinen Hinweis")
    }

    // MARK: - Hinweis: wann die 0 nicht stimmt

    func testNurGymHaekchenGibtHinweisFuerDenTag() {
        XCTAssertEqual(ohne([], gym: [heute: 1, "2026-10-12": 0]), [tag(heute, .nurHaken)])
    }

    func testEinheitOhneAbgehaktenSatzGibtHinweis() {
        let s = sessions(einheit("a", mit: [(uebung: "qdRxqCj", saetze: [satz(ok: nil), satz(ok: nil)])]))
        XCTAssertEqual(ohne(s), [tag(heute, .keinSatz)])
    }

    func testNurAufwaermsatzAbgehaktGibtHinweis() {
        // `GymTageLogik.hatDaten` nennt das Daten, die Kacheln zählen es nicht (`PlanSatz.zaehlt`).
        let s = sessions(einheit("a", mit: [(uebung: "qdRxqCj", saetze: [satz(typ: "w"), satz(ok: nil)])]))
        XCTAssertEqual(ohne(s), [tag(heute, .keinSatz)])
    }

    func testEinheitMitGezaehltemSatzGibtKeinenHinweis() {
        let s = sessions(einheit("a", mit: [(uebung: "qdRxqCj", saetze: [satz(typ: "w"), satz(), satz(ok: nil)])]))
        XCTAssertTrue(ohne(s).isEmpty)
    }

    func testNurEigeneUebungGibtHinweisEigeneUebung() {
        let s = sessions(einheit("a", mit: [(uebung: PlanUebung.eigen, saetze: [satz(), satz()])]))
        XCTAssertEqual(ohne(s), [tag(heute, .eigeneUebung)])
    }

    func testLaufendeEinheitOhneSaetzeGibtKeinenHinweis() {
        let s = sessions(einheit("a", beendet: false))
        let start = Datum.datum(heute).addingTimeInterval(5 * 3600)
        XCTAssertTrue(ohne(s, jetzt: start + 600).isEmpty)
        XCTAssertEqual(ohne(s, jetzt: start + 4 * 3600), [tag(heute, .keinSatz)], "nach 3 h läuft sie nicht mehr")
    }

    func testFertigerCardioLaufGibtKeinenHinweis() throws {
        let cardio = try XCTUnwrap(alle.first { $0.istCardio })
        let start = Datum.datum(heute).addingTimeInterval(5 * 3600)
        let s = sessions([
            op("gym.checkin", GymD(session: "c", start: start), start),
            op("gym.uebung", GymD(session: "c", plan: "k", uebung: cardio.id, status: "fertig"), start + 1200),
            op("gym.checkout", GymD(session: "c", ende: start + 1800), start + 1800),
        ])
        XCTAssertTrue(ohne(s, gym: [heute: 1]).isEmpty)
    }

    func testTagMitEinheitUndHaekchenOhneSaetzeGibtEinenHinweis() {
        let s = sessions(einheit("a") + einheit("b", am: "2026-10-12") + einheit("c", am: "2026-10-12"))
        XCTAssertEqual(ohne(s, gym: [heute: 1, "2026-10-12": 1]), [tag("2026-10-12", .keinSatz), tag(heute, .keinSatz)],
                       "älteste zuerst, jeder Tag einmal, das Häkchen allein ist neben einer Einheit kein eigener Fall")
    }

    func testTagMitZweiEinheitenUndEinerMitSatzGibtKeinenHinweis() {
        let s = sessions(einheit("leer") + einheit("voll", mit: [(uebung: "qdRxqCj", saetze: [satz()])]))
        XCTAssertTrue(ohne(s, gym: [heute: 1]).isEmpty)
    }

    func testHinweisGiltNurFuerDieWocheMontagBisSonntag() {
        let gym = ["2026-10-11": 1, "2026-10-12": 1, "2026-10-18": 1, "2026-10-19": 1]
        XCTAssertEqual(ohne([], gym: gym, heute: "2026-10-14"), [tag("2026-10-12", .nurHaken), tag("2026-10-18", .nurHaken)])
    }
}
