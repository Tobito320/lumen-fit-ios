import XCTest
@testable import LumenFit

@MainActor
final class ProfilLoeschenTests: XCTestCase {
    func testFalschesPasswortLoeschtNichts() throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        XCTAssertFalse(ProfilLoeschen.fuehreAus(u, passwort: "falsch"))
        XCTAssertTrue(u.profil.hatProfil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: daten.ordner.path))
    }

    func testRichtigesPasswortLoeschtProfilUndOrdner() throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let ordner = daten.ordner
        XCTAssertTrue(ProfilLoeschen.fuehreAus(u, passwort: "abcd"))
        XCTAssertFalse(u.profil.hatProfil, "danach erscheint das Onboarding wieder")
        XCTAssertNil(u.daten)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.path))
    }

    func testEinAnderesProfilBleibt() throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner(), name: "Eins")
        let erstes = daten.profil
        try u.profil.anlegen(name: "Zwei", passwort: "efgh")
        let zweites = try XCTUnwrap(u.profil.aktiv).id
        XCTAssertTrue(ProfilLoeschen.fuehreAus(u, passwort: "efgh"))
        XCTAssertEqual(u.profil.aktiv?.id, erstes, "das übrige Profil wird aktiv")
        XCTAssertFalse(FileManager.default.fileExists(atPath: u.profilOrdner(zweites).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: u.profilOrdner(erstes).path))
    }

    func testDieListeNenntWasGespeichertWar() throws {
        let (_, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let texte = ProfilLoeschen.liste(daten).map(\.text)
        XCTAssertEqual(texte.first, "1 Training")
        XCTAssertTrue(texte.contains("1 Tag im Essenstagebuch"))
        XCTAssertTrue(texte.contains("0 Meilensteine"))
    }

    func testPasswortAendernUndWechselnBrauchenDasRichtigePasswort() throws {
        let (u, _) = try ProfilTestWelt.gefuellt(ordner: tempOrdner(), name: "Eins")
        let erstes = try XCTUnwrap(u.profil.aktiv).id
        XCTAssertFalse(u.profil.aenderePasswort(alt: "falsch", neu: "neuespw"))
        XCTAssertTrue(u.profil.aenderePasswort(alt: "abcd", neu: "neuespw"))
        try u.profil.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertFalse(u.profil.wechsle(zu: erstes, passwort: "abcd"), "das alte Passwort gilt nicht mehr")
        XCTAssertTrue(u.profil.wechsle(zu: erstes, passwort: "neuespw"))
        XCTAssertEqual(u.profil.aktiv?.name, "Eins")
        u.profil.aendereName("Eins neu", sperreTage: 7)
        XCTAssertEqual(u.profil.aktiv?.name, "Eins neu")
    }
}
