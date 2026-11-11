import XCTest
@testable import LumenFit

final class GymVerpasstLogikTests: XCTestCase {
    /// Mittwoch, 11.11.2026; gestern Dienstag.
    private let heute = "2026-11-11"
    private let gestern = "2026-11-10"
    private let ohneMuskeln: (TrainingsTag) -> Set<String> = { _ in [] }

    private func tag(_ id: String, _ name: String, _ wochentage: [Int]) -> TrainingsTag {
        TrainingsTag(id: id, name: name, wochentage: wochentage, uebungen: [])
    }

    /// Mo Push, Di Pull, Do Beine, sonst Ruhe.
    private var plan: TrainingsPlan {
        TrainingsPlan(tage: [tag("push", "Push", [1]), tag("pull", "Pull", [2]), tag("beine", "Beine", [4])], ruhetage: [3, 5, 6, 7])
    }

    private func karte(_ p: TrainingsPlan? = nil, heute h: String? = nil, gymTage: Set<String> = [], laeuft: Bool = false, beantwortet: Set<String> = [],
                       schwerpunkt: ((TrainingsTag) -> Set<String>)? = nil) -> GymVerpasst? {
        GymVerpasstLogik.karte(plan: p ?? plan, heute: h ?? heute, gymTage: gymTage, laeuft: laeuft, beantwortet: beantwortet,
                               schwerpunkt: schwerpunkt ?? ohneMuskeln)
    }

    func testZeigtWennGesternGeplantUndNichtsGemacht() throws {
        let k = try XCTUnwrap(karte(gymTage: ["2026-11-09"]))
        XCTAssertEqual(k.gestern, gestern)
        XCTAssertEqual(k.tag.id, "pull")
        XCTAssertEqual(k.wochentag, "Dienstag")
        XCTAssertEqual(k.name, "Pull")
        XCTAssertEqual(k.freie, ["2026-11-13", "2026-11-14", "2026-11-15"], "ab morgen bis Sonntag, Donnerstag ist Beine, heute zählt nicht")
        XCTAssertEqual(k.freiText, "Freitag ist frei, zwischen Beine und Ruhetag.")
        XCTAssertEqual(k.id, "verpasst.2026-11-10")
    }

    func testNichtWennGesternTrainiert() {
        XCTAssertNil(karte(gymTage: [gestern]))
    }

    func testNichtWennHeuteTrainiertOderTrainingLaeuft() {
        XCTAssertNil(karte(gymTage: [heute]))
        XCTAssertNil(karte(laeuft: true))
    }

    func testNichtWennSchonBeantwortet() {
        XCTAssertNil(karte(beantwortet: [GymVerpasstLogik.id(gestern)]))
        XCTAssertNotNil(karte(beantwortet: [GymVerpasstLogik.id("2026-11-03")]), "eine alte Antwort zählt nicht für gestern")
    }

    func testNichtWennGesternRuhetag() {
        XCTAssertNil(karte(heute: "2026-11-12"), "Mittwoch war Ruhetag")
    }

    func testOhneFreienTagLeereListe() throws {
        let voll = TrainingsPlan(tage: [tag("pull", "Pull", [2]), tag("rest", "Ganzkörper", [4, 5, 6, 7])], ruhetage: [1, 3])
        let k = try XCTUnwrap(karte(voll))
        XCTAssertEqual(k.freie, [])
        XCTAssertNil(k.freiText)
    }

    func testTageNebenGleichenMuskelnKommenNachHinten() throws {
        // Mo Push, Di Pull, Do Rücken: Freitag läge direkt nach Rücken, Pull trainiert auch den Rücken.
        let p = TrainingsPlan(tage: [tag("push", "Push", [1]), tag("pull", "Pull", [2]), tag("ruecken", "Rücken", [4])], ruhetage: [3, 5, 6, 7])
        let muskeln: (TrainingsTag) -> Set<String> = { ["push": ["Brust"], "pull": ["Rücken", "Bizeps"], "ruecken": ["Rücken"]][$0.id] ?? [] }
        let k = try XCTUnwrap(karte(p, schwerpunkt: muskeln))
        XCTAssertEqual(k.freie, ["2026-11-14", "2026-11-15", "2026-11-13"])
        XCTAssertEqual(k.freiText, "Samstag ist frei, zwischen Ruhetag und Ruhetag.")
    }

    func testNachholenVerlegtNurDieseWocheUndKarteGehtWeg() throws {
        let k = try XCTUnwrap(karte())
        let neu = try XCTUnwrap(WochenLogik.verlegen(plan, von: k.gestern, auf: "2026-11-13", heute: heute))
        XCTAssertEqual(TrainingLogik.tag(neu, datum: "2026-11-13")?.id, "pull")
        XCTAssertNil(TrainingLogik.tag(neu, datum: "2026-11-20"), "nächste Woche gilt der feste Plan")
        XCTAssertEqual(TrainingLogik.tag(neu, datum: "2026-11-17")?.id, "pull")
        XCTAssertNil(karte(neu), "gestern ist danach kein offener Trainingstag mehr")
    }

    func testVorbelegtMitWertenVomLetztenMalUndAbgehakt() {
        let bank = PlanUebung(id: "u0", uebung: "bankdruecken", name: nil, saetze: Array(repeating: PlanSatz(wdh: 10, kg: 20, failure: false), count: 3), minuten: nil)
        let lauf = PlanUebung(id: "u1", uebung: "laufband", name: nil, saetze: [], minuten: 15)
        let t = TrainingsTag(id: "pull", name: "Pull", wochentage: [2], uebungen: [bank, lauf])
        let frueher = GymSession(id: "alt", tag: "pull", start: Datum.datum("2026-11-03"), ende: nil, laeufe: [
            UebungsLauf(plan: "u0", uebung: "bankdruecken", start: nil, ende: nil, fertig: false, saetze: nil,
                        stand: [PlanSatz(wdh: 12, kg: 25, failure: false, ok: true), PlanSatz(wdh: 10, kg: 27.5, failure: false, ok: true)])
        ])
        let liste = GymVerpasstLogik.vorbelegt(t, frueher: [frueher])
        XCTAssertEqual(liste.map(\.id), ["u0", "u1"])
        XCTAssertEqual(liste[0].saetze.map(\.kg), [25, 27.5, 20])
        XCTAssertEqual(liste[0].saetze.map(\.wdh), [12, 10, 10])
        XCTAssertTrue(liste[0].saetze.allSatisfy { $0.ok == true }, "nachgetragen heißt gemacht")
        XCTAssertTrue(liste[1].cardioFertig)
        XCTAssertTrue(liste[1].saetze.isEmpty)
    }
}
