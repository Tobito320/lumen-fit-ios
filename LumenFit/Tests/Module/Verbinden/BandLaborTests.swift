// Quelle: Lovea Tests/BandLaborTests.swift
import XCTest
@testable import LumenFit

/// Das Band-Labor: Pulslänge aus Messungen, Urteil über den zweiten Befehl, Speicher und der gemessene Wert im Protokoll.
final class BandLaborTests: XCTestCase {
    private func einzel(_ dauer: Double) -> BandLaborMessung {
        BandLaborMessung(datum: Date(timeIntervalSince1970: 1_800_000_000), art: .einzel, dauer: dauer)
    }

    private func doppel(_ urteil: BandLaborAuswertung.Doppel) -> BandLaborMessung {
        BandLaborMessung(datum: Date(timeIntervalSince1970: 1_800_000_000), art: .doppel, abstand: 1, dauer: 9, urteil: urteil)
    }

    func testPulsLaengeIstDerMedian() {
        XCTAssertEqual(BandLaborAuswertung.pulsLaenge([einzel(7), einzel(9), einzel(30)]), 9)
        XCTAssertEqual(BandLaborAuswertung.pulsLaenge([einzel(6), einzel(8)]), 7)
    }

    func testPulsLaengeIgnoriertFehlbedienungUndDoppelmessungen() {
        XCTAssertNil(BandLaborAuswertung.pulsLaenge([]))
        XCTAssertNil(BandLaborAuswertung.pulsLaenge([einzel(0.1), einzel(500)]))
        XCTAssertEqual(BandLaborAuswertung.pulsLaenge([einzel(8), einzel(0.1), doppel(.ignoriert)]), 8)
    }

    func testZweiterBefehlWirdIgnoriert() {
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 1, gesamt: 8.4), .ignoriert)
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 1, gesamt: 7.2), .ignoriert, "innerhalb der Toleranz")
    }

    func testZweiterBefehlStartetNeu() {
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 2, gesamt: 10), .neuGestartet)
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 3, gesamt: 10.5), .neuGestartet)
    }

    func testZweiterBefehlVerlaengert() {
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 3, gesamt: 9.5), .verlaengert)
    }

    func testZweiterPulsHaengtAn() {
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 0.5, gesamt: 16), .angehaengt)
    }

    func testZweiterBefehlBrichtAb() {
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 1, gesamt: 3), .abgebrochen)
    }

    func testAbstandSoGrossWiePulsIstGetrennt() {
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 2, abstand: 2, gesamt: 4), .getrennt)
    }

    func testPasstNichtsIstUnklar() {
        XCTAssertEqual(BandLaborAuswertung.beurteile(puls: 8, abstand: 1, gesamt: 40), .unklar)
    }

    func testGesamtUrteilIstDasHaeufigste() {
        XCTAssertNil(BandLaborAuswertung.gesamtUrteil([einzel(8)]))
        let liste = [doppel(.ignoriert), doppel(.neuGestartet), doppel(.neuGestartet), doppel(.getrennt)]
        XCTAssertEqual(BandLaborAuswertung.gesamtUrteil(liste), .neuGestartet)
        XCTAssertEqual(BandLaborAuswertung.gesamtUrteil([doppel(.ignoriert), doppel(.verlaengert)]), .verlaengert, "Gleichstand: das jüngste")
    }

    // MARK: Speicher

    private func frischeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "test.bandlabor")!
        defaults.removePersistentDomain(forName: "test.bandlabor")
        return defaults
    }

    func testMessungenBleibenUndSindAufVierzigBegrenzt() {
        let d = frischeDefaults()
        XCTAssertTrue(BandLaborSpeicher.messungen(d).isEmpty)
        for i in 0..<(BandLaborSpeicher.hoechstens + 5) { BandLaborSpeicher.anhaengen(einzel(Double(i + 1)), d) }
        let liste = BandLaborSpeicher.messungen(d)
        XCTAssertEqual(liste.count, BandLaborSpeicher.hoechstens)
        XCTAssertEqual(liste.last?.dauer, Double(BandLaborSpeicher.hoechstens + 5))
        BandLaborSpeicher.loeschen(d)
        XCTAssertTrue(BandLaborSpeicher.messungen(d).isEmpty)
    }

    func testGemessenerWertGiltNurWennEingeschaltetUndPlausibel() {
        let d = frischeDefaults()
        XCTAssertNil(BandLaborSpeicher.pulsDauer(d), "Standard wie bisher")
        BandLaborSpeicher.pulsDauerSetzen(6.5, d)
        XCTAssertNil(BandLaborSpeicher.pulsDauer(d), "gemessen, aber nicht eingeschaltet")
        d.set(true, forKey: BandLaborSpeicher.nutzenSchluessel)
        XCTAssertEqual(BandLaborSpeicher.pulsDauer(d), 6.5)
        BandLaborSpeicher.pulsDauerSetzen(0, d)
        XCTAssertNil(BandLaborSpeicher.pulsDauer(d), "unplausibel")
    }

    func testProtokollRechnetStandardMitDerAnnahme() {
        XCTAssertEqual(TrackerProtokoll.findenPulsDauerAnnahme, 8)
        XCTAssertEqual(TrackerProtokoll.findenPulsDauer, TrackerProtokoll.findenPulsDauerAnnahme, "im Test ist nichts übernommen")
    }
}
