// Quelle: Lovea Tests/BandRegelnTests.swift
import XCTest
@testable import LumenFit

/// Regeln für alle Pulse am Armband: Gate, Ruhefenster über Mitternacht, Akku-Wächter, Mindestpause, Ziel-Puls, Muster der Wünsche. Sitzen, Erinnerungen und Mitteilungs-Quellen entfallen mit Lovea.
final class BandRegelnTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
    private func vor(_ min: Double) -> Date { jetzt.addingTimeInterval(-min * 60) }

    private func umfeld(arm: Bool? = true, akku: Int? = 80, schwelle: Int = 20, ruhe: [BandRegeln.Zeitfenster] = [], ausnahme: Bool = true) -> BandRegeln.Umfeld {
        BandRegeln.Umfeld(bandAmArm: arm, akku: akku, akkuSchwelle: schwelle, ruhe: ruhe, ruheAusnahme: ausnahme)
    }

    private let regel = BandRegeln.Regel(an: true, staerke: .sanft, pauseMinuten: 3)

    private func pruefen(_ q: BandQuelle = .gymPause, regel: BandRegeln.Regel? = nil, letzte: Date? = nil, minute: Int = 600, umfeld: BandRegeln.Umfeld? = nil) -> BandRegeln.Grund? {
        BandRegeln.pruefen(q, regel: regel ?? self.regel, letzte: letzte, jetzt: jetzt, minute: minute, umfeld: umfeld ?? self.umfeld())
    }

    // MARK: Zeitfenster

    func testFensterAmTag() {
        let f = BandRegeln.Zeitfenster(von: 9 * 60, bis: 20 * 60)
        XCTAssertTrue(f.enthaelt(9 * 60))
        XCTAssertTrue(f.enthaelt(20 * 60 - 1))
        XCTAssertFalse(f.enthaelt(20 * 60))
        XCTAssertFalse(f.enthaelt(8 * 60 + 59))
    }

    func testFensterUeberMitternacht() {
        let nacht = BandRegeln.Zeitfenster(von: 23 * 60, bis: 7 * 60)
        XCTAssertTrue(nacht.enthaelt(23 * 60))
        XCTAssertTrue(nacht.enthaelt(0))
        XCTAssertTrue(nacht.enthaelt(7 * 60 - 1))
        XCTAssertFalse(nacht.enthaelt(7 * 60))
        XCTAssertFalse(nacht.enthaelt(12 * 60))
        XCTAssertFalse(nacht.enthaelt(23 * 60 - 1))
    }

    func testGleicheGrenzenSindLeer() {
        XCTAssertFalse(BandRegeln.Zeitfenster(von: 600, bis: 600).enthaelt(600))
    }

    func testStandardNachtGehtVonZweiundzwanzigBisSieben() {
        XCTAssertEqual(BandRegeln.standardNacht, BandRegeln.Zeitfenster(von: 22 * 60, bis: 7 * 60))
        XCTAssertTrue(BandRegeln.standardNacht.enthaelt(0))
        XCTAssertFalse(BandRegeln.standardNacht.enthaelt(12 * 60))
    }

    func testMinuteAmTagIstBerlinerZeit() {
        // 2026-10-28 12:34 Berlin (MEZ, UTC+1 nach der Zeitumstellung am 25.10.) = 11:34 UTC
        let datum = Date(timeIntervalSince1970: 1_793_187_240)
        XCTAssertEqual(BandRegeln.minuteAmTag(datum), 12 * 60 + 34)
    }

    // MARK: Gate

    func testFreieQuelleVibriert() {
        XCTAssertNil(pruefen())
    }

    func testAusSperrtZuerst() {
        XCTAssertEqual(pruefen(regel: BandRegeln.Regel(an: false, staerke: .sanft, pauseMinuten: 3), umfeld: umfeld(arm: false)), .aus)
    }

    func testBandNichtAmArmSperrtUnbekanntNicht() {
        XCTAssertEqual(pruefen(umfeld: umfeld(arm: false)), .nichtAmArm)
        XCTAssertNil(pruefen(umfeld: umfeld(arm: nil)))
    }

    func testAkkuWaechter() {
        XCTAssertEqual(pruefen(umfeld: umfeld(akku: 19)), .akkuNiedrig)
        XCTAssertNil(pruefen(umfeld: umfeld(akku: 20)))
        XCTAssertNil(pruefen(umfeld: umfeld(akku: nil)), "unbekannter Akku sperrt nicht")
        XCTAssertNil(pruefen(umfeld: umfeld(akku: 5, schwelle: 0)), "Schwelle 0 = Wächter aus")
    }

    func testRuhezeitSperrtAusserPartnerMitAusnahme() {
        let ruhe = [BandRegeln.Zeitfenster(von: 23 * 60, bis: 7 * 60)]
        XCTAssertEqual(pruefen(.gymPause, minute: 1, umfeld: umfeld(ruhe: ruhe)), .ruhezeit)
        XCTAssertNil(pruefen(.wunsch, minute: 1, umfeld: umfeld(ruhe: ruhe)))
        XCTAssertNil(pruefen(.partner, minute: 1, umfeld: umfeld(ruhe: ruhe)))
        XCTAssertEqual(pruefen(.wunsch, minute: 1, umfeld: umfeld(ruhe: ruhe, ausnahme: false)), .ruhezeit)
        XCTAssertNil(pruefen(.gymPause, minute: 12 * 60, umfeld: umfeld(ruhe: ruhe)))
    }

    func testMehrereFensterJedesZaehlt() {
        let ruhe = [BandRegeln.Zeitfenster(von: 12 * 60, bis: 13 * 60), BandRegeln.Zeitfenster(von: 23 * 60, bis: 7 * 60)]
        XCTAssertEqual(pruefen(minute: 12 * 60 + 30, umfeld: umfeld(ruhe: ruhe)), .ruhezeit)
        XCTAssertEqual(pruefen(minute: 2 * 60, umfeld: umfeld(ruhe: ruhe)), .ruhezeit)
        XCTAssertNil(pruefen(minute: 15 * 60, umfeld: umfeld(ruhe: ruhe)))
    }

    func testMindestpauseJeQuelleUndUntergrenze() {
        XCTAssertEqual(pruefen(letzte: vor(2)), .pause)
        XCTAssertNil(pruefen(letzte: vor(3)))
        let ohne = BandRegeln.Regel(an: true, staerke: .stark, pauseMinuten: 0)
        XCTAssertEqual(pruefen(regel: ohne, letzte: jetzt.addingTimeInterval(-10)), .pause, "auch ohne Pause mindestens 30 s")
        XCTAssertNil(pruefen(regel: ohne, letzte: jetzt.addingTimeInterval(-31)))
        XCTAssertNil(pruefen(letzte: jetzt.addingTimeInterval(500)), "Uhr zurückgestellt: Pause vorbei")
    }

    // MARK: Stufen

    func testEhrlicheStufenNamenUndGespeicherteSchluessel() {
        XCTAssertEqual(BandNachrichtRegel.Staerke.allCases.map(\.name), ["1 Puls", "2 Pulse", "3 Pulse"])
        XCTAssertEqual(BandNachrichtRegel.Staerke.allCases.map(\.rawValue), ["sanft", "normal", "stark"])
        XCTAssertTrue(BandNachrichtRegel.pausen.contains(BandNachrichtRegel.standardPause))
    }

    func testSchluesselSindEindeutigUndBeginnenMitFitBand() {
        XCTAssertEqual(BandQuelle.partner.anSchluessel, "fit.band.partner.an")
        XCTAssertEqual(BandQuelle.partner.staerkeSchluessel, "fit.band.partner.staerke")
        XCTAssertEqual(BandQuelle.partner.pauseSchluessel, "fit.band.partner.pause")
        XCTAssertEqual(BandQuelle.partner.letzteSchluessel, "fit.band.partner.letzte")
        XCTAssertEqual(Set(BandQuelle.allCases.map(\.anSchluessel)).count, BandQuelle.allCases.count)
        XCTAssertEqual(Set(BandQuelle.allCases.map(\.letzteSchluessel)).count, BandQuelle.allCases.count)
    }

    func testStandardsJeQuelle() {
        XCTAssertEqual(BandQuelle.partner.standardStaerke.pulse, 1)
        XCTAssertEqual(BandQuelle.wunsch.standardStaerke.pulse, 2)
        XCTAssertTrue(BandQuelle.wunsch.standardAn)
        XCTAssertTrue(BandQuelle.gymPause.standardAn, "Idee 87: das Pausen-Ende vibriert, sobald das Band an ist")
        XCTAssertFalse(BandQuelle.partner.standardAn)
        XCTAssertFalse(BandQuelle.gymPuls.standardAn)
        for q in BandQuelle.allCases { XCTAssertTrue(q.pausen.contains(q.standardPause), q.rawValue) }
    }

    func testRegelLiestSchluesselUndStandard() {
        let d = UserDefaults(suiteName: "BandRegelnTests")!
        d.removePersistentDomain(forName: "BandRegelnTests")
        XCTAssertEqual(BandQuelle.partner.regel(d), BandRegeln.Regel(an: false, staerke: .sanft, pauseMinuten: 3))
        d.set(true, forKey: "fit.band.partner.an")
        d.set("normal", forKey: "fit.band.partner.staerke")
        d.set(5, forKey: "fit.band.partner.pause")
        XCTAssertEqual(BandQuelle.partner.regel(d), BandRegeln.Regel(an: true, staerke: .normal, pauseMinuten: 5))
        d.set("kaputt", forKey: BandQuelle.wunsch.staerkeSchluessel)
        XCTAssertEqual(BandQuelle.wunsch.regel(d).staerke, .normal, "unbekannter Wert: Standard der Quelle")
    }

    // MARK: Muster der Wünsche

    func testMusterBestimmenDiePulse() {
        let eingestellt = BandNachrichtRegel.Staerke.stark
        XCTAssertEqual(BandMusterRegel.staerke(.kurz, pauseEnde: eingestellt), .sanft)
        XCTAssertEqual(BandMusterRegel.staerke(.lang, pauseEnde: eingestellt), .normal)
        XCTAssertEqual(BandMusterRegel.staerke(.doppelt, pauseEnde: eingestellt), .normal)
        XCTAssertEqual(BandMusterRegel.staerke(.ruf, pauseEnde: eingestellt), .stark)
        XCTAssertEqual(BandMusterRegel.staerke(.pauseEnde, pauseEnde: eingestellt), .stark, "Pausen-Ende: einstellbar")
        XCTAssertEqual(BandMusterRegel.staerke(.pauseEnde, pauseEnde: .sanft), .sanft)
    }

    func testPausenEndeGehoertZurGymPauseAlleAnderenZumWunsch() {
        XCTAssertEqual(BandMusterRegel.quelle(.pauseEnde), .gymPause)
        for m in [BandMuster.kurz, .lang, .doppelt, .ruf] { XCTAssertEqual(BandMusterRegel.quelle(m), .wunsch) }
    }

    // MARK: Gym

    func testZielPuls() {
        XCTAssertTrue(BandRegeln.zielPulsErreicht(training: true, puls: 155, zeit: vor(3), jetzt: jetzt, ziel: 150))
        XCTAssertFalse(BandRegeln.zielPulsErreicht(training: true, puls: 149, zeit: vor(3), jetzt: jetzt, ziel: 150))
        XCTAssertFalse(BandRegeln.zielPulsErreicht(training: false, puls: 170, zeit: vor(3), jetzt: jetzt, ziel: 150))
        XCTAssertFalse(BandRegeln.zielPulsErreicht(training: true, puls: 170, zeit: vor(30), jetzt: jetzt, ziel: 150), "zu alt")
        XCTAssertFalse(BandRegeln.zielPulsErreicht(training: true, puls: nil, zeit: nil, jetzt: jetzt, ziel: 150))
    }
}
