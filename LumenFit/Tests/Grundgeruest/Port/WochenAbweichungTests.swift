// Quelle: Lovea Tests/WochenAbweichungTests.swift
import XCTest
@testable import LumenFit

/// Verlegen und Testwoche (`WochenLogik`): eine Abweichung gilt nur für ihre Kalenderwoche (Mo bis So),
/// gelesen wird überall über `TrainingLogik.tag`. 2026-10-05 ist ein Montag.
@MainActor
final class WochenAbweichungTests: XCTestCase {
    private let mo = "2026-10-05", di = "2026-10-06", mi = "2026-10-07", don = "2026-10-08"
    private let fr = "2026-10-09", sa = "2026-10-10", so = "2026-10-11"
    private let naechsteMo = "2026-10-12", naechsteMi = "2026-10-14", naechsteDon = "2026-10-15"

    private func tag(_ name: String, _ wochentage: [Int], uebungen: Int = 0) -> TrainingsTag {
        TrainingsTag(id: name, name: name, wochentage: wochentage, uebungen: (0..<uebungen).map {
            PlanUebung(id: "\(name)\($0)", uebung: "x", name: "U", saetze: [], minuten: nil)
        })
    }

    /// Push Mo, Pull Mi, Beine Fr; ids gleich Namen.
    private var plan: TrainingsPlan {
        TrainingsPlan(tage: [tag("Push", [1], uebungen: 2), tag("Pull", [3], uebungen: 1), tag("Beine", [5], uebungen: 3)],
                      ruhetage: [2, 4, 6, 7], splitName: "Upper Lower")
    }

    private func vorlage(_ einheiten: [(String, [Int])], name: String = "Testsplit") -> SplitVorlage {
        SplitVorlage(id: "t", name: name, gruppe: "m", level: "mittel", ziel: "fit", geraet: "studio", tage: einheiten.count,
                     einheiten: einheiten.map {
                         SplitVorlage.Einheit(name: $0.0, wochentage: $0.1, uebungen: [SplitVorlage.Zeile(uebung: "x", saetze: 3, von: 8, bis: 12)])
                     })
    }

    /// Oben Di, Unten Do, Core Sa.
    private var testSplit: SplitVorlage { vorlage([("Oben", [2]), ("Unten", [4]), ("Core", [6])]) }

    private func starteTest(_ v: SplitVorlage? = nil, heute: String? = nil, gemacht: Set<String> = [], auf basis: TrainingsPlan? = nil) throws -> TrainingsPlan {
        try XCTUnwrap(WochenLogik.testStarten(basis ?? plan, vorlage: v ?? testSplit, heute: heute ?? mo, gemacht: gemacht))
    }

    private func verlege(_ von: String, _ auf: String, heute: String? = nil, in basis: TrainingsPlan? = nil) throws -> TrainingsPlan {
        try XCTUnwrap(WochenLogik.verlegen(basis ?? plan, von: von, auf: auf, heute: heute ?? mo))
    }

    private func tagName(_ p: TrainingsPlan, _ datum: String) -> String? { TrainingLogik.tag(p, datum: datum)?.name }

    private func wochenTest(_ p: TrainingsPlan, woche: String? = nil) -> WochenAbweichung.Test? {
        WochenLogik.abweichung(p, woche: woche ?? mo)?.test
    }

    // MARK: - Ohne Abweichung

    func testOhneAbweichungBleibtDerPlanWieEr() {
        let p = plan
        XCTAssertEqual(WochenLogik.effektiverPlan(p, woche: mi), p)
        XCTAssertNil(WochenLogik.abweichung(p, woche: mi))
        XCTAssertNil(WochenLogik.testHinweis(p, heute: mi))
        XCTAssertFalse(WochenLogik.verlegt(p, heute: mi))
        XCTAssertEqual(tagName(p, mi), "Pull")
        XCTAssertNil(tagName(p, di))
    }

    // MARK: - Verlegen

