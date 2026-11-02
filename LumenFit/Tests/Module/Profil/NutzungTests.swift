import XCTest
@testable import LumenFit

/// Nutzungsmeldung: ohne "Ja" nichts, feste Namen, Bündeln, Abläufe, Fehler. Erfundene Werte, ein `SkriptLader`, keine echte Verbindung.
@MainActor
final class NutzungTests: XCTestCase {
    private let tag = "2026-09-23"
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")

    private func speicher(_ uhr: TestUhr = TestUhr(), ordner: URL? = nil, an: Bool = true) throws -> NutzungSpeicher {
        let s = NutzungSpeicher(ordner: try ordner ?? tempOrdner(), uhr: uhr.uhr)
        s.an = an
        return s
    }

    private func dateiStand(_ ordner: URL) throws -> NutzungStand {
        try JSONDecoder().decode(NutzungStand.self, from: Data(contentsOf: ordner.appendingPathComponent(NutzungSpeicher.datei)))
    }

    private func antwort(_ status: Int, _ json: String = "{}") -> SkriptLader.Antwort { .init(status: status, daten: Data(json.utf8), fehler: nil) }

    private func dienst(_ lader: SkriptLader, uhr: TestUhr = TestUhr(), zugestimmt: Bool) throws -> KontoDienst {
        let d = KontoDienst(zugang: zugang, schluesselbund: SpeicherSchluesselbund(), http: lader, ordner: try tempOrdner(), uhr: uhr.uhr, version: "0.0.1")
        d.nutzung.an = zugestimmt
        return d
    }

    // MARK: - Zustimmung

