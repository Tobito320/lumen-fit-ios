import XCTest
@testable import LumenFit

/// Die Seite Fortschritt: Woche gegen Schnitt, Gewichte je Plan-Übung, Wochenwerte fürs Diagramm und die Einheiten nach Wochen.
/// Alle Zahlen erfunden und rund. "Heute" ist Mittwoch 11.11.2026 (KW 46, die Woche beginnt am 09.11.).
final class FortschrittLogikTests: XCTestCase {
    private let uhr = TestUhr(Datum.datum("2026-11-11").addingTimeInterval(12 * 3600))
    private var heute: String { Datum.text(uhr.lesen) }

    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
    private let lat = Uebung(id: "lat", name: "Latzug", en: "lat pulldown", muskel: "Rücken", koerper: "Rücken", geraet: "Kabelzug", neben: [])
    private let band = Uebung(id: "band", name: "Laufband", en: "treadmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Maschine", neben: [])

    private func katalog(_ id: String) -> Uebung? { [bank.id: bank, lat.id: lat, band.id: band][id] }

    private func satz(_ kg: Double, _ wdh: Int, typ: String? = nil) -> PlanSatz {
        PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ)
    }

    /// Ein Lauf im neuen Stil: alle Zeilen abgehakt im Stand, gezählt sind die ohne Aufwärmen.
    private func lauf(_ uebung: String, _ saetze: [PlanSatz]) -> UebungsLauf {
        let stand = saetze.map { s -> PlanSatz in var z = s; z.ok = true; return z }
        let gezaehlt = stand.filter { $0.typ != "w" }
        return UebungsLauf(plan: "p-\(uebung)", uebung: uebung, start: nil, ende: nil, fertig: !gezaehlt.isEmpty, saetze: gezaehlt.isEmpty ? nil : gezaehlt, stand: stand)
    }

    /// Eine Einheit um 18 Uhr; `minuten` Dauer, `beendet: false` = läuft noch.
    private func einheit(_ id: String, _ tag: String, minuten: Int = 60, beendet: Bool = true, tagId: String? = nil, _ laeufe: [UebungsLauf]) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        return GymSession(id: id, tag: tagId, start: start, ende: beendet ? start.addingTimeInterval(Double(minuten) * 60) : nil, laeufe: laeufe)
    }

    private func planUebung(_ id: String, _ katalogId: String, minuten: Int? = nil) -> PlanUebung {
        PlanUebung(id: id, uebung: katalogId, name: nil, saetze: [], minuten: minuten)
    }

    private func plan(_ tage: [TrainingsTag]) -> TrainingsPlan { TrainingsPlan(tage: tage) }

    // MARK: Woche gegen Schnitt

    func testVergleichDieseWocheGegenVierWochenSchnitt() {
        let s = [
            einheit("a", "2026-11-09", [lauf("bank", [satz(50, 10), satz(50, 10), satz(50, 10)])]),   // 1500 kg, 3 Sätze
            einheit("b", "2026-11-10", [lauf("lat", [satz(40, 10), satz(40, 10)])]),                  // 800 kg, 2 Sätze
            einheit("c1", "2026-10-13", [lauf("bank", [satz(60, 10), satz(60, 10)])]),               // vier Wochen davor: je 1200 kg, 2 Sätze
            einheit("c2", "2026-10-20", [lauf("bank", [satz(60, 10), satz(60, 10)])]),
            einheit("c3", "2026-10-27", [lauf("bank", [satz(60, 10), satz(60, 10)])]),
            einheit("c4", "2026-11-03", [lauf("bank", [satz(60, 10), satz(60, 10)])]),
            einheit("alt", "2026-10-06", [lauf("bank", [satz(99, 10)])]),                            // fünf Wochen davor: zählt nicht
        ]
        let v = FortschrittLogik.vergleich(s, plan: .leer, heute: heute, katalog: katalog)
        XCTAssertEqual(v.einheiten, 2)
        XCTAssertEqual(v.einheitenSchnitt, 1, accuracy: 0.001)
        XCTAssertEqual(v.volumen, 2300, accuracy: 0.001)
        XCTAssertEqual(v.volumenSchnitt, 1200, accuracy: 0.001)
        XCTAssertEqual(v.saetze, 5)
        XCTAssertEqual(v.saetzeSchnitt, 2, accuracy: 0.001)
    }

    func testGestiegenZaehltNurPlanuebungenMitHoeheremSchwerstemSatz() {
        // Bankdrücken steht an zwei Tagen im Plan und zählt einmal; Laufband (Cardio) und "kurz" (nicht im Plan) zählen nicht.
        let tage = [TrainingsTag(id: "t1", name: "Push", wochentage: [1], uebungen: [planUebung("u1", "bank"), planUebung("u2", "lat"), planUebung("u3", "band", minuten: 20)]),
                    TrainingsTag(id: "t2", name: "Brust", wochentage: [4], uebungen: [planUebung("u4", "bank")])]
        let s = [
            einheit("a", "2026-10-06", [lauf("bank", [satz(60, 8)]), lauf("lat", [satz(50, 8)]), lauf("kurz", [satz(20, 8)])]),
            einheit("b", "2026-11-03", [lauf("bank", [satz(65, 8)]), lauf("kurz", [satz(40, 8)])]),
            einheit("c", "2026-11-10", [lauf("bank", [satz(67.5, 6)]), lauf("lat", [satz(50, 10)])]),
        ]
        let v = FortschrittLogik.vergleich(s, plan: plan(tage), heute: heute, katalog: katalog)
        XCTAssertEqual(v.hauptuebungen, 2)
        XCTAssertEqual(v.gestiegen, 1)

        let zeilen = FortschrittLogik.gewichte(s, plan: plan(tage), heute: heute, katalog: katalog)
        XCTAssertEqual(zeilen.map(\.uebungId), ["bank", "lat"], "Reihenfolge wie im Plan, keine Doppelten, kein Cardio")
        XCTAssertEqual(zeilen[0].name, "Bankdrücken")
        XCTAssertEqual(zeilen[0].muskel, "Brust")
        XCTAssertEqual(zeilen[0].wochen, [nil, nil, 60, nil, nil, nil, 65, 67.5], "acht Wochen, älteste zuerst (21.09. bis 09.11.)")
        XCTAssertEqual(zeilen[0].aktuell, 67.5)
        XCTAssertEqual(zeilen[0].aenderung4Wochen, 7.5, accuracy: 0.001)
        XCTAssertEqual(zeilen[1].aenderung4Wochen, 0, accuracy: 0.001)
    }

    func testAufwaermsaetzeZaehlenNichtInsVolumen() {
        let s = [einheit("a", "2026-11-10", [lauf("bank", [satz(100, 5, typ: "w"), satz(60, 5)])])]
        let v = FortschrittLogik.vergleich(s, plan: .leer, heute: heute, katalog: katalog)
        XCTAssertEqual(v.volumen, 300, accuracy: 0.001)
        XCTAssertEqual(v.saetze, 1, "der Aufwärmsatz ist kein Arbeitssatz")
        let w = FortschrittLogik.wochen(s, heute: heute, art: .wiederholungen)
        XCTAssertEqual(w.last?.wert, 5)
    }

    func testAlterLaufOhneHakenZaehltUndOffenerSatzNicht() {
        // Alte "fertig"-Läufe haben Sätze ohne `ok`; im neuen Stil zählt nur, was im Stand abgehakt ist.
        let alt = UebungsLauf(plan: "p", uebung: "bank", start: nil, ende: nil, fertig: true, saetze: [satz(50, 10)])
        var offen = lauf("lat", [satz(40, 10)])
        offen.stand = [PlanSatz(wdh: 10, kg: 40, failure: false)]   // nicht abgehakt
        offen.saetze = nil
        offen.fertig = false
        let v = FortschrittLogik.vergleich([einheit("a", "2026-11-10", [alt, offen])], plan: .leer, heute: heute, katalog: katalog)
        XCTAssertEqual(v.volumen, 500, accuracy: 0.001)
        XCTAssertEqual(v.saetze, 1)
    }

    func testLaufendeEinheitZaehltErstNachDemBeendenAbgebrocheneVonGesternSchon() {
        let s = [einheit("heute", "2026-11-11", beendet: false, [lauf("bank", [satz(50, 10)])]),
                 einheit("gestern", "2026-11-10", beendet: false, [lauf("bank", [satz(50, 10)])])]
        XCTAssertEqual(FortschrittLogik.vergleich(s, plan: .leer, heute: heute, katalog: katalog).einheiten, 1)
        XCTAssertEqual(FortschrittLogik.nachWochen(s, heute: heute).flatMap(\.sessions).map(\.id), ["gestern"])
    }

    func testEinheitUeberMitternachtOhneEndeLaeuftNochAberVergesseneZaehlt() {
        // Start gestern 23:40, jetzt 00:30: läuft noch (weniger als 3 h her). Eine von gestern Abend, die jetzt 4 h alt ist, wurde vergessen und zählt.
        let nachts = GymSession(id: "nacht", tag: nil, start: Datum.datum("2026-11-10").addingTimeInterval(23 * 3600 + 40 * 60), ende: nil,
                                laeufe: [lauf("bank", [satz(50, 10)])])
        let jetzt = Datum.datum("2026-11-11").addingTimeInterval(30 * 60)
        XCTAssertFalse(FortschrittLogik.beendet(nachts, heute: "2026-11-11", jetzt: jetzt))
        XCTAssertEqual(FortschrittLogik.vergleich([nachts], plan: .leer, heute: "2026-11-11", jetzt: jetzt, katalog: katalog).einheiten, 0)
        XCTAssertTrue(FortschrittLogik.nachWochen([nachts], heute: "2026-11-11", jetzt: jetzt).isEmpty)
        XCTAssertEqual(FortschrittLogik.wochen([nachts], heute: "2026-11-11", jetzt: jetzt, art: .volumen).map(\.wert).reduce(0, +), 0)
        XCTAssertTrue(FortschrittLogik.beendet(nachts, heute: "2026-11-11", jetzt: jetzt.addingTimeInterval(4 * 3600)), "vergessen: über 3 h her")
        var fertig = nachts
        fertig.ende = nachts.start.addingTimeInterval(40 * 60)
        XCTAssertTrue(FortschrittLogik.beendet(fertig, heute: "2026-11-11", jetzt: jetzt), "mit Ende immer beendet")
    }

    func testWochengrenzeSonntag2330UndMontag0030() {
        // Sonntag 08.11. 23:30 gehört zur Woche vom 02.11., Montag 09.11. 00:30 zur neuen Woche vom 09.11.
        func nacht(_ id: String, _ tag: String, stunde: Double, _ s: PlanSatz) -> GymSession {
            let start = Datum.datum(tag).addingTimeInterval(stunde * 3600)
            return GymSession(id: id, tag: nil, start: start, ende: start.addingTimeInterval(1800), laeufe: [lauf("bank", [s])])
        }
        let s = [nacht("so", "2026-11-08", stunde: 23.5, satz(100, 10)), nacht("mo", "2026-11-09", stunde: 0.5, satz(50, 10))]   // 1000 kg, 500 kg

        let amSonntag = FortschrittLogik.vergleich(s, plan: .leer, heute: "2026-11-08", katalog: katalog)
        XCTAssertEqual(amSonntag.einheiten, 1, "der Montag liegt noch in der Zukunft")
        XCTAssertEqual(amSonntag.volumen, 1000, accuracy: 0.001)
        let amMontag = FortschrittLogik.vergleich(s, plan: .leer, heute: "2026-11-09", katalog: katalog)
        XCTAssertEqual(amMontag.einheiten, 1, "neue Woche: nur die Einheit von Montag 00:30")
        XCTAssertEqual(amMontag.volumen, 500, accuracy: 0.001)
        XCTAssertEqual(amMontag.einheitenSchnitt, 0.25, accuracy: 0.001, "die Einheit vom Sonntag steht im Schnitt der Wochen davor")

        XCTAssertEqual(FortschrittLogik.wochen(s, heute: "2026-11-08", art: .volumen).suffix(2).map(\.wert), [0, 1000], "am Sonntag zählt die Woche vom 02.11. noch")
        let wochen = FortschrittLogik.wochen(s, heute: "2026-11-09", art: .volumen)
        XCTAssertEqual(wochen.suffix(2).map(\.montag), ["2026-11-02", "2026-11-09"])
        XCTAssertEqual(wochen.suffix(2).map(\.wert), [1000, 500])
        XCTAssertEqual(FortschrittLogik.nachWochen(s, heute: "2026-11-09").map { $0.sessions.map(\.id) }, [["mo"], ["so"]])
    }

    func testAchtWochenMontageUeberDieZeitumstellungImAbstandVonSiebenTagen() {
        // Die Uhr wird am 25.10.2026 zurückgestellt: eine Woche hat dort 7 Tage und eine Stunde. Gezählt wird nach Kalendertagen.
        let wochen = FortschrittLogik.wochen([], heute: "2026-11-09", art: .dauer)
        XCTAssertEqual(wochen.count, 8)
        XCTAssertEqual(wochen.first?.montag, "2026-09-21")
        XCTAssertTrue(wochen.allSatisfy { Datum.wochentag($0.montag) == 1 })
        for (a, b) in zip(wochen, wochen.dropFirst()) {
            XCTAssertEqual(Datum.tageZwischen(a.montag, b.montag), 7, "\(a.montag) bis \(b.montag)")
        }
        XCTAssertTrue(wochen.map(\.montag).contains("2026-10-19") && wochen.map(\.montag).contains("2026-10-26"))
    }

    // MARK: Wochen fürs Diagramm

    func testWochenLiefernAchtWochenAeltesteZuerstMitNullen() {
        let s = [einheit("a", "2026-11-03", minuten: 75, [lauf("bank", [satz(50, 10), satz(50, 10)])]),
                 einheit("b", "2026-11-10", minuten: 62, [lauf("bank", [satz(60, 5)])]),
                 einheit("alt", "2026-09-20", [lauf("bank", [satz(99, 10)])])]   // Woche 14.09., außerhalb der acht Wochen
        let volumen = FortschrittLogik.wochen(s, heute: heute, art: .volumen)
        XCTAssertEqual(volumen.count, 8)
        XCTAssertEqual(volumen.first?.montag, "2026-09-21")
        XCTAssertEqual(volumen.last?.montag, "2026-11-09")
        XCTAssertEqual(volumen.map(\.wert), [0, 0, 0, 0, 0, 0, 1000, 300])
        XCTAssertEqual(FortschrittLogik.wochen(s, heute: heute, art: .dauer).map(\.wert), [0, 0, 0, 0, 0, 0, 75, 62], "Dauer in Minuten")
        XCTAssertEqual(FortschrittLogik.wochen(s, heute: heute, art: .wiederholungen).map(\.wert), [0, 0, 0, 0, 0, 0, 20, 5])
        XCTAssertEqual(FortschrittLogik.wochen(s, heute: heute, art: .volumen, anzahl: 3).map(\.montag), ["2026-10-26", "2026-11-02", "2026-11-09"])
    }

    // MARK: Nach Wochen

    func testNachWochenTitelUndJahreswechselKW52NachKW1() {
        XCTAssertEqual(FortschrittLogik.kalenderwoche("2026-12-21"), 52)
        XCTAssertEqual(FortschrittLogik.kalenderwoche("2026-12-28"), 53, "ISO: die Woche mit dem 01.01. gehört nicht schon zu 1")
        XCTAssertEqual(FortschrittLogik.kalenderwoche("2027-01-04"), 1)

        let s = [einheit("w1", "2027-01-05", [lauf("bank", [satz(50, 5)])]),
                 einheit("w53", "2026-12-30", [lauf("bank", [satz(50, 5)])]),
                 einheit("w53b", "2026-12-29", [lauf("bank", [satz(50, 5)])]),
                 einheit("w52", "2026-12-22", [lauf("bank", [satz(50, 5)])])]
        let gruppen = FortschrittLogik.nachWochen(s, heute: "2027-01-20")
        XCTAssertEqual(gruppen.map(\.titel), ["KW 1", "KW 53", "KW 52"])
        XCTAssertEqual(gruppen[1].sessions.map(\.id), ["w53", "w53b"], "in der Woche neueste zuerst")

        let nah = FortschrittLogik.nachWochen(s, heute: "2027-01-06")
        XCTAssertEqual(nah.map(\.titel), ["Diese Woche", "Letzte Woche", "KW 52"])
    }

    // MARK: Leer

    func testOhneTrainingLeereListenUndKeinSatz() {
        let tage = [TrainingsTag(id: "t1", name: "Push", wochentage: [1], uebungen: [planUebung("u1", "bank")])]
        let v = FortschrittLogik.vergleich([], plan: plan(tage), heute: heute, katalog: katalog)
        XCTAssertEqual(v, TrainingsWochenVergleich(einheiten: 0, einheitenSchnitt: 0, volumen: 0, volumenSchnitt: 0, saetze: 0, saetzeSchnitt: 0, gestiegen: 0, hauptuebungen: 0))
        XCTAssertNil(FortschrittLogik.satz(v, geplantRest: 2))
        XCTAssertTrue(FortschrittLogik.gewichte([], plan: plan(tage), heute: heute, katalog: katalog).isEmpty)
        XCTAssertTrue(FortschrittLogik.nachWochen([], heute: heute).isEmpty)
        XCTAssertEqual(FortschrittLogik.wochen([], heute: heute, art: .dauer).map(\.wert), Array(repeating: 0, count: 8))
    }

    // MARK: Satz und Planung

    func testSatzUnterWieGehtsDir() {
        let v = TrainingsWochenVergleich(einheiten: 2, einheitenSchnitt: 3.8, volumen: 12900, volumenSchnitt: 19700, saetze: 22, saetzeSchnitt: 46, gestiegen: 5, hauptuebungen: 7)
        XCTAssertEqual(FortschrittLogik.satz(v, geplantRest: 2), "5 von 7 Hauptübungen sind gestiegen. Die Woche läuft noch, 2 Trainings sind geplant.")
        XCTAssertEqual(FortschrittLogik.satz(v, geplantRest: 1), "5 von 7 Hauptübungen sind gestiegen. Die Woche läuft noch, 1 Training ist geplant.")
        XCTAssertEqual(FortschrittLogik.satz(v, geplantRest: 0), "5 von 7 Hauptübungen sind gestiegen.")
        var eine = v
        eine.hauptuebungen = 1
        eine.gestiegen = 1
        XCTAssertEqual(FortschrittLogik.satz(eine, geplantRest: 0), "1 von 1 Hauptübung ist gestiegen.")
    }

    func testGeplantRestZaehltHeuteNurOhneEinheitUndNimmtDenEffektivenPlan() {
        // Plan Mo, Mi, Fr; heute Mittwoch.
        let tage = [TrainingsTag(id: "t1", name: "A", wochentage: [1, 3, 5], uebungen: [])]
        XCTAssertEqual(FortschrittLogik.geplantRest(plan(tage), sessions: [], heute: heute), 2, "Mittwoch (heute, noch nicht trainiert) und Freitag")
        let heuteGemacht = [einheit("a", "2026-11-11", [lauf("bank", [satz(50, 5)])])]
        XCTAssertEqual(FortschrittLogik.geplantRest(plan(tage), sessions: heuteGemacht, heute: heute), 1)
        XCTAssertEqual(FortschrittLogik.geplantRest(.leer, sessions: [], heute: heute), 0)
    }

    func testGeplantRestAmSonntagZaehltNurHeuteUndKeinenMontag() {
        let tage = [TrainingsTag(id: "t1", name: "A", wochentage: [1, 7], uebungen: [])]
        XCTAssertEqual(FortschrittLogik.geplantRest(plan(tage), sessions: [], heute: "2026-11-08"), 1, "Sonntag selbst, der nächste Montag gehört zur neuen Woche")
        let gemacht = [einheit("a", "2026-11-08", [lauf("bank", [satz(50, 5)])])]
        XCTAssertEqual(FortschrittLogik.geplantRest(plan(tage), sessions: gemacht, heute: "2026-11-08"), 0)
        XCTAssertEqual(FortschrittLogik.geplantRest(plan(tage), sessions: gemacht, heute: "2026-11-09"), 2, "am Montag: Montag und Sonntag stehen noch an")
    }

    func testVolumenTextGrenzeNachDemRunden() {
        XCTAssertEqual(FortschrittLogik.volumenText(9999.4), "9.999 kg")
        XCTAssertEqual(FortschrittLogik.volumenText(9999.6), "10,0 t", "nicht \"10.000 kg\" neben \"10,0 t\"")
        XCTAssertEqual(FortschrittLogik.volumenText(10_000), "10,0 t")
    }

    func testVolumenText() {
        XCTAssertEqual(FortschrittLogik.volumenText(12900), "12,9 t")
        XCTAssertEqual(FortschrittLogik.volumenText(9690), "9.690 kg")
        XCTAssertEqual(FortschrittLogik.volumenText(0), "0 kg")
    }

    // MARK: Einheit

    func testEinheitDatenMitRekordBestemSatzUndTitel() {
        let frueher = einheit("f", "2026-11-03", [lauf("bank", [satz(60, 8)])])
        let jetzt = einheit("j", "2026-11-10", minuten: 75, tagId: "t1", [
            lauf("bank", [satz(40, 10, typ: "w"), satz(60, 8), satz(62.5, 5)]),   // 62,5 kg ist schwerer als 60 kg: Rekord
            lauf("lat", [satz(50, 10)]),                                          // erstes Mal: kein Rekord
        ])
        let d = FortschrittLogik.einheit(jetzt, titel: "Push", frueher: [frueher, jetzt], katalog: katalog)
        XCTAssertEqual(d.titel, "Push")
        XCTAssertEqual(d.dauer, 75 * 60)
        XCTAssertEqual(d.saetze, 3)
        XCTAssertEqual(d.volumen, 480 + 312.5 + 500, accuracy: 0.001)
        XCTAssertEqual(d.rekorde, 1)
        XCTAssertEqual(d.zeilen.map(\.name), ["Bankdrücken", "Latzug"])
        XCTAssertEqual(d.zeilen.map(\.saetze), [2, 1])
        XCTAssertEqual(d.zeilen.map(\.rekord), [true, false])
        XCTAssertEqual(d.zeilen[0].bester?.kg, 62.5)
        XCTAssertEqual(FortschrittLogik.einheit(jetzt, titel: nil, frueher: [], katalog: katalog).titel, "Training")
    }

    func testTexteFuerGewichtZeileUndDatum() {
        XCTAssertEqual(FortschrittLogik.aenderungText(5), "+5 kg")
        XCTAssertEqual(FortschrittLogik.aenderungText(7.5), "+7,5 kg")
        XCTAssertEqual(FortschrittLogik.aenderungText(-2.5), "−2,5 kg")
        XCTAssertEqual(FortschrittLogik.aenderungText(0), "±0 kg")
        var z = GewichtZeile(uebungId: "bank", name: "Brustpresse", muskel: "Brust", wochen: [], aktuell: 32.5, aenderung4Wochen: 5)
        XCTAssertEqual(z.sprechtext, "Brustpresse, 32,5 Kilo, plus 5 seit 4 Wochen")
        z.aenderung4Wochen = 0
        XCTAssertEqual(z.sprechtext, "Brustpresse, 32,5 Kilo, unverändert seit 4 Wochen")
        let tag = FortschrittLogik.kurzDatum(Datum.datum("2026-11-11").addingTimeInterval(18 * 3600))
        XCTAssertTrue(tag.contains("11") && tag.contains("Nov") && tag.contains("Mi"), tag)
        XCTAssertTrue(FortschrittLogik.wochenSpanne("2026-10-05").contains("5.") && FortschrittLogik.wochenSpanne("2026-10-05").contains("11."))
    }
}
