import XCTest
@testable import LumenFit

/// Der Band-Dienst (Idee 85, 87, 88): ohne `bandAktiv` kein Bluetooth-Objekt; Verbindungsweg im zweiten Prozess (retrieveConnected, retrievePeripherals, Scan);
/// Status und Akku-Warnung; Vibration nach den Regeln; Status für Lovea.
@MainActor
final class BandDienstImplTests: XCTestCase {
    private var defaults: UserDefaults!
    private var schalter = false

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "BandDienstImplTests")
        defaults.removePersistentDomain(forName: "BandDienstImplTests")
        schalter = false
    }

    private struct Aufbau {
        var dienst: BandDienstImpl
        var fabrik: FakeFunkFabrik
        var bruecke: FakePartnerAustausch
        var tage: BandOpsSammler
    }

    private func aufbau(bruecke: FakePartnerAustausch = FakePartnerAustausch()) -> Aufbau {
        let fabrik = FakeFunkFabrik()
        let sammler = BandOpsSammler()
        let d = defaults!
        let senke = BandSenke(bisher: { sammler.bisher }, tag: { sammler.tage.append($0); sammler.bisher[$0.tag] = $0 }, schlaf: { sammler.schlaf.append($0) })
        let dienst = BandDienstImpl(aktiv: { [unowned self] in self.schalter }, bruecke: bruecke, defaults: d, uhr: { VerbindenTest.jetzt }, sende: { _ in },
                                    modell: { TrackerModell(funk: { fabrik.baue($0) }, senke: senke, defaults: d, uhr: { VerbindenTest.jetzt }) })
        return Aufbau(dienst: dienst, fabrik: fabrik, bruecke: bruecke, tage: sammler)
    }

    private func warte(_ bedingung: @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if bedingung() { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: Ohne Schalter kein Bluetooth

    func testOhneSchalterEntstehtKeinFunkUndKeinModell() async {
        let a = aufbau()
        a.dienst.starte()
        await a.dienst.verbinde()
        await a.dienst.vibriere(.kurz)
        await a.dienst.vibriere(.pauseEnde)
        let status = await a.dienst.status()
        XCTAssertEqual(a.fabrik.anzahl, 0, "kein CBCentralManager ohne bandAktiv")
        XCTAssertNil(a.dienst.modell)
        XCTAssertEqual(status, BandStatus(verbunden: false, akkuProzent: nil, name: nil))
        XCTAssertTrue(a.fabrik.funk.aufrufe.isEmpty)
    }

    func testMitSchalterEntstehtDasModellErstBeimVerbindenOderFortsetzen() async {
        schalter = true
        let a = aufbau()
        a.dienst.starte()
        XCTAssertNotNil(a.dienst.modell)
        XCTAssertEqual(a.fabrik.anzahl, 0, "noch nicht gekoppelt: auch jetzt kein Funk, die Bluetooth-Frage kommt erst mit Verbinden")
        await a.dienst.verbinde()
        XCTAssertEqual(a.fabrik.anzahl, 1)
        XCTAssertEqual(a.fabrik.funk.aufrufe, ["starten"])
        await a.dienst.verbinde()
        XCTAssertEqual(a.fabrik.anzahl, 1, "ein Funk genügt")
    }

    func testGekoppeltesBandVerbindetBeimStartVonSelbst() async {
        defaults.set(UUID().uuidString, forKey: TrackerFunk.kennungSchluessel)
        schalter = true
        let a = aufbau()
        a.dienst.starte()
        XCTAssertEqual(a.fabrik.anzahl, 1)
        XCTAssertEqual(a.fabrik.funk.aufrufe, ["starten"])
    }

    func testSchalterAusTrenntUndMeldetLovea() async {
        schalter = true
        let a = aufbau()
        await a.dienst.verbinde()
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        await warte { a.dienst.modell?.zustand == .verbunden }
        schalter = false
        a.dienst.ausschalten()
        XCTAssertTrue(a.fabrik.funk.aufrufe.contains("trennen"))
        XCTAssertEqual(a.bruecke.status.last?.verbunden, false)
        let status = await a.dienst.status()
        XCTAssertFalse(status.verbunden)
    }

    // MARK: Status, Akku, Warnung

    func testStatusZeigtVerbindungNameUndAkku() async {
        schalter = true
        let a = aufbau()
        await a.dienst.verbinde()
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        await warte { a.dienst.modell?.zustand == .verbunden }
        a.fabrik.melde(.daten(TrackerProtokoll.paket(.akku, [64, 0])))
        await warte { a.dienst.modell?.akku != nil }
        let status = await a.dienst.status()
        XCTAssertEqual(status, BandStatus(verbunden: true, akkuProzent: 64, name: "H59 Test"))
        XCTAssertFalse(a.dienst.modell?.akkuNiedrig ?? true)
    }

    func testAkkuUnterFuenfzehnProzentIstNiedrig() async {
        schalter = true
        let a = aufbau()
        await a.dienst.verbinde()
        a.fabrik.melde(.verbunden(name: nil))
        await warte { a.dienst.modell?.zustand == .verbunden }
        a.fabrik.melde(.daten(TrackerProtokoll.paket(.akku, [14, 0])))
        await warte { a.dienst.modell?.akku != nil }
        XCTAssertTrue(a.dienst.modell?.akkuNiedrig ?? false)
        XCTAssertEqual(a.dienst.modell?.akkuVerlauf.punkte.last?.prozent, 14, "der Verlauf der letzten Tage nimmt den Wert auf")
    }

    func testStatusFuerLoveaWirdBeiAenderungGeschrieben() async {
        schalter = true
        let a = aufbau()
        await a.dienst.verbinde()
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        a.fabrik.melde(.daten(TrackerProtokoll.paket(.akku, [64, 0])))
        await warte { a.dienst.modell?.akku != nil }
        a.dienst.statusSchreiben()
        a.dienst.statusSchreiben()
        let geschrieben = a.bruecke.status
        XCTAssertEqual(geschrieben.count, 1, "unverändert nicht noch einmal")
        XCTAssertEqual(geschrieben.first?.verbunden, true)
        XCTAssertEqual(geschrieben.first?.akkuProzent, 64)
        XCTAssertEqual(geschrieben.first?.name, "H59 Test")
        XCTAssertEqual(geschrieben.first?.version, 1)
    }

    // MARK: Vibration

    private func verbunden(_ a: Aufbau) async {
        schalter = true
        await a.dienst.verbinde()
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        await warte { a.dienst.modell?.zustand == .verbunden }
    }

    func testPausenEndeVibriertAmBandUndRegelnGelten() async {
        let a = aufbau()
        await verbunden(a)
        let vorher = a.fabrik.funk.gesendet.filter { $0 == TrackerProtokoll.findenAnfrage }.count
        await a.dienst.vibriere(.pauseEnde)
        await warte { a.fabrik.funk.gesendet.filter { $0 == TrackerProtokoll.findenAnfrage }.count > vorher }
        XCTAssertEqual(a.fabrik.funk.gesendet.filter { $0 == TrackerProtokoll.findenAnfrage }.count, vorher + 1)
        // Innerhalb der Mindestpause (30 s) nicht noch einmal
        await a.dienst.vibriere(.pauseEnde)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(a.fabrik.funk.gesendet.filter { $0 == TrackerProtokoll.findenAnfrage }.count, vorher + 1)
    }

    func testPausenEndeAusgeschaltetVibriertNicht() async {
        let a = aufbau()
        await verbunden(a)
        defaults.set(false, forKey: BandQuelle.gymPause.anSchluessel)
        await a.dienst.vibriere(.pauseEnde)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(a.fabrik.funk.gesendet.contains(TrackerProtokoll.findenAnfrage))
    }

    func testOhneVerbindungVibriertNichts() async {
        schalter = true
        let a = aufbau()
        await a.dienst.verbinde()
        await a.dienst.vibriere(.kurz)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(a.fabrik.funk.gesendet.contains(TrackerProtokoll.findenAnfrage))
    }

    func testWunschErgebnisse() async {
        schalter = true
        let a = aufbau()
        let wunsch = BandWunsch(id: "w", muster: .kurz, zeit: VerbindenTest.jetzt, von: "kennung-b")
        XCTAssertEqual(a.dienst.wunschAusfuehren(wunsch), .spaeter, "noch kein Modell")
        await a.dienst.verbinde()
        XCTAssertEqual(a.dienst.wunschAusfuehren(wunsch), .spaeter, "Band nicht verbunden")
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        await warte { a.dienst.modell?.zustand == .verbunden }
        defaults.set(false, forKey: BandQuelle.wunsch.anSchluessel)
        XCTAssertEqual(a.dienst.wunschAusfuehren(wunsch), .verworfen, "Regel aus")
        defaults.set(true, forKey: BandQuelle.wunsch.anSchluessel)
        XCTAssertEqual(a.dienst.wunschAusfuehren(wunsch), .ausgefuehrt)
        schalter = false
        XCTAssertEqual(a.dienst.wunschAusfuehren(wunsch), .spaeter, "Schalter aus")
    }

    func testPartnerEreignisVibriertNurWennDieQuelleAnIst() async {
        let a = aufbau()
        await verbunden(a)
        let ereignis = PartnerEreignis(id: "e", art: .gymStart, zeit: VerbindenTest.jetzt, text: "t")
        a.dienst.partnerEreignis(ereignis)   // Standard: aus
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(a.fabrik.funk.gesendet.contains(TrackerProtokoll.findenAnfrage))
        defaults.set(true, forKey: BandQuelle.partner.anSchluessel)
        a.dienst.partnerEreignis(ereignis)
        await warte { a.fabrik.funk.gesendet.contains(TrackerProtokoll.findenAnfrage) }
        XCTAssertTrue(a.fabrik.funk.gesendet.contains(TrackerProtokoll.findenAnfrage))
    }

    // MARK: Uhr des Bands

    private func uhrPakete(_ a: Aufbau) -> [Data] { a.fabrik.funk.gesendet.filter { $0.first == TrackerProtokoll.Befehl.zeitSetzen.rawValue } }

    func testDieErsteRundeStelltDieUhrVorAllemAnderenUndVorDemSchlaf() async throws {
        let a = aufbau()
        await verbunden(a)
        a.fabrik.melde(.schlafBereit)
        try? await Task.sleep(for: .milliseconds(300)) // das Ereignis läuft über den Hauptakteur; unter der Ruhezeit von 3 s bleiben
        let modell = try XCTUnwrap(a.dienst.modell)
        XCTAssertEqual(a.fabrik.funk.gesendet, [TrackerProtokoll.zeitSetzenAnfrage(VerbindenTest.jetzt)], "als Erstes die Uhr, der Akku erst nach ihrer Antwort")
        XCTAssertFalse(a.fabrik.funk.aufrufe.contains("schlaf"), "die Schlaf-Anfrage kommt erst am Rundenende")
        XCTAssertTrue(modell.bandLog.contains { $0.hasSuffix("zeit: gesendet 01 26 10 29 10 00 00 00 00 00 00 00 00 00 00 70") })
    }

    func testDieAntwortAufDieUhrSchiebtDieRundeWeiterUndWirdGelogt() async throws {
        let a = aufbau()
        await verbunden(a)
        a.fabrik.melde(.daten(TrackerProtokoll.paket(.zeitSetzen, [0, 1, 0, 5])))
        await warte { a.fabrik.funk.gesendet.count == 2 }
        let modell = try XCTUnwrap(a.dienst.modell)
        XCTAssertEqual(a.fabrik.funk.gesendet.last, TrackerProtokoll.akkuAnfrage)
        XCTAssertTrue(modell.bandLog.contains { $0.contains("zeit: Antwort 01 00 01 00 05") })
        XCTAssertEqual(uhrPakete(a).count, 1, "einmal je Verbindung")
    }

    func testSchweigtDasBandZurUhrGehtDieRundeNachDerRuhezeitWeiterUndDasLogSagtEs() async throws {
        let a = aufbau()
        await verbunden(a)
        for _ in 0..<200 where a.fabrik.funk.gesendet.count < 2 { try? await Task.sleep(for: .milliseconds(25)) }
        let modell = try XCTUnwrap(a.dienst.modell)
        XCTAssertEqual(a.fabrik.funk.gesendet.last, TrackerProtokoll.akkuAnfrage, "keine Antwort darf die Runde nicht blockieren")
        XCTAssertTrue(modell.bandLog.contains { $0.hasSuffix("zeit: keine Antwort nach 3 s") })
    }

    func testJedeNeueVerbindungStelltDieUhrNeu() async {
        let a = aufbau()
        await verbunden(a)
        a.fabrik.melde(.getrennt)
        await warte { a.dienst.modell?.zustand == .wartet }
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        await warte { self.uhrPakete(a).count == 2 }
        XCTAssertEqual(uhrPakete(a).count, 2)
    }

    // MARK: Ops

    func testBandOpsLandenImRaumUndGesundheitsStandNimmtDasMaximum() async throws {
        let ordner = try tempOrdner()
        let raum = LokalerRaum(ordner: ordner, profil: TestDaten.profilID, uhr: { VerbindenTest.jetzt })
        let senke = BandSenke.raum { raum }
        XCTAssertEqual(senke.bisher(), [:])
        senke.tag(BandTagOp(tag: "2026-10-29", schritte: 15_000, meter: 10_000))
        senke.tag(BandTagOp(tag: "2026-10-28", schritte: 500, meter: 300))
        let bisher = try XCTUnwrap(senke.bisher())
        XCTAssertEqual(bisher["2026-10-29"]?.schritte, 15_000)
        XCTAssertEqual(bisher.count, 2)
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: "2026-10-29", schritte: 10_000, distanzMeter: 7_000)])
        let stand = GesundheitsStand(leser: leser, uhr: { VerbindenTest.jetzt }, band: { Array((senke.bisher() ?? [:]).values) })
        await stand.aktualisiere()
        XCTAssertEqual(stand.tage["2026-10-29"]?.schritte, 15_000, "das Maximum aus Health und Band, nie die Summe")
        XCTAssertEqual(stand.tage["2026-10-28"]?.schritte, 500)
    }

    func testBandSchlafOpWirdGeschriebenUndGelesen() async throws {
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: TestDaten.profilID, uhr: { VerbindenTest.jetzt })
        let bis = VerbindenTest.jetzt
        let von = bis.addingTimeInterval(-7 * 3600)
        let op = BandSchlafOp(tag: "2026-10-29", start: von, ende: bis, phasen: [SchlafAbschnitt(phase: .kern, von: von, bis: bis)])
        BandSenke.raum { raum }.schlaf(op)
        let gelesen = raum.ops(arten: ["fit.band.schlaf"]).compactMap { $0.daten(BandSchlafOp.self) }
        XCTAssertEqual(gelesen.map(\.tag), ["2026-10-29"])
    }

    func testOhneRaumSchreibtDieSenkeNichts() {
        let senke = BandSenke.raum { nil }
        XCTAssertNil(senke.bisher())
        senke.tag(BandTagOp(tag: "2026-10-29", schritte: 1, meter: 1))
    }
}

