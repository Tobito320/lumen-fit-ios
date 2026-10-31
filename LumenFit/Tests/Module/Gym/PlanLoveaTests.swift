import XCTest
@testable import LumenFit

/// Plan und Splits im Lovea-Aufbau: Filter der Bibliothek, gewählter Tag im Editor, Texte, Schieben einer Übung.
final class PlanLoveaLogikTests: XCTestCase {
    private func vorlage(_ id: String) -> SplitVorlage {
        SplitVorlage(id: id, name: id, gruppe: "m", level: "mittel", ziel: "muskeln", geraet: "studio", tage: 3, einheiten: [])
    }

    private func uebung(_ id: String, wdh: Int = 10, kg: Double? = nil, saetze: Int = 3) -> PlanUebung {
        PlanUebung(id: id, uebung: PlanUebung.eigen, name: id, saetze: Array(repeating: PlanSatz(wdh: wdh, kg: kg, failure: false), count: saetze), minuten: nil)
    }

    private func tag(_ id: String, wochentage: [Int] = [], uebungen: [PlanUebung] = []) -> TrainingsTag {
        TrainingsTag(id: id, name: id, wochentage: wochentage, uebungen: uebungen)
    }

    func testFuerDichNurMitEigenenSplits() {
        let ohne = [vorlage("m-a"), vorlage("m-b")]
        let mit = ohne + [vorlage("m-empf01")]
        XCTAssertFalse(PlanLoveaLogik.artWahl(ohne).contains { $0.id == "fuerdich" })
        XCTAssertTrue(PlanLoveaLogik.artWahl(mit).contains { $0.id == "fuerdich" })
        XCTAssertEqual(PlanLoveaLogik.artWahl(ohne).count, SplitLogik.artWahl.count - 1)
    }

    func testStartartUndWirksameArt() {
        let ohne = [vorlage("m-a")]
        let mit = [vorlage("m-a"), vorlage("m-empf01")]
        XCTAssertNil(PlanLoveaLogik.startArt(ohne))
        XCTAssertEqual(PlanLoveaLogik.startArt(mit), "fuerdich")
        // Ein gemerktes "Für dich" ohne eigene Splits darf die Liste nicht leeren.
        XCTAssertNil(PlanLoveaLogik.wirksameArt("fuerdich", ohne))
        XCTAssertEqual(PlanLoveaLogik.wirksameArt("fuerdich", mit), "fuerdich")
        XCTAssertEqual(PlanLoveaLogik.wirksameArt("kraft", ohne), "kraft")
        XCTAssertNil(PlanLoveaLogik.wirksameArt(nil, mit))
    }

    func testGewaehlterTagFaelltAufStartDanachAufDenErsten() {
        let plan = TrainingsPlan(tage: [tag("a"), tag("b"), tag("c")])
        XCTAssertEqual(PlanLoveaLogik.gewaehlterTag(plan, gewaehlt: "c", start: "b"), "c")
        XCTAssertEqual(PlanLoveaLogik.gewaehlterTag(plan, gewaehlt: nil, start: "b"), "b")
        XCTAssertEqual(PlanLoveaLogik.gewaehlterTag(plan, gewaehlt: nil, start: nil), "a")
        // Gelöschter Tag: weder der gewählte noch der Start gilt.
        XCTAssertEqual(PlanLoveaLogik.gewaehlterTag(plan, gewaehlt: "weg", start: "auch weg"), "a")
        XCTAssertNil(PlanLoveaLogik.gewaehlterTag(.leer, gewaehlt: "a", start: "b"))
    }

    func testNeuerTagNurBisSechs() {
        let fuenf = TrainingsPlan(tage: (1...5).map { tag("t\($0)") })
        XCTAssertTrue(PlanLoveaLogik.darfNeuerTag(fuenf))
        XCTAssertFalse(PlanLoveaLogik.darfNeuerTag(TrainingsPlan(tage: (1...6).map { tag("t\($0)") })))
        XCTAssertTrue(PlanLoveaLogik.darfNeuerTag(.leer))
    }

