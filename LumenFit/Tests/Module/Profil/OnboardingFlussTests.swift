import XCTest
@testable import LumenFit

@MainActor
final class OnboardingFlussTests: XCTestCase {
    /// Willkommen, Name, keine Einladung, Erfahrung, Rest der Fragen übersprungen, Nutzung, Health: steht dann auf "Dein Plan steht".
    private func bisZumPlan(_ f: ProfilOnboardingFluss, name: String = "Mira") {
        f.weiter()
        f.name = name
        f.weiter()
        f.weiter()
        f.waehleErfahrung(.unterSechsMonate)
        f.ueberspringe()
        f.antworteNutzung(.nein)   // die Frage nach der Nutzungsmeldung steht vor Health
        f.weiter()
    }

    func testKartenInFesterReihenfolge() {
        let f = ProfilOnboardingFluss()
        XCTAssertEqual(f.karten, ProfilOnboardingFluss.Karte.allCases)
        XCTAssertEqual(f.anzahl, 13)
        XCTAssertEqual(f.karte, .willkommen)
        XCTAssertEqual(f.stand, "Schritt 1 von 13")
        f.weiter()
        XCTAssertEqual(f.karte, .profil)
        f.name = "Mira"
        f.weiter()
        XCTAssertEqual(f.karte, .einladung)
        f.weiter()
        XCTAssertEqual(f.karte, .erfahrung)
        XCTAssertFalse(f.kannWeiter, "Frage 1 braucht eine Antwort")
        f.waehleErfahrung(.laenger)
        XCTAssertEqual(f.karte, .ziele, "ein Tipp auf die Einfachauswahl geht weiter")
        for erwartet in [ProfilOnboardingFluss.Karte.orte, .tage, .minuten, .fokus, .mitzaehlen, .nutzung] {
            f.weiter()
            XCTAssertEqual(f.karte, erwartet)
        }
        XCTAssertFalse(f.kannWeiter, "ohne Antwort geht es nicht weiter, vorgewählt ist nichts")
        f.weiter()
        XCTAssertEqual(f.karte, .nutzung)
        f.antworteNutzung(.ja)
        XCTAssertEqual(f.karte, .health)
        f.weiter()
        XCTAssertEqual(f.karte, .plan)
        XCTAssertTrue(f.istLetzte)
        f.weiter()
        XCTAssertEqual(f.karte, .plan, "nach der letzten Karte geht es nicht weiter")
        f.zurueck()
        XCTAssertEqual(f.karte, .health)
    }

    func testUeberspringenGehtNurAufFragenUndLandetBeiDerNutzungsfrage() {
        let f = ProfilOnboardingFluss()
        f.ueberspringe()
        XCTAssertEqual(f.karte, .willkommen, "Willkommen ist keine Frage")
        f.weiter(); f.name = "Mira"; f.weiter(); f.weiter()
        f.wahl.trainingsErfahrung = .bisZweiJahre
        f.weiter()
        XCTAssertEqual(f.karte, .ziele)
        f.ueberspringe()
        XCTAssertEqual(f.karte, .nutzung)
    }

    func testVorschlagSetztDieEmpfehlungUndGehtWeiter() {
        let f = ProfilOnboardingFluss()
        f.weiter(); f.name = "Mira"; f.weiter(); f.weiter(); f.waehleErfahrung(.geradeAngefangen)
        XCTAssertTrue(f.hatVorschlag)
        f.nimmVorschlag()
        XCTAssertEqual(f.wahl.trainingsZiele, [.muskeln])
        XCTAssertEqual(f.karte, .orte)
        f.nimmVorschlag()
        XCTAssertEqual(f.wahl.trainingsOrte, [.studio])
        f.gymTage = 6
        f.nimmVorschlag()
        XCTAssertEqual(f.gymTage, 3)
        f.nimmVorschlag()
        XCTAssertEqual(f.wahl.trainingsMinuten, 60)
        XCTAssertEqual(f.karte, .fokus)
        XCTAssertFalse(f.hatVorschlag)
    }

