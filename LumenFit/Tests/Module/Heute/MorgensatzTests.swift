import XCTest
@testable import LumenFit

final class MorgensatzTests: XCTestCase {
    private func score(_ punkte: Int?, schlaf: Int? = 460) -> BereitScore.Ergebnis {
        var teile: [BereitScore.Teil] = []
        if let schlaf { teile.append(BereitScore.Teil(art: .schlaf, wert: 90, kurz: "Schlaf \(BereitScore.stunden(schlaf))", detail: "")) }
        let stufe: BereitScore.Stufe = punkte.map { $0 >= 70 ? .bereit : ($0 >= 45 ? .normal : .schonen) } ?? .keine
        return BereitScore.Ergebnis(punkte: punkte, stufe: stufe, teile: teile, fehlend: [], satz: "")
    }

    private func eingabe(_ punkte: Int?, wert: Int? = nil, plan: String? = "Beine", stunde: Int = 8) -> Morgensatz.Eingabe {
        Morgensatz.Eingabe(score: score(punkte), stimmungsWert: wert, planName: plan, stunde: stunde)
    }

    func testGutErholtNenntSchlafUndPlan() {
        let e = Morgensatz.sprich(eingabe(85))
        XCTAssertEqual(e.satz, "Gut erholt (Schlaf 7:40 h). Heute Beine?")
        XCTAssertEqual(e.stimmung, .bereit)
        XCTAssertFalse(e.locker)
    }

    func testStimmungFolgtDemScore() {
        XCTAssertEqual(Morgensatz.sprich(eingabe(85)).stimmung, .bereit)
        XCTAssertEqual(Morgensatz.sprich(eingabe(55)).stimmung, .bereit)
        XCTAssertEqual(Morgensatz.sprich(eingabe(30)).stimmung, .muede)
        XCTAssertEqual(Morgensatz.sprich(eingabe(nil)).stimmung, .denkt)
    }

    func testNormalerTagGehtImEigenenTempo() {
        XCTAssertEqual(Morgensatz.sprich(eingabe(60)).satz, "Solide Basis (Schlaf 7:40 h). Beine geht, im eigenen Tempo.")
    }

    func testSchwacherScoreSagtHeuteLocker() {
        let e = Morgensatz.sprich(eingabe(30))
        XCTAssertTrue(e.satz.contains("Heute locker."))
        XCTAssertTrue(e.satz.contains("Beine mit weniger Gewicht"))
        XCTAssertTrue(e.locker)
    }

    func testOhneScoreFehlenDaten() {
        let e = Morgensatz.sprich(eingabe(nil))
        XCTAssertTrue(e.satz.contains("Mir fehlen noch Daten"))
        XCTAssertFalse(e.locker)
    }

    // MARK: Morgen-Check

    func testWertEinsOderZweiMachtLumiMuedeUndDenPlanLocker() {
        for wert in [1, 2] {
            let e = Morgensatz.sprich(eingabe(90, wert: wert))
            XCTAssertEqual(e.stimmung, .muede, "Wert \(wert)")
            XCTAssertTrue(e.locker)
            XCTAssertTrue(e.satz.contains("Beine lieber leichter."))
        }
    }

    func testWertVierOderFuenfHebtDenBereitSatz() {
        for wert in [4, 5] {
            XCTAssertEqual(Morgensatz.sprich(eingabe(85, wert: wert)).satz, "Gut erholt (Schlaf 7:40 h), und du fühlst dich stark. Heute Beine?")
        }
        XCTAssertEqual(Morgensatz.sprich(eingabe(85, wert: 3)).satz, "Gut erholt (Schlaf 7:40 h). Heute Beine?", "Wert 3 ändert nichts")
        XCTAssertTrue(Morgensatz.sprich(eingabe(30, wert: 5)).satz.hasPrefix("Du fühlst dich gut, die Zahlen sagen Ruhe"))
    }

    func testSchwerGiltAuchOhneScore() {
        let e = Morgensatz.sprich(eingabe(nil, wert: 1, plan: nil))
        XCTAssertEqual(e.stimmung, .muede)
        XCTAssertTrue(e.satz.contains("Spaziergang"))
        XCTAssertTrue(Morgensatz.schwer(2))
        XCTAssertFalse(Morgensatz.schwer(3))
        XCTAssertFalse(Morgensatz.schwer(nil))
        XCTAssertTrue(Morgensatz.stark(4))
        XCTAssertFalse(Morgensatz.stark(nil))
    }

    // MARK: Besondere Fälle

