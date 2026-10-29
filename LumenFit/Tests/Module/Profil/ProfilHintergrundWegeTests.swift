import XCTest
@testable import LumenFit

/// Die Wege, die die Oberfläche wirklich geht (Passwort wird abseits des Hauptthreads gerechnet): gleiche Ergebnisse wie die synchronen.
@MainActor
final class ProfilHintergrundWegeTests: XCTestCase {
    func testFalschesPasswortLoeschtImHintergrundNichts() async throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let ok = await ProfilLoeschen.fuehreAusImHintergrund(u, passwort: "falsch")
        XCTAssertFalse(ok)
        XCTAssertTrue(u.profil.hatProfil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: daten.ordner.path))
    }

    func testRichtigesPasswortLoeschtImHintergrundProfilUndOrdner() async throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let ordner = daten.ordner
        let ok = await ProfilLoeschen.fuehreAusImHintergrund(u, passwort: "abcd")
        XCTAssertTrue(ok)
        XCTAssertFalse(u.profil.hatProfil)
        XCTAssertNil(u.daten)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.path))
    }

    private func bisZurHealthKarte(_ f: ProfilOnboardingFluss, name: String = "Mira", passwort: String = "abcd") {
        f.weiter()
        f.name = name
        f.passwort = passwort
        f.weiter()
        f.weiter()
    }

    func testOnboardingLegtImHintergrundDasProfilAnUndLeertDasPasswort() async throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        let ok = await f.abschliessenImHintergrund(in: u)
        XCTAssertTrue(ok)
        XCTAssertEqual(u.profil.aktiv?.name, "Mira")
        XCTAssertTrue(u.profil.pruefe(passwort: "abcd", fuer: try XCTUnwrap(u.profil.aktiv).id))
        XCTAssertEqual(f.passwort, "")
    }

    func testOnboardingImHintergrundMeldetNameUndZuKurzesPasswort() async throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        f.passwort = "ab"
        let kurz = await f.abschliessenImHintergrund(in: u)
        XCTAssertFalse(kurz)
        XCTAssertFalse(u.profil.hatProfil)
        XCTAssertEqual(f.karte, .profil)
        XCTAssertEqual(f.fehler, "Das Passwort braucht mindestens 4 Zeichen.")
        f.passwort = "abcd"
        f.name = ""
        let leer = await f.abschliessenImHintergrund(in: u)
        XCTAssertFalse(leer)
        XCTAssertEqual(f.fehler, "Wie soll Lumi dich nennen?")
        XCTAssertEqual(f.karte, .profil)
    }
}
