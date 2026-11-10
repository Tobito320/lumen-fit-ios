import XCTest
@testable import LumenFit

/// Hilfen der ersten Wochen im laufenden Training: Formtipp und "Wie war das Set? Leicht / Passt / Schwer".
@MainActor
final class LaufHilfeTests: XCTestCase {
    private let jetzt = Datum.datum("2026-11-10").addingTimeInterval(18 * 3600)

    private func einheit(_ id: String, tageZurueck: Double, beendet: Bool = true) -> GymSession {
        let start = jetzt.addingTimeInterval(-tageZurueck * 86400)
        return GymSession(id: id, tag: nil, start: start, ende: beendet ? start.addingTimeInterval(3600) : nil, laeufe: [])
    }

    private func satz(_ kg: Double?, ok: Bool) -> PlanSatz {
        var s = PlanSatz(wdh: 8, kg: kg, failure: false)
        s.ok = ok ? true : nil
        return s
    }

    func testErsteWochenBisZweiWochenNachDemErstenTraining() {
        XCTAssertTrue(LaufHilfe.ersteWochen([], jetzt: jetzt), "ohne Training ist man am Anfang")
        XCTAssertTrue(LaufHilfe.ersteWochen([einheit("a", tageZurueck: 13)], jetzt: jetzt))
        XCTAssertFalse(LaufHilfe.ersteWochen([einheit("a", tageZurueck: 15), einheit("b", tageZurueck: 1)], jetzt: jetzt))
        XCTAssertTrue(LaufHilfe.ersteWochen([einheit("a", tageZurueck: 20, beendet: false)], jetzt: jetzt), "nur beendete zählen")
    }

    func testFormtippIstDerHaeufigsteFehler() {
        XCTAssertEqual(LaufHilfe.formtipp("EIeI8Vf"), UebungsAnleitungen.finden("EIeI8Vf")?.fehler)
        XCTAssertNotNil(LaufHilfe.formtipp("EIeI8Vf"))
        XCTAssertNil(LaufHilfe.formtipp("gibt-es-nicht"))
    }

    func testFrageNurUnterDemLetztenAbgehaktenMitOffenemSetDanach() {
        let s = [satz(60, ok: true), satz(60, ok: true), satz(60, ok: false)]
        XCTAssertFalse(LaufHilfe.gefuehlFrage(s, satz: 0), "nicht das letzte abgehakte")
        XCTAssertTrue(LaufHilfe.gefuehlFrage(s, satz: 1))
        XCTAssertFalse(LaufHilfe.gefuehlFrage(s, satz: 2), "offen")
        XCTAssertFalse(LaufHilfe.gefuehlFrage([satz(60, ok: true), satz(60, ok: true)], satz: 1), "kein Set mehr danach")
        XCTAssertFalse(LaufHilfe.gefuehlFrage([satz(nil, ok: true), satz(nil, ok: false)], satz: 0), "ohne Gewicht gibt es nichts anzupassen")
    }

    func testLeichtUndSchwerStellenDasNaechsteOffeneSet() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.sitzung.satzGefuehl(0, 0, .leicht)
        XCTAssertEqual(a.sitzung.liste[0].saetze[1].kg, 62.5, "Langhantel: 2,5 kg mehr")
        XCTAssertEqual(a.sitzung.liste[0].saetze[2].kg, 60, "nur das nächste Set")
        XCTAssertTrue(a.sitzung.gefuehlGegeben.contains("a|0"))
        a.sitzung.haken(0, 1)
        a.sitzung.satzGefuehl(0, 1, .schwer)
        XCTAssertEqual(a.sitzung.liste[0].saetze[2].kg, 57.5)
        a.sitzung.satzGefuehl(0, 1, .passt)
        XCTAssertEqual(a.sitzung.liste[0].saetze[2].kg, 57.5, "passt ändert nichts")
    }
}
