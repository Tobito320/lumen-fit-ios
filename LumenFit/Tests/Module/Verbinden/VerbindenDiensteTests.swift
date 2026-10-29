import XCTest
@testable import LumenFit

/// Die Verdrahtung des Moduls (`VerbindenDienste`): ohne Schalter bleibt alles still, mit Schalter kommt jede Mitteilung genau einmal, Wünsche brauchen beide Schalter.
@MainActor
final class VerbindenDiensteTests: XCTestCase {
    private func umgebung(bruecke: FakePartnerAustausch, mitteiler: FakeMitteiler) throws -> AppUmgebung {
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: mitteiler,
                            leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: bruecke, uhr: { VerbindenTest.jetzt }, passwortRunden: 1_000)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "abcd")
        return u
    }

    private func partner() throws -> ZusammenfassungDatei {
        try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: FixtureOrt.daten("Verbinden", "partner-beispiel.json"))
    }

    func testOhneSchalterBleibtAllesStill() async throws {
        let fake = FakePartnerAustausch(partner: .verbunden(try partner()))
        let mitteiler = FakeMitteiler()
        let u = try umgebung(bruecke: fake, mitteiler: mitteiler)
        let dienste = VerbindenDienste(u, startAbruf: false)
        await dienste.abruf()
        XCTAssertEqual(u.daten?.verbindung.partner, .nichtVerbunden, "Lovea-Schalter aus: kein Partner")
        XCTAssertTrue(mitteiler.meldungen.isEmpty)
        XCTAssertTrue(fake.zusammenfassungen.isEmpty)
        XCTAssertTrue(fake.status.isEmpty)
        XCTAssertNil(dienste.band.modell, "ohne Band-Schalter entsteht kein Band-Modell")
    }

    func testMitSchalterKommtJedeMitteilungGenauEinmal() async throws {
        let datei = try partner()
        let fake = FakePartnerAustausch(partner: .verbunden(datei))
        let mitteiler = FakeMitteiler()
        let u = try umgebung(bruecke: fake, mitteiler: mitteiler)
        u.daten?.einstellungen.aendere { $0.loveaVerbunden = true }
        let dienste = VerbindenDienste(u, startAbruf: false)
        await dienste.abruf()
        await dienste.abruf()
        XCTAssertEqual(u.daten?.verbindung.partner, .verbunden(datei))
        XCTAssertEqual(mitteiler.meldungen.count, datei.ereignisse.count, "jedes Ereignis einmal, auch nach zwei Runden")
        XCTAssertEqual(Set(mitteiler.meldungen.map(\.id)).count, mitteiler.meldungen.count)
        XCTAssertEqual(fake.zusammenfassungen.count, 1, "die Datei für Lovea wird geschrieben, ohne Änderung nicht noch einmal")
        XCTAssertTrue(fake.zusammenfassungen[0].freigaben.isEmpty, "Standard: nichts freigegeben")
        XCTAssertNil(dienste.band.modell)
    }

    func testWuenscheBrauchenBandSchalter() async throws {
        let wunsch = BandWunsch(id: "w1", muster: .kurz, zeit: VerbindenTest.jetzt, von: "Beispiel Partner")
        let fake = FakePartnerAustausch(wuensche: [wunsch])
        let u = try umgebung(bruecke: fake, mitteiler: FakeMitteiler())
        u.daten?.einstellungen.aendere { $0.loveaVerbunden = true }
        let dienste = VerbindenDienste(u, startAbruf: false)
        await dienste.abruf()
        dienste.wuenscheAusfuehren()
        XCTAssertTrue(fake.erledigt.isEmpty, "Band-Schalter aus: der Wunsch bleibt liegen")
    }
}
