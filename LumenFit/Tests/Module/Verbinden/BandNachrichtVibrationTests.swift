// Quelle: Lovea Tests/BandNachrichtVibrationTests.swift
import XCTest
@testable import LumenFit

/// Wann das Armband vibriert, wenn der Partner etwas meldet: Schalter, Band am Arm, frische Meldung, Pause.
final class BandNachrichtVibrationTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_800_000_000)

    private func soll(an: Bool = true, bandAmArm: Bool? = true, alter: TimeInterval = 5, letzte: TimeInterval? = nil,
                      pause: TimeInterval = 180, frisch: TimeInterval = BandNachrichtRegel.frischGrenze) -> Bool {
        BandNachrichtRegel.vibriert(an: an, bandAmArm: bandAmArm, zeit: jetzt.addingTimeInterval(-alter), jetzt: jetzt,
                                    letzte: letzte.map { jetzt.addingTimeInterval(-$0) }, pause: pause, frisch: frisch)
    }

    func testErsteFrischeMeldungVibriert() {
        XCTAssertTrue(soll())
    }

    func testAusVibriertNie() {
        XCTAssertFalse(soll(an: false))
    }

    func testBandNichtAmArmVibriertNicht() {
        XCTAssertFalse(soll(bandAmArm: false))
    }

    func testUnbekannterZustandVibriertTrotzdem() {
        XCTAssertTrue(soll(bandAmArm: nil))
    }

    func testEigeneFrischGrenzeGiltFuerAeltereMeldungen() {
        XCTAssertFalse(soll(alter: 600))
        XCTAssertTrue(soll(alter: 600, frisch: 1_800))
    }

    func testAlteNachrichtAusDemNachholenVibriertNicht() {
        XCTAssertTrue(soll(alter: BandNachrichtRegel.frischGrenze - 1))
        XCTAssertFalse(soll(alter: BandNachrichtRegel.frischGrenze + 1))
    }

    func testInnerhalbDerPauseNurEineVibration() {
        XCTAssertFalse(soll(letzte: 60, pause: 180))
        XCTAssertFalse(soll(letzte: 179, pause: 180))
    }

    func testNachDerPauseVibriertEsWieder() {
        XCTAssertTrue(soll(letzte: 180, pause: 180))
        XCTAssertTrue(soll(letzte: 600, pause: 120))
    }

    func testUhrZurueckBeendetDiePause() {
        XCTAssertTrue(soll(letzte: -30, pause: 180))
    }

    func testStaerkeZaehltDiePulse() {
        XCTAssertEqual(BandNachrichtRegel.Staerke.sanft.pulse, 1)
        XCTAssertEqual(BandNachrichtRegel.Staerke.normal.pulse, 2)
        XCTAssertEqual(BandNachrichtRegel.Staerke.stark.pulse, 3)
        XCTAssertEqual(BandNachrichtRegel.Staerke(gespeichert: nil), .sanft)
        XCTAssertEqual(BandNachrichtRegel.Staerke(gespeichert: "normal"), .normal)
        XCTAssertEqual(BandNachrichtRegel.Staerke(gespeichert: "stark"), .stark)
        XCTAssertEqual(BandNachrichtRegel.Staerke(gespeichert: "kaputt"), .sanft)
    }

    /// Der Tracker kennt nur einen Puls von fester Länge: getrennt zu spüren sind zwei Pulse nur mit Abstand über der Pulslänge.
    func testDiePulseKommenNacheinanderMitAbstandUeberDerPulslaenge() {
        XCTAssertEqual(BandNachrichtRegel.zeiten(.sanft), [0])
        let normal = BandNachrichtRegel.zeiten(.normal)
        XCTAssertEqual(normal.count, 2)
        XCTAssertEqual(normal.first, 0)
        XCTAssertGreaterThan(normal[1], TrackerProtokoll.findenPulsDauer)
        let stark = BandNachrichtRegel.zeiten(.stark)
        XCTAssertEqual(stark.count, 3)
        for (a, b) in zip(stark, stark.dropFirst()) { XCTAssertGreaterThan(b - a, TrackerProtokoll.findenPulsDauer) }
    }

    func testJedeStufeIstLaengerAlsDieVorige() {
        let ende = BandNachrichtRegel.Staerke.allCases.map { BandNachrichtRegel.zeiten($0).last ?? 0 }
        XCTAssertEqual(ende, ende.sorted())
        XCTAssertEqual(Set(ende).count, ende.count)
        // Nach einer Push gibt iOS der App nur kurz Zeit (rund 30 s): die längste Folge muss darin enden.
        XCTAssertLessThanOrEqual(ende.last ?? 0, 30)
    }
}
