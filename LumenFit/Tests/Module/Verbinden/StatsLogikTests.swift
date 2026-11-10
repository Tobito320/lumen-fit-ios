import XCTest
@testable import LumenFit

/// Regeln von Stats: Plätze und Sätze, Prozent, Ausschnitt von Alle, Trainingsjahr, Vergleichsgruppe, Rekorde, was zum Server geht, Spitzname.
/// Feste Uhr Donnerstag 2026-11-12, 12 Uhr (Woche ab Montag 09.11.).
final class StatsLogikTests: XCTestCase {
    private let jetzt = Datum.datum("2026-11-12").addingTimeInterval(12 * 3600)

    private func satz(_ wdh: Int, _ kg: Double?, _ typ: String? = nil) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ)
        s.ok = true
        return s
    }

    private func einheit(_ tag: String, _ uebungen: [(id: String, saetze: [PlanSatz])]) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let laeufe = uebungen.map { UebungsLauf(plan: "p-\($0.id)", uebung: $0.id, start: start, ende: start.addingTimeInterval(600), fertig: true, saetze: $0.saetze) }
        return GymSession(id: "s-\(tag)", tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: laeufe)
    }

    private func eintrag(_ id: String, punkte: Int, jahr: Int? = 1, ich: Bool = false) -> StatsEintrag {
        StatsEintrag(id: id, name: "Spitz \(id)", jahr: jahr, punkte: punkte, trainings: 1, sets: 1, serie: 1, ich: ich)
    }

    // MARK: Plätze

    func testZeilenGleicherWertGleicherPlatzIchZuerst() {
        let z = StatsLogik.zeilen(ichName: "Du", ichWert: 57, andere: [(id: "a", name: "Freund 1", wert: 83), (id: "b", name: "Partner", wert: 57), (id: "c", name: "Freund 2", wert: 45)])
        XCTAssertEqual(z.map(\.id), ["a", CrewRang.eigeneId, "b", "c"])
        XCTAssertEqual(z.map(\.rang), [1, 2, 2, 4])
        XCTAssertEqual(StatsLogik.platz(z).rang, 2)
        XCTAssertEqual(StatsLogik.platz(z).von, 4)
        XCTAssertEqual(StatsLogik.satzFreunde(z, mass: .punkte), "Noch 27 Punkte bis Platz 1.")
        let vorn = StatsLogik.zeilen(ichName: "Du", ichWert: 90, andere: [(id: "a", name: "Freund 1", wert: 83)])
        XCTAssertEqual(StatsLogik.satzFreunde(vorn, mass: .punkte), "Du führst. Bleib dran.")
        XCTAssertNil(StatsLogik.satzFreunde(StatsLogik.zeilen(ichName: "Du", ichWert: 3, andere: []), mass: .punkte), "allein: kein Satz")
        let knapp = StatsLogik.zeilen(ichName: "Du", ichWert: 2, andere: [(id: "a", name: "Freund 1", wert: 2), (id: "b", name: "Freund 2", wert: 3)])
        XCTAssertEqual(StatsLogik.satzFreunde(knapp, mass: .trainings), "Noch 2 Trainings bis Platz 1.")
        XCTAssertEqual(StatsLogik.satzFreunde(StatsLogik.zeilen(ichName: "Du", ichWert: 1, andere: [(id: "a", name: "F", wert: 1), (id: "b", name: "G", wert: 1)]), mass: .serie),
                       "Du führst. Bleib dran.", "gleichauf vorn")
        XCTAssertEqual(StatsLogik.satzFreunde(StatsLogik.zeilen(ichName: "Du", ichWert: 9, andere: [(id: "a", name: "F", wert: 10)]), mass: .sets), "Noch 2 Sets bis Platz 1.")
        XCTAssertEqual(StatsLogik.satzFreunde(StatsLogik.zeilen(ichName: "Du", ichWert: 10, andere: [(id: "a", name: "F", wert: 10), (id: "b", name: "G", wert: 11)]), mass: .punkte),
                       "Noch 2 Punkte bis Platz 1.")
    }

    func testProzentAusListeUndVerteilung() {
        XCTAssertEqual(StatsLogik.prozent(mein: 5, andere: [1, 2, 5, 9]), 50, "nur echt weniger zählt")
        XCTAssertNil(StatsLogik.prozent(mein: 5, andere: []))
        XCTAssertEqual(StatsLogik.prozent(mein: 120, verteilung: [[100, 1], [120, 2], [140, 1]]), 25)
        XCTAssertEqual(StatsLogik.prozent(mein: 200, verteilung: [[100, 3]]), 100)
        XCTAssertNil(StatsLogik.prozent(mein: 1, verteilung: []))
        XCTAssertNil(StatsLogik.prozent(mein: 1, verteilung: [[1]]), "kaputte Paare zählen nicht")
        XCTAssertEqual(StatsLogik.satzAlle(prozent: 76, mass: .trainings, jahr: 1), "Öfter dabei als 76 % der Leute im 1. Jahr.")
        XCTAssertEqual(StatsLogik.satzAlle(prozent: 40, mass: .punkte, jahr: nil), "Mehr Punkte als 40 % der Leute.")
    }

    func testAusschnittErsteFuenfLueckeUndNachbarn() {
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 20, ich: 11), [0, 1, 2, 3, 4, nil, 10, 11, 12])
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 20, ich: 6), [0, 1, 2, 3, 4, 5, 6, 7], "direkt anschließend: keine Lücke")
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 20, ich: 2), [0, 1, 2, 3, 4])
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 8, ich: 7), [0, 1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 9, ich: 8), [0, 1, 2, 3, 4, nil, 7, 8])
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 20, ich: 7), [0, 1, 2, 3, 4, 5, 6, 7, 8], "eine einzelne fehlende Zeile steht da")
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 3, ich: nil), [0, 1, 2])
        XCTAssertEqual(StatsLogik.ausschnitt(anzahl: 0, ich: nil), [])
    }

    // MARK: Trainingsjahr und Vergleichsgruppe

    func testTrainingsjahrAusErstemTrainingUndEinfuehrung() {
        XCTAssertEqual(StatsLogik.trainingsjahr(sessions: [], erfahrung: nil, jetzt: jetzt), 1)
        XCTAssertEqual(StatsLogik.trainingsjahr(sessions: [], erfahrung: .unterSechsMonate, jetzt: jetzt), 1)
        XCTAssertEqual(StatsLogik.trainingsjahr(sessions: [], erfahrung: .bisZweiJahre, jetzt: jetzt), 2)
        XCTAssertEqual(StatsLogik.trainingsjahr(sessions: [], erfahrung: .laenger, jetzt: jetzt), 3)
        let alt = [einheit("2024-10-01", [(id: "bank", saetze: [satz(5, 60)])])]
        XCTAssertEqual(StatsLogik.trainingsjahr(sessions: alt, erfahrung: .geradeAngefangen, jetzt: jetzt), 3, "das erste Training ist älter als die Antwort")
        XCTAssertEqual(StatsLogik.trainingsjahr(sessions: [einheit("2016-01-04", [(id: "bank", saetze: [satz(5, 60)])])], erfahrung: nil, jetzt: jetzt), 5, "höchstens 5")
        let nurAufwaermen = [einheit("2024-10-01", [(id: "bank", saetze: [satz(5, 30, "w")])])]
        XCTAssertEqual(StatsLogik.trainingsjahr(sessions: nurAufwaermen, erfahrung: nil, jetzt: jetzt), 1, "ohne gezählten Satz kein Training")
        XCTAssertEqual(StatsLogik.jahrText(1), "im 1. Jahr")
        XCTAssertEqual(StatsLogik.jahrText(5), "ab dem 5. Jahr")
    }

    func testVergleichMitGleichemJahrNurMitGenugLeuten() {
        let wenige = (0..<9).map { eintrag("j\($0)", punkte: $0) } + [eintrag("x", punkte: 5, jahr: 2), eintrag("ich", punkte: 3, ich: true)]
        let a = StatsLogik.vergleich(wenige, jahr: 1)
        XCTAssertNil(a.jahr)
        XCTAssertEqual(a.andere.count, 10, "alle außer mir")
        let genug = wenige + [eintrag("j9", punkte: 9)]
        let b = StatsLogik.vergleich(genug, jahr: 1)
        XCTAssertEqual(b.jahr, 1)
        XCTAssertEqual(b.andere.count, 10)
        XCTAssertFalse(b.andere.contains { $0.ich || $0.id == "x" })
        let spaet = (0..<10).map { eintrag("s\($0)", punkte: $0, jahr: 7) }
        XCTAssertEqual(StatsLogik.vergleich(spaet, jahr: 5).jahr, 5, "ab dem 5. Jahr zählt zusammen")
    }

    // MARK: Rekorde

    func testHauptuebungenNurKatalogMitGewichtOhneKoerpergewichtNachHaeufigkeit() {
        // CHpahtl: Maschine, xnInPfE: Langhantel, 2gPfomN: Körpergewicht.
        let sessions = [
            einheit("2026-11-02", [(id: "CHpahtl", saetze: [satz(10, 40)]), (id: "xnInPfE", saetze: [satz(8, 20)]), (id: "2gPfomN", saetze: [satz(20, 5)])]),
            einheit("2026-11-05", [(id: "CHpahtl", saetze: [satz(10, 45)]), (id: PlanUebung.eigen, saetze: [satz(10, 99)])]),
        ]
        XCTAssertEqual(StatsLogik.hauptuebungen(sessions), [StatsUebungKg(id: "CHpahtl", kg: 45), StatsUebungKg(id: "xnInPfE", kg: 20)])
        XCTAssertEqual(StatsLogik.hauptuebungen(sessions, grenze: 1).map(\.id), ["CHpahtl"])
    }

    func testRekordeImVergleich() {
        let freunde = [StatsFreund(id: "a", name: "F", punkte: 0, trainings: 0, sets: 0, serie: 0, rekorde: ["u": 150]),
                       StatsFreund(id: "b", name: "G", punkte: 0, trainings: 0, sets: 0, serie: 0, rekorde: ["u": 100, "v": 80]),
                       StatsFreund(id: "c", name: "H", punkte: 0, trainings: 0, sets: 0, serie: 0, rekorde: [:])]
        XCTAssertTrue(StatsLogik.platzFreunde(kg: 120, uebung: "u", freunde: freunde) == (2, 3))
        XCTAssertTrue(StatsLogik.platzFreunde(kg: 50, uebung: "w", freunde: freunde) == (1, 1))
        let rekorde: [String: [String: [[Double]]]] = ["u": ["alle": [[100, 3], [140, 1]], "1": [[100, 1], [110, 4]]]]
        XCTAssertTrue(StatsLogik.prozentAlle(kg: 120, uebung: "u", rekorde: rekorde, jahr: 1).map { $0 == (100, 1) } ?? false)
        XCTAssertTrue(StatsLogik.prozentAlle(kg: 120, uebung: "u", rekorde: rekorde, jahr: 2).map { $0 == (75, nil) } ?? false, "ohne Jahr-Verteilung gilt alle")
        XCTAssertNil(StatsLogik.prozentAlle(kg: 120, uebung: "x", rekorde: rekorde, jahr: 1))
    }

    // MARK: Zum Server

    func testMeldungPrivatNurSchalterSonstZahlenOeffentlichMitNameUndJahr() throws {
        var e = Einstellungen()
        let sessions = [einheit("2026-11-10", [(id: "CHpahtl", saetze: [satz(10, 40), satz(10, 40)])])]
        XCTAssertEqual(StatsLogik.meldung(einstellungen: e, sessions: sessions, jetzt: jetzt), .aus)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(String(decoding: try encoder.encode(StatsMeldung.aus), as: UTF8.self), #"{"freunde":false,"oeffentlich":false}"#)
        e.statsOeffentlich = true
        XCTAssertEqual(StatsLogik.meldung(einstellungen: e, sessions: sessions, jetzt: jetzt), .aus, "öffentlich ohne Spitzname ist privat")
        e.statsFreunde = true
        let freunde = StatsLogik.meldung(einstellungen: e, sessions: sessions, jetzt: jetzt)
        XCTAssertEqual(freunde, StatsMeldung(freunde: true, oeffentlich: false, spitzname: nil, jahr: nil, montag: "2026-11-09", trainings: 1, sets: 2, rekordeNeu: 0, serie: 1,
                                             rekorde: ["CHpahtl": 40]))
        e.statsSpitzname = "Eisenfaust"
        let oeffentlich = StatsLogik.meldung(einstellungen: e, sessions: sessions, jetzt: jetzt)
        XCTAssertEqual(oeffentlich.spitzname, "Eisenfaust")
        XCTAssertEqual(oeffentlich.jahr, 1)
        XCTAssertTrue(oeffentlich.oeffentlich)
    }

    func testAntwortDesServersLaesstSichLesen() throws {
        let json = #"{"montag":"2026-11-09","ich":{"freunde":true,"oeffentlich":false,"spitzname":null,"ausgeblendet":false},"freunde":[{"id":"aaaa","name":"Freund 1","punkte":75,"trainings":3,"sets":40,"serie":4,"rekorde":{"CHpahtl":150,"xnInPfE":32.5}}],"alle":[{"id":"bbbb","name":"Eisenfaust","jahr":1,"punkte":30,"trainings":2,"sets":10,"serie":4,"ich":false}],"rekorde":{"CHpahtl":{"alle":[[100,1],[120,2]],"1":[[100,1],[120,2]]}}}"#
        let a = try JSONDecoder().decode(StatsAntwort.self, from: Data(json.utf8))
        XCTAssertEqual(a.freunde.first?.rekorde["xnInPfE"], 32.5)
        XCTAssertEqual(a.alle.first?.name, "Eisenfaust")
        XCTAssertEqual(a.rekorde["CHpahtl"]?["1"], [[100, 1], [120, 2]])
        XCTAssertTrue(a.ich.freunde)
    }

    // MARK: Spitzname und Texte

    func testSpitznameWieDerServerSoweitDasGeraetEsWeiss() {
        XCTAssertEqual(StatsLogik.spitzname("  Eisen   Faust "), "Eisen Faust")
        XCTAssertNil(StatsLogik.spitznameGrund("Eisenfaust"))
        XCTAssertNil(StatsLogik.spitznameGrund("Bär_99"))
        XCTAssertNil(StatsLogik.spitznameGrund("Çelik-Kraft"))
        XCTAssertEqual(StatsLogik.spitznameGrund("ab"), .laenge)
        XCTAssertEqual(StatsLogik.spitznameGrund(String(repeating: "a", count: 21)), .laenge)
        XCTAssertEqual(StatsLogik.spitznameGrund("Eisen/Faust"), .zeichen)
        XCTAssertEqual(StatsLogik.spitznameGrund("Ей Faust"), .zeichen, "keine anderen Schriften")
        XCTAssertEqual(StatsLogik.spitznameGrund("12345"), .buchstaben)
        XCTAssertEqual(StatsLogik.fehlerText("spitzname_vergeben"), "Diesen Spitznamen hat schon jemand.")
        XCTAssertEqual(StatsLogik.fehlerText("spitzname_unpassend"), StatsLogik.spitznameText(.unpassend))
        XCTAssertEqual(StatsLogik.fehlerText(nil), StatsLogik.fehlerText("unbekannt"))
    }

    func testSichtbarkeitText() {
        var e = Einstellungen()
        XCTAssertEqual(StatsLogik.sichtbarkeitText(e), "Privat")
        e.statsFreunde = true
        XCTAssertEqual(StatsLogik.sichtbarkeitText(e), "Freunde")
        e.statsOeffentlich = true
        XCTAssertEqual(StatsLogik.sichtbarkeitText(e), "Freunde", "öffentlich erst mit Spitzname")
        e.statsSpitzname = "Eisenfaust"
        XCTAssertEqual(StatsLogik.sichtbarkeitText(e), "Öffentlich")
    }
}