    func testVerlegenAufFreienTagGiltNurDieseWoche() throws {
        let p = plan
        let neu = try verlege(mi, don)
        XCTAssertEqual(tagName(neu, don), "Pull")
        XCTAssertNil(tagName(neu, mi), "der alte Tag ist frei")
        XCTAssertEqual(tagName(neu, mo), "Push")
        XCTAssertEqual(tagName(neu, fr), "Beine")
        XCTAssertEqual(neu.tage, p.tage, "der feste Plan bleibt")
        XCTAssertEqual(neu.ruhetage, p.ruhetage)
        XCTAssertEqual(neu.splitName, "Upper Lower")
        XCTAssertEqual(neu.wochen?.map(\.montag), [mo])
        XCTAssertTrue(WochenLogik.verlegt(neu, heute: don))
        XCTAssertEqual(WochenLogik.effektiverPlan(neu, woche: don).ruhetage, [2, 3, 6, 7])
        XCTAssertEqual(tagName(neu, naechsteMi), "Pull", "nächste Woche gilt wieder der feste Plan")
        XCTAssertNil(tagName(neu, naechsteDon))
        XCTAssertFalse(WochenLogik.verlegt(neu, heute: naechsteMo))
    }

    func testVerlegenAufBelegtenTagTauscht() throws {
        let neu = try verlege(mi, fr)
        XCTAssertEqual(tagName(neu, mi), "Beine")
        XCTAssertEqual(tagName(neu, fr), "Pull")
        XCTAssertEqual(tagName(neu, mo), "Push")
        XCTAssertEqual(tagName(neu, naechsteMi), "Pull")
        XCTAssertEqual(tagName(neu, "2026-10-16"), "Beine")
    }

    func testNichtInDieVergangenheitVerlegen() {
        let ziele = WochenLogik.verlegeZiele(plan, von: fr, heute: mi)
        XCTAssertEqual(ziele.map(\.datum), [mi, don, sa, so])
        XCTAssertEqual(ziele.map(\.text), ["Mittwoch · tauscht mit Pull", "Donnerstag · frei", "Samstag · frei", "Sonntag · frei"])
        XCTAssertNil(WochenLogik.verlegen(plan, von: fr, auf: mo, heute: mi), "Montag ist vorbei")
        XCTAssertNil(WochenLogik.verlegen(plan, von: fr, auf: di, heute: mi), "Dienstag ist vorbei")
        XCTAssertNil(WochenLogik.verlegen(plan, von: fr, auf: naechsteMo, heute: mi), "nur diese Woche")
        XCTAssertNil(WochenLogik.verlegen(plan, von: fr, auf: fr, heute: mi), "nicht auf sich selbst")
        XCTAssertTrue(WochenLogik.verlegeZiele(plan, von: "2026-10-16", heute: mi).isEmpty, "Tag einer anderen Woche")
    }

    func testVerpassterTagNurAufFreienTagAbHeute() throws {
        let ziele = WochenLogik.verlegeZiele(plan, von: mi, heute: don)
        XCTAssertEqual(ziele.map(\.datum), [don, sa, so])
        XCTAssertTrue(ziele.allSatisfy { $0.text.hasSuffix("frei") })
        XCTAssertNil(WochenLogik.verlegen(plan, von: mi, auf: fr, heute: don), "kein Tausch für einen verpassten Tag")
        let neu = try XCTUnwrap(WochenLogik.verlegen(plan, von: mi, auf: sa, heute: don))
        XCTAssertEqual(tagName(neu, sa), "Pull")
        XCTAssertNil(tagName(neu, mi))
    }

    func testErledigterTagBleibtStehenUndIstKeinZiel() {
        XCTAssertTrue(WochenLogik.verlegeZiele(plan, von: mi, heute: mi, gemacht: [mi]).isEmpty)
        XCTAssertNil(WochenLogik.verlegen(plan, von: mi, auf: don, heute: mi, gemacht: [mi]))
        let ziele = WochenLogik.verlegeZiele(plan, von: fr, heute: mi, gemacht: [don])
        XCTAssertEqual(ziele.map(\.datum), [mi, sa, so], "Donnerstag hat schon eine Einheit")
    }

    func testRuhetagHatKeineZiele() {
        XCTAssertTrue(WochenLogik.verlegeZiele(plan, von: di, heute: mo).isEmpty)
        XCTAssertNil(WochenLogik.verlegen(plan, von: di, auf: don, heute: mo))
    }

    func testZweitesVerlegenBautAufDemErstenAuf() throws {
        let erst = try verlege(mi, don)
        XCTAssertEqual(WochenLogik.verlegeZiele(erst, von: don, heute: mo).map(\.datum), [mo, di, mi, fr, sa, so])
        let zweit = try verlege(don, sa, in: erst)
        XCTAssertEqual(tagName(zweit, sa), "Pull")
        XCTAssertNil(tagName(zweit, don))
        XCTAssertNil(tagName(zweit, mi))
        XCTAssertEqual(tagName(zweit, mo), "Push")
        XCTAssertEqual(tagName(zweit, fr), "Beine")
        XCTAssertEqual(zweit.wochen?.count, 1, "eine Woche, ein Eintrag")
        XCTAssertEqual(tagName(zweit, naechsteMi), "Pull")
    }

