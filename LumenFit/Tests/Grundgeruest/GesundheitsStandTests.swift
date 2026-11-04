import XCTest
@testable import LumenFit

@MainActor
final class GesundheitsStandTests: XCTestCase {
    private let uhr = TestUhr()
    private var heute: String { Datum.text(uhr.lesen) }

    private func tage(_ anzahl: Int, schritte: Int = 5000) -> [TagesWerte] {
        (0..<anzahl).map { TagesWerte(tag: Datum.addTage(heute, -$0), schritte: schritte) }
    }

    func testDerErsteAbrufHolt60TageSpaeterePurDieLetztenDrei() async {
        let leser = FakeHealthLeser(tage: tage(80))
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        XCTAssertEqual(stand.zugriff, .unbekannt)
        XCTAssertNil(stand.letzteAktualisierung)

        await stand.aktualisiere()
        XCTAssertEqual(leser.tagesAbfragen.count, 1)
        XCTAssertEqual(leser.tagesAbfragen[0].von, Datum.addTage(heute, -59))
        XCTAssertEqual(leser.tagesAbfragen[0].bis, heute)
        XCTAssertEqual(stand.tage.count, 60)
        XCTAssertEqual(stand.zugriff, .angefragt)
        XCTAssertEqual(stand.letzteAktualisierung, uhr.lesen)

        uhr.vor(sekunden: 3600)
        await stand.aktualisiere()
        XCTAssertEqual(leser.tagesAbfragen.count, 2)
        XCTAssertEqual(leser.tagesAbfragen[1].von, Datum.addTage(heute, -(GesundheitsStand.nachladeTage - 1)))
        XCTAssertEqual(stand.tage.count, 60, "alte Tage bleiben stehen")
    }

    func testWerDenLaufendenAbrufTrifftWartetUndBekommtEinenFolgeabruf() async {
        let innen = FakeHealthLeser(tage: tage(5))
        let leser = GesundheitsMerkLeser(innen: innen)
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        let erster = Task { await stand.aktualisiere() }
        await leser.tor.warteAufAnkunft()   // der erste Abruf steckt in den Tageswerten
        innen.setze(tage: tage(5, schritte: 9000))   // Health meldet neue Schritte
        // `Task` statt `async let`: erbt den Hauptakteur, läuft also beim `yield` sicher bis zum Warten an.
        let wartende = (0..<3).map { _ in Task { await stand.aktualisiere() } }
        await Task.yield()
        await leser.tor.oeffnen()
        for w in wartende { await w.value }
        await erster.value
        XCTAssertEqual(innen.tagesAbfragen.count, 2, "drei Wartende, ein Folgeabruf statt drei")
        XCTAssertEqual(stand.tage[heute]?.schritte, 9000, "der Folgeabruf holt, was während des ersten kam")
        await stand.aktualisiere()
        XCTAssertEqual(innen.tagesAbfragen.count, 3, "danach startet wieder ein eigener Abruf")
    }

