import XCTest
@testable import LumenFit

/// Die Regeln rund um Verbindungen: Token aus Link, Standard-Bereiche, Zuschnitt für Lovea, Wahl des Partner-Stands, Band-Standard.
final class VerbindungenLogikTests: XCTestCase {
    private let token = String(repeating: "aB3_-", count: 8) + "xyz"   // 43 Zeichen

    func testTokenKommtAusLinkOderNackt() {
        XCTAssertEqual(token.utf8.count, 43)
        XCTAssertEqual(VerbindungenLogik.token(aus: token), token)
        XCTAssertEqual(VerbindungenLogik.token(aus: "  \(token)\n"), token)
        XCTAssertEqual(VerbindungenLogik.token(aus: VerbindungenLogik.link(token: token).absoluteString), token)
    }

    func testKeinTokenBleibtKeins() {
        XCTAssertNil(VerbindungenLogik.token(aus: nil))
        XCTAssertNil(VerbindungenLogik.token(aus: ""))
        XCTAssertNil(VerbindungenLogik.token(aus: String(token.dropLast())), "zu kurz")
        XCTAssertNil(VerbindungenLogik.token(aus: token + "a"), "zu lang")
        XCTAssertNil(VerbindungenLogik.token(aus: String(token.dropLast()) + "."), "Punkt: alte Wochenkarte")
        XCTAssertNil(VerbindungenLogik.token(aus: "https://example.org/\(token)"))
    }

    func testStandardZeigtNurSchritteUndGym() {
        XCTAssertEqual(VerbindungenLogik.standardZeigt, [.schritte, .gym])
        XCTAssertEqual(VerbindungEinstellung().zeigtBereiche, [], "ohne Angabe zeigt der Eintrag nichts")
    }

    func testFreigabeStufenWenigAllesUndEigene() {
        XCTAssertEqual(FreigabeStufe.wenig.bereiche, [.schritte, .gym])
        XCTAssertEqual(FreigabeStufe.alles.bereiche, Set(VerbindungBereich.allCases))
        XCTAssertEqual(FreigabeStufe.von([.schritte, .gym]), .wenig)
        XCTAssertEqual(FreigabeStufe.von(Set(VerbindungBereich.allCases)), .alles)
        XCTAssertNil(FreigabeStufe.von([.schritte, .schlaf]), "eigene Auswahl bleibt, wie sie ist")
        XCTAssertNil(FreigabeStufe.von([]))
    }

    func testEinzelnerSchalterAendertNurSeinenBereichUndDieStufeFolgt() {
        let wenig = FreigabeStufe.wenig.bereiche
        let mitSchlaf = FreigabeStufe.schalte(wenig, .schlaf, ein: true)
        XCTAssertEqual(mitSchlaf, [.schritte, .gym, .schlaf])
        XCTAssertNil(FreigabeStufe.von(mitSchlaf), "eigene Auswahl: im Segment ist nichts aktiv")
        XCTAssertEqual(FreigabeStufe.schalte(mitSchlaf, .schlaf, ein: false), wenig)
        XCTAssertEqual(FreigabeStufe.von(FreigabeStufe.schalte(mitSchlaf, .schlaf, ein: false)), .wenig)
        XCTAssertEqual(FreigabeStufe.schalte(wenig, .gym, ein: true), wenig, "schon an bleibt an")
        // Alle zehn Schalter an ist genau "Alles" (es gibt keinen elften Bereich).
        let alle = VerbindungBereich.allCases.reduce(Set<VerbindungBereich>()) { FreigabeStufe.schalte($0, $1, ein: true) }
        XCTAssertEqual(FreigabeStufe.von(alle), .alles)
        XCTAssertTrue(FreigabeStufe.schalte([.schritte], .schritte, ein: false).isEmpty, "auch alles aus ist erlaubt")
    }

    func testFeldFuerDenServerIstSortiertUndOhneZyklus() {
        let felder = FreigabeStufe.felder([.schlaf, .gym, .schritte])
        XCTAssertEqual(felder["zeigt"] as? [String], ["gym", "schlaf", "schritte"])
        XCTAssertEqual(felder.count, 1)
        XCTAssertEqual((FreigabeStufe.felder(FreigabeStufe.alles.bereiche)["zeigt"] as? [String])?.count, 10)
    }

