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

    private func bisZurHealthKarte(_ f: ProfilOnboardingFluss, name: String = "Mira") {
        f.weiter()
        f.name = name
        f.weiter()
        f.weiter()
        f.weiter()
    }

    func testOnboardingLegtImHintergrundDasProfilOhnePasswortAn() async throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        let ok = await f.abschliessenImHintergrund(in: u)
        XCTAssertTrue(ok)
        XCTAssertEqual(u.profil.aktiv?.name, "Mira")
        XCTAssertEqual(u.profil.aktiv?.ohnePasswort, true)
    }

    func testOnboardingImHintergrundMeldetDenLeerenNamen() async throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        f.name = ""
        let leer = await f.abschliessenImHintergrund(in: u)
        XCTAssertFalse(leer)
        XCTAssertFalse(u.profil.hatProfil)
        XCTAssertEqual(f.fehler, "Wie soll Lumi dich nennen?")
        XCTAssertEqual(f.karte, .profil)
    }
}