    func testEinNeuerBereichWaehrendEinesAbrufsWirdTrotzdemGefragt() async {
        let leser = GesundheitsMerkLeser(innen: FakeHealthLeser(tage: tage(5)))
        let wahl = GesundheitsTypenWahl()
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr, typen: { wahl.typen })
        let erster = Task { await stand.aktualisiere() }
        await leser.tor.warteAufAnkunft()   // der erste Abruf hat [.schritte] gefragt und steckt in den Tageswerten
        wahl.typen = [.schritte, .schlaf]
        let zweiter = Task { await stand.aktualisiere() }
        await Task.yield()
        await leser.tor.oeffnen()
        await zweiter.value
        await erster.value
        XCTAssertEqual(leser.anfragen, [[.schritte], [.schritte, .schlaf]], "der neue Bereich wurde gefragt, nicht vom laufenden Abruf verschluckt")
    }

    func testNeueWerteDerLetztenTageErsetzenDieAlten() async {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 1000)])
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        await stand.aktualisiere()
        XCTAssertEqual(stand.tage[heute]?.schritte, 1000)
        leser.setze(tage: [TagesWerte(tag: heute, schritte: 4000)])
        await stand.aktualisiere()
        XCTAssertEqual(stand.tage[heute]?.schritte, 4000)
    }

    func testOhneHealthGibtEsEinenStatusStattEinesAbsturzes() async {
        let leser = FakeHealthLeser(zugriff: .nichtVerfuegbar, tage: tage(5))
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        await stand.aktualisiere()
        XCTAssertEqual(stand.zugriff, .nichtVerfuegbar)
        XCTAssertTrue(stand.tage.isEmpty)
        XCTAssertTrue(leser.tagesAbfragen.isEmpty, "ohne Health wird nichts abgefragt")
        XCTAssertNil(stand.letzteAktualisierung)
    }

    func testBandUndHealthZaehlenDasMaximumNieDieSumme() async {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 10_000, distanzMeter: 7000), TagesWerte(tag: Datum.addTage(heute, -1), schritte: 3000)])
        let gestern = Datum.addTage(heute, -1)
        let band = [BandTagOp(tag: heute, schritte: 15_000, meter: 11_000), BandTagOp(tag: gestern, schritte: 2000, meter: 1500), BandTagOp(tag: Datum.addTage(heute, -2), schritte: 4000, meter: 3000)]
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr, band: { band })
        await stand.aktualisiere()
        XCTAssertEqual(stand.tage[heute]?.schritte, 15_000, "Band größer: Band gilt")
        XCTAssertEqual(stand.tage[heute]?.distanzMeter, 11_000)
        XCTAssertEqual(stand.tage[gestern]?.schritte, 3000, "Health größer: Health gilt")
        XCTAssertEqual(stand.tage[Datum.addTage(heute, -2)]?.schritte, 4000, "Tag nur vom Band")
    }

    // MARK: Schlaf: Hand, Band, Health

    private func bandOp(_ n: SchlafNacht, minuten: Int) -> BandSchlafOp {
        let bis = n.bis
        let von = bis.addingTimeInterval(-Double(minuten) * 60)
        return BandSchlafOp(tag: n.tag, start: von, ende: bis, phasen: [SchlafAbschnitt(phase: .kern, von: von, bis: bis)])
    }

    func testNaechteGeltenInDerReihenfolgeHandBandHealth() async {
        let gestern = Datum.addTage(heute, -1)
        let vorgestern = Datum.addTage(heute, -2)
        let healthHeute = SchlafTestBau.nacht(heute, minuten: 400)
        let leser = FakeHealthLeser(naechte: [healthHeute, SchlafTestBau.nacht(gestern, minuten: 430), SchlafTestBau.nacht(vorgestern, minuten: 410, phasen: true)])
        let handGestern = SchlafTestBau.nacht(gestern, minuten: 300)
        let eigene = SchlafEigeneQuellen(hand: [gestern: handGestern], band: [bandOp(healthHeute, minuten: 450), bandOp(SchlafTestBau.nacht(gestern, minuten: 0), minuten: 480)])
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr, eigeneNaechte: { eigene })
        await stand.aktualisiere()
        XCTAssertEqual(stand.naechte[heute]?.schlafMinuten, 450, "Band vor Health")
        XCTAssertEqual(stand.naechte[gestern]?.schlafMinuten, 300, "von Hand vor Band und Health")
        XCTAssertEqual(stand.naechte[vorgestern]?.schlafMinuten, 410, "ohne Band und Hand zählt Health")
        XCTAssertEqual(stand.naechteAusHealth[heute]?.schlafMinuten, 400, "der Schlaf-Tab bekommt Health getrennt")
        XCTAssertEqual(stand.gewaehlteNaechte(eigene: eigene).first { $0.nacht.tag == heute }?.quelle, .band)
        XCTAssertEqual(stand.gewaehlteNaechte(eigene: eigene).first { $0.nacht.tag == gestern }?.quelle, .eingetragen)
    }

    func testOhneEigeneNaechteGiltNurHealthWieBisher() async {
        let n = SchlafTestBau.nacht(heute, minuten: 400)
        let stand = GesundheitsStand(leser: FakeHealthLeser(naechte: [n]), uhr: uhr.uhr)
        await stand.aktualisiere()
        XCTAssertEqual(stand.naechte, [heute: n])
    }

    func testEinGesperrterTagBleibtLeerAuchMitBandAberEigeneEintragGiltWieder() async {
        var verlauf = ImportVerlaufStand()
        verlauf.schlafGesperrt = [heute]
        let health = SchlafTestBau.nacht(heute, minuten: 400)
        let band = BandSchlafOp(tag: heute, start: health.von, ende: health.bis, phasen: [SchlafAbschnitt(phase: .kern, von: health.von, bis: health.bis)])
        let nurBand = SchlafEigeneQuellen(hand: [:], band: [band])
        let stand = GesundheitsStand(leser: FakeHealthLeser(naechte: [health]), uhr: uhr.uhr, importVerlauf: { verlauf }, eigeneNaechte: { nurBand })
        await stand.aktualisiere()
        XCTAssertNil(stand.naechte[heute], "in Lovea gelöscht: weder Health noch Band holen die Nacht zurück")
        let mitEintrag = SchlafEigeneQuellen(hand: [heute: SchlafTestBau.nacht(heute, minuten: 360)], band: [band])
        let mitHand = GesundheitsStand(leser: FakeHealthLeser(naechte: [health]), uhr: uhr.uhr, importVerlauf: { verlauf }, eigeneNaechte: { mitEintrag })
        await mitHand.aktualisiere()
        XCTAssertEqual(mitHand.naechte[heute]?.schlafMinuten, 360)
    }

    func testGewichtUndVitalwerteKommenMitUndWerdenZusammengefuehrt() async {
        let gestern = Datum.addTage(heute, -1)
        let leser = FakeHealthLeser(gewichte: [GewichtsMesswert(tag: gestern, kg: 80.4), GewichtsMesswert(tag: heute, kg: 80.1)])
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        await stand.aktualisiere()
        XCTAssertEqual(stand.gewichte.map(\.kg), [80.4, 80.1])
        XCTAssertEqual(stand.vitale[.ruhepuls]?.count, 0)
    }
}

