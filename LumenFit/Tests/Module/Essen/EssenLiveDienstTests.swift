import XCTest
@testable import LumenFit

/// Fake-Fabrik der Essen-Live-Activity (ein Akteur: Sendable ohne Sperre). Zeichnet jeden Aufruf auf.
actor EssenLiveTestFabrik: EssenLiveFabrik {
    enum Aufruf: Equatable { case starte(EssenLiveStand), aktualisiere(EssenLiveStand), beende }

    private(set) var aufrufe: [Aufruf] = []
    private(set) var veraltetAb: [Date] = []
    private var laufend: String?
    private var training: Bool
    private var startErlaubt: Bool

    init(laufendTag: String? = nil, training: Bool = false, startErlaubt: Bool = true) {
        laufend = laufendTag
        self.training = training
        self.startErlaubt = startErlaubt
    }

    func setzeTraining(_ laeuft: Bool) { training = laeuft }
    func setzeStartErlaubt(_ erlaubt: Bool) { startErlaubt = erlaubt }
    /// Die Person wischt die Activity vom Sperrbildschirm.
    func wegwischen() { laufend = nil }

    func laufenderTag() async -> String? { laufend }
    func trainingLaeuft() async -> Bool { training }

    func starte(_ stand: EssenLiveStand, veraltetAb: Date) async -> Bool {
        aufrufe.append(.starte(stand))
        self.veraltetAb.append(veraltetAb)
        guard startErlaubt else { return false }
        laufend = stand.tag
        return true
    }

    func aktualisiere(_ stand: EssenLiveStand, veraltetAb: Date) async {
        aufrufe.append(.aktualisiere(stand))
        self.veraltetAb.append(veraltetAb)
    }

    func beende() async {
        aufrufe.append(.beende)
        laufend = nil
    }
}

/// Der Dienst gegen die Fake-Fabrik (ActivityKit selbst prüft nur ein Gerät) und die Laufzeit gegen echte Ereignisse.
final class EssenLiveDienstTests: XCTestCase {
    private let uhr = TestUhr()   // Mittwoch 23.09.2026, 12:00 Berlin

    private func stand(tag: String = "2026-09-23", kcal: Int = 0) -> EssenLiveStand {
        EssenLiveStand(tag: tag, kcal: kcal, kcalZiel: 2000, proteinG: 0, proteinZiel: 120, kohlenhydrateG: 0, kohlenhydrateZiel: 220, fettG: 0, fettZiel: 70,
                       mahlzeitenKcal: [kcal, 0, 0, 0], naechste: "mittag")
    }

    private func dienst(_ fabrik: EssenLiveTestFabrik) -> EssenLiveDienst { EssenLiveDienst(fabrik: fabrik, uhr: uhr.uhr) }

