import XCTest
@testable import LumenFit

/// Einmal-Import, Partner über den Server und Nutzungs-Bündel: erfundene Werte, ein `SkriptLader`, keine echte Verbindung.
/// Sammelt Hochlade-Aufrufe aus einem @Sendable-Rückruf.
private final class Sammler: @unchecked Sendable {   // @unchecked: alles hinter der Sperre
    private let sperre = NSLock()
    private var daten: [Data] = []
    func add(_ d: Data) { sperre.withLock { daten.append(d) } }
    var anzahl: Int { sperre.withLock { daten.count } }
}

@MainActor
final class EinmalLoveaTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")
    private let configJson = #"{"config":{}}"#
    private let freigabeJson = #"{"erlaubt":true,"person":"person-a","importErledigt":false}"#

    private func antwort(_ status: Int, _ json: String = "{}") -> SkriptLader.Antwort { .init(status: status, daten: Data(json.utf8), fehler: nil) }

    private func dienst(_ lader: SkriptLader, bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), ordner: URL? = nil, uhr: TestUhr = TestUhr()) throws -> KontoDienst {
        KontoDienst(zugang: zugang, schluesselbund: bund, http: lader, ordner: try ordner ?? tempOrdner(), uhr: uhr.uhr, version: "0.0.1")
    }

    private func pfade(_ l: SkriptLader) -> [String] { l.anfragen.compactMap { $0.url?.path } }

    // MARK: - Nutzungs-Bündel

    func testNutzungZaehltNurGueltigeNamenUndDeckeltSie() {
        var s = NutzungStand()
        s.zaehleBereich("tab.gym", tag: "2026-09-23")
        s.zaehleBereich("tab.gym", tag: "2026-09-23")
        s.zaehleBereich("Freitext mit Leerzeichen", tag: "2026-09-23")
        s.zaehleBereich("Tab.gym", tag: "2026-09-23")
        s.zaehleFunktion("training", tag: "2026-09-23")
        XCTAssertEqual(s.tage["2026-09-23"]?.bereiche, ["tab.gym": 2], "ungültige Namen werden nie gemeldet")
        XCTAssertEqual(s.tage["2026-09-23"]?.funktionen, ["training": 1])
        for i in 0..<(NutzungStand.maxNamen + 10) { s.zaehleBereich("n\(i)", tag: "2026-09-24") }
        XCTAssertEqual(s.tage["2026-09-24"]?.bereiche.count, NutzungStand.maxNamen)
        for _ in 0..<(NutzungStand.maxAnzahl + 5) { s.zaehleFunktion("satz", tag: "2026-09-25") }
        XCTAssertEqual(s.tage["2026-09-25"]?.funktionen["satz"], NutzungStand.maxAnzahl)
    }

    func testNutzungFaelligHeuteEinmalJeStartAeltereMitInhaltUndAbgeschicktLeert() {
        var s = NutzungStand()
        s.zaehleBereich("tab.gym", tag: "2026-09-22")
        s.aktiv(tag: "2026-09-21")   // alt und leer: nichts zu senden
        s.zaehleBereich("tab.essen", tag: "2026-09-23")
        XCTAssertEqual(s.faellig(heute: "2026-09-23", ersterInSitzung: true).map(\.0), ["2026-09-22", "2026-09-23"])
        XCTAssertEqual(s.faellig(heute: "2026-09-23", ersterInSitzung: false).map(\.0), ["2026-09-22"], "heute geht nur beim Start raus")
        XCTAssertEqual(NutzungStand().faellig(heute: "2026-09-23", ersterInSitzung: true).map(\.0), ["2026-09-23"], "auch leer: das ist der aktive Tag")
        s.abgeschickt(tag: "2026-09-22")
        XCTAssertNil(s.tage["2026-09-22"])
    }

    func testNutzungHebtHoechstensVierTageAuf() {
        var s = NutzungStand()
        for t in 20...26 { s.zaehleBereich("tab.gym", tag: "2026-09-\(t)") }
        XCTAssertEqual(s.tage.keys.sorted(), ["2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26"])
    }

    func testNutzungNamenKommenNurAusFestenWoertern() {
        XCTAssertEqual(NutzungName.tab(.gym), "tab.gym")
        XCTAssertEqual(NutzungName.seite(.gym(.plaene)), "seite.gym.plaene")
        XCTAssertEqual(NutzungName.seite(.uebung(id: "geheime-kennung")), "seite.uebung", "keine Kennung in der Meldung")
        XCTAssertEqual(NutzungName.seite(.coach(frage: "Wie viel soll ich essen?")), "seite.coach", "nie eine Frage")
        XCTAssertEqual(NutzungName.blatt(.profil(.aussehen)), "blatt.profil")
        XCTAssertEqual(NutzungName.funktion(.mahlzeitGespeichert(tag: "2026-09-23")), "mahlzeit")
        XCTAssertNil(NutzungName.funktion(.vordergrund))
        for route: Route in [.heute, .gym(.training), .essen(.scan), .schlaf(.verlauf), .coach(frage: nil), .profil(.lumi), .verlauf, .gewichtEintragen, .uebung(id: "x"), .freund(daten: nil)] {
            XCTAssertTrue(NutzungStand.gueltig(NutzungName.seite(route)), "\(route)")
            XCTAssertTrue(NutzungStand.gueltig(NutzungName.blatt(route)), "\(route)")
        }
    }

    func testDienstSendetNutzungEinmalJeStartUndLeertDenTag() async throws {
        let uhr = TestUhr()
        let lader = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#), antwort(200)])
        let d = try dienst(lader, uhr: uhr)
        d.nutzung.bereich("tab.gym")
        d.nutzung.funktion("training")
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let nutzung = try XCTUnwrap(lader.anfragen.last { $0.url?.path == "/nutzung" })
        let koerper = try JSONDecoder().decode(NutzungMeldung.self, from: try XCTUnwrap(nutzung.httpBody))
        XCTAssertEqual(koerper, NutzungMeldung(tag: "2026-09-23", bereiche: ["tab.gym": 1], funktionen: ["training": 1]))
        XCTAssertEqual(nutzung.value(forHTTPHeaderField: "X-App-Version"), "0.0.1")
        XCTAssertTrue(d.nutzung.stand.tage["2026-09-23"] == nil, "gesendete Zähler sind weg")
        let vorher = lader.aufrufe
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertEqual(Array(pfade(lader).suffix(lader.aufrufe - vorher)), ["/config", "/lovea/freigabe"], "in derselben Sitzung geht nichts mehr raus")
    }

    func testNutzungBleibtBeiNetzfehlerLiegen() async throws {
        let lader = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#), .init(status: 0, daten: Data(), fehler: .notConnectedToInternet)])
        let d = try dienst(lader)
        d.nutzung.bereich("tab.gym")
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertEqual(d.nutzung.stand.tage["2026-09-23"]?.bereiche, ["tab.gym": 1])
    }

    func testNutzungMeldetKeineInhalteDesProfils() async throws {
        let lader = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#), antwort(200)])
        let d = try dienst(lader)
        d.nutzung.bereich("seite.uebung")
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let text = String(decoding: try XCTUnwrap(lader.anfragen.last { $0.url?.path == "/nutzung" }?.httpBody), as: UTF8.self)
        XCTAssertFalse(text.contains("Beispiel"), "kein Profilname in der Nutzungsmeldung")
        XCTAssertEqual(Set((try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] ?? [:]).keys), ["tag", "bereiche", "funktionen"])
    }

    // MARK: - Import-erledigt

    func testServerSagtImportErledigtDannBleibtErNichtOffen() async throws {
        let offen = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson)]))
        await offen.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(offen.loveaImportOffen)
        let fertig = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":true,"person":"person-a","importErledigt":true}"#)]))
        await fertig.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertFalse(fertig.loveaImportOffen, "nach Neuinstallation nicht nochmal")
        XCTAssertTrue(fertig.loveaErlaubt, "der Partner bleibt verbunden")
        // Der Server hat den Merker zurückgesetzt (Test, neue Geräte-Daten): der Import läuft beim nächsten Start nochmal (nichts wird doppelt).
        let ordner = try tempOrdner(), bund = SpeicherSchluesselbund()
        let erst = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":true,"person":"person-a","importErledigt":true}"#)]), bund: bund, ordner: ordner)
        await erst.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertFalse(erst.loveaImportOffen)
        let zurueck = try dienst(SkriptLader([antwort(200, configJson), antwort(200, freigabeJson)]), bund: bund, ordner: ordner)
        await zurueck.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(zurueck.loveaImportOffen, "ausdrückliches false vom Server gilt")
        let aus = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#)]))
        await aus.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertFalse(aus.loveaImportOffen, "ohne Freigabe nie")
    }

    func testImportAbgeschlossenMerktLokalMeldetDemServerUndWiederholtBeiNetzfehler() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let lader = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson), antwort(404), antwort(200),
                                 .init(status: 0, daten: Data(), fehler: .notConnectedToInternet), antwort(200)])
        let d = try dienst(lader, bund: bund, ordner: ordner)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        await d.loveaImportAbgeschlossen()   // Netzfehler beim Melden
        XCTAssertFalse(d.loveaImportOffen)
        // Neuer Start: der gemerkte Stand gilt sofort, die offene Meldung geht nach.
        let danach = SkriptLader([antwort(200, configJson), antwort(200, freigabeJson), antwort(200), antwort(404), antwort(200)])
        let neu = try dienst(danach, bund: bund, ordner: ordner)
        XCTAssertFalse(neu.loveaImportOffen)
        await neu.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertTrue(pfade(danach).contains("/lovea/import-erledigt"))
        XCTAssertEqual(danach.anfragen.first { $0.url?.path == "/lovea/import-erledigt" }?.httpMethod, "POST")
        XCTAssertFalse(neu.loveaImportOffen)
        let nochmal = SkriptLader([antwort(200, configJson), antwort(200, #"{"erlaubt":true,"person":"person-a","importErledigt":true}"#), antwort(404), antwort(200)])
        let drittes = try dienst(nochmal, bund: bund, ordner: ordner)
        await drittes.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertFalse(pfade(nochmal).contains("/lovea/import-erledigt"), "gemeldet ist gemeldet")
    }

    func testEinmalImportLaeuftVonSelbstEinmalUndMerktSich() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let konto = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson), antwort(404), antwort(200), antwort(200)])
        let d = try dienst(konto, bund: bund, ordner: ordner)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)

        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "efgh")
        let daten = try XCTUnwrap(u.daten)
        let op: [String: Any] = ["seq": 1, "id": "op-1", "art": "habit.anlegen", "von": "person-a", "zeit": "2026-09-23T10:00:00.123Z", "d": [:]]
        let ops = SkriptLader([antwort(200, String(decoding: try JSONSerialization.data(withJSONObject: ["ops": [op], "mehr": false]), as: UTF8.self))])

        let lauf = LoveaEinmalImport()
        XCTAssertEqual(lauf.zustand, .aus)
        let gelaufen = await lauf.starteWennOffen(konto: d, daten: daten, lader: ops)
        XCTAssertTrue(gelaufen)
        guard case .fertig(let e) = lauf.zustand else { return XCTFail("erwartet fertig, ist \(lauf.zustand)") }
        XCTAssertEqual(e.neu, 1)
        XCTAssertFalse(d.loveaImportOffen, "danach erledigt")
        XCTAssertTrue(pfade(konto).contains("/lovea/import-erledigt"))
        XCTAssertEqual(ops.anfragen.first?.url?.path, "/lovea/agent/ops", "über den Proxy des Servers, nie direkt zu Lovea")

        let zweites = LoveaEinmalImport()
        let nochmal = await zweites.starteWennOffen(konto: d, daten: daten, lader: ops)
        XCTAssertFalse(nochmal, "kein zweiter Lauf")
        XCTAssertEqual(ops.aufrufe, 1)
        lauf.schliesse()
        XCTAssertEqual(lauf.zustand, .aus)
    }

    func testEinmalImportFehlerLaesstIhnOffenFuerDenNaechstenStart() async throws {
        let d = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson)]))
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "efgh")
        let lauf = LoveaEinmalImport()
        _ = await lauf.starteWennOffen(konto: d, daten: u.daten, lader: SkriptLader.fehler(.notConnectedToInternet))
        XCTAssertEqual(lauf.zustand, .fehler(.netz))
        XCTAssertTrue(d.loveaImportOffen, "ein Fehler zählt nicht als erledigt")
        lauf.schliesse()
        let ok = SkriptLader([antwort(200, #"{"ops":[],"mehr":false}"#)])
        _ = await lauf.starteWennOffen(konto: d, daten: u.daten, lader: ok)
        guard case .fertig = lauf.zustand else { return XCTFail("zweiter Versuch sollte gehen: \(lauf.zustand)") }
        XCTAssertFalse(d.loveaImportOffen)
    }

    func testOhneFreigabeKeinImport() async throws {
        let d = try dienst(SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#)]))
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "efgh")
        let ops = SkriptLader([antwort(200, #"{"ops":[],"mehr":false}"#)])
        let gelaufen = await LoveaEinmalImport().starteWennOffen(konto: d, daten: u.daten, lader: ops)
        XCTAssertFalse(gelaufen)
        XCTAssertEqual(ops.aufrufe, 0)
    }

    // MARK: - Partner über den Server

    private func partnerJson(name: String = "Partner", geschrieben: String) -> String {
        #"{"partner":{"version":1,"geschrieben":""# + geschrieben + #"","profilName":""# + name + #"","freigaben":["schritte"],"heute":{"tag":"2026-09-23","schritte":4200},"ereignisse":[]},"aktualisiert":"x"}"#
    }

    func testPartnerVomServerLandetInDerDateiUndFaelltBeiNullWeg() async throws {
        let ordner = try tempOrdner()
        let bund = SpeicherSchluesselbund()
        let mit = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson), antwort(200, partnerJson(geschrieben: "2026-09-23T11:00:00.000Z")), antwort(200)])
        let d = try dienst(mit, bund: bund, ordner: ordner)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let datei = ordner.appendingPathComponent(KontoDienst.partnerDatei)
        let gelesen = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: try Data(contentsOf: datei))
        XCTAssertEqual(gelesen.profilName, "Partner")
        XCTAssertEqual(gelesen.heute.schritte, 4200)
        XCTAssertEqual(mit.anfragen.first { $0.url?.path == "/partner" }?.httpMethod, "GET")

        let ohne = SkriptLader([antwort(200, configJson), antwort(200, freigabeJson), antwort(200, #"{"partner":null,"aktualisiert":null}"#), antwort(200)])
        let neu = try dienst(ohne, bund: bund, ordner: ordner)
        await neu.aktualisiere(profilName: "Beispiel", erzwingen: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: datei.path), "kein Partner mehr: nichts zeigen")
    }

    func testEigeneZusammenfassungGehtMitKontoKopfzeilenAnDenServer() async throws {
        let lader = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, freigabeJson), antwort(200, #"{"partner":null}"#), antwort(200)])
        let d = try dienst(lader)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        let datei = ZusammenfassungDatei(version: 1, geschrieben: TestUhr().lesen, profilName: "Beispiel", freigaben: [.schritte],
                                         heute: TagesZusammenfassung(tag: "2026-09-23", schritte: 5000), ereignisse: [])
        d.partnerHochladen(try LoveaVertrag.encoder().encode(datei))
        for _ in 0..<50 where !lader.anfragen.contains(where: { $0.httpMethod == "PUT" }) { try await Task.sleep(for: .milliseconds(20)) }
        let put = try XCTUnwrap(lader.anfragen.last { $0.httpMethod == "PUT" })
        XCTAssertEqual(put.url?.path, "/partner")
        XCTAssertNotNil(put.value(forHTTPHeaderField: "X-Konto"))
        let zurueck = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: try XCTUnwrap(put.httpBody))
        XCTAssertEqual(zurueck, datei)
    }

    func testOhneFreigabeGehtNichtsAnDenPartnerWeg() async throws {
        let lader = SkriptLader([antwort(201), antwort(200, configJson), antwort(200, #"{"erlaubt":false}"#), antwort(200)])
        let d = try dienst(lader)
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        d.partnerHochladen(Data("{}".utf8))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(pfade(lader).contains("/partner"))
    }

    func testBrueckeWaehltFrischenServerStandDannLoveaDateiDannVeraltet() {
        let jetzt = TestUhr().lesen
        func datei(_ name: String, vor: TimeInterval) -> ZusammenfassungDatei {
            ZusammenfassungDatei(version: 1, geschrieben: jetzt.addingTimeInterval(-vor), profilName: name, freigaben: [], heute: TagesZusammenfassung(tag: "2026-09-23"), ereignisse: [])
        }
        let frisch = datei("Server", vor: 60), alt = datei("Server", vor: 3 * LoveaVertrag.frist), lovea = datei("Datei", vor: 60)
        XCTAssertEqual(ServerPartnerBruecke.waehle(server: frisch, innen: .verbunden(lovea), jetzt: jetzt), .verbunden(frisch), "der Server gewinnt")
        XCTAssertEqual(ServerPartnerBruecke.waehle(server: alt, innen: .verbunden(lovea), jetzt: jetzt), .verbunden(lovea), "Lovea-Datei, solange Lovea sie schreibt")
        XCTAssertEqual(ServerPartnerBruecke.waehle(server: alt, innen: .nichtVerbunden, jetzt: jetzt), .veraltet(alt))
        XCTAssertEqual(ServerPartnerBruecke.waehle(server: nil, innen: .verbunden(lovea), jetzt: jetzt), .verbunden(lovea))
        XCTAssertEqual(ServerPartnerBruecke.waehle(server: nil, innen: .nichtVerbunden, jetzt: jetzt), .nichtVerbunden)
        XCTAssertEqual(ServerPartnerBruecke.waehle(server: nil, innen: .unbekannteVersion, jetzt: jetzt), .unbekannteVersion)
    }

    func testBrueckeSchreibtAnLoveaUndAnDenServerWegUndBandBleibtBeiLovea() throws {
        let ordner = try tempOrdner()
        let innen = LoveaBruecke(ordner: ordner)
        let kanal = PartnerHochlader()
        let gesendet = Sammler()
        kanal.setze { d in gesendet.add(d) }
        let b = ServerPartnerBruecke(innen: innen, serverDatei: ordner.appendingPathComponent(KontoDienst.partnerDatei), hochlader: kanal)
        let datei = ZusammenfassungDatei(version: 1, geschrieben: TestUhr().lesen, profilName: "Beispiel", freigaben: [.gym],
                                         heute: TagesZusammenfassung(tag: "2026-09-23", gymTageWoche: 2), ereignisse: [])
        b.schreibe(zusammenfassung: datei)
        XCTAssertEqual(gesendet.anzahl, 1)
        let lovea = ordner.appendingPathComponent("LumenFit/zusammenfassung.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: lovea.path), "der Datei-Weg zu Lovea bleibt")
        b.melde(erledigt: ["w1"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("LumenFit/band-erledigt.json").path))
        try Data("{}".utf8).write(to: ordner.appendingPathComponent(KontoDienst.partnerDatei))
        b.loescheEigeneDateien()
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent(KontoDienst.partnerDatei).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: lovea.path))
    }

    // MARK: - Theme Lovea

    func testThemeLoveaHatEigenesMusterMitHerzen() {
        XCTAssertTrue(ThemaID.allCases.contains(.lovea))
        XCTAssertEqual(ThemaID.lovea.anzeigeName, "Lovea")
        XCTAssertEqual(ProfilThemaWahl.muster(.lovea), "Herzen")
        XCTAssertFalse(MusterZeichner.herzen(CGSize(width: 120, height: 80), raster: 22, groesse: 7).isEmpty)
        XCTAssertTrue(MusterZeichner.herzen(.zero, raster: 22, groesse: 7).isEmpty)
        XCTAssertEqual(Einstellungen().thema, .monochrom, "Standard bleibt monochrom")
        XCTAssertEqual(try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"lovea"}"#.utf8)).thema, .lovea)
        XCTAssertEqual(try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"gibtsNicht"}"#.utf8)).thema, .monochrom)
    }
}
