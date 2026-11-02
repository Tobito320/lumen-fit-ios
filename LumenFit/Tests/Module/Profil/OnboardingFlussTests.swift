import XCTest
@testable import LumenFit

@MainActor
final class OnboardingFlussTests: XCTestCase {
    private func bisZurHealthKarte(_ f: ProfilOnboardingFluss, name: String = "Mira") {
        f.weiter()
        f.name = name
        f.weiter()
        f.weiter()
        f.weiter()
        f.antworteNutzung(.nein)   // die Frage nach der Nutzungsmeldung steht vor Health
    }

    func testSechsKartenInFesterReihenfolge() {
        let f = ProfilOnboardingFluss()
        XCTAssertEqual(f.anzahl, 6)
        XCTAssertEqual(f.karte, .willkommen)
        XCTAssertEqual(f.stand, "Schritt 1 von 6")
        f.weiter()
        XCTAssertEqual(f.karte, .profil)
        XCTAssertEqual(f.stand, "Schritt 2 von 6")
        f.name = "Mira"
        f.weiter()
        XCTAssertEqual(f.karte, .bereiche)
        f.weiter(); f.weiter()
        XCTAssertEqual(f.karte, .nutzung)
        XCTAssertFalse(f.kannWeiter, "ohne Antwort geht es nicht weiter, vorgewählt ist nichts")
        f.weiter()
        XCTAssertEqual(f.karte, .nutzung)
        f.antworteNutzung(.ja)
        XCTAssertEqual(f.karte, .health)
        XCTAssertTrue(f.istLetzte)
        f.weiter()
        XCTAssertEqual(f.karte, .health, "nach der letzten Karte geht es nicht weiter")
        f.zurueck()
        XCTAssertEqual(f.karte, .nutzung)
    }

    func testAntwortAufDieNutzungsFrageLandetImProfilUndHealthHaengtNichtDaran() async throws {
        for antwort in [NutzungAntwort.ja, .nein] {
            let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
            let f = ProfilOnboardingFluss()
            f.weiter(); f.name = "Mira"; f.weiter(); f.weiter(); f.weiter()
            f.antworteNutzung(antwort)
            await f.healthFragen(leser: u.healthLeser)
            XCTAssertTrue(f.abschliessen(in: u))
            let e = try XCTUnwrap(u.daten?.einstellungen.werte)
            XCTAssertEqual(e.nutzungAntwort, antwort)
            XCTAssertEqual(e.nutzungErlaubt, antwort == .ja)
            XCTAssertEqual(e.nutzungJaSeit != nil, antwort == .ja, "den Tag des Ja merkt sich nur ein Ja")
            XCTAssertTrue(e.healthGefragt, "Health wird bei Ja und bei Nein gleich gefragt")
        }
    }

    func testNurDerNameIstPflichtAufDerZweitenKarte() {
        let f = ProfilOnboardingFluss()
        f.weiter()
        XCTAssertFalse(f.kannWeiter)
        f.name = "   "
        XCTAssertFalse(f.kannWeiter, "ein Name nur aus Leerzeichen zählt nicht")
        f.name = "Mira"
        XCTAssertTrue(f.kannWeiter, "kein Passwort nötig")
        f.weiter()
        XCTAssertEqual(f.karte, .bereiche)
    }

    func testDasProfilEntstehtErstAmEndeUndOhnePasswort() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        XCTAssertFalse(u.profil.hatProfil, "bis zur letzten Karte gibt es kein Profil, sonst wechselte die Wurzel zu den Tabs")
        XCTAssertTrue(f.abschliessen(in: u))
        XCTAssertTrue(u.profil.hatProfil)
        XCTAssertEqual(u.profil.aktiv?.name, "Mira")
        XCTAssertEqual(u.profil.aktiv?.ohnePasswort, true)
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
        XCTAssertEqual(neu.profil.aktiv?.ohnePasswort, true, "das Profil ohne Passwort übersteht den Neustart")
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

    func testGewaehlteBereicheLandenInDenEinstellungenUndMindestensEinerBleibt() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        XCTAssertTrue(f.bereiche.gymAn && f.bereiche.essenAn && f.bereiche.schlafAn, "Standard: alles")
        XCTAssertTrue(f.setzeBereich(.schlaf, an: false))
        XCTAssertTrue(f.setzeBereich(.essen, an: false))
        XCTAssertFalse(f.setzeBereich(.gym, an: false), "der letzte bleibt an")
        bisZurHealthKarte(f)
        XCTAssertTrue(f.abschliessen(in: u))
        let e = try XCTUnwrap(u.daten?.einstellungen.werte)
        XCTAssertTrue(e.gymAn)
        XCTAssertFalse(e.essenAn || e.schlafAn)
    }

    func testStartRouteNurMitGym() {
        let f = ProfilOnboardingFluss()
        XCTAssertEqual(f.startRoute, .gym(.plaene), "mit Gym direkt zu den Plänen")
        f.setzeBereich(.gym, an: false)
        XCTAssertNil(f.startRoute)
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

    func testLeererNameLegtNichtsAnUndSpringtZurueck() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZurHealthKarte(f)
        f.name = ""
        XCTAssertFalse(f.abschliessen(in: u))
        XCTAssertFalse(u.profil.hatProfil)
        XCTAssertEqual(f.karte, .profil)
        XCTAssertEqual(f.fehler, "Wie soll Lumi dich nennen?")
    }
}