    func testOhneZustimmungWirdNichtsGezaehltGespeichertOderGeliefert() throws {
        let ordner = try tempOrdner()
        let s = try speicher(ordner: ordner, an: false)
        s.vordergrund(); s.bereich("tab.gym"); s.funktion("training"); s.fehler(.absturz); s.gesehen(.profilKonto); s.getippt(.profilKonto)
        s.ablauf(.qr, stufe: "scannen"); s.route(methode: "GET", pfad: "/config", status: 500, dauer: 5); s.startdauer(2); s.hintergrund()
        s.einstellungen(Einstellungen())
        XCTAssertEqual(s.stand, NutzungStand())
        XCTAssertTrue(s.faellig(heute: tag, ersterInSitzung: true).isEmpty, "auch kein leerer aktiver Tag")
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent(NutzungSpeicher.datei).path))
    }

    func testEineAlteDateiWirdOhneZustimmungVerworfen() throws {
        let ordner = try tempOrdner()
        let erster = try speicher(ordner: ordner)
        erster.bereich("tab.gym")
        erster.hintergrund()
        XCTAssertFalse(try dateiStand(ordner).tage.isEmpty, "Vorbedingung: die Datei hat Inhalt")
        let zweiter = NutzungSpeicher(ordner: ordner, uhr: TestUhr().uhr)
        XCTAssertFalse(zweiter.stand.tage.isEmpty, "bis die App die Antwort kennt, bleibt der Stand im Speicher")
        zweiter.an = false   // so gleicht die App ab: kein "Ja" in den Einstellungen
        XCTAssertEqual(zweiter.stand, NutzungStand())
        XCTAssertEqual(try dateiStand(ordner), NutzungStand(), "auch die Datei ist leer")
        XCTAssertTrue(zweiter.faellig(heute: tag, ersterInSitzung: true).isEmpty)
    }

    func testDienstSendetOhneZustimmungNichts() async throws {
        let lader = SkriptLader([antwort(201), antwort(200, #"{"config":{}}"#), antwort(200, #"{"erlaubt":false}"#), antwort(200)])
        let d = try dienst(lader, zugestimmt: false)
        d.nutzung.bereich("tab.gym")
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        await d.nutzungHochladen()
        XCTAssertFalse(lader.anfragen.compactMap { $0.url?.path }.contains("/nutzung"), "ohne Ja geht nichts raus, auch kein leerer aktiver Tag")
        XCTAssertTrue(lader.anfragen.compactMap { $0.url?.path }.contains("/config"), "die Geräteanmeldung bleibt")
    }

    func testDasAusschaltenWaehrendDesSendensStopptDenRest() async throws {
        let lader = SkriptLader([antwort(201), antwort(200, #"{"config":{}}"#), antwort(200, #"{"erlaubt":false}"#), antwort(200)])
        let d = try dienst(lader, zugestimmt: true)
        d.nutzung.bereich("tab.gym")
        d.nutzung.an = false
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertFalse(lader.anfragen.compactMap { $0.url?.path }.contains("/nutzung"))
        XCTAssertEqual(d.nutzung.stand, NutzungStand(), "Noch nicht Gesendetes ist weg")
    }

    // MARK: - Erster Griff, Wege, Dauer

    func testErsterTabUndErsteFunktionDesTagesZaehlenEinmalAuchNachDemSenden() throws {
        let uhr = TestUhr()
        let s = try speicher(uhr)
        s.bereich("tab.essen"); s.bereich("tab.gym"); s.funktion("mahlzeit"); s.funktion("satz")
        XCTAssertEqual(s.stand.tage[tag]?.mehr["erster"], ["tab.essen": 1, "fn.mahlzeit": 1])
        s.abgeschickt(tag: tag)
        s.bereich("tab.heute"); s.funktion("training")
        XCTAssertNil(s.stand.tage[tag]?.mehr["erster"], "nach dem Senden zählt der erste Griff desselben Tages nicht nochmal")
        uhr.vor(sekunden: 86_400)
        s.bereich("tab.schlaf")
        XCTAssertEqual(s.stand.tage["2026-09-24"]?.mehr["erster"], ["tab.schlaf": 1])
    }

    func testWegeAbsprungDauerStartUndTageszeit() throws {
        let uhr = TestUhr()
        let s = try speicher(uhr)
        s.vordergrund()
        s.bereich("tab.heute"); s.bereich("tab.heute"); s.bereich("seite.gym.plaene")
        uhr.vor(sekunden: 400)
        s.hintergrund()
        let m = try XCTUnwrap(s.stand.tage[tag]?.mehr)
        XCTAssertEqual(m["weg"], ["start>tab.heute": 1, "tab.heute>seite.gym.plaene": 1], "ein Wechsel auf denselben Bereich ist kein Weg")
        XCTAssertEqual(m["absprung"], ["seite.gym.plaene": 1])
        XCTAssertEqual(m["dauer"], ["m5_15": 1])
        XCTAssertEqual(m["start"], ["anzahl": 1, "block_mittag": 1])
        s.vordergrund(); s.hintergrund()
        XCTAssertEqual(s.stand.tage[tag]?.mehr["start"]?["anzahl"], 2)
        XCTAssertNil(s.stand.tage[tag]?.mehr["absprung"]?["start"], "wer nichts geöffnet hat, springt von nirgends ab")
    }

    func testZeitBisZumZielAlsBereichEinmalJeSitzung() throws {
        let uhr = TestUhr()
        let s = try speicher(uhr)
        s.vordergrund()
        uhr.vor(sekunden: 45)
        s.funktion("training"); s.funktion("training"); s.funktion("gewicht")
        XCTAssertEqual(s.stand.tage[tag]?.mehr["ziel"], ["training.lt1m": 1])
        s.hintergrund(); s.vordergrund()
        uhr.vor(sekunden: 4)
        s.funktion("training")
        XCTAssertEqual(s.stand.tage[tag]?.mehr["ziel"], ["training.lt1m": 1, "training.lt10s": 1], "jede Sitzung hat ihr eigenes erstes Mal")
    }

    func testBereicheFuerDauerUndTageszeitSindGrob() {
        XCTAssertEqual([30, 200, 800, 1700, 5000].map { NutzungMass.dauer($0) }, ["lt1m", "m1_5", "m5_15", "m15_30", "gt30m"])
        XCTAssertEqual([3, 20, 50, 100, 400].map { NutzungMass.ziel($0) }, ["lt10s", "lt30s", "lt1m", "lt3m", "gt3m"])
        XCTAssertEqual([0.2, 1.5, 9].map { NutzungMass.tempo($0) }, ["lt1s", "lt3s", "gt3s"])
        let berlin = { (h: Int) in Datum.datum(self.tag).addingTimeInterval(TimeInterval(h) * 3600 + 60) }
        XCTAssertEqual([2, 7, 12, 16, 20, 23].map { NutzungMass.block(berlin($0)) }, ["nacht", "morgen", "mittag", "nachmittag", "abend", "nacht"])
    }

    // MARK: - Abläufe

    func testAblaufBegonnenFertigUndAbbruchMitStufe() throws {
        let s = try speicher()
        s.ablauf(.qr, stufe: "scannen"); s.ablauf(.qr, stufe: "frage"); s.ablaufFertig(.qr)
        s.ablauf(.essen, stufe: "offen"); s.ablauf(.essen, stufe: "scan"); s.ablaufEnde(.essen)
        s.ablauf(.studio, stufe: "gibtEsNicht"); s.ablaufFertig(.studio); s.ablaufEnde(.studio)
        let m = try XCTUnwrap(s.stand.tage[tag]?.mehr)
        XCTAssertEqual(m["begonnen"], ["qr": 1, "essen": 1])
        XCTAssertEqual(m["fertig"], ["qr": 1])
        XCTAssertEqual(m["abbruch"], ["essen.scan": 1])
        XCTAssertTrue(s.stand.offen.isEmpty)
        s.ablaufEnde(.qr)
        XCTAssertEqual(s.stand.tage[tag]?.mehr["abbruch"], ["essen.scan": 1], "ein fertiger Ablauf wird nie nachträglich zum Abbruch")
    }

    func testEinUnbeendeterAblaufEinerFruehherenSitzungZaehltBeimNaechstenStartAlsAbbruch() throws {
        let ordner = try tempOrdner()
        let alt = try speicher(ordner: ordner)
        alt.ablauf(.qr, stufe: "wartet")
        alt.hintergrund()
        let neu = try speicher(ordner: ordner)
        XCTAssertEqual(neu.stand.offen, ["qr": "wartet"], "der Absturz hat die Datei nicht verloren")
        neu.vordergrund()
        XCTAssertEqual(neu.stand.tage[tag]?.mehr["abbruch"], ["qr.wartet": 1])
        XCTAssertTrue(neu.stand.offen.isEmpty)
    }

    // MARK: - Fehler, Server, Einstellungen

    func testServeraufrufeZaehlenDauerUndNurFehlschlaegeMitStatus() throws {
        let s = try speicher()
        s.route(methode: "GET", pfad: "/config", status: 200, dauer: 0.4)
        s.route(methode: "PUT", pfad: "/partner", status: 503, dauer: 4)
        s.route(methode: "GET", pfad: "/partner", status: nil, dauer: 0.1)
        s.route(methode: "POST", pfad: "/verbindungen/abc123/entfernen", status: 418, dauer: 1)
        s.route(methode: "POST", pfad: "/nutzung", status: 500, dauer: 1)
        s.route(methode: "GET", pfad: "/irgendwo/anders", status: 500, dauer: 1)
        let m = try XCTUnwrap(s.stand.tage[tag]?.mehr)
        XCTAssertEqual(m["tempo"], ["config.lt1s": 1, "partner_put.gt3s": 1, "partner_get.lt1s": 1, "verbindungen.lt3s": 1])
        XCTAssertEqual(m["route"], ["partner_put.s503": 1, "partner_get.netz": 1, "verbindungen.s4xx": 1])
    }

    func testFehlerArtenSindFesteNamenMitAnzahl() throws {
        let s = try speicher()
        s.fehler(.absturz, anzahl: 2); s.fehler(.speichern); s.fehler(.coachAntwort)
        XCTAssertEqual(s.stand.tage[tag]?.mehr["fehler"], ["absturz": 2, "speichern": 1, "coach_antwort": 1])
        s.fehler(.haenger, anzahl: 0)
        XCTAssertNil(s.stand.tage[tag]?.mehr["fehler"]?["haenger"])
    }

    func testEinstellungenSindEinStandKeinZaehler() throws {
        let s = try speicher()
        var e = Einstellungen()
        e.thema = .wald; e.bandAktiv = true; e.essenAn = false; e.haptik = false
        s.einstellungen(e)
        s.einstellungen(Einstellungen())
        let namen = try XCTUnwrap(s.stand.tage[tag]?.mehr["stand"])
        XCTAssertEqual(Set(namen.keys), ["theme_monochrom", "band_aus", "einheit_kg", "bereich_gym", "bereich_essen", "bereich_schlaf"], "der zweite Stand ersetzt den ersten")
        XCTAssertTrue(namen.values.allSatisfy { $0 == 1 })
    }

    func testGesehenZaehltEinmalJeSitzungGetipptJedesMal() throws {
        let s = try speicher()
        s.gesehen(.profilZiele); s.gesehen(.profilZiele); s.getippt(.profilZiele); s.getippt(.profilZiele)
        XCTAssertEqual(s.stand.tage[tag]?.mehr["gesehen"], ["profil_ziele": 1])
        XCTAssertEqual(s.stand.tage[tag]?.mehr["getippt"], ["profil_ziele": 2])
    }

    // MARK: - Grenzen und Form

    func testGruppenNehmenNurGueltigeNamenAnUndDeckelnJeArt() {
        var s = NutzungStand()
        for name in ["Gewicht 82", "a>b>c", ">x", "x>", "tab.heute", "", String(repeating: "a", count: 41)] { s.zaehleMehr(.weg, name, tag: "2026-09-23") }
        XCTAssertNil(s.tage["2026-09-23"], "kein Weg ohne zwei gültige Teile")
        for i in 0..<(NutzungArt.weg.maxNamen + 10) { s.zaehleMehr(.weg, "n\(i)>m\(i)", tag: "2026-09-23") }
        XCTAssertEqual(s.tage["2026-09-23"]?.mehr["weg"]?.count, NutzungArt.weg.maxNamen)
        s.zaehleMehr(.fehler, "absturz", tag: "2026-09-24", anzahl: 0)
        s.zaehleMehr(.fehler, "absturz", tag: "2026-09-24", anzahl: -3)
        XCTAssertNil(s.tage["2026-09-24"])
        for _ in 0..<3 { s.zaehleMehr(.fehler, "absturz", tag: "2026-09-25", anzahl: NutzungStand.maxAnzahl) }
        XCTAssertEqual(s.tage["2026-09-25"]?.mehr["fehler"]?["absturz"], NutzungStand.maxAnzahl)
    }

    func testStandMitDenGruppenKommtAusAlterDateiOhneGruppenZurueck() throws {
        let alt = #"{"tage":{"2026-09-23":{"bereiche":{"tab.gym":2},"funktionen":{}}}}"#
        let stand = try JSONDecoder().decode(NutzungStand.self, from: Data(alt.utf8))
        XCTAssertEqual(stand.tage[tag]?.bereiche, ["tab.gym": 2])
        XCTAssertEqual(stand.tage[tag]?.mehr, [:])
        XCTAssertTrue(stand.offen.isEmpty)
        XCTAssertNil(stand.ersterTabTag)
    }

    func testDieDateiHatNurDieErlaubtenFelder() throws {
        let ordner = try tempOrdner()
        let s = try speicher(ordner: ordner)
        s.vordergrund(); s.bereich("tab.gym"); s.funktion("satz"); s.fehler(.absturz); s.ablauf(.qr, stufe: "frage"); s.hintergrund()
        let roh = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: ordner.appendingPathComponent(NutzungSpeicher.datei))) as? [String: Any])
        XCTAssertTrue(Set(roh.keys).isSubset(of: ["tage", "ersterTabTag", "ersteFunktionTag", "offen"]), "\(roh.keys)")
        let tage = try XCTUnwrap(roh["tage"] as? [String: [String: Any]])
        for (_, z) in tage { XCTAssertTrue(Set(z.keys).isSubset(of: ["bereiche", "funktionen", "mehr"])) }
    }

    func testDieDateiWirdNichtBeiJedemZaehlerGeschriebenAberImHintergrund() throws {
        let uhr = TestUhr()
        let ordner = try tempOrdner()
        let s = try speicher(uhr, ordner: ordner)
        s.bereich("tab.gym")
        let erst = try dateiStand(ordner).tage[tag]?.bereiche
        s.bereich("tab.essen")
        XCTAssertEqual(try dateiStand(ordner).tage[tag]?.bereiche, erst, "innerhalb von 15 Sekunden kein neuer Schreibvorgang")
        s.hintergrund()
        XCTAssertEqual(try dateiStand(ordner).tage[tag]?.bereiche, ["tab.gym": 1, "tab.essen": 1])
    }

    // MARK: - Senden

    func testHintergrundSendetHeuteGedrosseltUndNurMitInhalt() async throws {
        let uhr = TestUhr()
        let lader = SkriptLader([antwort(201), antwort(200, #"{"config":{}}"#), antwort(200, #"{"erlaubt":false}"#), antwort(200)])
        let d = try dienst(lader, uhr: uhr, zugestimmt: true)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let nutzungsAufrufe = { lader.anfragen.filter { $0.url?.path == "/nutzung" }.count }
        let nachStart = nutzungsAufrufe()
        XCTAssertEqual(nachStart, 1, "der Start meldet den aktiven Tag")
        await d.nutzungHochladen()
        XCTAssertEqual(nutzungsAufrufe(), nachStart, "ohne neuen Inhalt geht beim Wechsel in den Hintergrund nichts raus")
        d.nutzung.fehler(.speichern)
        await d.nutzungHochladen()
        XCTAssertEqual(nutzungsAufrufe(), nachStart + 1)
        let koerper = try JSONDecoder().decode(NutzungMeldung.self, from: try XCTUnwrap(lader.anfragen.last { $0.url?.path == "/nutzung" }?.httpBody))
        XCTAssertEqual(koerper.gruppen?["fehler"], ["speichern": 1])
        d.nutzung.fehler(.absturz)
        await d.nutzungHochladen()
        XCTAssertEqual(nutzungsAufrufe(), nachStart + 1, "höchstens alle \(Int(KontoDienst.nutzungPause)) Sekunden")
        uhr.vor(sekunden: KontoDienst.nutzungPause)
        await d.nutzungHochladen()
        XCTAssertEqual(nutzungsAufrufe(), nachStart + 2)
    }

    func testAufrufeDesKontoDienstesWerdenMitDauerUndStatusGezaehlt() async throws {
        let lader = SkriptLader([antwort(201), antwort(200, #"{"config":{}}"#), antwort(500)])
        let d = try dienst(lader, zugestimmt: true)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let m = try XCTUnwrap(d.nutzung.stand.tage[tag]?.mehr ?? NutzungStand().tage[tag]?.mehr)
        XCTAssertEqual(m["tempo"]?["konto.lt1s"], 1)
        XCTAssertEqual(m["route"]?["freigabe.s500"], 1)
        XCTAssertNil(m["tempo"]?.keys.first { $0.hasPrefix("nutzung") }, "/nutzung misst sich nicht selbst")
    }
}
