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

    func testEintragIstNurMitStatusAktivAktiv() throws {
        let json = #"{"verbindungen":[{"id":"a","name":"Person","status":"aktiv"},{"id":"b","name":"Zukunft","status":"neuerStatus"},{"kaputt":true},{"id":"c","name":"Wartet","status":"anfrageEingehend"}],"teilen":["schritte","irgendwas"]}"#
        let a = try LoveaVertrag.decoder().decode(VerbindungenAntwort.self, from: Data(json.utf8))
        XCTAssertEqual(a.verbindungen.map(\.id), ["a", "b", "c"], "ein Eintrag, den die App nicht versteht, fällt weg")
        XCTAssertEqual(a.verbindungen.filter(\.aktiv).map(\.id), ["a"], "ein unbekannter Status zeigt nichts")
        XCTAssertEqual(a.teilenBereiche, [.schritte])
    }

    func testHochladenFolgtDerTeilenListe() {
        XCTAssertTrue(VerbindungenLogik.hochladen(nil).freigaben.isEmpty)
        let h = VerbindungenLogik.hochladen(VerbindungenAntwort(teilen: ["schritte", "zyklus"]))
        XCTAssertEqual(h.freigaben, [.schritte])
        XCTAssertTrue(h.zyklus)
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
        XCTAssertNil(VerbindungenLogik.begrenze(datei, auf: Set(FreigabeArt.allCases)).heute.zyklus, "Zyklus kommt nie aus einer Datei")
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
}