    func testRuhetagUndKeinPlan() {
        var e = eingabe(85)
        e.ruhetag = true
        XCTAssertTrue(Morgensatz.sprich(e).satz.contains("Ruhetag"))
        e.ruhetag = false
        e.planName = nil
        XCTAssertTrue(Morgensatz.sprich(e).satz.contains("Bewegung tut dir heute gut"))
    }

    func testTrainiertUndAlleBoegenVollSindStolz() {
        var e = eingabe(30)
        e.trainiert = true
        XCTAssertEqual(Morgensatz.sprich(e).stimmung, .stolz)
        e.trainiert = false
        e.alleBoegenVoll = true
        XCTAssertEqual(Morgensatz.sprich(e).stimmung, .stolz)
    }

    func testNachtsSchlaeftLumi() {
        XCTAssertEqual(Morgensatz.sprich(eingabe(85, stunde: 23)).stimmung, .schlaeft)
        XCTAssertEqual(Morgensatz.sprich(eingabe(85, stunde: 2)).stimmung, .schlaeft)
        XCTAssertEqual(Morgensatz.sprich(eingabe(85, stunde: 5)).stimmung, .bereit)
        XCTAssertEqual(Morgensatz.sprich(eingabe(85, stunde: 22)).stimmung, .bereit)
    }
}

final class HeutePlanLogikTests: XCTestCase {
    private func tag(_ id: String, _ name: String, _ wochentage: [Int], uebungen: Int = 4) -> TrainingsTag {
        TrainingsTag(id: id, name: name, wochentage: wochentage,
                     uebungen: (0..<uebungen).map { PlanUebung(id: "u\($0)", uebung: "x\($0)", name: "Übung \($0)", saetze: [], minuten: nil) })
    }

    /// Mittwoch, 23.09.2026 (Wochentag 3).
    private let heute = "2026-09-23"

    private func plan(_ tage: [TrainingsTag], ruhe: [Int] = []) -> TrainingsPlan {
        TrainingsPlan(tage: tage, ruhetage: ruhe)
    }

    func testHeutigerTagMitKnopf() {
        let v = HeutePlanLogik.vorschlag(plan: plan([tag("a", "Beine", [3])]), heute: heute, trainiert: false, locker: false, gymInFolge: 0)
        XCTAssertEqual(v.art, .training)
        XCTAssertEqual(v.name, "Beine")
        XCTAssertEqual(v.tagID, "a")
        XCTAssertEqual(v.uebungen, 4)
        XCTAssertEqual(v.knopf, "Training starten")
        XCTAssertFalse(v.locker)
    }

    func testLockerWennDerMorgenCheckSchwerWar() {
        let v = HeutePlanLogik.vorschlag(plan: plan([tag("a", "Beine", [3])]), heute: heute, trainiert: false, locker: true, gymInFolge: 0)
        XCTAssertTrue(v.locker)
        XCTAssertTrue(v.tipp.hasPrefix("Heute locker"))
    }

    func testDreiTageAmStueckRaetZumLeichteren() {
        let v = HeutePlanLogik.vorschlag(plan: plan([tag("a", "Beine", [3])]), heute: heute, trainiert: false, locker: false, gymInFolge: 3)
        XCTAssertTrue(v.locker)
        XCTAssertTrue(v.tipp.contains("3 Tage am Stück"))
    }

    func testRuhetagOhneKnopf() {
        let v = HeutePlanLogik.vorschlag(plan: plan([tag("a", "Beine", [1])], ruhe: [3]), heute: heute, trainiert: false, locker: false, gymInFolge: 0)
        XCTAssertEqual(v.art, .ruhetag)
        XCTAssertNil(v.knopf)
    }

    func testOffenerTagLaesstTrotzdemStarten() {
        let v = HeutePlanLogik.vorschlag(plan: plan([tag("a", "Beine", [1])]), heute: heute, trainiert: false, locker: false, gymInFolge: 0)
        XCTAssertEqual(v.art, .keinTrainingHeute)
        XCTAssertEqual(v.knopf, "Training starten")
    }

    func testKeinPlanUndErledigt() {
        XCTAssertEqual(HeutePlanLogik.vorschlag(plan: .leer, heute: heute, trainiert: false, locker: false, gymInFolge: 0).art, .keinPlan)
        XCTAssertEqual(HeutePlanLogik.vorschlag(plan: plan([tag("a", "Beine", [3])]), heute: heute, trainiert: true, locker: false, gymInFolge: 0).art, .erledigt)
    }
}
