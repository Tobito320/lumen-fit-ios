// Quelle: Lovea Tests/TrackerArmTests.swift
import XCTest
@testable import LumenFit

/// Wann das Band als "am Arm" oder "abgelegt" gilt, und wie der Pulsverlauf des Trackers gelesen wird.
/// Die Regel ist rein; der Pulsverlauf (0x15) ist am Gerät noch nicht belegt, die Pakete hier sind nach
/// der Referenz colmi_r02_client gebaut.
final class TrackerArmTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_791_800_000)
    private func minuten(_ n: Double) -> TimeInterval { n * 60 }

    private func zustand(an: Bool = true, intervall: Int = 10, puls vorMinuten: Double? = 5, gelesenVor: Double = 0,
                         seitMitternacht: Double = 600) -> TrackerArm.Zustand {
        TrackerArm.zustand(pulsAn: an, intervallMinuten: intervall,
                           letzterPuls: vorMinuten.map { jetzt.addingTimeInterval(-minuten($0)) },
                           gelesen: jetzt.addingTimeInterval(-minuten(gelesenVor)),
                           tagesanfang: jetzt.addingTimeInterval(-minuten(seitMitternacht)),
                           jetzt: jetzt)
    }

    func testFrischerPulsMeintAmArm() {
        XCTAssertEqual(zustand(puls: 5), .amArm)
    }

    func testAltPulsMeintAbgelegt() {
        XCTAssertEqual(zustand(puls: 60), .abgelegt)
    }

    func testGrenzeIstZweiAbstaendePlusFuenfMinuten() {
        XCTAssertEqual(zustand(intervall: 10, puls: 25), .amArm)
        XCTAssertEqual(zustand(intervall: 10, puls: 25.1), .abgelegt)
        XCTAssertEqual(zustand(intervall: 60, puls: 125), .amArm)
    }

    func testDauermessungAusOderUnbekanntGibtUnbekannt() {
        XCTAssertEqual(zustand(an: false, puls: 5), .unbekannt)
        XCTAssertEqual(zustand(intervall: 0, puls: 5), .unbekannt)
        XCTAssertEqual(TrackerArm.zustand(pulsAn: true, intervallMinuten: 10, letzterPuls: nil, gelesen: nil,
                                          tagesanfang: jetzt, jetzt: jetzt), .unbekannt)
    }

    func testZuAlterStandIstNieAbgelegt() {
        XCTAssertEqual(zustand(puls: 60, gelesenVor: 60), .unbekannt)
    }

    func testGarKeinPulsHeuteMeintAbgelegtErstNachDemFenster() {
        XCTAssertEqual(zustand(puls: nil, seitMitternacht: 600), .abgelegt)
        XCTAssertEqual(zustand(puls: nil, seitMitternacht: 10), .unbekannt)
    }

    // MARK: Pulsverlauf lesen

    private let tag: UInt32 = 1_791_763_200

    private func roh(_ unterart: UInt8, _ nutz: [UInt8]) -> TrackerProtokoll.Antwort? {
        TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsVerlauf, [unterart] + nutz))
    }

    private func start(zeit: UInt32, _ werte: [UInt8]) -> TrackerProtokoll.Antwort? {
        let z = (0..<4).map { UInt8(truncatingIfNeeded: zeit >> (8 * UInt32($0))) }
        return roh(1, z + werte)
    }

    func testPaketeWerdenGedeutet() {
        XCTAssertEqual(roh(0, [24, 5]), .pulsKopf(pakete: 24, abstand: 5))
        XCTAssertEqual(roh(0xFF, []), .pulsEnde)
        XCTAssertEqual(roh(2, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]), .pulsWerte(nr: 2, werte: Array(1...13)))
        XCTAssertEqual(start(zeit: 0x0102_0304, Array(1...9)), .pulsStart(zeit: 0x0102_0304, werte: Array(1...9)))
    }

    func testAnfrageSchreibtMitternachtLittleEndian() {
        XCTAssertEqual(TrackerProtokoll.pulsVerlaufAnfrage(tag: 0x0102_0304),
                       TrackerProtokoll.paket(.pulsVerlauf, [0x04, 0x03, 0x02, 0x01]))
        XCTAssertEqual(Array([UInt8](TrackerProtokoll.pulsVerlaufAnfrage(tag: 0x0102_0304)).prefix(5)), [0x15, 0x04, 0x03, 0x02, 0x01])
    }

    func testTagSekundenIstDieWandzeitAlsUTC() {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let nachmittag = berlin.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 15, minute: 30))!
        XCTAssertEqual(TrackerProtokoll.tagSekunden(nachmittag, kalender: berlin), tag)
    }

    private func verlauf(_ pakete: [TrackerProtokoll.Antwort?]) -> (PulsVerlauf, Bool) {
        var v = PulsVerlauf(tag: tag)
        var fertig = false
        for p in pakete { fertig = v.aufnehmen(p!) }
        return (v, fertig)
    }

    func testVerlaufIstErstNachDemLetztenPaketFertig() {
        let (v, fertig) = verlauf([roh(0, [3, 5]), start(zeit: tag, [0, 0, 0, 0, 0, 0, 0, 0, 70])])
        XCTAssertFalse(fertig)
        XCTAssertEqual(v.werte.count, 9)
        let (v2, fertig2) = verlauf([roh(0, [3, 5]), start(zeit: tag, [0, 0, 0, 0, 0, 0, 0, 0, 70]),
                                     roh(2, [0, 0, 0, 0, 0, 80, 0, 0, 0, 0, 0, 0, 0])])
        XCTAssertTrue(fertig2)
        XCTAssertTrue(v2.gueltig)
        XCTAssertEqual(v2.werte.count, 22)
    }

    func testLetzterPulsHatDieZeitDesSlots() {
        let (v, _) = verlauf([roh(0, [3, 5]), start(zeit: tag, [0, 0, 0, 0, 0, 0, 0, 0, 70]),
                              roh(2, [0, 0, 0, 0, 0, 80, 0, 0, 0, 0, 0, 0, 0])])
        let anfang = Date(timeIntervalSince1970: 0)
        let spaet = anfang.addingTimeInterval(86_400)
        XCTAssertEqual(v.letzter(tagesanfang: anfang, bis: spaet)?.wert, 80)
        XCTAssertEqual(v.letzter(tagesanfang: anfang, bis: spaet)?.zeit, anfang.addingTimeInterval(minuten(14 * 5)))
        // Slot 14 liegt nach "bis": dann zählt der davor.
        XCTAssertEqual(v.letzter(tagesanfang: anfang, bis: anfang.addingTimeInterval(minuten(60)))?.wert, 70)
    }

    func testNullUndFehlwerteSindKeinPuls() {
        let (v, _) = verlauf([roh(0, [2, 5]), start(zeit: tag, [72, 255, 0, 20, 221, 0, 0, 0, 0])])
        XCTAssertEqual(v.letzter(tagesanfang: .distantPast, bis: .distantFuture)?.wert, 72)
    }

    func testAndererTagIstUngueltig() {
        let (v, _) = verlauf([roh(0, [2, 5]), start(zeit: tag + 86_400, [72, 0, 0, 0, 0, 0, 0, 0, 0])])
        XCTAssertFalse(v.gueltig)
    }

    func testZustandAlsBandAmArmFuerDieNachrichtVibration() {
        XCTAssertEqual(TrackerArm.Zustand.amArm.bandAmArm, true)
        XCTAssertEqual(TrackerArm.Zustand.abgelegt.bandAmArm, false)
        XCTAssertNil(TrackerArm.Zustand.unbekannt.bandAmArm)
    }

    func testKeineDatenIstFertigOhneGueltigenVerlauf() {
        let (v, fertig) = verlauf([roh(0xFF, [])])
        XCTAssertTrue(fertig)
        XCTAssertFalse(v.gueltig)
    }
}