    func testZeilentexte() {
        XCTAssertEqual(PlanLoveaLogik.wochentageText(tag("a")), "flexibel")
        XCTAssertEqual(PlanLoveaLogik.wochentageText(tag("a", wochentage: [1, 4])), TrainingLogik.wochentageText([1, 4]))
        XCTAssertEqual(PlanLoveaLogik.uebungenText(tag("a")), "Noch keine Übungen")
        XCTAssertEqual(PlanLoveaLogik.uebungenText(tag("a", uebungen: [uebung("Bank"), uebung("Dips")])), "Bank · Dips")
        var ohneName = tag("a")
        ohneName.name = ""
        XCTAssertEqual(PlanLoveaLogik.tagName(ohneName), "Ohne Namen")
    }

    func testWochenleisteTexte() {
        let t = tag("Push", wochentage: [1])
        XCTAssertEqual(PlanLoveaLogik.titel(.training(t)), "Push")
        XCTAssertEqual(PlanLoveaLogik.titel(.ruhe), "Ruhe")
        XCTAssertEqual(PlanLoveaLogik.titel(.offen), "?")
        XCTAssertEqual(PlanLoveaLogik.beschreibung(.ruhe), "Ruhetag")
        XCTAssertEqual(PlanLoveaLogik.beschreibung(.offen), "noch nicht geplant")
        var leer = t
        leer.name = ""
        XCTAssertEqual(PlanLoveaLogik.titel(.training(leer)), "Training")
    }

    func testGewichtUndWiederholungenSchnellzeile() {
        XCTAssertEqual(PlanLoveaLogik.kgText(uebung("a")), "ohne")
        XCTAssertEqual(PlanLoveaLogik.kgText(uebung("a", kg: 40)), "\(TrainingLogik.kgText(40)) kg")
        var gemischt = uebung("a", kg: 40)
        gemischt.saetze[1].kg = 45
        XCTAssertEqual(PlanLoveaLogik.kgText(gemischt), "gemischt")
        XCTAssertEqual(PlanLoveaLogik.wdhText(uebung("a", wdh: 8)), "8")
        gemischt.saetze[2].wdh = 6
        XCTAssertEqual(PlanLoveaLogik.wdhText(gemischt), "gemischt")
        XCTAssertEqual(PlanLoveaLogik.wdhText(uebung("a", saetze: 0)), "10")
    }

    func testTagFarbeBleibtImBereich() {
        // Kein Absturz bei Index außerhalb: unter 0 die erste, über der Obergrenze die letzte (flexible Tage).
        _ = PlanLoveaLogik.tagFarbe(-3)
        _ = PlanLoveaLogik.tagFarbe(TagFarbe.flexibel)
        _ = PlanLoveaLogik.tagFarbe(99)
    }

    func testSchiebenVerschiebtUmEineStelleUndHaeltDenRand() {
        let t = tag("a", uebungen: [uebung("u1"), uebung("u2"), uebung("u3")])
        XCTAssertEqual(PlanEditor.schieben(t, id: "u2", um: -1).uebungen.map(\.id), ["u2", "u1", "u3"])
        XCTAssertEqual(PlanEditor.schieben(t, id: "u2", um: 1).uebungen.map(\.id), ["u1", "u3", "u2"])
        XCTAssertEqual(PlanEditor.schieben(t, id: "u1", um: -1), t)
        XCTAssertEqual(PlanEditor.schieben(t, id: "u3", um: 1), t)
        XCTAssertEqual(PlanEditor.schieben(t, id: "gibtsnicht", um: 1), t)
    }

    func testSchiebenLoestDieSupersatzKopplung() {
        var t = tag("a", uebungen: [uebung("u1"), uebung("u2")])
        t.uebungen[0].supersatz = true
        XCTAssertTrue(PlanEditor.schieben(t, id: "u1", um: 1).uebungen.allSatisfy { $0.supersatz == nil })
    }
}