    func testZurueckAufPlan() throws {
        let neu = try verlege(mi, don)
        let zurueck = WochenLogik.verlegungenLoeschen(neu, heute: don)
        XCTAssertNil(zurueck.wochen)
        XCTAssertEqual(zurueck, plan)
        XCTAssertEqual(tagName(zurueck, mi), "Pull")
        XCTAssertFalse(WochenLogik.verlegt(zurueck, heute: don))
    }

    func testSchreibenRaeumtAlteWochenAuf() throws {
        var p = plan
        p.wochen = [WochenAbweichung(montag: "2026-01-05", plaetze: [WochenAbweichung.Platz(wochentag: 3, tag: nil)])]
        let neu = try verlege(mi, don, in: p)
        XCTAssertEqual(neu.wochen?.map(\.montag), [mo])
    }

    func testAufraeumenWirftAlteUndLeereWeg() {
        func eintrag(_ montag: String, platz: Bool = true) -> WochenAbweichung {
            WochenAbweichung(montag: montag, plaetze: platz ? [WochenAbweichung.Platz(wochentag: 3, tag: nil)] : [])
        }
        // Woche ab 2026-10-05, acht Wochen davor ist 2026-08-10.
        let rest = WochenLogik.aufraeumen([eintrag("2026-01-05"), eintrag("2026-08-03"), eintrag("2026-08-10"), eintrag("2026-09-28", platz: false), eintrag(mo)], heute: mi)
        XCTAssertEqual(rest?.map(\.montag), ["2026-08-10", mo])
        XCTAssertNil(WochenLogik.aufraeumen([eintrag("2026-01-05"), eintrag(mo, platz: false)], heute: mi))
        XCTAssertNil(WochenLogik.aufraeumen([], heute: mi))
    }

    // MARK: - Testwoche

    func testTestwocheAbMontag() throws {
        let p = plan
        let neu = try starteTest()
        XCTAssertEqual(tagName(neu, mo), "Oben")
        XCTAssertEqual(tagName(neu, mi), "Unten")
        XCTAssertEqual(tagName(neu, fr), "Core")
        for frei in [di, don, sa, so] { XCTAssertNil(tagName(neu, frei), frei) }
        XCTAssertEqual(tagName(neu, naechsteMo), "Push", "ab nächster Woche wieder der normale Split")
        XCTAssertEqual(tagName(neu, naechsteMi), "Pull")
        XCTAssertEqual(WochenLogik.testHinweis(neu, heute: mi), "Testwoche: Testsplit, ab Montag wieder Upper Lower")
        XCTAssertNil(WochenLogik.testHinweis(neu, heute: naechsteMo))
        XCTAssertEqual(neu.tage, p.tage, "fester Plan und Split bleiben")
        XCTAssertEqual(neu.ruhetage, p.ruhetage)
        XCTAssertEqual(neu.splitName, "Upper Lower")
        XCTAssertEqual(wochenTest(neu)?.split, "Testsplit")
        XCTAssertEqual(wochenTest(neu)?.ab, 1)
    }

    func testTestwocheMittenInDerWoche() throws {
        let neu = try starteTest(heute: mi)
        XCTAssertEqual(tagName(neu, mo), "Push", "vergangene Tage bleiben")
        XCTAssertEqual(tagName(neu, mi), "Oben")
        XCTAssertEqual(tagName(neu, fr), "Unten")
        XCTAssertNil(tagName(neu, sa))
        XCTAssertEqual(wochenTest(neu)?.ab, 3)
        XCTAssertEqual(wochenTest(neu)?.tage.map(\.name), ["Oben", "Unten"], "Core fällt weg")
        XCTAssertEqual(WochenLogik.effektiverPlan(neu, woche: mi).tage.map(\.name), ["Push", "Oben", "Unten"])
    }