@MainActor private final class GesundheitsTypenWahl {
    var typen: Set<HealthTyp> = [.schritte]
}

/// Merkt sich, für welche Typen nach den Rechten gefragt wurde; sonst wie der innere Fake.
private final class GesundheitsMerkLeser: HealthLeser, @unchecked Sendable {   // @unchecked: `_anfragen` nur unter `schloss`
    private let innen: FakeHealthLeser
    private let schloss = NSLock()
    private var _anfragen: [Set<HealthTyp>] = []
    init(innen: FakeHealthLeser) { self.innen = innen }
    var anfragen: [Set<HealthTyp>] { schloss.withLock { _anfragen } }

    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff {
        schloss.withLock { _anfragen.append(typen) }
        return await innen.zugriff(fuer: typen)
    }
    /// Hält die erste Tagesabfrage an, bis der Test `tor.oeffnen()` ruft.
    let tor = GesundheitsTor()
    func tagesWerte(von: String, bis: String) async -> [TagesWerte] {
        await tor.ankommenUndWarten()
        return await innen.tagesWerte(von: von, bis: bis)
    }
    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht] { await innen.schlafNaechte(von: von, bis: bis) }
    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert] { await innen.vitalwerte(art, von: von, bis: bis) }
    func gewichte(von: String, bis: String) async -> [GewichtsMesswert] { await innen.gewichte(von: von, bis: bis) }
    func workouts(von: String, bis: String) async -> [HealthWorkout] { await innen.workouts(von: von, bis: bis) }
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void) {}
}

/// Hält nur den ersten Durchgang an; alle späteren laufen durch.
private actor GesundheitsTor {
    private var benutzt = false
    private var angekommen = false
    private var ankunft: CheckedContinuation<Void, Never>?
    private var offen: CheckedContinuation<Void, Never>?

    func ankommenUndWarten() async {
        guard !benutzt else { return }
        benutzt = true
        angekommen = true
        ankunft?.resume()
        ankunft = nil
        await withCheckedContinuation { offen = $0 }
    }
    func warteAufAnkunft() async {
        guard !angekommen else { return }
        await withCheckedContinuation { ankunft = $0 }
    }
    func oeffnen() {
        offen?.resume()
        offen = nil
    }
}
