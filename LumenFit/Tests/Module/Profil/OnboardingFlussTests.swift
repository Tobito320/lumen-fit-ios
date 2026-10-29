import XCTest
@testable import LumenFit

@MainActor
final class OnboardingFlussTests: XCTestCase {
    private func bisZurHealthKarte(_ f: ProfilOnboardingFluss, name: String = "Mira", passwort: String = "abcd") {
        f.weiter()
        f.name = name
        f.passwort = passwort
        f.weiter()
        f.weiter()
    }

    func testVierKartenInFesterReihenfolge() {
        let f = ProfilOnboardingFluss()
        XCTAssertEqual(f.anzahl, 4)
        XCTAssertEqual(f.karte, .willkommen)
        XCTAssertEqual(f.stand, "Schritt 1 von 4")
        f.weiter()
        XCTAssertEqual(f.karte, .profil)
        XCTAssertEqual(f.stand, "Schritt 2 von 4")
        f.name = "Mira"
        f.passwort = "abcd"
        f.weiter(); f.weiter()
        XCTAssertEqual(f.karte, .health)
        XCTAssertTrue(f.istLetzte)
        f.weiter()
        XCTAssertEqual(f.karte, .health, "nach der letzten Karte geht es nicht weiter")
        f.zurueck()
        XCTAssertEqual(f.karte, .ziel)
    }

    func testNameUndPasswortSindPflichtAufDerZweitenKarte() {
        let f = ProfilOnboardingFluss()
        f.weiter()
        XCTAssertFalse(f.kannWeiter)
        f.name = "   "
        f.passwort = "abcd"
        XCTAssertFalse(f.kannWeiter, "ein Name nur aus Leerzeichen zählt nicht")
        f.name = "Mira"
        f.passwort = "abc"
        XCTAssertFalse(f.kannWeiter)
        XCTAssertNotNil(f.passwortHinweis)
        f.passwort = "abcd"
        XCTAssertTrue(f.kannWeiter)
        XCTAssertNil(f.passwortHinweis)
        f.weiter()
        XCTAssertEqual(f.karte, .ziel)
    }

    func testDasProfilEntstehtErstAmEnde() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        XCTAssertFalse(u.profil.hatProfil, "bis zur letzten Karte gibt es kein Profil, sonst wechselte die Wurzel zu den Tabs")
        XCTAssertTrue(f.abschliessen(in: u))
        XCTAssertTrue(u.profil.hatProfil)
        XCTAssertEqual(u.profil.aktiv?.name, "Mira")
        XCTAssertEqual(f.passwort, "", "das Passwort bleibt nicht im Speicher")
    }

    func testNachDemNeustartKeinePasswortEingabe() throws {
        let bund = SpeicherSchluesselbund()
        let ordner = try tempOrdner()
        let erste = ProfilTestWelt.umgebung(ordner: ordner, bund: bund)
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f, name: "Mira")
        XCTAssertTrue(f.abschliessen(in: erste))

        // Neustart: frische Umgebung, gleicher Schlüsselbund, gleiche Dateien. Das Profil ist aktiv, ohne dass jemand ein Passwort nennt.
        let neu = ProfilTestWelt.umgebung(ordner: ordner, bund: bund)
        XCTAssertTrue(neu.profil.hatProfil)
        XCTAssertEqual(neu.profil.aktiv?.name, "Mira")
        XCTAssertFalse(neu.neuinstallationErkannt)
        XCTAssertNotNil(neu.daten)
    }

    func testZielUndGymTageLandenInDenStores() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        f.art = .abnehmen
        f.gymTage = 4
        XCTAssertTrue(f.abschliessen(in: u))
        let daten = try XCTUnwrap(u.daten)
        XCTAssertEqual(daten.ziele.ziele.art, .abnehmen)
        XCTAssertEqual(daten.ziele.ziele.gymTageProWoche, 4)
        XCTAssertEqual(daten.essen.ernaehrungsZiele.richtung, 0)
        XCTAssertTrue(daten.essen.ernaehrungsZiele.eingerichtet)
        XCTAssertEqual(daten.essen.ernaehrungsZiele.kcal, daten.ziele.ziele.kalorien, "beide Orte sagen dasselbe")
    }

    func testHealthOhneZwang() async throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        XCTAssertTrue(f.abschliessen(in: u), "auch ohne Health-Frage legt der Fluss das Profil an")
        XCTAssertEqual(u.daten?.einstellungen.werte.healthGefragt, false)

        let v = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let g = ProfilOnboardingFluss()
        bisZurHealthKarte(g)
        await g.healthFragen(leser: FakeHealthLeser())
        XCTAssertTrue(g.healthAngefragt)
        XCTAssertTrue(g.abschliessen(in: v))
        XCTAssertEqual(v.daten?.einstellungen.werte.healthGefragt, true)
    }

    func testZuKurzesPasswortLegtNichtsAnUndSpringtZurueck() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        f.passwort = "ab"
        XCTAssertFalse(f.abschliessen(in: u))
        XCTAssertFalse(u.profil.hatProfil)
        XCTAssertEqual(f.karte, .profil)
        XCTAssertEqual(f.fehler, "Das Passwort braucht mindestens 4 Zeichen.")
        f.passwort = "abcd"
        f.name = ""
        XCTAssertFalse(f.abschliessen(in: u))
        XCTAssertEqual(f.fehler, "Wie soll Lumi dich nennen?")
    }
}