    func testMitSchalterAnStartetDieActivityEinmalUndAktualisiertNurBeiAenderung() async {
        let fabrik = EssenLiveTestFabrik()
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await d.abgleichen(stand(), an: true)              // derselbe Stand: nichts
        await d.abgleichen(stand(kcal: 400), an: true)     // neuer Eintrag
        await d.abgleichen(stand(kcal: 400), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .aktualisiere(stand(kcal: 400))])
    }

    func testMitSchalterAusPassiertNichts() async {
        let fabrik = EssenLiveTestFabrik()
        await dienst(fabrik).abgleichen(stand(), an: false)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [])
    }

    func testSchalterAusBeendetEineLaufendeUndAnStartetNeu() async {
        let fabrik = EssenLiveTestFabrik()
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await d.abgleichen(stand(), an: false)
        await d.abgleichen(stand(), an: false)             // schon beendet: nichts mehr
        await d.abgleichen(stand(), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .beende, .starte(stand())])
    }

    func testEineActivityVomVortagWirdDurchEineNeueErsetzt() async {
        let fabrik = EssenLiveTestFabrik(laufendTag: "2026-09-22")
        await dienst(fabrik).abgleichen(stand(), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand())])
    }

    func testEineActivityEinesFruehherenProzessesWirdWeitergefuehrtStattDoppeltAngelegt() async {
        let fabrik = EssenLiveTestFabrik(laufendTag: "2026-09-23")
        await dienst(fabrik).abgleichen(stand(kcal: 100), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.aktualisiere(stand(kcal: 100))])
    }

    func testWaehrendDesTrainingsLaeuftKeineEssenActivity() async {
        let fabrik = EssenLiveTestFabrik()
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await fabrik.setzeTraining(true)
        await d.abgleichen(stand(kcal: 200), an: true)     // beendet
        await d.abgleichen(stand(kcal: 300), an: true)     // Training läuft noch: nichts
        await fabrik.setzeTraining(false)
        await d.abgleichen(stand(kcal: 300), an: true)     // danach wieder da
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .beende, .starte(stand(kcal: 300))])
    }

    func testWeggewischteActivityStartetHeuteNichtVonSelbstNeu() async {
        let fabrik = EssenLiveTestFabrik()
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await fabrik.wegwischen()
        await d.abgleichen(stand(kcal: 200), an: true)     // die Person hat sie beendet: Ruhe
        await d.abgleichen(stand(kcal: 400), an: true)
        var aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand())])
        // Am nächsten Tag darf sie wieder starten.
        await d.abgleichen(stand(tag: "2026-09-24"), an: true)
        aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .starte(stand(tag: "2026-09-24"))])
    }

    func testWeggewischtGiltAuchNachEinemNeustart() async throws {
        let speicher = try XCTUnwrap(UserDefaults(suiteName: "essenLive-\(UUID().uuidString)"))
        let erste = EssenLiveTestFabrik()
        let d1 = EssenLiveDienst(fabrik: erste, uhr: uhr.uhr, ablage: EssenLiveAblage(werte: speicher))
        await d1.abgleichen(stand(), an: true)
        await erste.wegwischen()
        await d1.abgleichen(stand(kcal: 100), an: true)
        // Neuer Prozess: derselbe Speicher, keine Activity mehr.
        let zweite = EssenLiveTestFabrik()
        let d2 = EssenLiveDienst(fabrik: zweite, uhr: uhr.uhr, ablage: EssenLiveAblage(werte: speicher))
        await d2.abgleichen(stand(kcal: 200), an: true)
        var aufrufe = await zweite.aufrufe
        XCTAssertEqual(aufrufe, [], "heute nicht von selbst wieder")
        await d2.abgleichen(stand(tag: "2026-09-24"), an: true)
        aufrufe = await zweite.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand(tag: "2026-09-24"))], "am nächsten Tag darf sie wieder starten")
    }

    func testWegwischenWaehrendDieAppBeendetWarGiltBeimNaechstenStart() async throws {
        let speicher = try XCTUnwrap(UserDefaults(suiteName: "essenLive-\(UUID().uuidString)"))
        let d1 = EssenLiveDienst(fabrik: EssenLiveTestFabrik(), uhr: uhr.uhr, ablage: EssenLiveAblage(werte: speicher))
        await d1.abgleichen(stand(), an: true)
        let fabrik = EssenLiveTestFabrik()
        await EssenLiveDienst(fabrik: fabrik, uhr: uhr.uhr, ablage: EssenLiveAblage(werte: speicher)).abgleichen(stand(), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [])
    }

    func testAusUndWiederAnNachDemWegwischenStartetNeu() async {
        let fabrik = EssenLiveTestFabrik()
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await fabrik.wegwischen()
        await d.abgleichen(stand(), an: false)
        await d.abgleichen(stand(), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .starte(stand())])
    }

    func testGehtDerStartNichtWirdBeimNaechstenStandNochEinmalVersucht() async {
        let fabrik = EssenLiveTestFabrik(startErlaubt: false)   // zum Beispiel: App nicht im Vordergrund
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await fabrik.setzeStartErlaubt(true)
        await d.abgleichen(stand(kcal: 100), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .starte(stand(kcal: 100))])
    }

    func testBeendenRaeumtAufUndDanachStartetEsNeu() async {
        let fabrik = EssenLiveTestFabrik()
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await d.beenden()
        await d.abgleichen(stand(), an: true)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [.starte(stand()), .beende, .starte(stand())])
    }

    func testDieActivityWirdMitMitternachtAlsVeraltetMarkiert() async {
        let fabrik = EssenLiveTestFabrik()
        let d = dienst(fabrik)
        await d.abgleichen(stand(), an: true)
        await d.abgleichen(stand(kcal: 100), an: true)
        let zeiten = await fabrik.veraltetAb
        XCTAssertEqual(zeiten, [Datum.datum("2026-09-24"), Datum.datum("2026-09-24")])
    }

    // MARK: - Laufzeit

    @MainActor
    func testEinGespeichertesEssenStartetDieActivityMitDemStandDesTages() async throws {
        let speicher = try XCTUnwrap(UserDefaults(suiteName: "EssenLiveDienstTests-\(UUID().uuidString)"))
        EssenLiveEinstellung.setze(true, speicher)
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner(), uhr: uhr)
        let daten = try XCTUnwrap(u.daten)
        let fabrik = EssenLiveTestFabrik()
        EssenLiveModul.start(u, fabrik: fabrik, speicher: speicher)
        let laufzeit = try XCTUnwrap(EssenLiveModul.laufzeit(u))
        let reis = Lebensmittel(id: "l-reis", name: "Reis", pro100: Naehrwerte(kcal: 130, protein: 3, kohlenhydrate: 28, fett: 0.3))
        daten.essen.eintragen(reis, menge: 200, einheit: .g, mahlzeit: .mittag, datum: "2026-09-23")
        await laufzeit.verarbeite(.mahlzeitGespeichert(tag: "2026-09-23"))
        let aufrufe = await fabrik.aufrufe
        guard case .starte(let stand)? = aufrufe.first else { return XCTFail("keine Activity gestartet: \(aufrufe)") }
        XCTAssertEqual(stand.tag, "2026-09-23")
        XCTAssertEqual(stand.kcal, 260)
        XCTAssertEqual(stand.mahlzeitenKcal, [0, 260, 0, 0])
        XCTAssertEqual(stand.naechste, "abend")   // 12 Uhr: Mittag ist voll, Abendessen kommt als Nächstes
    }

    @MainActor
    func testMitSchalterAusBleibtDieLaufzeitStill() async throws {
        let speicher = try XCTUnwrap(UserDefaults(suiteName: "EssenLiveDienstTests-\(UUID().uuidString)"))
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner(), uhr: uhr)
        let fabrik = EssenLiveTestFabrik()
        EssenLiveModul.start(u, fabrik: fabrik, speicher: speicher)
        let laufzeit = try XCTUnwrap(EssenLiveModul.laufzeit(u))
        await laufzeit.verarbeite(.vordergrund)
        await laufzeit.verarbeite(.einstellungenGeaendert)
        let aufrufe = await fabrik.aufrufe
        XCTAssertEqual(aufrufe, [])
    }
}
