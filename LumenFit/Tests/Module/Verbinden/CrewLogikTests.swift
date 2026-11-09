import XCTest
@testable import LumenFit

/// Die Regeln der Crew: Wochenwerte, Rangliste, Herausforderungen, Reaktionen, Vergleich und Bestwert. Feste Uhr Freitag 2025-10-31 (Woche ab 27.10.).
final class CrewLogikTests: XCTestCase {
    private typealias T = CrewTestDaten

    private func satz(_ wdh: Int, _ kg: Double?, _ typ: String? = nil) -> PlanSatz {
        var s = PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ)
        s.ok = true
        return s
    }

    /// Eine fertige Einheit am Tag `tag` um 18 Uhr mit einer Übung je Name.
    private func session(_ tag: String, _ uebungen: [(String, [PlanSatz])]) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let laeufe = uebungen.enumerated().map { i, u in
            UebungsLauf(plan: "p\(i)", uebung: "x\(i)", start: start, ende: start.addingTimeInterval(600), fertig: true, saetze: u.1, name: u.0)
        }
        return GymSession(id: "s-\(tag)", tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: laeufe)
    }

    private func herausforderung(_ mass: CrewMass = .saetze, modus: CrewModus = .gegen, ziel: Int? = nil, uebung: String? = nil,
                                 start: String = "2025-10-27", ende: String = "2025-11-03", status: String = "laeuft", ich: String = "dabei",
                                 meins: Int = 0, andere: [Int] = [0]) -> CrewHerausforderung {
        var t = [CrewTeilnehmer(id: "ich-x", ich: true, name: "Du", wert: meins)]
        t += andere.enumerated().map { CrewTeilnehmer(id: "v\($0.offset)", name: "Freund \($0.offset)", wert: $0.element) }
        return CrewHerausforderung(id: "h1", mass: mass, modus: modus, ziel: ziel, uebung: uebung, start: Datum.datum(start), ende: Datum.datum(ende),
                                   status: status, ich: ich, teilnehmer: t)
    }

    // MARK: Woche

    func testEigeneWocheZaehltNurDieseWocheOhneAufwaermen() {
        let sessions = [
            session("2025-10-26", [("Kniebeuge", [satz(5, 100)])]),                                   // Sonntag davor: zählt nicht
            session("2025-10-27", [("Kniebeuge", [satz(10, 60, "w"), satz(5, 110), satz(5, 110)])]),  // Rekord gegen Sonntag
            session("2025-10-29", [("Bankdrücken", [satz(8, 80)])])                                    // erstes Mal: kein Rekord
        ]
        let w = CrewLogik.woche(sessions: sessions, jetzt: T.jetzt)
        XCTAssertEqual(w.tage, 2)
        XCTAssertEqual(w.saetze, 3)
        XCTAssertEqual(w.volumen, 110 * 5 * 2 + 80 * 8)
        XCTAssertEqual(w.rekorde, 1)
    }

    func testWocheEinerPersonAusDerZusammenfassung() {
        let einheiten = [
            T.einheit("2025-10-30", [("Kniebeuge", [T.satz(10, 600, "w"), T.satz(5, 1200), T.satz(5, 1200)])]),
            T.einheit("2025-10-20", [("Kniebeuge", [T.satz(5, 1100)])])
        ]
        var d = T.datei(verlauf: PartnerVerlauf(trainings: [], tage: nil, einheiten: einheiten))
        d.heute.gymTage = ["2025-10-24", "2025-10-28", "2025-10-30"]
        let w = CrewLogik.woche(d, jetzt: T.jetzt)
        XCTAssertEqual(w?.tage, 2, "der Freitag der Vorwoche zählt nicht")
        XCTAssertEqual(w?.saetze, 2)
        XCTAssertEqual(w?.volumen, 1200)
        XCTAssertEqual(w?.rekorde, 1)
    }

    func testFehlendeFreigabeIstNilNieNull() {
        XCTAssertNil(CrewLogik.woche(nil, jetzt: T.jetzt))
        let nurSchritte = CrewLogik.woche(T.datei(freigaben: [.schritte]), jetzt: T.jetzt)
        XCTAssertEqual(nurSchritte, CrewWoche())
        var nurGym = T.datei(freigaben: [.gym], verlauf: PartnerVerlauf(trainings: [], tage: nil, einheiten: []))
        nurGym.heute.gymTage = ["2025-10-28"]
        let w = CrewLogik.woche(nurGym, jetzt: T.jetzt)
        XCTAssertEqual(w?.tage, 1)
        XCTAssertNil(w?.saetze, "ohne verlauf keine Sätze")
        XCTAssertNil(w?.wert(.volumen))
    }

    func testAlteWocheZaehltNicht() {
        var d = T.datei(freigaben: [.gym])
        d.heute.tag = "2025-10-24"
        d.heute.gymTageWoche = 4
        XCTAssertEqual(CrewLogik.woche(d, jetzt: T.jetzt)?.tage, 0)
        d.heute.tag = T.heute
        XCTAssertEqual(CrewLogik.woche(d, jetzt: T.jetzt)?.tage, 4)
    }

    // MARK: Rangliste

    func testRanglisteGleichstandGleicherRangDuZuerst() {
        let z = CrewLogik.raenge([
            CrewRang(id: "b", name: "B", wert: 3, rang: 0, ich: false),
            CrewRang(id: "a", name: "A", wert: 5, rang: 0, ich: false),
            CrewRang(id: CrewRang.eigeneId, name: "Du", wert: 5, rang: 0, ich: true)
        ])
        XCTAssertEqual(z.map(\.id), [CrewRang.eigeneId, "a", "b"])
        XCTAssertEqual(z.map(\.rang), [1, 1, 3])
    }

    func testRanglisteLaesstPersonenOhneWertWegUndPausierte() {
        var mitTagen = T.datei(freigaben: [.gym])
        mitTagen.heute.gymTage = ["2025-10-28", "2025-10-29", "2025-10-30"]
        let eintraege = [
            T.eintrag("a", name: "A", daten: mitTagen),
            T.eintrag("b", name: "B", daten: T.datei(freigaben: [.schritte])),
            T.eintrag("c", name: "C", pause: true, daten: mitTagen)
        ]
        let z = CrewLogik.rangliste(.tage, ich: CrewWoche(tage: 1), eintraege: eintraege, jetzt: T.jetzt)
        XCTAssertEqual(z.map(\.id), ["a", CrewRang.eigeneId])
        XCTAssertEqual(z.first?.wert, 3)
    }

    // MARK: Herausforderungen

    func testWerteJeMassImZeitraum() {
        let sessions = [
            session("2025-10-20", [("Kniebeuge", [satz(5, 100)])]),
            session("2025-10-28", [("Kniebeuge", [satz(5, 105), satz(5, 105)]), ("Rudern", [satz(10, 50)])]),
            session("2025-11-04", [("Kniebeuge", [satz(5, 200)])])  // nach dem Ende
        ]
        func w(_ m: CrewMass) -> Int { CrewLogik.eigenerWert(herausforderung(m, uebung: "Kniebeuge"), sessions: sessions) }
        XCTAssertEqual(w(.tage), 1)
        XCTAssertEqual(w(.saetze), 3)
        XCTAssertEqual(w(.volumen), 105 * 5 * 2 + 500)
        XCTAssertEqual(w(.rekorde), 1)
        XCTAssertEqual(w(.uebung), 50, "105 gegen 100 kg bei gleichen Wiederholungen: 5 Prozent")
    }

    func testUebungPromilleOhneWertDavorGegenDieErsteEinheit() {
        let sessions = [
            session("2025-10-27", [("Kniebeuge (Langhantel)", [satz(1, 100)])]),
            session("2025-10-30", [("kniebeuge", [satz(1, 110)])])
        ]
        XCTAssertEqual(CrewLogik.eigenerWert(herausforderung(.uebung, uebung: "Kniebeuge"), sessions: sessions), 100)
        XCTAssertEqual(CrewLogik.eigenerWert(herausforderung(.uebung, uebung: "Rudern"), sessions: sessions), 0)
        let schwaecher = [session("2025-10-20", [("Kniebeuge", [satz(1, 120)])]), session("2025-10-28", [("Kniebeuge", [satz(1, 100)])])]
        XCTAssertEqual(CrewLogik.eigenerWert(herausforderung(.uebung, uebung: "Kniebeuge"), sessions: schwaecher), 0, "nie negativ")
    }

    func testStandLaufendUndBeendet() {
        let jetzt = T.jetzt
        XCTAssertEqual(CrewLogik.stand(herausforderung(meins: 5, andere: [3, 4]), jetzt: jetzt), .fuehrt)
        XCTAssertEqual(CrewLogik.stand(herausforderung(meins: 4, andere: [4]), jetzt: jetzt), .gleich)
        XCTAssertEqual(CrewLogik.stand(herausforderung(meins: 2, andere: [4]), jetzt: jetzt), .hinten)
        XCTAssertEqual(CrewLogik.stand(herausforderung(ende: "2025-10-30", meins: 6, andere: [4]), jetzt: jetzt), .gewonnen)
        XCTAssertEqual(CrewLogik.stand(herausforderung(status: "beendet", meins: 1, andere: [4]), jetzt: jetzt), .verloren)
        XCTAssertEqual(CrewLogik.stand(herausforderung(status: "abgebrochen", meins: 9), jetzt: jetzt), .abgebrochen)
    }

    func testStandGemeinsamInProzentNurDabei() {
        var h = herausforderung(modus: .gemeinsam, ziel: 40, meins: 10, andere: [12])
        h.teilnehmer.append(CrewTeilnehmer(id: "e", name: "E", status: "eingeladen", wert: 100))
        XCTAssertEqual(CrewLogik.stand(h, jetzt: T.jetzt), .gemeinsam(prozent: 55))
        XCTAssertEqual(CrewLogik.text(.gemeinsam(prozent: 55)), "55 % geschafft")
    }

    func testZuMeldenNurDabeiGeaendertUndBisEndePlusEinTag() {
        let sessions = [session("2025-10-28", [("Kniebeuge", [satz(5, 100)])])]
        func id(_ z: Character) -> String { String(repeating: z, count: 32) }
        var gleich = herausforderung(meins: 1); gleich.id = id("1")
        var neu = herausforderung(meins: 0); neu.id = id("a")
        var eingeladen = herausforderung(ich: "eingeladen"); eingeladen.id = id("2")
        var abgebrochen = herausforderung(status: "abgebrochen"); abgebrochen.id = id("3")
        var alt = herausforderung(start: "2025-10-20", ende: "2025-10-29"); alt.id = id("4")
        var kaputt = herausforderung(meins: 0); kaputt.id = "keine-hex-id"
        let antwort = CrewAntwort(herausforderungen: [gleich, neu, eingeladen, abgebrochen, alt, kaputt])
        XCTAssertEqual(CrewLogik.zuMelden(antwort, sessions: sessions, jetzt: T.jetzt), [CrewWertMeldung(id: id("a"), wert: 1)])
    }

    func testEndeBisSonntagUndRestText() {
        let ende = CrewLogik.endeBisSonntag(jetzt: T.jetzt)
        XCTAssertEqual(Datum.text(ende), "2025-11-02")
        let spaet = Datum.datum("2025-11-02").addingTimeInterval(23.5 * 3600)
        XCTAssertEqual(Datum.text(CrewLogik.endeBisSonntag(jetzt: spaet)), "2025-11-09", "weniger als eine Stunde: nächste Woche")
        XCTAssertEqual(CrewLogik.restText(herausforderung(), jetzt: T.jetzt), "noch 2 Tage")
        XCTAssertEqual(CrewLogik.restText(herausforderung(ende: "2025-10-30"), jetzt: T.jetzt), "beendet")
    }

    func testZielVorschlagGerundet() {
        XCTAssertEqual(CrewLogik.zielVorschlag(wochenwerte: [3, nil, 4], tage: 14), 14)
        XCTAssertEqual(CrewLogik.zielVorschlag(wochenwerte: [8_430, 6_000], tage: 7), 14_400)
        XCTAssertEqual(CrewLogik.zielVorschlag(wochenwerte: [], tage: 7), 1)
    }

    func testTitelUndArt() {
        XCTAssertEqual(CrewLogik.titel(herausforderung(.saetze)), "Duell: Sätze")
        XCTAssertEqual(CrewLogik.titel(herausforderung(.uebung, uebung: "Kniebeuge", andere: [0, 0])), "Gruppe: Kniebeuge")
        XCTAssertEqual(CrewLogik.titel(herausforderung(.volumen, modus: .gemeinsam)), "Gemeinsam: Volumen")
    }

    // MARK: Reaktionen

    func testZielTexteBegrenzt() {
        XCTAssertEqual(CrewLogik.zielRekord(tag: "2026-11-09", uebung: "Kniebeuge (Langhantel)"), "rekord:2026-11-09:kniebeuge")
        let lang = CrewLogik.zielRekord(tag: "2026-11-09", uebung: String(repeating: "Ü", count: 120))
        XCTAssertEqual(lang.utf16.count, 80)
        XCTAssertEqual(CrewLogik.zielStups(tag: "2026-11-09"), "stups:2026-11-09")
        XCTAssertEqual(CrewLogik.zielEinheit(tag: "2026-11-09"), "einheit:2026-11-09")
        XCTAssertEqual(CrewLogik.zielLive(tag: "2026-11-09"), "live:2026-11-09")
    }

    func testNeueReaktionenSeitEinemZeitpunkt() {
        let r = [0, 2, 1].map { CrewReaktion(id: "r\($0)", von: "a", name: "A", art: .respekt, ziel: "z", zeit: T.jetzt.addingTimeInterval(Double($0) * 60)) }
        XCTAssertEqual(CrewLogik.neue(r, seit: nil).map(\.id), ["r2", "r1", "r0"])
        XCTAssertEqual(CrewLogik.neue(r, seit: T.jetzt).map(\.id), ["r2", "r1"])
    }

    // MARK: Vergleich, Bestwert, Pinnwand

    func testVergleichNurGemeinsameUebungen() {
        let sessions = [session("2025-10-28", [("Kniebeuge", [satz(1, 100)]), ("Rudern", [satz(1, 60)])])]
        let d = T.datei(verlauf: PartnerVerlauf(trainings: [], tage: nil, einheiten: [T.einheit("2025-10-29", [("Kniebeuge (Langhantel)", [T.satz(1, 1200)]), ("Dips", [T.satz(1, 300)])])]))
        let v = CrewLogik.vergleich(sessions: sessions, datei: d)
        XCTAssertEqual(v, [CrewVergleich(uebung: "Kniebeuge", ich: 100, person: 120)])
        XCTAssertEqual(CrewLogik.vergleich(sessions: sessions, datei: T.datei(freigaben: [.gym], verlauf: d.heute.verlauf)), [], "ohne verlauf nichts")
    }

    func testBestwertDerCrewOhneAufwaermenUndNurMitFreigabe() {
        let a = T.datei(verlauf: PartnerVerlauf(trainings: [], tage: nil, einheiten: [T.einheit("2025-10-29", [("Bankdrücken", [T.satz(1, 1500, "w"), T.satz(8, 800)])])]))
        let b = T.datei(verlauf: PartnerVerlauf(trainings: [], tage: nil, einheiten: [T.einheit("2025-10-29", [("Bankdrücken", [T.satz(5, 850)])])]))
        let ohne = T.datei(freigaben: [.gym], verlauf: PartnerVerlauf(trainings: [], tage: nil, einheiten: [T.einheit("2025-10-29", [("Bankdrücken", [T.satz(1, 2000)])])]))
        let e = [T.eintrag("a", name: "A", daten: a), T.eintrag("b", name: "B", daten: b), T.eintrag("c", name: "C", daten: ohne)]
        let best = CrewLogik.bestwert(uebung: "bankdrücken", eintraege: e)
        XCTAssertEqual(best, CrewBestwert(name: "A", kg: 80, wdh: 8), "80 × 8 (e1RM 101) schlägt 85 × 5 (99)")
        XCTAssertEqual(best.map(CrewLogik.bestwertText), "Crew-Bestwert: A 80 kg × 8")
        XCTAssertNil(CrewLogik.bestwert(uebung: "Kniebeuge", eintraege: e))
    }

    func testPinnwandGleichWieImGymTabMitPerson() {
        let d = T.datei(verlauf: PartnerVerlauf(trainings: [], tage: nil, einheiten: [
            T.einheit(T.heute, [("Kniebeuge", [T.satz(5, 1200)])]), T.einheit("2025-10-01", [("Kniebeuge", [T.satz(5, 1100)])])
        ]))
        let e = [T.eintrag("a", name: "A", daten: d), T.eintrag("b", name: "B", daten: d)]
        let mitPerson = CrewLogik.pinnwand(eintraege: e, jetzt: T.jetzt)
        XCTAssertEqual(mitPerson.map(\.rekord), GymRekordPinnwandLogik.pinnwand(eintraege: e, jetzt: T.jetzt))
        XCTAssertEqual(mitPerson.map(\.person), ["a", "b"])
    }

    func testReagierenNurMitGymFreigabe() {
        XCTAssertTrue(CrewLogik.darfReagieren(T.eintrag("a", daten: T.datei(freigaben: [.gym]))))
        XCTAssertFalse(CrewLogik.darfReagieren(T.eintrag("a", daten: T.datei(freigaben: [.schritte]))))
        XCTAssertFalse(CrewLogik.darfReagieren(T.eintrag("a", pause: true, daten: T.datei(freigaben: [.gym]))))
    }

    func testWertText() {
        XCTAssertEqual(CrewLogik.wertText(8_400, .volumen), "8.400 kg")
        XCTAssertEqual(CrewLogik.wertText(1, .tage), "1 Tag")
        XCTAssertEqual(CrewLogik.wertText(12, .saetze), "12 Sätze")
        XCTAssertEqual(CrewLogik.wertText(35, .uebung), "35 ‰")
    }

    func testEinstiegText() {
        XCTAssertEqual(CrewLogik.einstiegText(imGym: 2, herausforderung: "Duell: du führst", neu: 1, personen: 3), "2 im Gym · Duell: du führst · 1 neu")
        XCTAssertEqual(CrewLogik.einstiegText(imGym: 0, herausforderung: nil, neu: 0, personen: 0), "Freunde einladen und herausfordern")
        XCTAssertEqual(CrewLogik.einstiegStand(CrewAntwort(herausforderungen: [herausforderung(meins: 3, andere: [1])]), jetzt: T.jetzt), "Duell: du führst")
    }
}
