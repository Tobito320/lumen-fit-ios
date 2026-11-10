import UIKit
import XCTest
@testable import LumenFit

/// Die Haken der Intents (Satz fertig, Kurzbefehle) gegen eine Fake-Steuerung. Im Widget-Prozess sind die Haken nil: dann tut der Intent nichts und stürzt nicht.
@MainActor
final class SatzFertigIntentTests: XCTestCase {
    override func tearDown() async throws {
        SatzFertigIntent.ausfuehren = nil
        SatzStartenIntent.ausfuehren = nil
        KurzbefehlHaken.trainingStarten = nil
        KurzbefehlHaken.oeffne = nil
        try await super.tearDown()
    }

    private func start() throws -> (umgebung: AppUmgebung, steuerung: WidgetsTestSteuerung) {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        let steuerung = WidgetsTestSteuerung()
        u.trainingSteuerung = steuerung
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: WidgetsTestFabrik(), neuladen: {})
        return (u, steuerung)
    }

    func testSatzFertigRuftDieSteuerungDesTrainings() async throws {
        let (_, steuerung) = try start()
        _ = try await SatzFertigIntent().perform()
        XCTAssertEqual(steuerung.satzFertigAufrufe, 1)
        _ = try await SatzFertigIntent().perform()
        XCTAssertEqual(steuerung.satzFertigAufrufe, 2)
    }

    func testSatzStartenRuftDieSteuerungDesTrainings() async throws {
        let (_, steuerung) = try start()
        _ = try await SatzStartenIntent().perform()
        XCTAssertEqual(steuerung.satzStartAufrufe, 1)
        XCTAssertEqual(steuerung.satzFertigAufrufe, 0, "kein Haken, nur der Start")
    }

    func testDieSteuerungWirdErstBeimTippenGelesen() async throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: WidgetsTestFabrik(), neuladen: {})
        let spaeter = WidgetsTestSteuerung()
        u.trainingSteuerung = spaeter   // das Modul gym setzt sie in seinem eigenen start, auch nach widgets
        _ = try await SatzFertigIntent().perform()
        XCTAssertEqual(spaeter.satzFertigAufrufe, 1)
    }

    func testImWidgetProzessIstDerHakenNilUndNichtsPassiert() async throws {
        SatzFertigIntent.ausfuehren = nil
        _ = try await SatzFertigIntent().perform()
        SatzStartenIntent.ausfuehren = nil
        _ = try await SatzStartenIntent().perform()
        KurzbefehlHaken.trainingStarten = nil
        KurzbefehlHaken.oeffne = nil
        _ = try await TrainingStartenIntent().perform()
        _ = try await GewichtEintragenIntent().perform()
        _ = try await EssenScannenIntent().perform()
    }

    func testTrainingStartenStartetDenHeutigenPlantagUndZeigtDasGym() async throws {
        let (u, steuerung) = try start()
        _ = try await TrainingStartenIntent().perform()
        XCTAssertEqual(steuerung.gestartet.count, 1)
        XCTAssertNil(steuerung.gestartet[0], "kein bestimmter Plantag: der Gym-Teil nimmt den von heute")
        XCTAssertEqual(u.router.tab, .training)
    }

    func testGewichtEintragenUndEssenScannenOeffnenDieSeiten() async throws {
        let (u, _) = try start()
        _ = try await GewichtEintragenIntent().perform()
        XCTAssertTrue(u.router.pfade.values.flatMap { $0 }.contains(.gewichtEintragen))
        _ = try await EssenScannenIntent().perform()
        XCTAssertEqual(u.router.tab, .profil)
        XCTAssertEqual(u.router.pfade[.profil], [.essen(.scan)])
    }

    func testStartIstIdempotentUndSetztDieLiveAnzeige() throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        XCTAssertNil(WidgetsModul.laufzeit(u))
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: WidgetsTestFabrik(), neuladen: {})
        let erste = try XCTUnwrap(WidgetsModul.laufzeit(u))
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: WidgetsTestFabrik(), neuladen: {})
        XCTAssertTrue(WidgetsModul.laufzeit(u) === erste)
        XCTAssertTrue(u.liveAnzeige is LiveActivityDienst)
    }

    func testTrainingBeendetBeendetDieLiveActivity() async throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        let fabrik = WidgetsTestFabrik()
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: fabrik, neuladen: {})
        let laufzeit = try XCTUnwrap(WidgetsModul.laufzeit(u))
        let stand = TrainingLiveStand(uebung: "Beispiel-Übung", satz: 1, von: 3, pauseEnde: nil, start: Date(), planName: "Push")
        await u.liveAnzeige.training(stand)
        await laufzeit.verarbeite(.trainingBeendet(session: "s1"))
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand), .beende])
    }

    // MARK: - Steuerelement (Idee 100)

    func testSchnellzugriffTrainingStartetUndScanOeffnetDenScan() async throws {
        let (u, steuerung) = try start()
        _ = try await SchnellzugriffIntent(aktion: .training).perform()
        XCTAssertEqual(steuerung.gestartet.count, 1)
        XCTAssertEqual(u.router.tab, .training)
        _ = try await SchnellzugriffIntent(aktion: .scan).perform()
        XCTAssertEqual(u.router.tab, .profil)
        XCTAssertEqual(u.router.pfade[.profil], [.essen(.scan)])
    }

    func testSchnellzugriffImWidgetProzessTutNichts() async throws {
        KurzbefehlHaken.trainingStarten = nil
        KurzbefehlHaken.oeffne = nil
        _ = try await SchnellzugriffIntent(aktion: .training).perform()
        _ = try await SchnellzugriffIntent(aktion: .scan).perform()
    }

    func testSchnellzugriffSymboleGibtEsUndSindBenannt() {
        for aktion in SchnellzugriffAktion.allCases {
            XCTAssertNotNil(UIImage(systemName: aktion.symbolName), aktion.symbolName)
            XCTAssertFalse(aktion.titel.isEmpty)
        }
        XCTAssertEqual(SchnellzugriffAktion.allCases.count, 2)
    }
}
