import XCTest
@testable import LumenFit

/// Bereiche wählen (Gym, Essen, Schlaf): Einstellungen, Tabs und Links.
@MainActor
final class BereicheTests: XCTestCase {
    /// Einstellungen mit den genannten Bereichen aus (der Rest bleibt an).
    private func aus(_ bereiche: AppBereich...) -> Einstellungen {
        var e = Einstellungen()
        for b in bereiche { e.setze(b, an: false) }
        return e
    }

    // MARK: Einstellungen

    func testStandardZeigtAllesUndAlteDateiAuchOhneDieFelder() throws {
        XCTAssertTrue(AppBereich.allCases.allSatisfy { Einstellungen().zeigt($0) })
        let alt = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"wald"}"#.utf8))
        XCTAssertTrue(alt.gymAn && alt.essenAn && alt.schlafAn, "Bestandsprofile behalten alles")
    }

    func testBereicheUeberlebenSpeichernUndLaden() throws {
        let neu = try JSONDecoder().decode(Einstellungen.self, from: JSONEncoder().encode(aus(.schlaf)))
        XCTAssertFalse(neu.schlafAn)
        XCTAssertTrue(neu.gymAn && neu.essenAn)
    }

    func testDerLetzteBereichBleibtAn() {
        var e = aus(.gym, .essen)
        XCTAssertFalse(e.setze(.schlaf, an: false))
        XCTAssertTrue(e.schlafAn)
        XCTAssertTrue(e.setze(.gym, an: true))
        XCTAssertTrue(e.setze(.schlaf, an: false), "mit einem zweiten an darf Schlaf aus")
    }

    func testEineDateiMitAllemAusZeigtWiederAlles() throws {
        let e = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"gymAn":false,"essenAn":false,"schlafAn":false}"#.utf8))
        XCTAssertTrue(e.gymAn && e.essenAn && e.schlafAn)
    }

    func testRoutenFolgenDenBereichenUndTabsBleiben() {
        let e = aus(.schlaf, .essen)
        XCTAssertFalse(e.zeigt(Route.schlaf(.letzteNacht)) || e.zeigt(Route.essen(.heute)))
        XCTAssertTrue(e.zeigt(Route.gym(.training)) && e.zeigt(Route.uebung(id: "x")) && e.zeigt(Route.heute) && e.zeigt(Route.profil(.einstellungen)))
        XCTAssertFalse(aus(.gym).zeigt(Route.gym(.plaene)) || aus(.gym).zeigt(Route.uebung(id: "x")))
    }

    // MARK: Router

    func testAusgeschalteterBereichNimmtDieSeiteVomStapelUndOeffnetNichts() {
        let router = Router()
        router.tab = .profil
        router.pfade[.profil] = [.schlaf(.letzteNacht)]
        router.setze(einstellungen: aus(.schlaf))
        XCTAssertEqual(router.tab, .profil, "der Tab bleibt, es gibt keinen Schlaf-Tab mehr")
        XCTAssertNil(router.pfade[.profil], "die Seite ist weg, die Daten nicht")

        router.oeffne(.schlaf(.letzteNacht))
        XCTAssertEqual(router.tab, .heute)
        router.oeffne(.essen(.heute))
        XCTAssertEqual(router.tab, .profil, "Essen ist an: die Seite liegt im Profil-Stapel")
        XCTAssertEqual(router.pfade[.profil], [.essen(.heute)])
    }

    func testLinkUndSchiebenAufAusgeschaltetenBereichOeffnenHeute() {
        let router = Router()
        router.setze(einstellungen: aus(.gym))
        router.tab = .freunde
        XCTAssertTrue(router.oeffne(url: URL(string: "lumenfit://gym")!))
        XCTAssertEqual(router.tab, .heute)
        router.schiebe(.gym(.training))
        XCTAssertTrue(router.pfade[.heute]?.isEmpty ?? true, "nichts landet auf dem Stapel von Heute")
    }

    // MARK: Schlaf nur mit Erlaubnis des Servers

    func testOhneErlaubnisKeinSchlafTabUndSchlafRoutenLandenAufHeute() {
        let router = Router()
        XCTAssertFalse(router.schlafSichtbar, "Standard: aus")
        XCTAssertFalse(router.zeigt(Route.schlaf(.letzteNacht)))
        XCTAssertTrue(router.zeigt(Route.gym(.training)) && router.zeigt(Route.essen(.heute)) && router.zeigt(Route.heute))
        router.oeffne(.schlaf(.werte))
        XCTAssertEqual(router.tab, .heute)
        router.schiebe(.schlaf(.letzteNacht))
        XCTAssertTrue(router.pfade[.heute]?.isEmpty ?? true)
        XCTAssertTrue(router.oeffne(url: URL(string: "lumenfit://schlaf?bereich=verlauf")!))
        XCTAssertEqual(router.tab, .heute)
    }

    func testMitErlaubnisOeffnetSchlafImProfilUndDasWegnehmenNimmtDieSeiteWeg() {
        let router = Router()
        router.setzeSchlafSichtbar(true)
        XCTAssertTrue(router.zeigt(Route.schlaf(.werte)))
        router.oeffne(.schlaf(.werte))
        XCTAssertEqual(router.tab, .profil)
        XCTAssertEqual(router.pfade[.profil], [.schlaf(.werte)])
        router.setzeSchlafSichtbar(false)
        XCTAssertNil(router.pfade[.profil], "eine offene Schlaf-Seite verlässt den Stapel")
    }

    func testErlaubnisUndEigeneWahlGeltenBeide() {
        let router = Router()
        router.setzeSchlafSichtbar(true)
        router.setze(einstellungen: aus(.schlaf))
        XCTAssertFalse(router.zeigt(Route.schlaf(.letzteNacht)), "erlaubt, aber selbst ausgeschaltet")
    }

    func testWirksameBereicheBlendenSchlafOhneErlaubnisAusUndLassenImmerEinenAn() {
        XCTAssertFalse(Einstellungen().wirksam(schlafSichtbar: false).schlafAn)
        XCTAssertTrue(Einstellungen().wirksam(schlafSichtbar: true).schlafAn)
        XCTAssertTrue(Einstellungen().wirksam(schlafSichtbar: false).gymAn)
        var nurSchlaf = Einstellungen()
        nurSchlaf.gymAn = false
        nurSchlaf.essenAn = false
        let w = nurSchlaf.wirksam(schlafSichtbar: false)
        XCTAssertTrue(w.gymAn || w.essenAn, "nie ein Profil ohne sichtbaren Bereich")
        XCTAssertTrue(nurSchlaf.schlafAn, "die gespeicherte Wahl bleibt unverändert")
        XCTAssertEqual(ProfilBereiche.waehlbar(schlafSichtbar: false), [.gym, .essen])
        XCTAssertEqual(ProfilBereiche.waehlbar(schlafSichtbar: true), [.gym, .essen, .schlaf])
    }

    // MARK: Fünf Tabs (Aufteilung B)

    func testFuenfTabsImmerSichtbar() {
        // Neues Design (Besitzer 10.11.2026: "training in die mitte", Stats statt Rangliste, Symbole wie bisher).
        XCTAssertEqual(LumenFitTab.allCases, [.heute, .fortschritt, .training, .freunde, .profil])
        XCTAssertEqual(LumenFitTab.allCases.map(\.titel), ["Heute", "Fortschritt", "Training", "Stats", "Profil"])
        XCTAssertEqual(LumenFitTab.allCases.map(\.symbolName), ["house.fill", "chart.xyaxis.line", "dumbbell.fill", "person.2.fill", "person.crop.circle.fill"])
        XCTAssertEqual(LumenFitTab.freunde.rawValue, "freunde", "der Rohwert bleibt (Nutzungsname, Links)")
        XCTAssertEqual(LumenFitTab.heute.rawValue, "heute", "der Rohwert bleibt (Nutzungsname, gemerkter Tab)")
        for einstellungen in [Einstellungen(), aus(.gym), aus(.essen, .schlaf), aus(.gym, .essen)] {
            let router = Router()
            router.setze(einstellungen: einstellungen)
            XCTAssertTrue(LumenFitTab.allCases.allSatisfy { router.zeigt($0) })
        }
    }

    func testRoutenLandenAufDemRichtigenTab() {
        XCTAssertEqual(LumenFitTab.fuer(.heute), .heute)
        XCTAssertEqual(LumenFitTab.fuer(.gewichtEintragen), .heute)
        XCTAssertEqual(LumenFitTab.fuer(.gym(.training)), .training)
        XCTAssertEqual(LumenFitTab.fuer(.gym(.plaene)), .training)
        XCTAssertEqual(LumenFitTab.fuer(.uebung(id: "x")), .training)
        XCTAssertEqual(LumenFitTab.fuer(.gym(.fortschritt)), .fortschritt)
        XCTAssertEqual(LumenFitTab.fuer(.verlauf), .fortschritt)
        XCTAssertEqual(LumenFitTab.fuer(.einsichten), .fortschritt, "Einsichten und Hinweise: Zeile im Fortschritt (Besitzer 10.11.2026)")
        XCTAssertEqual(LumenFitTab.fuer(.freund(daten: nil)), .freunde)
        XCTAssertEqual(LumenFitTab.fuer(.profil(.verbindungen)), .freunde)
        XCTAssertEqual(LumenFitTab.fuer(.essen(.heute)), .profil)
        XCTAssertEqual(LumenFitTab.fuer(.schlaf(.letzteNacht)), .profil)
        XCTAssertEqual(LumenFitTab.fuer(.profil(.ziele)), .profil)
    }

    func testAlteLinksLandenAufDemNeuenTabMitDerSeite() {
        let router = Router()
        router.setzeSchlafSichtbar(true)
        router.oeffne(.gym(.plaene))
        XCTAssertEqual(router.tab, .training)
        XCTAssertEqual(router.pfade[.training], [.gym(.plaene)], "Plan ist eine Unterseite des Trainings")
        router.oeffne(.gym(.fortschritt))
        XCTAssertEqual(router.tab, .fortschritt)
        XCTAssertEqual(router.pfade[.fortschritt], [], "die Wurzel des Tabs ist der Fortschritt selbst")
        router.oeffne(.verlauf)
        XCTAssertEqual(router.pfade[.fortschritt], [.verlauf])
        router.oeffne(.einsichten)
        XCTAssertEqual(router.tab, .fortschritt)
        XCTAssertEqual(router.pfade[.fortschritt], [.einsichten])
        router.oeffne(.essen(.scan))
        XCTAssertEqual(router.tab, .profil)
        XCTAssertEqual(router.pfade[.profil], [.essen(.scan)])
        router.oeffne(.schlaf(.letzteNacht))
        XCTAssertEqual(router.pfade[.profil], [.schlaf(.letzteNacht)])
        router.oeffne(.profil(.einstellungen))
        XCTAssertEqual(router.tab, .profil)
        XCTAssertEqual(router.pfade[.profil], [], "Einstellungen ist die Wurzel des Profils")
        router.oeffne(.profil(.datensicherung))
        XCTAssertEqual(router.pfade[.profil], [.profil(.datensicherung)])
        router.oeffne(.profil(.verbindungen))
        XCTAssertEqual(router.tab, .freunde)
        router.oeffne(.uebung(id: "x"))
        XCTAssertEqual(router.tab, .training)
        XCTAssertNil(router.blatt)
    }

    func testFreundeLinkOeffnetFreundeTabNurMitTokenAlsBlatt() {
        let router = Router()
        router.oeffne(.freund(daten: nil))
        XCTAssertEqual(router.tab, .freunde)
        XCTAssertNil(router.blatt)
        router.oeffne(.freund(daten: "abc"))
        XCTAssertEqual(router.tab, .freunde)
        XCTAssertEqual(router.blatt, .freund(daten: "abc"), "das Bestätigen bleibt ein Blatt über dem Tab")
    }

    func testBereichGymBlendetGymSeitenAusNichtDieTabs() {
        let e = aus(.gym)
        let router = Router()
        router.setze(einstellungen: e)
        router.oeffne(.gym(.plaene))
        XCTAssertEqual(router.tab, .heute)
        router.oeffne(.uebung(id: "x"))
        XCTAssertEqual(router.tab, .heute)
    }

    func testMiniLeisteNurBeiLaufendemTrainingUndNichtImTraining() {
        for tab in LumenFitTab.allCases {
            XCTAssertEqual(LumenFitTab.zeigtMiniLeiste(auf: tab, trainingLaeuft: true), tab != .training, "\(tab)")
            XCTAssertFalse(LumenFitTab.zeigtMiniLeiste(auf: tab, trainingLaeuft: false), "\(tab)")
        }
    }

    func testLaufendesTrainingZeigtImTrainingTabDenLauf() {
        XCTAssertEqual(GymSeite.wahl(bereich: .training, laeuft: true), .lauf)
        XCTAssertEqual(GymSeite.wahl(bereich: .training, laeuft: false), .start)
    }

    // MARK: Profil: Zeilen Essen und Schlaf (Übergang bis zum Umzug)

    func testEssenZeileNurMitEssenUndSchlafZeileNurMitFreigabe() {
        XCTAssertEqual(ProfilUmzugLogik.zeilen(essenAn: false, schlafSichtbar: false, loveaErlaubt: true), [], "keine leeren Zeilen")
        let nurEssen = ProfilUmzugLogik.zeilen(essenAn: true, schlafSichtbar: false, loveaErlaubt: false)
        XCTAssertEqual(nurEssen.map(\.titel), ["Essen"])
        XCTAssertEqual(nurEssen.first?.untertitel, "", "ohne Lovea-Freigabe kein Umzugs-Hinweis")
        XCTAssertEqual(nurEssen.first?.route, .essen(.heute))
        let beide = ProfilUmzugLogik.zeilen(essenAn: true, schlafSichtbar: true, loveaErlaubt: true)
        XCTAssertEqual(beide.map(\.titel), ["Essen", "Schlaf"])
        XCTAssertEqual(beide.first?.untertitel, "Zieht bald zu Lovea um")
        XCTAssertEqual(beide.last?.untertitel, "Zieht bald zu Lumen Alarm um")
        XCTAssertEqual(beide.last?.route, .schlaf(.letzteNacht))
        XCTAssertEqual(ProfilUmzugLogik.zeilen(essenAn: false, schlafSichtbar: true, loveaErlaubt: false).map(\.titel), ["Schlaf"])
    }

    #if DEBUG
    func testAlteStartArgumenteLandenImNeuenTab() {
        func tab(_ wert: String) -> LumenFitTab? {
            let d = UserDefaults(suiteName: "tab-arg-\(UUID().uuidString)")!
            d.set(wert, forKey: "lumenFitTab")
            return StartArgumente.lies(d).tab
        }
        XCTAssertEqual(tab("plan"), .training)
        XCTAssertEqual(tab("gym"), .training)
        XCTAssertEqual(tab("essen"), .profil)
        XCTAssertEqual(tab("schlaf"), .profil)
        for neu in LumenFitTab.allCases { XCTAssertEqual(tab(neu.rawValue), neu) }
        XCTAssertNil(tab("coach"))
    }
    #endif
}