    func testEinladungNurMitGueltigemCode() {
        let f = ProfilOnboardingFluss()
        f.weiter(); f.name = "Mira"; f.weiter()
        XCTAssertEqual(f.karte, .einladung)
        XCTAssertTrue(f.kannWeiter, "niemand hat eingeladen: leer geht")
        XCTAssertNil(f.einladungZumEinloesen)
        f.einladung = "abc"
        XCTAssertFalse(f.kannWeiter)
        f.einladung = "k7q2-9fx"
        XCTAssertTrue(f.kannWeiter)
        XCTAssertEqual(f.einladungZumEinloesen, "K7Q29FX", "Groß/Klein und Bindestrich sind egal")
    }

    func testAntwortAufDieNutzungsFrageLandetImProfilUndHealthHaengtNichtDaran() async throws {
        for antwort in [NutzungAntwort.ja, .nein] {
            let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
            let f = ProfilOnboardingFluss()
            f.weiter(); f.name = "Mira"; f.weiter(); f.weiter(); f.waehleErfahrung(.laenger); f.ueberspringe()
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
        XCTAssertEqual(f.karte, .einladung)
    }

    func testDasProfilEntstehtErstAmEndeUndOhnePasswort() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZumPlan(f)
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
        bisZumPlan(f, name: "Mira")
        XCTAssertTrue(f.abschliessen(in: erste))

        // Neustart: frische Umgebung, gleicher Schlüsselbund, gleiche Dateien. Das Profil ist aktiv, ohne dass jemand ein Passwort nennt.
        let neu = ProfilTestWelt.umgebung(ordner: ordner, bund: bund)
        XCTAssertTrue(neu.profil.hatProfil)
        XCTAssertEqual(neu.profil.aktiv?.name, "Mira")
        XCTAssertEqual(neu.profil.aktiv?.ohnePasswort, true, "das Profil ohne Passwort übersteht den Neustart")
        XCTAssertFalse(neu.neuinstallationErkannt)
        XCTAssertNotNil(neu.daten)
    }