/// Sammelt, was das Band-Modell schreibt (ein Verweistyp statt erfasster Variablen).
final class BandOpsSammler {
    var tage: [BandTagOp] = []
    var schlaf: [BandSchlafOp] = []
    var bisher: [String: BandTagOp] = [:]
}

/// Der Verbindungsweg im zweiten Prozess (SPEC 5.6): erst `retrieveConnectedPeripherals(withServices:)`, dann `retrievePeripherals(withIdentifiers:)`, zuletzt Scan.
final class BandVerbindungswegTests: XCTestCase {
    private let band = BandGeraetInfo(kennung: UUID(), name: "H59MAX")

    func testErstSchonVerbundeneDannBekannteDannScan() {
        let leer = FakeZentrale()
        XCTAssertEqual(BandVerbindungsweg.waehle(leer, gemerkt: UUID()), .scan)
        XCTAssertEqual(leer.aufrufe, ["verbundene", "bekannte"], "Scan ist der letzte Weg: nur wenn beide Abfragen nichts liefern")
    }

    func testSchonVerbundenesBandGewinntUndFragtNichtWeiter() {
        let z = FakeZentrale()
        z.verbundeneGeraete = [band]
        XCTAssertEqual(BandVerbindungsweg.waehle(z, gemerkt: nil), .schonVerbunden(band.kennung))
        XCTAssertEqual(z.aufrufe, ["verbundene"])
    }

