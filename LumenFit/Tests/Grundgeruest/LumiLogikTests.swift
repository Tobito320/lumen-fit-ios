import XCTest
@testable import LumenFit

final class LumiLogikTests: XCTestCase {
    /// Mittwoch, 23.09.2026, 12 Uhr.
    private let heute = "2026-09-23"

    private func tag(_ zurueck: Int) -> String { Datum.addTage(heute, -zurueck) }

    private func zustand(_ aendern: (inout LumiLage) -> Void = { _ in }) -> LumiZustand {
        var lage = LumiLage(heute: heute, stunde: 12)
        aendern(&lage)
        return LumiLogik.zustand(lage)
    }

    func testOhneRegelGiltDieBasis() {
        XCTAssertEqual(zustand(), .bereit)
        XCTAssertEqual(zustand { $0.basis = .denkt }, .denkt)
        XCTAssertEqual(zustand { $0.basis = .muede }, .muede)
    }

    func testNachtsSchlaeftLumiAuchNachDemTraining() {
        XCTAssertEqual(zustand { $0.stunde = 23; $0.trainingsTage = [self.heute] }, .schlaeft)
        XCTAssertEqual(zustand { $0.stunde = 4 }, .schlaeft)
        XCTAssertEqual(zustand { $0.stunde = 5 }, .bereit)
        XCTAssertEqual(zustand { $0.stunde = 22 }, .bereit)
    }

    func testTrainiertHeuteIstZiel() {
        XCTAssertEqual(zustand { $0.trainingsTage = [self.heute] }, .ziel)
    }

    func testRekordGehtVorErschoepft() {
        XCTAssertEqual(zustand { $0.trainingsTage = [self.heute]; $0.rekordHeute = true; $0.minutenHeute = 120 }, .stolz)
        XCTAssertEqual(zustand { $0.rekordHeute = true }, .bereit, "ohne Training heute zählt kein Rekord")
    }

    func testErschoepftNachLangemOderSchweremTraining() {
        let grenzen: [(String, (inout LumiLage) -> Void, LumiZustand)] = [
            ("91 min", { $0.minutenHeute = 91 }, .erschoepft), ("90 min", { $0.minutenHeute = 90 }, .ziel),
            ("RPE 9", { $0.rpeSchnittHeute = 9 }, .erschoepft), ("RPE 8,9", { $0.rpeSchnittHeute = 8.9 }, .ziel),
            ("Gefühl 2", { $0.gefuehlHeute = 2 }, .erschoepft), ("Gefühl 3", { $0.gefuehlHeute = 3 }, .ziel),
            ("Morgen-Check 2", { $0.morgenCheck = 2 }, .erschoepft),
        ]
        for (name, aendern, erwartet) in grenzen {
            XCTAssertEqual(zustand { $0.trainingsTage = [self.heute]; aendern(&$0) }, erwartet, name)
        }
    }

    func testSerieBrauchtZweiWochenUndDasWochenziel() {
        XCTAssertEqual(zustand { $0.trainingsTage = [self.heute]; $0.serieWochen = 2; $0.wochenzielErreicht = true }, .serie)
        XCTAssertEqual(zustand { $0.trainingsTage = [self.heute]; $0.serieWochen = 1; $0.wochenzielErreicht = true }, .ziel)
        XCTAssertEqual(zustand { $0.trainingsTage = [self.heute]; $0.serieWochen = 5; $0.wochenzielErreicht = false }, .ziel)
        XCTAssertEqual(zustand { $0.trainingsTage = [self.heute]; $0.serieWochen = 5; $0.wochenzielErreicht = true; $0.minutenHeute = 100 }, .erschoepft)
    }

    func testVolleBoegenOhneTrainingSindZiel() {
        XCTAssertEqual(zustand { $0.boegenVoll = true; $0.schlafMinuten = 300 }, .ziel)
    }

    func testMuedeBeiKurzerNachtOderSchweremMorgen() {
        XCTAssertEqual(zustand { $0.schlafMinuten = 359 }, .muede)
        XCTAssertEqual(zustand { $0.schlafMinuten = 360 }, .bereit)
        XCTAssertEqual(zustand { $0.morgenCheck = 2 }, .muede)
        XCTAssertEqual(zustand { $0.morgenCheck = 3 }, .bereit)
        XCTAssertEqual(zustand { $0.schlafMinuten = 300; $0.trainingsTage = [self.tag(1)] }, .muede, "müde geht vor Muskelkater")
    }

    func testMuskelkaterNachEinemNeustart() {
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(1)] }, .muskelkater, "erstes Training gestern")
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(2)] }, .muskelkater, "erstes Training vorgestern")
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(1), self.tag(9)] }, .muskelkater, "nach 7 Tagen Pause")
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(1), self.tag(8)] }, .bereit, "6 Tage Pause sind kein Neustart")
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(1), self.tag(2)] }, .bereit, "regelmäßig trainiert")
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(3)] }, .bereit, "drei Tage her")
    }

    func testRuhetagGehtVorVermisst() {
        XCTAssertEqual(zustand { $0.ruhetag = true; $0.trainingsTage = [self.tag(3)] }, .ruhetag)
        XCTAssertEqual(zustand { $0.ruhetag = true; $0.trainingsTage = [self.tag(10)] }, .ruhetag)
    }

    func testVermisstAbSiebenTagenOhneTraining() {
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(7)] }, .vermisst)
        XCTAssertEqual(zustand { $0.trainingsTage = [self.tag(6)] }, .bereit)
        XCTAssertEqual(zustand { $0.trainingsTage = [] }, .bereit, "wer nie trainiert hat, wird nicht vermisst")
    }
}
