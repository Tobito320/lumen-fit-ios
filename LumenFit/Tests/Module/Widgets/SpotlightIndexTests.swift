import XCTest
@testable import LumenFit

/// Spotlight: Einträge für Übungen, Plan-Tage und Favoriten (rein), jede Kennung ist der Link der Seite; die Pflege schreibt nur bei Änderung.
@MainActor
final class SpotlightIndexTests: XCTestCase {
    private let bank = Uebung(id: "u-bank", name: "Bankdrücken", en: "Bench Press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
    private let rudern = Uebung(id: "u-rudern", name: "Rudern am Kabel", en: "Cable Row", muskel: "Rücken", koerper: "Rücken", geraet: "Kabelzug", neben: [])

    private func plan() -> TrainingsPlan {
        TrainingsPlan(tage: [TrainingsTag(id: "push", name: "Push", wochentage: [1, 3, 5], uebungen: []),
                             TrainingsTag(id: "pull", name: "Pull", wochentage: [2, 6], uebungen: [])])
    }

    // MARK: - Einträge (rein)

    func testUebungOeffnetDieUebungSeite() throws {
        let eintraege = SpotlightIndex.uebungen([bank, rudern])
        XCTAssertEqual(eintraege.count, 2)
        XCTAssertEqual(eintraege[0].titel, "Bankdrücken")
        XCTAssertEqual(eintraege[0].kennung, "lumenfit://uebung?id=u-bank")
        XCTAssertEqual(RouteURL.route(ausSpotlightKennung: eintraege[0].kennung), .uebung(id: "u-bank"))
        XCTAssertTrue(eintraege[0].stichworte.contains("Bench Press"), "auch der englische Name ist suchbar")
        XCTAssertEqual(eintraege[0].beschreibung, "Übung · Brust · Langhantel")
    }

    func testDoppelteUebungenWerdenZusammengelegt() {
        XCTAssertEqual(SpotlightIndex.uebungen([bank, bank, rudern]).count, 2)
    }

    func testPlanTageHabenEigeneKennungenUndOeffnenDiePlaene() {
        let eintraege = SpotlightIndex.plaene(plan())
        XCTAssertEqual(eintraege.map(\.titel), ["Push", "Pull"])
        XCTAssertEqual(Set(eintraege.map(\.kennung)).count, 2, "jede Kennung ist einmalig")
        for e in eintraege { XCTAssertEqual(RouteURL.route(ausSpotlightKennung: e.kennung), .gym(.plaene), e.kennung) }
        XCTAssertEqual(eintraege[0].beschreibung, "Trainingstag · Mo, Mi, Fr · 0 Übungen")
    }

    func testFavoritenOeffnenDieFavoritenSeite() {
        let eintraege = SpotlightIndex.favoriten([TestDaten.haferflocken])
        XCTAssertEqual(eintraege.map(\.titel), ["Beispiel-Haferflocken"])
        XCTAssertEqual(RouteURL.route(ausSpotlightKennung: eintraege[0].kennung), .essen(.favoriten))
        XCTAssertTrue(eintraege[0].kennung.hasPrefix("lumenfit://essen"))
    }

    func testNichtsGibtNichts() {
        XCTAssertEqual(SpotlightIndex.uebungen([]), [])
        XCTAssertEqual(SpotlightIndex.plaene(TrainingsPlan(tage: [])), [])
        XCTAssertEqual(SpotlightIndex.favoriten([]), [])
    }

    func testFavoritenSindBegrenzt() {
        let viele = (0..<(SpotlightIndex.hoechstensFavoriten + 20)).map { i -> Lebensmittel in
            var l = TestDaten.haferflocken
            l.id = "eigen-\(i)"
            return l
        }
        XCTAssertEqual(SpotlightIndex.favoriten(viele).count, SpotlightIndex.hoechstensFavoriten)
    }

    func testStempelAendertSichMitKatalogUndVersion() {
        XCTAssertEqual(SpotlightIndex.uebungenStempel(anzahl: 1_324, version: "7"), "7-1324")
        XCTAssertNotEqual(SpotlightIndex.uebungenStempel(anzahl: 1_324, version: "7"), SpotlightIndex.uebungenStempel(anzahl: 1_325, version: "7"))
        XCTAssertNotEqual(SpotlightIndex.uebungenStempel(anzahl: 1_324, version: "7"), SpotlightIndex.uebungenStempel(anzahl: 1_324, version: "8"))
    }

    // MARK: - Pflege

    private func pflege(_ u: AppUmgebung, _ senke: WidgetsTestSenke, version: String = "1") -> SpotlightPflege {
        let liste = [bank, rudern]
        return SpotlightPflege(umgebung: u, senke: senke, katalog: { liste }, version: version)
    }

    func testPflegeSchreibtUebungenEinmalUndProfilBeiAenderung() throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        let daten = try XCTUnwrap(u.daten)
        let senke = WidgetsTestSenke()
        let p = pflege(u, senke)

        p.aktualisiere()
        XCTAssertEqual(senke.ersetzt(.uebungen).count, 1)
        XCTAssertEqual(senke.ersetzt(.uebungen).first?.count, 2)
        XCTAssertEqual(senke.ersetzt(.profil).count, 1)
        XCTAssertEqual(senke.ersetzt(.profil).first, [], "ohne Plan und Favoriten ist der Profil-Bereich leer")

        p.aktualisiere()
        XCTAssertEqual(senke.ersetzt(.uebungen).count, 1, "unveränderter Katalog: nicht noch einmal")
        XCTAssertEqual(senke.ersetzt(.profil).count, 1, "unverändertes Profil: nicht noch einmal")

        daten.training.planSichern(plan())
        daten.essen.favoritSetzen(TestDaten.haferflocken, an: true)
        p.aktualisiere()
        XCTAssertEqual(senke.ersetzt(.profil).count, 2)
        XCTAssertEqual(senke.ersetzt(.profil).last?.map(\.titel), ["Push", "Pull", "Beispiel-Haferflocken"])
    }