    func testGemerktesBandBeiMehrerenVerbundenenGewinnt() {
        let andere = BandGeraetInfo(kennung: UUID(), name: "H59ANDERES")
        let z = FakeZentrale()
        z.verbundeneGeraete = [andere, band]
        XCTAssertEqual(BandVerbindungsweg.waehle(z, gemerkt: band.kennung), .schonVerbunden(band.kennung))
    }

    func testVerbundenesGeraetMitFremdemNamenWirdNichtGenommen() {
        let z = FakeZentrale()
        z.verbundeneGeraete = [BandGeraetInfo(kennung: UUID(), name: "Kopfhörer")]
        XCTAssertEqual(BandVerbindungsweg.waehle(z, gemerkt: nil), .scan)
        XCTAssertEqual(z.aufrufe, ["verbundene"], "ohne gemerkte Kennung gibt es nichts zu fragen")
    }

    func testBekanntesBandWennNichtVerbunden() {
        let z = FakeZentrale()
        z.bekannteGeraete = [band]
        XCTAssertEqual(BandVerbindungsweg.waehle(z, gemerkt: band.kennung), .bekannt(band.kennung))
        XCTAssertEqual(z.aufrufe, ["verbundene", "bekannte"])
    }

    func testFremdeKennungWirdNichtGefunden() {
        let z = FakeZentrale()
        z.bekannteGeraete = [band]
        XCTAssertEqual(BandVerbindungsweg.waehle(z, gemerkt: UUID()), .scan, "die Kennung von Lovea hilft nicht: je App verschieden")
    }
}