    func testZieleUndGymTageLandenInDenStores() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZumPlan(f)
        f.wahl.trainingsZiele = [.muskeln, .abnehmen]
        f.gymTage = 4
        XCTAssertEqual(f.art, .abnehmen, "Abnehmen gewinnt")
        XCTAssertTrue(f.abschliessen(in: u))
        let daten = try XCTUnwrap(u.daten)
        XCTAssertEqual(daten.ziele.ziele.art, .abnehmen)
        XCTAssertEqual(daten.ziele.ziele.gymTageProWoche, 4)
        XCTAssertEqual(daten.essen.ernaehrungsZiele.richtung, 0)
        XCTAssertTrue(daten.essen.ernaehrungsZiele.eingerichtet)
        XCTAssertEqual(daten.essen.ernaehrungsZiele.kcal, daten.ziele.ziele.kalorien, "beide Orte sagen dasselbe")
    }

    func testAntwortenLandenInDenEinstellungen() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZumPlan(f)
        f.wahl.trainingsOrte = [.zuhause, .calisthenics]
        f.wahl.fokusMuskeln = ["brust"]
        f.wahl.creatinMitzaehlen = true
        f.wahl.schritteMitzaehlen = false
        XCTAssertTrue(f.abschliessen(in: u))
        let e = try XCTUnwrap(u.daten?.einstellungen.werte)
        XCTAssertEqual(e.trainingsErfahrung, .unterSechsMonate)
        XCTAssertEqual(e.trainingsOrte, [.zuhause, .calisthenics])
        XCTAssertEqual(e.trainingsMinuten, 60, "übersprungen: der Standard")
        XCTAssertEqual(e.fokusMuskeln, ["brust"])
        XCTAssertTrue(e.creatinMitzaehlen)
        XCTAssertFalse(e.schritteMitzaehlen)
        XCTAssertTrue(e.gewichtMitzaehlen)
    }

    func testGewaehlteBereicheLandenInDenEinstellungenUndMindestensEinerBleibt() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        XCTAssertTrue(f.wahl.gymAn && f.wahl.essenAn && f.wahl.schlafAn, "Standard: alles")
        XCTAssertTrue(f.setzeBereich(.schlaf, an: false))
        XCTAssertTrue(f.setzeBereich(.essen, an: false))
        XCTAssertFalse(f.setzeBereich(.gym, an: false), "der letzte bleibt an")
        bisZumPlan(f)
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

    func testPlanAusDenAntwortenWirdNurMitLosGehtsUebernommen() throws {
        let ohne = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZumPlan(f)
        let plan = try XCTUnwrap(f.plan, "der Plan steht beim Betreten der letzten Karte")
        XCTAssertTrue(f.abschliessen(in: ohne, planUebernehmen: false))
        XCTAssertEqual(ohne.daten?.training.plan.tage.isEmpty, true, "Anderen Plan wählen: kein Plan gespeichert")

        let mit = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let g = ProfilOnboardingFluss()
        bisZumPlan(g)
        XCTAssertTrue(g.abschliessen(in: mit, planUebernehmen: true))
        XCTAssertEqual(mit.daten?.training.plan.splitName, plan.name)
        XCTAssertEqual(mit.daten?.training.plan.tage.count, plan.einheiten.count)
    }

    func testNochmalNurFragenUndPlanOhneNeuesProfil() throws {
        let (u, daten) = try ProfilTestWelt.gefuellt(ordner: try tempOrdner())
        var start = daten.einstellungen.werte
        start.trainingsErfahrung = .laenger
        let f = ProfilOnboardingFluss(nochmal: true, start: start, gymTage: 5)
        XCTAssertEqual(f.karte, .erfahrung)
        XCTAssertEqual(f.anzahl, 8, "sieben Fragen und der Plan")
        XCTAssertFalse(f.karten.contains(.profil) || f.karten.contains(.nutzung) || f.karten.contains(.health))
        XCTAssertTrue(f.kannWeiter, "die alte Antwort steht schon da")
        f.wahl.trainingsZiele = [.staerker]
        f.ueberspringe()
        XCTAssertEqual(f.karte, .plan)
        f.sichereNochmal(in: u)
        XCTAssertEqual(u.profil.profile.count, 1, "kein neues Profil")
        XCTAssertEqual(daten.einstellungen.werte.trainingsZiele, [.staerker])
        XCTAssertEqual(daten.einstellungen.werte.trainingsErfahrung, .laenger)
        XCTAssertEqual(daten.ziele.ziele.gymTageProWoche, 5)
    }

    func testHealthOhneZwang() async throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZumPlan(f)
        XCTAssertTrue(f.abschliessen(in: u), "auch ohne Health-Frage legt der Fluss das Profil an")
        XCTAssertEqual(u.daten?.einstellungen.werte.healthGefragt, false)

        let v = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let g = ProfilOnboardingFluss()
        bisZumPlan(g)
        await g.healthFragen(leser: FakeHealthLeser())
        XCTAssertTrue(g.healthAngefragt)
        XCTAssertTrue(g.abschliessen(in: v))
        XCTAssertEqual(v.daten?.einstellungen.werte.healthGefragt, true)
    }

    func testLeererNameLegtNichtsAnUndSpringtZurueck() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let f = ProfilOnboardingFluss()
        bisZumPlan(f)
        f.name = ""
        XCTAssertFalse(f.abschliessen(in: u))
        XCTAssertFalse(u.profil.hatProfil)
        XCTAssertEqual(f.karte, .profil)
        XCTAssertEqual(f.fehler, "Wie soll Lumi dich nennen?")
    }
}
