import XCTest
@testable import LumenFit

/// Die Live Activity des Trainings gegen eine Fake-Fabrik (ActivityKit selbst prüft nur ein Gerät): nur im Training gestartet, nur bei Satzwechsel aktualisiert, am Ende beendet.
final class LiveActivityDienstTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_157_600)

    private func stand(satz: Int = 1, uebung: String = "Beispiel-Bankdrücken", von: Int = 4, pauseEnde: Date? = nil) -> TrainingLiveStand {
        TrainingLiveStand(uebung: uebung, satz: satz, von: von, pauseEnde: pauseEnde, start: start, planName: "Push")
    }

    func testDerErsteStandStartetDieActivity() async {
        let fabrik = WidgetsTestFabrik()
        let dienst = LiveActivityDienst(fabrik: fabrik)
        await dienst.training(stand())
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand())])
    }

    func testOhneTrainingWirdNichtsGestartetOderBeendet() async {
        let fabrik = WidgetsTestFabrik()
        let dienst = LiveActivityDienst(fabrik: fabrik)
        await dienst.training(nil)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [])
    }

    func testAktualisiertWirdNurBeiSatzwechsel() async {
        let fabrik = WidgetsTestFabrik()
        let dienst = LiveActivityDienst(fabrik: fabrik)
        await dienst.training(stand(satz: 1))
        await dienst.training(stand(satz: 1))                       // derselbe Stand: nichts
        await dienst.training(stand(satz: 2))                       // neuer Satz
        await dienst.training(stand(satz: 2))                       // wieder derselbe
        await dienst.training(stand(satz: 3, von: 5))               // andere Satzzahl
        await dienst.training(stand(satz: 1, uebung: "Rudern", von: 3)) // neue Übung
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand(satz: 1)), .aktualisiere(stand(satz: 2)), .aktualisiere(stand(satz: 3, von: 5)),
                                 .aktualisiere(stand(satz: 1, uebung: "Rudern", von: 3))])
    }

    func testEinePauseAendertDieAnzeige() async {
        let fabrik = WidgetsTestFabrik()
        let dienst = LiveActivityDienst(fabrik: fabrik)
        let ende = start.addingTimeInterval(90)
        await dienst.training(stand(satz: 2))
        await dienst.training(stand(satz: 2, pauseEnde: ende))
        await dienst.training(stand(satz: 2, pauseEnde: ende))
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand(satz: 2)), .aktualisiere(stand(satz: 2, pauseEnde: ende))])
    }

    func testDasEndeBeendetUndEinNeuesTrainingStartetNeu() async {
        let fabrik = WidgetsTestFabrik()
        let dienst = LiveActivityDienst(fabrik: fabrik)
        await dienst.training(stand())
        await dienst.training(nil)
        await dienst.training(nil)           // zweites Ende: nichts mehr zu beenden
        await dienst.training(stand(uebung: "Kniebeugen"))
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .beende, .starte(stand(uebung: "Kniebeugen"))])
    }

    func testGehtDerStartNichtWirdBeimNaechstenStandNochEinmalVersucht() async {
        let fabrik = WidgetsTestFabrik(startErlaubt: false)   // zum Beispiel: App nicht im Vordergrund
        let dienst = LiveActivityDienst(fabrik: fabrik)
        await dienst.training(stand(satz: 1))
        await fabrik.setzeStartErlaubt(true)
        await dienst.training(stand(satz: 2))
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand(satz: 1)), .starte(stand(satz: 2))])
    }

    func testEineActivityEinesFruehherenProzessesWirdWeitergefuehrtStattDoppeltAngelegt() async {
        let fabrik = WidgetsTestFabrik(lebtSchon: true)
        let dienst = LiveActivityDienst(fabrik: fabrik)
        await dienst.training(stand(satz: 2))
        await dienst.training(stand(satz: 2))
        await dienst.training(stand(satz: 3))
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.aktualisiere(stand(satz: 2)), .aktualisiere(stand(satz: 3))])
    }

    func testEineLaufendeActivityWirdBeiNilAuchOhneEigenenStartBeendet() async {
        let fabrik = WidgetsTestFabrik(lebtSchon: true)
        let dienst = LiveActivityDienst(fabrik: fabrik)
        await dienst.training(nil)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.beende])
    }

    func testBrauchtUpdateRein() {
        XCTAssertTrue(LiveAktivitaetLogik.brauchtUpdate(alt: nil, neu: stand()))
        XCTAssertFalse(LiveAktivitaetLogik.brauchtUpdate(alt: stand(), neu: stand()))
        XCTAssertTrue(LiveAktivitaetLogik.brauchtUpdate(alt: stand(satz: 1), neu: stand(satz: 2)))
        XCTAssertTrue(LiveAktivitaetLogik.brauchtUpdate(alt: stand(), neu: stand(uebung: "Rudern")))
        XCTAssertTrue(LiveAktivitaetLogik.brauchtUpdate(alt: stand(), neu: stand(pauseEnde: start.addingTimeInterval(60))))
    }
}
