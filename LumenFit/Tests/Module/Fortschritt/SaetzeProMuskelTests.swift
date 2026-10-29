import XCTest
@testable import LumenFit

/// Sätze je Muskel gegen Ziel (Idee 32): gezählte Sätze der Woche, Aufwärmsätze zählen nicht. Die Einheiten laufen durch `TrainingFaltung`,
/// wie sie auf dem Gerät entstehen.
final class SaetzeProMuskelTests: XCTestCase {
    /// Mittwoch 14.10.2026; die Woche geht vom 12. bis 18.10.
    private let heute = "2026-10-14"
    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: ["Trizeps"])
    private let kniebeuge = Uebung(id: "knie", name: "Kniebeuge", en: "squat", muskel: "Quadrizeps", koerper: "Beine", geraet: "Langhantel", neben: [])

    private func katalog(_ id: String) -> Uebung? { [bank.id: bank, kniebeuge.id: kniebeuge][id] }

    private func op(_ art: String, _ d: GymD, _ zeit: Date) -> Op {
        Op(id: UUID().uuidString, art: art, von: .testA, zeit: zeit, d: (try? JSONEncoder().encode(d)) ?? Data())
    }

    private func satz(typ: String? = nil, ok: Bool? = true) -> PlanSatz {
        var s = PlanSatz(wdh: 8, kg: 60, failure: false, typ: typ)
        s.ok = ok
        return s
    }

    /// Eine Einheit am `tag` um 18:00; `status` "satz" (Trainingsansicht) oder "fertig" (alter Weg, schickt alle Sätze).
    private func sessions(am tag: String, uebung: String, saetze: [PlanSatz], status: String) -> [GymSession] {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        var f = TrainingFaltung()
        f.anwenden(op("gym.checkin", GymD(session: "s-\(tag)", start: start), start))
        f.anwenden(op("gym.uebung", GymD(session: "s-\(tag)", plan: "p", uebung: uebung, status: status, saetze: saetze), start + 60))
        f.anwenden(op("gym.checkout", GymD(session: "s-\(tag)", ende: start + 3000), start + 3000))
        return f.sessions(.testA)
    }

    private func ziele(_ eigen: [MuskelGruppe: Int]) -> KoerperZiele {
        KoerperZiele.lesen(wert: { schluessel in
            for g in MuskelGruppe.allCases where schluessel == "ziel.saetze.\(g.rawValue)" { return eigen[g] }
            return nil
        })
    }

    private func zeile(_ g: MuskelGruppe, _ liste: [SatzZeile]) -> SatzZeile? { liste.first { $0.gruppe == g } }

    func testAufwaermsaetzeAusDerTrainingsansichtZaehlenNicht() {
        let s = sessions(am: "2026-10-13", uebung: "knie", saetze: [satz(typ: "w"), satz(), satz(), satz(ok: nil)], status: "satz")
        let z = SaetzeProMuskel.zeilen(s, heute: heute, ziele: ziele([.beine: 10]), katalog: katalog)
        XCTAssertEqual(zeile(.beine, z)?.saetze, 2, "ein Aufwärmsatz und ein offener Satz zählen nicht")
    }

    func testAufwaermsaetzeAusDemAltenWegZaehlenAuchNicht() {
        let s = sessions(am: "2026-10-13", uebung: "knie", saetze: [satz(typ: "w"), satz(), satz(), satz()], status: "fertig")
        XCTAssertEqual(s.first?.laeufe.first?.saetze?.count, 4, "der alte Weg speichert alle vier")
        let z = SaetzeProMuskel.zeilen(s, heute: heute, ziele: ziele([.beine: 10]), katalog: katalog)
        XCTAssertEqual(zeile(.beine, z)?.saetze, 3)
    }

    func testNurAufwaermenGibtNull() {
        let s = sessions(am: "2026-10-13", uebung: "knie", saetze: [satz(typ: "w"), satz(typ: "w")], status: "fertig")
        let z = SaetzeProMuskel.zeilen(s, heute: heute, ziele: ziele([.beine: 10]), katalog: katalog)
        XCTAssertEqual(zeile(.beine, z)?.saetze, 0)
    }

    func testMitarbeitZaehltHalbUndNurDieseWoche() {
        let diese = sessions(am: "2026-10-13", uebung: "bank", saetze: [satz(), satz(), satz(), satz()], status: "satz")
        let vorige = sessions(am: "2026-10-08", uebung: "bank", saetze: [satz(), satz()], status: "satz").map { s -> GymSession in
            var n = s
            n.id = "alt"
            return n
        }
        let z = SaetzeProMuskel.zeilen(diese + vorige, heute: heute, ziele: ziele([.brust: 12, .trizeps: 8]), katalog: katalog)
        XCTAssertEqual(zeile(.brust, z)?.saetze, 4)
        XCTAssertEqual(zeile(.trizeps, z)?.saetze, 2, "Hilfsmuskel zählt halb")
    }

    func testAnteilErreichtUndText() {
        XCTAssertEqual(SatzZeile(gruppe: .brust, saetze: 6, ziel: 12).anteil, 0.5)
        XCTAssertEqual(SatzZeile(gruppe: .brust, saetze: 20, ziel: 12).anteil, 1)
        XCTAssertTrue(SatzZeile(gruppe: .brust, saetze: 12, ziel: 12).erreicht)
        XCTAssertFalse(SatzZeile(gruppe: .brust, saetze: 11.5, ziel: 12).erreicht)
        XCTAssertEqual(SatzZeile(gruppe: .brust, saetze: 4.5, ziel: 8).text, "4,5 von 8")
        XCTAssertEqual(SatzZeile(gruppe: .brust, saetze: 0, ziel: 0).anteil, 0)
    }

    func testReihenfolgeFolgtDerPrioUndZielNullFehlt() {
        let z = SaetzeProMuskel.zeilen([], heute: heute, ziele: ziele([.nacken: 0, .bauch: 6]), katalog: katalog)
        XCTAssertEqual(z.first?.gruppe, MuskelGruppe.standardPrio.first, "Prio zuerst")
        XCTAssertNil(zeile(.nacken, z), "Ziel 0 gilt als kein Ziel")
        XCTAssertEqual(zeile(.bauch, z)?.ziel, 6)
        XCTAssertEqual(zeile(.beine, z)?.ziel, MuskelLogik.standardZiel(.beine, prio: false))
    }

    func testAussageUndKernzeile() {
        let z = [SatzZeile(gruppe: .brust, saetze: 12, ziel: 12), SatzZeile(gruppe: .ruecken, saetze: 4, ziel: 16), SatzZeile(gruppe: .beine, saetze: 2, ziel: 8)]
        XCTAssertEqual(SaetzeProMuskel.aussage(z), "1 von 3 Muskelgruppen im Wochenziel")
        XCTAssertEqual(SaetzeProMuskel.kernzeile(z), "Am meisten fehlt Rücken: noch 12 Sätze.")
        XCTAssertEqual(SaetzeProMuskel.kernzeile([SatzZeile(gruppe: .brust, saetze: 12, ziel: 12)]), "Alle Wochenziele sind erreicht.")
        XCTAssertEqual(SaetzeProMuskel.kernzeile([SatzZeile(gruppe: .brust, saetze: 0, ziel: 12)]), "Diese Woche noch kein Satz. Tipp auf Starten, Lumi zählt mit.")
        XCTAssertEqual(SaetzeProMuskel.aussage([]), "Noch keine Wochenziele")
    }
}