    func testEintragIstNurMitStatusAktivAktiv() throws {
        let json = #"{"verbindungen":[{"id":"a","name":"Person","status":"aktiv"},{"id":"b","name":"Zukunft","status":"neuerStatus"},{"kaputt":true},{"id":"c","name":"Wartet","status":"anfrageEingehend"}],"teilen":["schritte","irgendwas"]}"#
        let a = try LoveaVertrag.decoder().decode(VerbindungenAntwort.self, from: Data(json.utf8))
        XCTAssertEqual(a.verbindungen.map(\.id), ["a", "b", "c"], "ein Eintrag, den die App nicht versteht, fällt weg")
        XCTAssertEqual(a.verbindungen.filter(\.aktiv).map(\.id), ["a"], "ein unbekannter Status zeigt nichts")
        XCTAssertEqual(a.teilenBereiche, [.schritte])
    }

    func testHochladenFolgtDerTeilenListe() {
        XCTAssertTrue(VerbindungenLogik.hochladen(nil).isEmpty)
        let h = VerbindungenLogik.hochladen(VerbindungenAntwort(teilen: ["schritte", "zyklus"]))
        XCTAssertEqual(h, [.schritte], "Zyklus nennt der Server vielleicht noch, Lumen Fit lädt ihn nie hoch")
    }

    func testFreigabenFuerLoveaBraucheAktivUndKeinePause() {
        var e = VerbindungEintrag(id: "l", name: "Partner", lovea: true, ich: VerbindungEinstellung(zeigt: ["schritte", "zyklus", "gym"]))
        XCTAssertEqual(VerbindungenLogik.freigaben(fuer: e), [.schritte, .gym], "Zyklus ist keine Freigabe der Datei")
        e.ich.pause = true
        XCTAssertEqual(VerbindungenLogik.freigaben(fuer: e), [])
        XCTAssertEqual(VerbindungenLogik.freigaben(fuer: VerbindungEintrag(id: "x", name: "A", status: .anfrageEingehend, ich: VerbindungEinstellung(zeigt: ["gym"]))), [])
        XCTAssertEqual(VerbindungenLogik.freigaben(fuer: nil), [])
    }

