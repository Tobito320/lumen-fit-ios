import XCTest
@testable import LumenFit

@MainActor
final class WillkommenZurueckTests: XCTestCase {
    /// Schlüsselbund-Profil da, Profilordner fehlt: eine frische Installation mit altem Schlüsselbund.
    private func neuinstallation() throws -> (alt: AppUmgebung, neu: AppUmgebung, bund: SpeicherSchluesselbund) {
        let bund = SpeicherSchluesselbund()
        let alt = ProfilTestWelt.umgebung(ordner: try tempOrdner(), bund: bund)
        try alt.profil.anlegen(name: "Mira", passwort: "abcd")
        _ = alt.daten
        let neu = ProfilTestWelt.umgebung(ordner: try tempOrdner(), bund: bund)
        return (alt, neu, bund)
    }

    func testKarteErscheintWennDasProfilDaIstUndDieDatenFehlen() throws {
        let (_, neu, _) = try neuinstallation()
        XCTAssertTrue(neu.profil.hatProfil)
        XCTAssertTrue(neu.neuinstallationErkannt)
        XCTAssertNil(neu.router.pfade[.profil])
        ProfilModul.start(neu)
        XCTAssertEqual(neu.router.pfade[.profil], [.profil(.datensicherung)], "die Datensicherung öffnet von selbst, dort steht die Willkommen-zurück-Karte")
    }

    func testNormalerStartOeffnetNichts() throws {
        let bund = SpeicherSchluesselbund()
        let ordner = try tempOrdner()
        let erste = ProfilTestWelt.umgebung(ordner: ordner, bund: bund)
        try erste.profil.anlegen(name: "Mira", passwort: "abcd")
        _ = erste.daten
        let zweite = ProfilTestWelt.umgebung(ordner: ordner, bund: bund)
        XCTAssertFalse(zweite.neuinstallationErkannt)
        ProfilModul.start(zweite)
        XCTAssertNil(zweite.router.pfade[.profil])

        let leer = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        ProfilModul.start(leer)
        XCTAssertNil(leer.router.pfade[.profil], "ohne Profil zeigt die Wurzel das Onboarding, keine Seite")
    }

    func testStartIstIdempotentUndStoertKeinOffenesBlatt() throws {
        let (_, neu, _) = try neuinstallation()
        ProfilModul.start(neu)
        ProfilModul.start(neu)
        XCTAssertEqual(neu.router.pfade[.profil], [.profil(.datensicherung)], "zweimal gestartet, einmal geöffnet")
        neu.router.pfade[.profil] = [.profil(.aussehen)]
        ProfilModul.oeffneWillkommenZurueck(neu)
        XCTAssertEqual(neu.router.pfade[.profil], [.profil(.aussehen)], "eine schon offene Profil-Seite bleibt")
    }

    func testBeantwortetIstDieKarteWeg() throws {
        let (_, neu, _) = try neuinstallation()
        neu.neuinstallationQuittieren()
        ProfilModul.oeffneWillkommenZurueck(neu)
        XCTAssertNil(neu.router.pfade[.profil])
    }

    func testSicherungEinspielenBeantwortetDieKarteUndBringtDieDatenZurueck() throws {
        let (_, neu, _) = try neuinstallation()
        let daten = try XCTUnwrap(neu.daten)
        XCTAssertEqual(daten.training.sessions.count, 0)
        let sicherung = try ProfilSicherung.lies(FixtureOrt.daten("Profil", "sicherung-beispiel.json"))
        ProfilSicherungLogik.spieleEin(sicherung, in: daten)
        neu.neuinstallationQuittieren()
        XCTAssertEqual(daten.training.sessions.count, 1)
        XCTAssertFalse(neu.neuinstallationErkannt)
    }
}