    func testTestwocheStartetNachHeuteWennHeuteSchonTrainiert() throws {
        let neu = try starteTest(heute: mi, gemacht: [mi])
        XCTAssertEqual(wochenTest(neu)?.ab, 4)
        XCTAssertEqual(tagName(neu, mi), "Pull", "heute bleibt, wie es war")
        XCTAssertEqual(tagName(neu, fr), "Oben")
        XCTAssertNil(tagName(neu, sa))
        XCTAssertEqual(wochenTest(neu)?.tage.map(\.name), ["Oben"])
    }

    func testWenigerEinheitenMachenRuhetage() throws {
        let neu = try starteTest(vorlage([("Solo", [3])]))
        XCTAssertEqual(tagName(neu, mo), "Solo")
        XCTAssertNil(tagName(neu, mi))
        XCTAssertNil(tagName(neu, fr))
        XCTAssertEqual(WochenLogik.effektiverPlan(neu, woche: mo).ruhetage, [2, 3, 4, 5, 6, 7])
    }

    func testTestwocheAmSonntag() throws {
        let neu = try starteTest(heute: so)
        XCTAssertEqual(wochenTest(neu)?.ab, 7)
        XCTAssertEqual(tagName(neu, so), "Oben", "Sonntag gehört noch zur Woche ab Montag 5.")
        XCTAssertEqual(tagName(neu, mo), "Push")
        XCTAssertEqual(tagName(neu, mi), "Pull")
        XCTAssertEqual(tagName(neu, fr), "Beine")
        XCTAssertEqual(tagName(neu, naechsteMo), "Push")
        XCTAssertNil(tagName(neu, "2026-10-18"), "nächster Sonntag: kein Test mehr")
        XCTAssertNil(WochenLogik.testStarten(plan, vorlage: testSplit, heute: so, gemacht: [so]), "Sonntag schon trainiert: kein Tag mehr")
    }

    func testTestwocheAbbrechen() throws {
        let neu = try starteTest()
        let zurueck = WochenLogik.testAbbrechen(neu, heute: mi)
        XCTAssertNil(zurueck.wochen)
        XCTAssertEqual(zurueck, plan)
        XCTAssertNil(WochenLogik.testHinweis(zurueck, heute: mi))
        XCTAssertEqual(tagName(zurueck, mi), "Pull")
    }

    func testTestwocheErsetztVerlegungen() throws {
        let verlegt = try verlege(mi, don)
        let neu = try starteTest(auf: verlegt)
        XCTAssertEqual(WochenLogik.abweichung(neu, woche: mo)?.plaetze.isEmpty, true)
        XCTAssertFalse(WochenLogik.verlegt(neu, heute: mo))
        XCTAssertEqual(tagName(neu, mi), "Unten")
        XCTAssertEqual(neu.wochen?.count, 1)
    }

    func testVerlegenInnerhalbDerTestwoche() throws {
        let testet = try starteTest()
        let ziele = WochenLogik.verlegeZiele(testet, von: mi, heute: mo)
        XCTAssertTrue(ziele.contains(WochenLogik.Ziel(datum: don, text: "Donnerstag · frei")))
        let neu = try verlege(mi, don, in: testet)
        XCTAssertEqual(tagName(neu, don), "Unten")
        XCTAssertNil(tagName(neu, mi))
        XCTAssertEqual(tagName(neu, mo), "Oben")
        XCTAssertEqual(tagName(neu, fr), "Core")
        XCTAssertNotNil(WochenLogik.testHinweis(neu, heute: mo), "die Testwoche läuft weiter")
        XCTAssertEqual(tagName(neu, naechsteMi), "Pull")
    }

    func testTestHinweisOhneSplitNameSagtDeinPlan() throws {
        var p = plan
        p.splitName = nil
        let neu = try starteTest(auf: p)
        XCTAssertEqual(WochenLogik.testHinweis(neu, heute: mo), "Testwoche: Testsplit, ab Montag wieder dein Plan")
    }

    func testWaehlbarZaehltTestEinheitenNurInDerTestwoche() throws {
        XCTAssertEqual(WochenLogik.waehlbar(plan, heute: mi).count, 3)
        let neu = try starteTest()
        XCTAssertEqual(WochenLogik.waehlbar(neu, heute: mi).count, 6)
        XCTAssertEqual(WochenLogik.waehlbar(neu, heute: naechsteMi).count, 3)
    }

    // MARK: - Zuordnung