    func testNeueVersionSchreibtDieUebungenNeuAuchNachNeuemStart() throws {
        let ordner = try tempOrdner()
        let u = try WidgetsTestUmgebung.neu(ordner: ordner)
        let erste = WidgetsTestSenke()
        pflege(u, erste, version: "1").aktualisiere()
        XCTAssertEqual(erste.ersetzt(.uebungen).count, 1)

        // Neuer Start derselben Version: der Stempel liegt auf der Platte, nichts wird erneuert.
        let zweite = WidgetsTestSenke()
        pflege(u, zweite, version: "1").aktualisiere()
        XCTAssertEqual(zweite.ersetzt(.uebungen).count, 0)

        let dritte = WidgetsTestSenke()
        pflege(u, dritte, version: "2").aktualisiere()
        XCTAssertEqual(dritte.ersetzt(.uebungen).count, 1)
    }

    func testProfilWechselErsetztDenProfilBereich() throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        let senke = WidgetsTestSenke()
        let p = pflege(u, senke)
        try XCTUnwrap(u.daten).training.planSichern(plan())
        p.aktualisiere()
        XCTAssertEqual(senke.ersetzt(.profil).last?.count, 2)

        _ = try u.profil.anlegen(name: "Zwei", passwort: "efgh")   // das neue Profil ist aktiv und hat keinen Plan
        p.aktualisiere()
        XCTAssertEqual(senke.ersetzt(.profil).last, [], "der Plan des ersten Profils verschwindet aus der Suche")
    }

    func testOhneKatalogWirdNichtsFuerUebungenGeschrieben() throws {
        let u = try WidgetsTestUmgebung.neu(ordner: try tempOrdner())
        let senke = WidgetsTestSenke()
        SpotlightPflege(umgebung: u, senke: senke, katalog: { [] }, version: "1").aktualisiere()
        XCTAssertEqual(senke.ersetzt(.uebungen).count, 0)
    }
}
