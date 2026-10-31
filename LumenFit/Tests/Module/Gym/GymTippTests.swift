import TipKit
import XCTest
@testable import LumenFit

/// Wann ein Gym-Hinweis erscheint (reine Regeln), die Pause-Regel und dass jeder Hinweis eine eigene Kennung hat.
@MainActor
final class GymTippTests: XCTestCase {
    private func zeigen(_ art: GymTippArt, laeuft: Bool = true, index: Int = 0, saetze: Int = 0, volumen: Double = 0, wechselbar: Bool = false, plan: Int = 0) -> Bool {
        GymTippRegeln.zeigen(art, GymTippKontext(trainingLaeuft: laeuft, kartenIndex: index, saetze: saetze, volumen: volumen, tagWechselbar: wechselbar, planUebungen: plan))
    }

    func testBeendenNurImLaufendenTraining() {
        XCTAssertTrue(zeigen(.trainingBeenden))
        XCTAssertFalse(zeigen(.trainingBeenden, laeuft: false))
    }

    func testTagWechselNurWennWechselbar() {
        XCTAssertTrue(zeigen(.trainingstagWechseln, wechselbar: true))
        XCTAssertFalse(zeigen(.trainingstagWechseln, wechselbar: false))
        XCTAssertFalse(zeigen(.trainingstagWechseln, laeuft: false, wechselbar: true))
    }

    func testUebungMehrNurAmObersten() {
        XCTAssertTrue(zeigen(.uebungMehr, index: 0))
        XCTAssertFalse(zeigen(.uebungMehr, index: 1))
        XCTAssertFalse(zeigen(.uebungMehr, laeuft: false))
    }

    func testCardioSchnellNurOhneLaufendesTraining() {
        XCTAssertTrue(zeigen(.cardioSchnell, laeuft: false))
        XCTAssertFalse(zeigen(.cardioSchnell, laeuft: true))
    }

    func testVolumenErstMitVolumen() {
        XCTAssertFalse(zeigen(.volumen, volumen: 0))
        XCTAssertTrue(zeigen(.volumen, volumen: 1_250))
        XCTAssertFalse(zeigen(.volumen, laeuft: false, volumen: 1_250))
    }

    func testSatzWischenNurAmOberstenMitSaetzen() {
        XCTAssertTrue(zeigen(.satzWischen, index: 0, saetze: 3))
        XCTAssertFalse(zeigen(.satzWischen, index: 0, saetze: 0))
        XCTAssertFalse(zeigen(.satzWischen, index: 2, saetze: 3))
        XCTAssertFalse(zeigen(.satzWischen, laeuft: false, saetze: 3))
    }

    func testPlanZeileNurMitUebungen() {
        XCTAssertTrue(zeigen(.planZeile, laeuft: false, plan: 2))
        XCTAssertFalse(zeigen(.planZeile, laeuft: false, plan: 0))
    }

    func testSplitFuerDichImmer() {
        XCTAssertTrue(zeigen(.splitFuerDich, laeuft: false))
    }

    func testJederHinweisHatEineEigeneKennungUndText() {
        let kennungen = GymTippArt.allCases.map { $0.tipp.id }
        XCTAssertEqual(Set(kennungen).count, GymTippArt.allCases.count)
        XCTAssertEqual(GymTippArt.allCases.count, 13)
    }

    // MARK: Lovea-Aufbau

    func testLoveaHinweiseHabenEigeneTypenNebenDenLumenHinweisen() {
        XCTAssertEqual(GymTippArt.allCases.filter { $0.rawValue.hasPrefix("lovea") }.count, 5)
        XCTAssertNotEqual(GymTippArt.loveaUebungMehr.tipp.id, GymTippArt.uebungMehr.tipp.id, "der Lumen-Text und sein Zähler bleiben unberührt")
    }

    func testLoveaHinweiseKommenWoDasElementZuSehenIst() {
        XCTAssertTrue(zeigen(.loveaUebungMehr, index: 3))
        XCTAssertFalse(zeigen(.loveaUebungMehr, laeuft: false))
        XCTAssertTrue(zeigen(.loveaTrainingstagWechseln, wechselbar: true))
        XCTAssertFalse(zeigen(.loveaTrainingstagWechseln, wechselbar: false))
        for art in [GymTippArt.loveaSplitFuerDich, .loveaStartMehr, .loveaSplitTagMehr] { XCTAssertTrue(zeigen(art, laeuft: false)) }
    }

    // MARK: Ein- und ausschalten

    func testAusImTestHostUndBeiDemo() {
        XCTAssertTrue(GymTippRegeln.aktiv(argumente: ["App"], imTestHost: false))
        XCTAssertFalse(GymTippRegeln.aktiv(argumente: ["App"], imTestHost: true))
        XCTAssertFalse(GymTippRegeln.aktiv(argumente: ["App", "-lumenFitDemo"], imTestHost: false))
    }

    func testImTestHostSindDieSprechblasenAus() {
        XCTAssertFalse(GymTipps.an)
    }

    // MARK: Pause

    func testPauseErsterStartZeigtNichtNeu() {
        XCTAssertFalse(GymTippPause.wiederZeigen(letzterStart: nil, jetzt: Date()))
    }

    func testPauseGrenzeVierzehnTage() {
        let jetzt = Date()
        XCTAssertFalse(GymTippPause.wiederZeigen(letzterStart: jetzt.addingTimeInterval(-13 * 86_400), jetzt: jetzt))
        XCTAssertTrue(GymTippPause.wiederZeigen(letzterStart: jetzt.addingTimeInterval(-14 * 86_400), jetzt: jetzt))
        XCTAssertTrue(GymTippPause.wiederZeigen(letzterStart: jetzt.addingTimeInterval(-40 * 86_400), jetzt: jetzt))
    }

    func testVorKonfigurationMerktDenStartOhneLeeren() throws {
        let name = "gym-tipp-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let t0 = Date()
        GymTippPause.vorKonfiguration(defaults, jetzt: t0)
        XCTAssertEqual(defaults.object(forKey: GymTippPause.schluessel) as? Date, t0)
        let t1 = t0.addingTimeInterval(3 * 86_400)
        GymTippPause.vorKonfiguration(defaults, jetzt: t1)
        XCTAssertEqual(defaults.object(forKey: GymTippPause.schluessel) as? Date, t1)
    }
}