    func testZuordnungSortiertNachWochentagDerEinheit() {
        let v = vorlage([("Core", [6]), ("Oben", [2]), ("Unten", [4])])
        let z = WochenLogik.zuordnung(plan, vorlage: v, ab: 1)
        XCTAssertEqual(z.map { $0.einheit }, [1, 2, 0])
        XCTAssertEqual(z.map { $0.wochentag }, [1, 3, 5])
        let ganz = WochenLogik.zuordnung(plan, vorlage: vorlage([("Ganzkörper", [1, 3, 5])]), ab: 1)
        XCTAssertEqual(ganz.map { $0.wochentag }, [1, 3, 5], "eine Einheit auf drei Tagen")
        let neu = WochenLogik.testStarten(plan, vorlage: vorlage([("Ganzkörper", [1, 3, 5])]), heute: mo)
        XCTAssertEqual(wochenTest(neu ?? plan)?.tage.first?.wochentage, [1, 3, 5])
    }

    func testZuordnungOhneFesteTageNimmtDieDesSplits() {
        let nurMontag = TrainingsPlan(tage: [tag("Push", [1])], ruhetage: [2, 3, 4, 5, 6, 7])
        let z = WochenLogik.zuordnung(nurMontag, vorlage: testSplit, ab: 3)
        XCTAssertEqual(z.map { $0.wochentag }, [4, 6], "feste Tage des Splits ab Mittwoch")
        let spaet = WochenLogik.zuordnung(nurMontag, vorlage: testSplit, ab: 7)
        XCTAssertEqual(spaet.map { $0.wochentag }, [7], "sonst alle Tage bis Sonntag")
    }

    // MARK: - Zentrale Anzeige

    func testTagMitIdAuchNachDerTestwoche() throws {
        let neu = try starteTest()
        let oben = try XCTUnwrap(wochenTest(neu)?.tage.first)
        XCTAssertEqual(oben.name, "Oben")
        XCTAssertEqual(oben.uebungen.count, 1)
        XCTAssertFalse(neu.tage.contains { $0.id == oben.id }, "nicht im festen Plan")
        XCTAssertEqual(neu.tag(id: oben.id)?.name, "Oben")
        XCTAssertEqual(neu.tag(id: "Push")?.name, "Push")
        XCTAssertNil(neu.tag(id: nil))
        XCTAssertNil(neu.tag(id: "gibt-es-nicht"))
        XCTAssertEqual(TrainingLogik.tag(neu, datum: naechsteMo)?.id, "Push")
    }

    func testTagSetzenAufTestEinheitLaesstFestenPlanUnberuehrt() throws {
        let neu = try starteTest()
        var oben = try XCTUnwrap(wochenTest(neu)?.tage.first)
        oben.name = "Oben neu"
        oben.wochentage = [6]
        oben.uebungen = []
        let r = TrainingLogik.tagSetzen(neu, oben)
        XCTAssertEqual(r.tage, neu.tage)
        XCTAssertEqual(r.ruhetage, neu.ruhetage)
        XCTAssertEqual(r.tag(id: oben.id)?.name, "Oben neu")
        XCTAssertEqual(r.tag(id: oben.id)?.uebungen.count, 0)
        XCTAssertEqual(r.tag(id: oben.id)?.wochentage, [1], "der Wochentag der Testwoche bleibt")
        var push = try XCTUnwrap(neu.tag(id: "Push"))
        push.name = "Push neu"
        XCTAssertEqual(TrainingLogik.tagSetzen(neu, push).tage.first?.name, "Push neu", "ein fester Tag wie bisher")
    }

    func testAendernErreichtUebungEinerTestEinheit() throws {
        let neu = try starteTest()
        let oben = try XCTUnwrap(wochenTest(neu)?.tage.first)
        let uebungId = try XCTUnwrap(oben.uebungen.first?.id)
        let r = TrainingLogik.aendern(neu, planUebung: uebungId) { $0.notiz = "Sitz 4" }
        XCTAssertEqual(r.tag(id: oben.id)?.uebungen.first?.notiz, "Sitz 4")
        XCTAssertEqual(r.tage, neu.tage, "fester Plan bleibt")
        let satz = [PlanSatz(wdh: 5, kg: 50, failure: false)]
        XCTAssertEqual(TrainingLogik.uebernehmen(neu, planUebung: uebungId, saetze: satz).tag(id: oben.id)?.uebungen.first?.saetze, satz)
        let fest = TrainingLogik.aendern(neu, planUebung: "Push0") { $0.notiz = "x" }
        XCTAssertEqual(fest.tag(id: "Push")?.uebungen.first?.notiz, "x")
        XCTAssertEqual(fest.tag(id: oben.id), oben, "Testeinheit unberührt")
    }