    func testBegrenzenLaesstFelderAbgeschalteterBereicheWegNichtNurDieListe() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        var heute = TagesZusammenfassung(tag: "2026-10-29", schritte: 5000, gymTageWoche: 3, schlafMinuten: 420, kcal: 2000)
        heute.habitsFertig = ["gym", "wasser"]
        let datei = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Person", freigaben: [.schritte, .gym, .schlaf, .essen], heute: heute,
                                         ereignisse: [PartnerEreignis(id: "e1", art: .gymStart, zeit: jetzt, text: "x"), PartnerEreignis(id: "e2", art: .schlafGut, zeit: jetzt, text: "y")])
        let kurz = VerbindungenLogik.begrenze(datei, auf: [.schritte, .gym])
        XCTAssertEqual(kurz.freigaben, [.schritte, .gym])
        XCTAssertEqual(kurz.heute.schritte, 5000)
        XCTAssertEqual(kurz.heute.gymTageWoche, 3)
        XCTAssertNil(kurz.heute.schlafMinuten)
        XCTAssertNil(kurz.heute.kcal)
        XCTAssertEqual(kurz.heute.habitsFertig, ["gym"], "Wasser gehört zu Essen")
        XCTAssertEqual(kurz.ereignisse.map(\.id), ["e1"])
    }

    func testZuletztText() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(VerbindungenLogik.zuletztText(nil, jetzt: jetzt), "Noch keine Daten")
        XCTAssertEqual(VerbindungenLogik.zuletztText(jetzt.addingTimeInterval(-30), jetzt: jetzt), "Gerade eben aktualisiert")
        XCTAssertEqual(VerbindungenLogik.zuletztText(jetzt.addingTimeInterval(-60 * 5), jetzt: jetzt), "Vor 5 Minuten aktualisiert")
        XCTAssertEqual(VerbindungenLogik.zuletztText(jetzt.addingTimeInterval(-3600), jetzt: jetzt), "Vor 1 Stunde aktualisiert")
        XCTAssertEqual(VerbindungenLogik.zuletztText(jetzt.addingTimeInterval(-86_400), jetzt: jetzt), "Gestern aktualisiert")
    }

    // MARK: Wahl des Partner-Stands

    func testOhneAktiveLoveaVerbindungKeinPartnerAuchNichtAusDerDatei() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        let lovea = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Datei", freigaben: [.schritte], heute: TagesZusammenfassung(tag: "2026-10-29", schritte: 1), ereignisse: [])
        let leer = VerbindungenAntwort()
        XCTAssertEqual(ServerPartnerBruecke.waehle(liste: leer, server: nil, innen: .verbunden(lovea), jetzt: jetzt), .nichtVerbunden, "entfernt: auch die Datei von Lovea bringt sie nicht zurück")
        let pausiert = VerbindungenAntwort(verbindungen: [VerbindungEintrag(id: "l", name: "P", lovea: true, ich: VerbindungEinstellung(pause: true))])
        XCTAssertEqual(ServerPartnerBruecke.waehle(liste: pausiert, server: nil, innen: .verbunden(lovea), jetzt: jetzt), .nichtVerbunden)
    }

    func testMitLoveaVerbindungGewinntDerServerDannDieBegrenzteDatei() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        var heute = TagesZusammenfassung(tag: "2026-10-29", schritte: 9, kcal: 1500)
        heute.gymTageWoche = 2
        let lovea = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Datei", freigaben: [.schritte, .essen, .gym], heute: heute, ereignisse: [])
        let server = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Server", freigaben: [.schritte], heute: TagesZusammenfassung(tag: "2026-10-29", schritte: 7), ereignisse: [])
        let liste = VerbindungenAntwort(verbindungen: [VerbindungEintrag(id: "l", name: "P", lovea: true, siehst: ["schritte", "gym"])])
        XCTAssertEqual(ServerPartnerBruecke.waehle(liste: liste, server: server, innen: .verbunden(lovea), jetzt: jetzt), .verbunden(server))
        guard case .verbunden(let d) = ServerPartnerBruecke.waehle(liste: liste, server: nil, innen: .verbunden(lovea), jetzt: jetzt) else { return XCTFail("verbunden erwartet") }
        XCTAssertEqual(Set(d.freigaben), [.schritte, .gym])
        XCTAssertNil(d.heute.kcal, "Essen sieht diese Verbindung nicht")
    }

    // MARK: Trainingspartner (frei gewählt, unabhängig von Lovea)

    func testTrainingspartnerGewaehltSonstLoveaPersonKeinerHeisstKeiner() {
        let lovea = VerbindungEintrag(id: "l", name: "L", lovea: true)
        let freund = VerbindungEintrag(id: "f", name: "F")
        let pausiert = VerbindungEintrag(id: "p", name: "P", ich: VerbindungEinstellung(pause: true))
        let liste = [lovea, freund, pausiert]
        XCTAssertEqual(VerbindungenLogik.partner(liste, gewaehlt: "f")?.id, "f")
        XCTAssertEqual(VerbindungenLogik.partner(liste, gewaehlt: nil)?.id, "l", "ohne Wahl wie bisher die Lovea-Person")
        XCTAssertEqual(VerbindungenLogik.partner(liste, gewaehlt: "p")?.id, "l", "pausiert: zurück zur Vorgabe")
        XCTAssertEqual(VerbindungenLogik.partner(liste, gewaehlt: "weg")?.id, "l")
        XCTAssertNil(VerbindungenLogik.partner(liste, gewaehlt: VerbindungenLogik.keinPartner))
        XCTAssertNil(VerbindungenLogik.partner([freund], gewaehlt: nil), "ohne Wahl und ohne Lovea-Person keiner")
    }

    func testGewaehlterFreundKommtVomServerDieDateiVonLoveaNurFuerDieLoveaPerson() {
        let jetzt = Date(timeIntervalSince1970: 1_800_000_000)
        let datei = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Datei", freigaben: [.schritte], heute: TagesZusammenfassung(tag: "2026-10-29", schritte: 1), ereignisse: [])
        let server = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Freund", freigaben: [.gym], heute: TagesZusammenfassung(tag: "2026-10-29", gymTageWoche: 2), ereignisse: [])
        let liste = VerbindungenAntwort(verbindungen: [VerbindungEintrag(id: "l", name: "L", lovea: true, siehst: ["schritte"]), VerbindungEintrag(id: "f", name: "F", siehst: ["gym"])])
        XCTAssertEqual(ServerPartnerBruecke.waehle(liste: liste, server: server, innen: .verbunden(datei), jetzt: jetzt, gewaehlt: "f"), .verbunden(server))
        XCTAssertEqual(ServerPartnerBruecke.waehle(liste: liste, server: nil, innen: .verbunden(datei), jetzt: jetzt, gewaehlt: "f"), .nichtVerbunden,
                       "die Datei von Lovea ist kein Ersatz für einen anderen Freund")
        guard case .verbunden = ServerPartnerBruecke.waehle(liste: liste, server: nil, innen: .verbunden(datei), jetzt: jetzt, gewaehlt: nil) else {
            return XCTFail("Lovea-Person mit Datei erwartet")
        }
        XCTAssertEqual(ServerPartnerBruecke.waehle(liste: liste, server: server, innen: .verbunden(datei), jetzt: jetzt, gewaehlt: VerbindungenLogik.keinPartner), .nichtVerbunden)
    }

    // MARK: Form der Server-Antworten (Wortlaut wie `server/verbindungen.js` sie schickt)

    func testAntwortDesServersLaesstSichLesen() throws {
        let json = #"""
        {"verbindungen":[
          {"id":"abc123","name":"Person","auto":true,"erstellt":"2026-10-31T09:00:00.000Z","lovea":true,"status":"aktiv",
           "ich":{"zeigt":["schritte","gym","schlaf","essen","plan","verlauf","tagebuch","koerper","stimmung","gewohnheiten","zyklus"],"ausblenden":["koerper"],"pause":false,"mitteilungen":true,"favorit":true,"name":""},
           "siehst":["schritte","gym"],"pausiert":false,"zuletzt":"2026-10-31T09:30:00.000Z",
           "daten":{"version":1,"geschrieben":"2026-10-31T09:30:00.000Z","profilName":"Person","freigaben":["schritte","gym"],
                    "heute":{"tag":"2026-10-31","schritte":4200,"gymTageWoche":2},"ereignisse":[]}},
          {"id":"def456","name":"Ben","auto":false,"erstellt":"2026-10-31T09:00:00.000Z","lovea":false,"status":"anfrageEingehend"},
          {"id":"ghi789","name":"Cem","auto":false,"erstellt":"2026-10-31T09:00:00.000Z","lovea":false,"status":"anfrageAusgehend"}],
         "teilen":["schritte","gym","schlaf","essen","plan","verlauf","tagebuch","koerper","stimmung","gewohnheiten","zyklus"]}
        """#
        let a = try LoveaVertrag.decoder().decode(VerbindungenAntwort.self, from: Data(json.utf8))
        XCTAssertEqual(a.verbindungen.map(\.status), [.aktiv, .anfrageEingehend, .anfrageAusgehend])
        let e = try XCTUnwrap(a.verbindungen.first)
        XCTAssertTrue(e.lovea)
        XCTAssertEqual(e.ich.zeigtBereiche.count, 10, "ein altes \"zyklus\" vom Server fällt beim Lesen weg")
        XCTAssertFalse(e.ich.zeigt.isEmpty)
        XCTAssertEqual(e.ich.ausgeblendet, [.koerper])
        XCTAssertEqual(e.sichtbareBereiche, [.schritte, .gym])
        XCTAssertNotNil(e.zuletzt)
        XCTAssertEqual(e.daten?.heute.schritte, 4200)
        XCTAssertEqual(a.teilenBereiche, Set(VerbindungBereich.allCases))
    }

    func testEinladungDesServersLaesstSichLesen() throws {
        // `POST /verbindungen/einladung` antwortet mit 43 Zeichen Token und einem ISO-Datum mit Millisekunden.
        let json = #"{"token":"\#(token)","laeuftAb":"2026-10-31T10:10:00.000Z","sekunden":600}"#
        struct Antwort: Decodable { var token: String; var laeuftAb: String }
        let a = try JSONDecoder().decode(Antwort.self, from: Data(json.utf8))
        XCTAssertTrue(VerbindungenLogik.istToken(a.token))
        XCTAssertNotNil(LoveaVertrag.isoDatum(a.laeuftAb))
    }

    // MARK: Band-Standard und Einstellungen

    func testBandBewusstAusUeberlebtDenRoundTripUndFehltBeiAlterDatei() throws {
        var e = Einstellungen()
        XCTAssertFalse(e.bandBewusstAus)
        e.bandBewusstAus = true
        let zurueck = try JSONDecoder().decode(Einstellungen.self, from: try JSONEncoder().encode(e))
        XCTAssertTrue(zurueck.bandBewusstAus)
        let alt = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"wald","bandAktiv":true}"#.utf8))
        XCTAssertFalse(alt.bandBewusstAus)
    }

    func testServerConfigBandStandard() {
        XCTAssertFalse(ServerConfig.standard.bandStandard)
        let neu = ServerConfig.zusammen(.standard, antwort: Data(#"{"config":{"bandStandard":true}}"#.utf8))
        XCTAssertEqual(neu?.bandStandard, true)
    }

    // MARK: Ausgeschaltete Bereiche, Liste

    func testAusgeschalteterBereichWirdNichtHochgeladen() {
        let antwort = VerbindungenAntwort(teilen: ["schritte", "gym", "plan", "verlauf", "essen", "tagebuch", "schlaf"])
        var e = Einstellungen()
        XCTAssertEqual(VerbindungenLogik.hochladen(antwort, einstellungen: e).count, 7, "alles an: alles darf hinaus")
        e.setze(.gym, an: false)
        XCTAssertEqual(VerbindungenLogik.hochladen(antwort, einstellungen: e), [.schritte, .essen, .tagebuch, .schlaf], "Gym aus: auch Plan und Training bleiben da")
        e.setze(.essen, an: false)
        XCTAssertEqual(VerbindungenLogik.hochladen(antwort, einstellungen: e), [.schritte, .schlaf])
        XCTAssertEqual(VerbindungenLogik.hochladen(VerbindungenAntwort(teilen: ["schritte", "gym"]), einstellungen: e), [.schritte], "Wenig ohne Gym teilt nur Schritte")
    }

    func testNichtGeteiltNenntErlaubteAberFehlendeBereiche() {
        let jetzt = TestUhr().lesen
        let datei = ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: jetzt, profilName: "Beispiel", freigaben: [.schritte],
                                         heute: TagesZusammenfassung(tag: Datum.text(jetzt)), ereignisse: [])
        var e = VerbindungEintrag(id: "p", name: "Person", siehst: ["schritte", "gym"], daten: datei)
        XCTAssertEqual(VerbindungenLogik.nichtGeteilt(e), [.gym])
        e.daten = nil
        XCTAssertEqual(VerbindungenLogik.nichtGeteilt(e), [], "ohne Daten wird nichts behauptet")
    }

    func testKurzInfoZeigtSchritteUndGymVonHeute() {
        let jetzt = TestUhr().lesen
        var tag = TagesZusammenfassung(tag: Datum.text(jetzt))
        tag.schritte = 4200; tag.gymTageWoche = 2; tag.gymZiel = 4
        let datei = ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: jetzt, profilName: "Beispiel", freigaben: [.schritte, .gym], heute: tag, ereignisse: [])
        var e = VerbindungEintrag(id: "p", name: "Person", daten: datei)
        XCTAssertEqual(VerbindungenLogik.kurzInfo(e, jetzt: jetzt), "4.200 Schritte · Gym 2 von 4")
        e.daten?.freigaben = [.schritte]
        XCTAssertEqual(VerbindungenLogik.kurzInfo(e, jetzt: jetzt), "4.200 Schritte", "Gym nicht geteilt: keine Gym-Zeile")
        e.daten?.freigaben = []
        XCTAssertNil(VerbindungenLogik.kurzInfo(e, jetzt: jetzt))
        e.daten = datei
        e.ich.pause = true
        XCTAssertNil(VerbindungenLogik.kurzInfo(e, jetzt: jetzt), "Pause: nichts")
        e.ich.pause = false
        XCTAssertNil(VerbindungenLogik.kurzInfo(e, jetzt: jetzt.addingTimeInterval(2 * 86_400)), "gestriger Stand steht nicht als heute da")
    }

    // MARK: Warten auf die Annahme

    func testAnfrageStandWartetBisAnnahmeOderAblehnung() {
        let wartend = VerbindungEintrag(id: "x", name: "Person", status: .anfrageAusgehend)
        let aktiv = VerbindungEintrag(id: "x", name: "Person", status: .aktiv)
        XCTAssertEqual(VerbindungenLogik.anfrageStand(id: "x", gesehen: true, in: [wartend]), .wartet)
        XCTAssertEqual(VerbindungenLogik.anfrageStand(id: "x", gesehen: true, in: [aktiv]), .verbunden)
        XCTAssertEqual(VerbindungenLogik.anfrageStand(id: "x", gesehen: true, in: []), .abgelehnt, "der Server löscht die Zeile beim Ablehnen")
        XCTAssertEqual(VerbindungenLogik.anfrageStand(id: "x", gesehen: false, in: []), .wartet, "nie gesehen: eine alte Liste, kein Ablehnen")
        XCTAssertEqual(VerbindungenLogik.anfrageStand(id: "x", gesehen: true, in: [VerbindungEintrag(id: "y", name: "Andere", status: .aktiv)]), .abgelehnt)
    }

    func testNeuePersonNurUeberMeineEinladungUndNochNichtBekannt() {
        let alt = VerbindungEintrag(id: "alt", name: "Alt", eingeladen: true)
        let neu = VerbindungEintrag(id: "neu", name: "Neu", eingeladen: true)
        let gescannt = VerbindungEintrag(id: "ich-scannte", name: "Andere", eingeladen: false)
        let anfrage = VerbindungEintrag(id: "anfrage", name: "Anfrage", status: .anfrageEingehend, eingeladen: true)
        XCTAssertNil(VerbindungenLogik.neuePerson([alt], bekannt: ["alt"]))
        XCTAssertEqual(VerbindungenLogik.neuePerson([alt, gescannt, anfrage, neu], bekannt: ["alt"])?.id, "neu")
        XCTAssertNil(VerbindungenLogik.neuePerson([], bekannt: []))
    }

    // MARK: Einladen per QR-Code oder Code (W-033)

    func testTokenAusDerSeiteImQRCode() {
        let server = URL(string: "https://lumen-fit-test.example.workers.dev")!
        let seite = VerbindungenLogik.seite(server: server, token: token)
        XCTAssertEqual(seite.absoluteString, "https://lumen-fit-test.example.workers.dev/f/\(token)")
        XCTAssertEqual(VerbindungenLogik.token(aus: seite.absoluteString), token)
        XCTAssertNil(VerbindungenLogik.token(aus: "https://example.org/g/\(token)"), "nur der Weg /f/")
        XCTAssertNil(VerbindungenLogik.token(aus: "https://example.org/f/\(token)/mehr"))
        XCTAssertNil(VerbindungenLogik.token(aus: "http://example.org/f/\(token)"), "nur https")
    }

    func testCodeGrossKleinLeerzeichenUndBindestrichEgal() {
        XCTAssertEqual(VerbindungenLogik.code(aus: "K7Q2-9FXA"), "K7Q29FXA")
        XCTAssertEqual(VerbindungenLogik.code(aus: " k7q2 9fxa\n"), "K7Q29FXA")
        XCTAssertEqual(VerbindungenLogik.code(aus: "k7q29fxa"), "K7Q29FXA")
        for falsch in [nil, "", "K7Q2-9FX", "K7Q2-9FXAB", "K7Q2-9FX0", "K7Q2-9FXO", "K7Q2-9FXI", "K7Q2-9FX1", "K7Q2-9FXL", "K7Q2-9FXÄ", "K7Q2_9FXA"] {
            XCTAssertNil(VerbindungenLogik.code(aus: falsch), falsch ?? "nil")
        }
        XCTAssertEqual(VerbindungenLogik.codeZeichen.count, 31)
    }

    func testEinladungNimmtTokenSeiteOderCode() {
        XCTAssertEqual(VerbindungenLogik.einladung(aus: token), token)
        XCTAssertEqual(VerbindungenLogik.einladung(aus: VerbindungenLogik.link(token: token).absoluteString), token)
        XCTAssertEqual(VerbindungenLogik.einladung(aus: "abcd-efgh"), "ABCDEFGH")
        XCTAssertNil(VerbindungenLogik.einladung(aus: "Hallo"))
    }

    func testNeuVerbundenNurMeineEinladungenNachDemLetztenBlickHoechstensSiebenTage() {
        let jetzt = Date(timeIntervalSince1970: 1_794_300_000)
        func e(_ id: String, vor stunden: Double?, eingeladen: Bool = true, status: VerbindungStatus = .aktiv) -> VerbindungEintrag {
            VerbindungEintrag(id: id, name: id, status: status, erstellt: stunden.map { jetzt.addingTimeInterval(-$0 * 3600) }, eingeladen: eingeladen)
        }
        let liste = [e("alt", vor: 24 * 8), e("gestern", vor: 20), e("eben", vor: 1), e("selbst", vor: 1, eingeladen: false),
                     e("anfrage", vor: 1, status: .anfrageEingehend), e("ohneZeit", vor: nil)]
        XCTAssertEqual(VerbindungenLogik.neuVerbunden(liste, seit: nil, jetzt: jetzt).map(\.id), ["eben", "gestern"], "neueste zuerst, höchstens sieben Tage")
        XCTAssertEqual(VerbindungenLogik.neuVerbunden(liste, seit: jetzt.addingTimeInterval(-2 * 3600), jetzt: jetzt).map(\.id), ["eben"])
        XCTAssertEqual(VerbindungenLogik.neuVerbunden(liste, seit: jetzt, jetzt: jetzt), [])
    }
}
