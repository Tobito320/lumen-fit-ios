import XCTest
@testable import LumenFit

/// Lovea-Aufbau: "Übung starten", "Nächster Satz", "Satz fertig". Der gestartete Satz, seine Uhr, die Dauer beim Haken, das Aufhören bei verschobenen Zeilen.
@MainActor
final class SatzStartTests: XCTestCase {
    private func aufbau() throws -> GymTestAufbau {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        return a
    }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(true, forKey: GymAnzeige.satzzeitSchluessel)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: GymAnzeige.satzzeitSchluessel)
        super.tearDown()
    }

    func testKnopfTextFolgtLovea() {
        XCTAssertEqual(SatzUhrLogik.knopfText(laeuft: false, offener: 0), "Übung starten")
        XCTAssertEqual(SatzUhrLogik.knopfText(laeuft: false, offener: 1), "Nächster Satz")
        XCTAssertEqual(SatzUhrLogik.knopfText(laeuft: true, offener: 0), "Satz fertig")
        XCTAssertEqual(SatzUhrLogik.knopfText(laeuft: true, offener: 2), "Satz fertig")
    }

    func testStartenLaesstDieUhrDesSatzesLaufen() throws {
        let a = try aufbau()
        XCTAssertNil(a.sitzung.laufenderSatz(0))
        a.sitzung.satzStarten(0, 0)
        XCTAssertEqual(a.sitzung.laufenderSatz(0), 0)
        XCTAssertNil(a.sitzung.laufenderSatz(1), "nur diese Übung")
        XCTAssertEqual(a.sitzung.satzLauf?.seit, a.uhr.lesen)
        XCTAssertEqual(a.sitzung.satzStartZaehler, 1)
    }

    func testDerHakenMisstDieDauerAbDemStartUndBeendetDenLauf() throws {
        let a = try aufbau()
        a.sitzung.satzStarten(0, 0)
        a.uhr.vor(sekunden: 42)
        a.sitzung.haken(0, 0)
        XCTAssertEqual(a.sitzung.liste[0].saetze[0].sek, 42)
        XCTAssertNil(a.sitzung.satzLauf, "der Haken beendet den Lauf, die Pause beginnt")
        XCTAssertEqual(a.sitzung.pause?.satz, 0)
    }

    func testStartenBeendetDiePauseUndSchreibtIhreLaengeAnDenSatzDavor() throws {
        let a = try aufbau()
        a.sitzung.haken(0, 0)
        a.uhr.vor(sekunden: 75)
        a.sitzung.satzStarten(0, 1)
        XCTAssertNil(a.sitzung.pause)
        XCTAssertEqual(a.sitzung.liste[0].saetze[0].pause, 75)
        let gesendet = a.daten.training.laufende()?.laeufe.first?.stand
        XCTAssertEqual(gesendet?.first?.pause, 75, "die Zeilen gehen schon beim Start raus")
        XCTAssertEqual(a.sitzung.laufenderSatz(0), 1)
    }

    func testEinTippInDerPauseStartetDenNaechstenSatz() throws {
        let a = try aufbau()
        a.sitzung.haken(0, 0)
        a.uhr.vor(sekunden: 60)
        a.sitzung.naechsterSatzStarten()
        XCTAssertNil(a.sitzung.pause, "die Pause ist zu Ende")
        XCTAssertEqual(a.sitzung.liste[0].saetze[0].pause, 60)
        XCTAssertEqual(a.sitzung.laufenderSatz(0), 1, "der nächste Satz läuft")
    }

    func testStartenAuchOhnePauseSendetDieZeilen() throws {
        let a = try aufbau()
        a.sitzung.satzStarten(1, 0)
        let lauf = a.daten.training.laufende()?.laeufe.first { $0.plan == "b" }
        XCTAssertEqual(lauf?.stand?.count, 2, "so beginnt die Übung für Partner und Figur")
    }

    func testVerschobeneZeilenBeendenDenLauf() throws {
        let a = try aufbau()
        let aktionen: [() -> Void] = [
            { a.sitzung.satzLoeschen(0, 2) },
            { a.sitzung.satzKopieren(0, 1) },
            { a.sitzung.aufwaermen(0, arbeit: 60) },
            { a.sitzung.auslassen(0) },
        ]
        for aktion in aktionen {
            a.sitzung.satzStarten(0, 0)
            XCTAssertNotNil(a.sitzung.laufenderSatz(0))
            aktion()
            XCTAssertNil(a.sitzung.satzLauf)
        }
    }

    func testEineAndereUebungBeendetDenLaufNicht() throws {
        let a = try aufbau()
        a.sitzung.satzStarten(0, 0)
        a.sitzung.satzLoeschen(1, 1)
        XCTAssertEqual(a.sitzung.laufenderSatz(0), 0)
    }

    func testOhneStartBleibtAllesWieImLumenAufbau() throws {
        let a = try aufbau()
        a.sitzung.haken(0, 0)
        a.uhr.vor(sekunden: 100)
        a.sitzung.haken(0, 1)
        XCTAssertNil(a.sitzung.satzLauf)
        XCTAssertEqual(a.sitzung.satzStartZaehler, 0)
        XCTAssertEqual(a.sitzung.liste[0].saetze[1].sek, 10, "ohne Start misst die Satz-Uhr weiter ab dem Ende der Pause (90 s Ziel, 100 s vergangen)")
    }

    func testDerLaufUeberstehtEinenNeustart() throws {
        let a = try aufbau()
        a.sitzung.satzStarten(1, 1)
        let neu = GymSitzung(umgebung: a.umgebung, puls: GymFakePuls())
        neu.ladeWennNoetig()
        XCTAssertEqual(neu.laufenderSatz(1), 1)
    }

    func testBeendenRaeumtDenLaufAuf() async throws {
        let a = try aufbau()
        a.sitzung.satzStarten(0, 0)
        a.sitzung.beende()
        await a.sitzung.endeAufgabe?.value
        XCTAssertNil(a.sitzung.satzLauf)
        let neu = GymSitzung(umgebung: a.umgebung, puls: GymFakePuls())
        neu.ladeWennNoetig()
        XCTAssertNil(neu.satzLauf)
    }
}