    func testEffektiverPlanIstIdempotent() throws {
        let neu = try verlege(mi, don, in: try starteTest())
        let einmal = WochenLogik.effektiverPlan(neu, woche: mi)
        XCTAssertNil(einmal.wochen)
        XCTAssertEqual(WochenLogik.effektiverPlan(einmal, woche: mi), einmal)
    }

    // MARK: - Wochenschlüssel, Jahreswechsel, deutscher Kalender

    func testWochenschluesselUmDenJahreswechsel() {
        XCTAssertEqual(Datum.montagDerWoche("2026-12-28"), "2026-12-28")
        XCTAssertEqual(Datum.montagDerWoche("2026-12-31"), "2026-12-28")
        XCTAssertEqual(Datum.montagDerWoche("2027-01-01"), "2026-12-28")
        XCTAssertEqual(Datum.montagDerWoche("2027-01-03"), "2026-12-28")
        XCTAssertEqual(Datum.montagDerWoche("2027-01-04"), "2027-01-04")
    }

    func testVerlegenUeberDenJahreswechsel() throws {
        let neu = try XCTUnwrap(WochenLogik.verlegen(plan, von: "2026-12-30", auf: "2027-01-01", heute: "2026-12-30"))
        XCTAssertEqual(neu.wochen?.map(\.montag), ["2026-12-28"])
        XCTAssertEqual(tagName(neu, "2026-12-28"), "Push")
        XCTAssertEqual(tagName(neu, "2026-12-30"), "Beine")
        XCTAssertEqual(tagName(neu, "2027-01-01"), "Pull", "Neujahr gehört noch zur Woche ab 28.12.")
        XCTAssertEqual(tagName(neu, "2027-01-04"), "Push")
        XCTAssertEqual(tagName(neu, "2027-01-06"), "Pull", "nächste Woche wieder der feste Plan")
        XCTAssertEqual(tagName(neu, "2027-01-08"), "Beine")
    }

    func testTestwocheUeberDenJahreswechsel() throws {
        let neu = try starteTest(heute: "2027-01-01")
        XCTAssertEqual(wochenTest(neu, woche: "2027-01-03")?.split, "Testsplit", "Sonntag 3.1. gehört zur Woche ab 28.12.")
        XCTAssertNil(wochenTest(neu, woche: "2027-01-04"))
        XCTAssertEqual(tagName(neu, "2027-01-01"), "Oben")
        XCTAssertEqual(tagName(neu, "2027-01-04"), "Push")
    }

    func testDeutscherKalenderWochenbeginntMontag() {
        XCTAssertEqual(Datum.kalender.firstWeekday, 2)
        XCTAssertEqual(Datum.kalender.timeZone.identifier, "Europe/Berlin")
        XCTAssertEqual(Datum.wochentag(mo), 1)
        XCTAssertEqual(Datum.wochentag(so), 7)
        XCTAssertEqual(Datum.montagDerWoche(so), mo, "Sonntag gehört zur Woche davor")
        XCTAssertEqual(Datum.montagDerWoche(mo), mo)
        XCTAssertEqual(Datum.montagDerWoche(naechsteMo), naechsteMo)
        XCTAssertEqual(Datum.montagDerWoche("2026-10-25"), "2026-10-19", "Sonntag mit Zeitumstellung")
        XCTAssertEqual(Datum.montagDerWoche("2026-10-26"), "2026-10-26")
        XCTAssertEqual(TrainingLogik.wochentagName.first, "Montag")
        XCTAssertEqual(TrainingLogik.wochentagName.last, "Sonntag")
    }

    // MARK: - Speichern

    func testCodableRundlaufUndAlteJSON() throws {
        let neu = try verlege(mi, don, in: try starteTest())
        let daten = try JSONEncoder().encode(neu)
        XCTAssertEqual(try JSONDecoder().decode(TrainingsPlan.self, from: daten), neu)
        let alt = try JSONDecoder().decode(TrainingsPlan.self, from: Data(#"{"tage":[]}"#.utf8))
        XCTAssertNil(alt.wochen, "alter Plan ohne Abweichungen")
        XCTAssertEqual(alt, .leer)
    }

    // MARK: - Gym-Start und Wochenleiste

}
