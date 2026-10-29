import XCTest
@testable import LumenFit

/// Der Coach kennt das Training (Idee 66): letztes Training, Rekorde, Wochensätze, Vorschläge fürs nächste Mal. Katalog und Zeit kommen von außen.
final class CoachTrainingTests: XCTestCase {
    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "Bench Press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
    private let band = Uebung(id: "band", name: "Laufband", en: "Treadmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Maschine", neben: [])
    private let heute = "2026-09-23"

    private func katalog(_ id: String) -> Uebung? { [bank, band].first { $0.id == id } }

    private func jetzt(_ stunde: Double = 12) -> Date { Datum.datum(heute).addingTimeInterval(stunde * 3600) }

    private func satz(_ kg: Double?, _ wdh: Int, typ: String? = nil) -> PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ, ok: true) }

    private func session(_ tag: String, stunde: Double = 18, minuten: Double? = 52, uebung: String = "bank", saetze: [PlanSatz], id: String? = nil) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(stunde * 3600)
        let lauf = UebungsLauf(plan: "p-\(uebung)", uebung: uebung, start: start, ende: nil, fertig: true, saetze: saetze)
        return GymSession(id: id ?? "s-\(tag)", tag: "t1", start: start, ende: minuten.map { start.addingTimeInterval($0 * 60) }, laeufe: [lauf])
    }

    // MARK: - Letztes Training

    func testLetztesTrainingAlsEineZeile() {
        let s = session("2026-09-22", saetze: [satz(20, 10, typ: "w"), satz(60, 8), satz(60, 8), satz(60, 7)])
        XCTAssertEqual(CoachTraining.letztesTraining([s], plan: CoachTestBau.plan(), jetzt: jetzt()), "Push, gestern, 52 Minuten, 3 Sätze")
    }

    func testAufwaermsaetzeUndLeereEinheitenZaehlenNicht() {
        let leer = session("2026-09-22", saetze: [satz(20, 10, typ: "w")])
        XCTAssertEqual(CoachTraining.saetze(leer), 0)
        XCTAssertNil(CoachTraining.letztesTraining([leer], plan: CoachTestBau.plan(), jetzt: jetzt()), "ohne Arbeitssatz kein letztes Training")
        XCTAssertNil(CoachTraining.letztesTraining([], plan: CoachTestBau.plan(), jetzt: jetzt()))
    }

    func testDieJuengsteEinheitGewinntUndOhneEndeFehltDieDauer() {
        let alt = session("2026-09-15", saetze: [satz(60, 8)])
        let neu = session("2026-09-21", minuten: nil, saetze: [satz(60, 8), satz(60, 8)])
        XCTAssertEqual(CoachTraining.letztesTraining([alt, neu], plan: .leer, jetzt: jetzt()), "Training, vor 2 Tagen, 2 Sätze")
    }

    func testWannHeuteGesternVorTagen() {
        XCTAssertEqual(CoachTraining.wann(jetzt(9), jetzt: jetzt()), "heute")
        XCTAssertEqual(CoachTraining.wann(Datum.datum("2026-09-22"), jetzt: jetzt()), "gestern")
        XCTAssertEqual(CoachTraining.wann(Datum.datum("2026-09-18"), jetzt: jetzt()), "vor 5 Tagen")
    }

    // MARK: - Rekorde

    func testRekordNurWennDavorSchonTrainiertWurde() {
        let erste = session("2026-09-20", saetze: [satz(70, 8)])
        XCTAssertEqual(CoachTraining.rekorde([erste], heute: heute, katalog: katalog), [], "der allererste Satz ist kein Rekord")

        let davor = session("2026-09-01", saetze: [satz(60, 8)])
        let rekorde = CoachTraining.rekorde([davor, erste], heute: heute, katalog: katalog)
        XCTAssertEqual(rekorde.map(\.text), ["Bankdrücken 70 kg × 8"])
        XCTAssertEqual(rekorde.first?.tag, "2026-09-20")
    }

    func testAlterRekordZaehltNichtMehrUndBesseresGewinnt() {
        let a = session("2026-08-20", saetze: [satz(60, 8)])
        let b = session("2026-09-02", saetze: [satz(70, 8)])
        XCTAssertEqual(CoachTraining.rekorde([a, b], heute: heute, katalog: katalog), [], "21 Tage her")
        let c = session("2026-09-10", saetze: [satz(50, 8)])
        XCTAssertEqual(CoachTraining.rekorde([a, b, c], heute: heute, tage: 30, katalog: katalog).map(\.text), ["Bankdrücken 70 kg × 8"], "der leichtere Satz überschreibt nicht")
    }

    func testAufwaermsaetzeUndSaetzeOhneGewichtGebenKeinenRekord() {
        let davor = session("2026-09-01", saetze: [satz(60, 8)])
        let neu = session("2026-09-20", saetze: [satz(100, 5, typ: "w"), satz(nil, 20)])
        XCTAssertEqual(CoachTraining.rekorde([davor, neu], heute: heute, katalog: katalog), [])
    }

    // MARK: - Wochensätze

    func testGruppenNurDieInDenLetztenVierWochenTrainiertenMitFaelligkeit() {
        let s = session("2026-09-22", saetze: [satz(60, 8), satz(60, 8), satz(60, 8)])
        let gruppen = CoachTraining.gruppen([s], heute: heute, katalog: katalog)
        XCTAssertEqual(gruppen.map(\.name), ["Brust"], "wer Arme nie trainiert, bekommt keine Mahnung")
        XCTAssertEqual(gruppen.first?.saetze, 3)
        XCTAssertEqual(gruppen.first?.ziel, 12)
        XCTAssertEqual(gruppen.first?.faellig, true, "3 von 12 ist unter der Hälfte")

        let viele = session("2026-09-22", saetze: Array(repeating: satz(60, 8), count: 8))
        XCTAssertEqual(CoachTraining.gruppen([viele], heute: heute, katalog: katalog).first?.faellig, false)
    }

    func testAlteTrainingsFallenAusDenGruppen() {
        let alt = session("2026-07-01", saetze: [satz(60, 8)])
        XCTAssertEqual(CoachTraining.gruppen([alt], heute: heute, katalog: katalog), [])
    }

    // MARK: - Fürs nächste Mal

    func testVorschlagFuersNaechsteMalAusDerLetztenEinheit() {
        let alt = session("2026-09-15", saetze: [satz(40, 12), satz(40, 12)])
        let neu = session("2026-09-22", saetze: [satz(60, 8), satz(60, 9), satz(60, 10)])
        let liste = CoachTraining.uebungen([alt, neu], katalog: katalog)
        XCTAssertEqual(liste.map(\.name), ["Bankdrücken"])
        XCTAssertEqual(liste.first?.vorschlag, CoachSteigerung(kg: 60, wdh: 9, mehrGewicht: false))
    }

    func testCardioUndLeereEinheitenGebenKeinenVorschlag() {
        let cardio = session("2026-09-22", uebung: "band", saetze: [satz(nil, 1)])
        XCTAssertEqual(CoachTraining.uebungen([cardio], katalog: katalog), [])
        XCTAssertEqual(CoachTraining.uebungen([], katalog: katalog), [])
    }

    func testObenAmZielGibtMehrGewicht() {
        let s = session("2026-09-22", saetze: [satz(60, 12), satz(60, 12)])
        XCTAssertEqual(CoachTraining.uebungen([s], katalog: katalog).first?.vorschlag, CoachSteigerung(kg: 62.5, wdh: 8, mehrGewicht: true))
    }
}
