import XCTest
@testable import LumenFit

/// Flugmodus: jeder Server-Aufruf scheitert mit "kein Netz". Training starten, Sätze eintragen, Plan lesen und Beenden gehen trotzdem ganz,
/// alles liegt lokal; die Server-Wege (Konto, Postfach, Partner) brechen still ab (Wunsch vom 09.11.2026: "It should easily work with no WiFi").
@MainActor
final class FlugmodusTests: XCTestCase {
    func testTrainingLaeuftOhneNetzKomplettDurch() async throws {
        let lader = SkriptLader.fehler(.notConnectedToInternet)
        let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")
        let uhr = TestUhr()
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: lader, mitteiler: StilleMitteilung(),
                            leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr,
                            passwortRunden: 1_000, kontoZugang: zugang)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "")
        let daten = try XCTUnwrap(u.daten)
        daten.training.planSichern(GymTestAufbau.plan())
        // Der Start der App ohne Netz: Konto anmelden und Postfach holen scheitern, nichts bleibt hängen.
        await u.konto.aktualisiere(profilName: "Beispiel", erzwingen: true)
        await u.konto.postfachAbgleichen(training: daten.training)
        XCTAssertGreaterThan(lader.aufrufe, 0, "der Server wurde versucht")

        let sitzung = GymSitzung(umgebung: u)
        sitzung.starte(planTag: "push")
        sitzung.haken(0, 0)
        sitzung.gewicht(0, 1, richtung: 1)
        sitzung.entwurfSenden()
        uhr.vor(sekunden: 1800)
        sitzung.beende()
        await sitzung.endeAufgabe?.value

        let fertig = try XCTUnwrap(daten.training.sessions.first)
        XCTAssertNotNil(fertig.ende)
        XCTAssertEqual(fertig.laeufe.first?.stand?[0].ok, true)
        XCTAssertNotNil(fertig.laeufe.first?.stand?[1].kg)
        XCTAssertEqual(daten.training.plan.tage.first?.id, "push", "der Plan liegt lokal")
        // Alles steht auf der Platte: eine frische Umgebung über demselben Ordner liest es ohne Netz wieder.
        let neu = DatenSatz(profil: daten.profil, ordner: daten.ordner, ereignisse: EreignisKanal(), uhr: uhr.uhr)
        XCTAssertEqual(neu.training.sessions.count, 1)
        XCTAssertNotNil(neu.training.sessions.first?.ende)
    }
}
