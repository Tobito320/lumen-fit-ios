import XCTest
@testable import LumenFit

/// Die Verdrahtung zwischen Health, Training und Bereit-Score (`HeuteQuellen`): welcher Vitalwert zählt, wie die Tageslast entsteht, wer beim Gewicht gewinnt.
final class HeuteQuellenTests: XCTestCase {
    /// Mittwoch, 23.09.2026.
    private let heute = "2026-09-23"

    private func hrv(_ tag: String, _ wert: Double) -> VitalMesswert { VitalMesswert(art: .hrv, tag: tag, wert: wert) }

    // MARK: Vitalwerte

    func testEinWertVonGesternZaehltAlsAktuell() {
        let v = HeuteQuellen.vital([hrv("2026-09-22", 50)], heute: heute)
        XCTAssertEqual(v.aktuell, 50)
        XCTAssertTrue(v.basis.isEmpty)
    }

    func testEinWertVonVorgesternZaehltNicht() {
        let v = HeuteQuellen.vital([hrv("2026-09-21", 50), hrv("2026-09-20", 48)], heute: heute)
        XCTAssertNil(v.aktuell, "lieber kein Teil als eine Rechnung mit einem alten Wert")
        XCTAssertTrue(v.basis.isEmpty)
    }

    func testWerteAusDerZukunftWerdenIgnoriert() {
        let v = HeuteQuellen.vital([hrv("2026-09-24", 99), hrv(heute, 55)], heute: heute)
        XCTAssertEqual(v.aktuell, 55)
    }

    func testBasisLaesstDenNeuestenWegUndHatHoechstensSechzigTage() {
        let werte = (0..<70).map { hrv(Datum.addTage(heute, -$0), Double(100 + $0)) }
        let v = HeuteQuellen.vital(werte.shuffled(), heute: heute)
        XCTAssertEqual(v.aktuell, 100)
        XCTAssertEqual(v.basis.count, 60)
        XCTAssertEqual(v.basis.first, 101, "neueste zuerst, ohne den aktuellen Wert")
        XCTAssertEqual(v.basis.last, 160)
    }

    func testUnendlicheUndLeereWerteFallenWeg() {
        let v = HeuteQuellen.vital([hrv(heute, .nan), hrv("2026-09-22", 40), hrv("2026-09-21", .infinity)], heute: heute)
        XCTAssertEqual(v.aktuell, 40, "NaN ist kein Wert, der nächste zählt")
        XCTAssertTrue(v.basis.isEmpty)
        XCTAssertNil(HeuteQuellen.vital([], heute: heute).aktuell)
    }

    // MARK: Tageslast

    func testLastBeginntGesternHat31TageUndIstOhneDatenNil() {
        let last = HeuteQuellen.tageslast(heute: heute, tage: [:], saetze: [:])
        XCTAssertEqual(last.count, 31)
        XCTAssertTrue(last.allSatisfy { $0 == nil }, "weder Health noch Gym: keine Daten, nicht null")
    }

    func testLastIstKcalPlusZehnJeSatz() {
        XCTAssertEqual(BereitScore.satzKcal, 10)
        let tage = ["2026-09-22": TagesWerte(tag: "2026-09-22", aktiveKcal: 300), heute: TagesWerte(tag: heute, aktiveKcal: 999)]
        let last = HeuteQuellen.tageslast(heute: heute, tage: tage, saetze: ["2026-09-22": 4, "2026-09-21": 5])
        XCTAssertEqual(last[0], 340, "Index 0 ist gestern: 300 kcal plus 4 Sätze; heute zählt nicht")
        XCTAssertEqual(last[1], 50, "nur Gym, kein Health: 5 Sätze")
        XCTAssertNil(last[2])
    }

    func testEinHealthTagMitNullKcalIstNullUndNichtNil() {
        let last = HeuteQuellen.tageslast(heute: heute, tage: ["2026-09-22": TagesWerte(tag: "2026-09-22")], saetze: [:])
        XCTAssertEqual(last[0], 0)
    }

    func testSaetzeProTagZaehlenNurFertigeLaeufe() {
        func lauf(_ n: Int?, fertig: Bool) -> UebungsLauf {
            UebungsLauf(plan: "p", uebung: "x", start: nil, ende: nil, fertig: fertig, saetze: n.map { [PlanSatz](repeating: PlanSatz(wdh: 8, kg: 50, failure: false), count: $0) })
        }
        let morgens = Datum.datum("2026-09-22").addingTimeInterval(8 * 3600)
        let abends = Datum.datum("2026-09-22").addingTimeInterval(19 * 3600)
        let a = GymSession(id: "a", tag: nil, start: morgens, ende: nil, laeufe: [lauf(3, fertig: true), lauf(5, fertig: false), lauf(nil, fertig: true)])
        let b = GymSession(id: "b", tag: nil, start: abends, ende: nil, laeufe: [lauf(2, fertig: true)])
        XCTAssertEqual(HeuteQuellen.saetzeProTag([a, b]), ["2026-09-22": 5])
        XCTAssertTrue(HeuteQuellen.saetzeProTag([]).isEmpty)
    }

    // MARK: Gewicht und Zahlen

    func testHandEintragSchlaegtHealthAmSelbenTag() {
        let health = [GewichtsMesswert(tag: "2026-09-20", kg: 80.04), GewichtsMesswert(tag: "2026-09-19", kg: 81.0), GewichtsMesswert(tag: "2026-09-18", kg: .nan)]
        let w = HeuteQuellen.gewichtWerte(health: health, manuell: ["2026-09-20": 790, "2026-09-17": 0])
        XCTAssertEqual(w, ["2026-09-20": 790, "2026-09-19": 810])
        XCTAssertEqual(HeuteQuellen.gewichtWerte(health: [GewichtsMesswert(tag: "2026-09-20", kg: 80.04)], manuell: [:])["2026-09-20"], 800)
    }

    func testZahlMitDeutschemTausenderpunktUndGewichtsbereich() {
        XCTAssertEqual(HeuteQuellen.zahl(8_412), "8.412")
        XCTAssertEqual(HeuteQuellen.zahl(999), "999")
        XCTAssertEqual(HeuteQuellen.zahl(10_000), "10.000")
        XCTAssertTrue(HeuteQuellen.gewichtBereich.contains(300))
        XCTAssertFalse(HeuteQuellen.gewichtBereich.contains(299))
    }
}
