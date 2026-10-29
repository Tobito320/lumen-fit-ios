import XCTest
@testable import LumenFit

/// Das laufende Training: Haken, Pause von selbst, Rekord einmal, Supersatz ohne eigene Pause, Steuerung ohne Oberfläche, Beenden.
@MainActor
final class GymSitzungTests: XCTestCase {
    private func aufbau(healthSchreiben: Bool = false, plan: TrainingsPlan = GymTestAufbau.plan()) throws -> GymTestAufbau {
        let a = try GymTestAufbau(ordner: try tempOrdner(), healthSchreiben: healthSchreiben)
        a.daten.training.planSichern(plan)
        return a
    }

    func testStarteChecktEinUndHakeltDasGymHaekchen() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        XCTAssertNotNil(a.sitzung.sessionId)
        XCTAssertEqual(a.sitzung.laufende?.tag, "push")
        XCTAssertTrue(a.daten.habits.gymAbgehakt(Datum.text(a.uhr.lesen)))
        XCTAssertEqual(a.sitzung.liste.map(\.id), ["a", "b"])
        XCTAssertEqual(a.puls.gestartet, 1)
        // Noch einmal starten setzt das laufende Training fort, es entsteht kein zweites.
        a.sitzung.starte(planTag: "push")
        XCTAssertEqual(a.daten.training.sessions.count, 1)
    }

    func testDerHakenStartetDiePauseVonSelbstMitDerZeitDerUebung() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        XCTAssertNil(a.sitzung.pause)
        a.sitzung.haken(0, 0)
        XCTAssertEqual(a.sitzung.liste[0].saetze[0].ok, true)
        XCTAssertEqual(a.sitzung.pause?.ziel, 90) // eigene Pause der Übung
        XCTAssertEqual(a.sitzung.pause?.plan, "a")
        XCTAssertEqual(a.sitzung.pause?.satz, 0)
        XCTAssertEqual(a.sitzung.pause?.seit, a.uhr.lesen)
        // Die übrigen Übungen pausieren mit dem Standard.
        a.sitzung.haken(1, 0)
        XCTAssertEqual(a.sitzung.pause?.ziel, 120)
    }

    func testDieLaengeDerPauseGehtAnDenSatzDavor() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.uhr.vor(sekunden: 75)
        a.sitzung.haken(0, 1)
        XCTAssertEqual(a.sitzung.liste[0].saetze[0].pause, 75)
        let gesendet = a.daten.training.laufende()?.laeufe.first?.stand
        XCTAssertEqual(gesendet?.first?.pause, 75)
        XCTAssertEqual(gesendet?.filter { $0.ok == true }.count, 2)
    }

    func testPlusMinusFuenfzehnSekundenAufDieLaufendePause() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.sitzung.pauseAendern(sekunden: 15)
        XCTAssertEqual(a.sitzung.pause?.ziel, 105)
        a.sitzung.pauseAendern(sekunden: -15)
        a.sitzung.pauseAendern(sekunden: -15)
        a.sitzung.pauseAendern(sekunden: -15)
        a.sitzung.pauseAendern(sekunden: -15)
        a.sitzung.pauseAendern(sekunden: -15)
        a.sitzung.pauseAendern(sekunden: -15)
        a.sitzung.pauseAendern(sekunden: -15)
        XCTAssertEqual(a.sitzung.pause?.ziel, 15) // nie unter 15 Sekunden
    }

    func testPauseEndeMeldetEinmalHaptikUndBand() async throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.sitzung.pauseIstVorbei()
        XCTAssertEqual(a.sitzung.pauseEndeZaehler, 0, "noch nicht vorbei")
        a.uhr.vor(sekunden: 91)
        a.sitzung.pauseIstVorbei()
        a.sitzung.pauseIstVorbei()
        XCTAssertEqual(a.sitzung.pauseEndeZaehler, 1)
        await a.sitzung.bandAufgabe?.value
        XCTAssertEqual(a.band.muster, [.pauseEnde])
    }

    func testNochmalTippenNimmtDenHakenUndDiePauseZurueck() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.sitzung.haken(0, 0)
        XCTAssertNil(a.sitzung.liste[0].saetze[0].ok)
        XCTAssertNil(a.sitzung.pause)
        XCTAssertEqual(a.sitzung.saetzeZahl, 0)
    }

    // MARK: - Rekord

    func testRekordErscheintEinmalProRekord() throws {
        let a = try aufbau()
        a.fruehereEinheit(kg: 60, wdh: 10)
        a.sitzung.starte(planTag: "push")
        a.sitzung.gewicht(0, 0, richtung: 1) // 62,5 kg
        a.sitzung.wiederholungen(0, 0, richtung: -1) // die Zeile startet mit den 10 vom letzten Mal: zurück auf 8
        a.sitzung.wiederholungen(0, 0, richtung: -1)
        a.sitzung.haken(0, 0)
        // 62,5 × 8 gegen 60 × 10: schwerer; 1RM 79,2 und Volumen 500 liegen unter 80 und 600.
        XCTAssertEqual(a.sitzung.toast?.titel, "Neuer Rekord: Gewicht")
        XCTAssertEqual(a.sitzung.toast?.stimmung, .stolz)
        // Haken weg und wieder dran: derselbe Rekord meldet sich nicht noch einmal.
        a.sitzung.toast = nil
        a.sitzung.haken(0, 0)
        a.sitzung.haken(0, 0)
        XCTAssertNil(a.sitzung.toast)
        // Der zweite Satz mit demselben Gewicht bricht nichts.
        a.sitzung.gewicht(0, 1, richtung: 1)
        a.sitzung.haken(0, 1)
        XCTAssertNil(a.sitzung.toast)
        // Ein noch schwererer Satz (65 × 8: Gewicht und 1RM 82,3 über 80) ist ein neuer Rekord.
        a.sitzung.gewicht(0, 2, richtung: 1)
        a.sitzung.gewicht(0, 2, richtung: 1)
        a.sitzung.haken(0, 2)
        XCTAssertEqual(a.sitzung.toast?.titel, "Neue Rekorde: Gewicht, 1RM")
    }

    func testDasErsteTrainingDerUebungHatKeinenRekord() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.gewicht(0, 0, richtung: 1)
        a.sitzung.haken(0, 0)
        XCTAssertNil(a.sitzung.toast)
    }

    func testAufwaermsaetzeZaehlenNichtFuerVolumenUndRekorde() throws {
        let a = try aufbau()
        a.fruehereEinheit(kg: 60, wdh: 10)
        a.sitzung.starte(planTag: "push")
        a.sitzung.typ(0, 0, "w")
        a.sitzung.gewicht(0, 0, richtung: 1)
        a.sitzung.gewicht(0, 0, richtung: 1) // 65 kg im Aufwärmsatz: schwerer als 60, aber Aufwärmen
        a.sitzung.haken(0, 0)
        XCTAssertNil(a.sitzung.toast)
        XCTAssertEqual(a.sitzung.volumen, 0)
        XCTAssertEqual(a.sitzung.liste[0].saetze[0].kuerzel, "W")
        a.sitzung.haken(0, 1)
        XCTAssertEqual(a.sitzung.volumen, 480) // nur der zweite Satz: 60 × 8
        XCTAssertEqual(a.sitzung.saetzeZahl, 2) // gezählt wird jeder Haken, das Volumen nur Arbeitssätze
    }

    // MARK: - Supersatz

    func testSupersatzWechseltDieUebungOhneEigenePause() throws {
        let a = try aufbau(plan: GymTestAufbau.plan(supersatz: true))
        a.sitzung.starte(planTag: "push")
        XCTAssertEqual(a.sitzung.dran?.uebung, 0)
        a.sitzung.haken(0, 0)
        XCTAssertNil(a.sitzung.pause, "A zu B: keine Pause")
        XCTAssertEqual(a.sitzung.dran?.uebung, 1)
        a.sitzung.haken(1, 0)
        XCTAssertEqual(a.sitzung.pause?.ziel, 120, "nach dem Paar die längere Pause: B hat den Standard, A 90")
        XCTAssertEqual(a.sitzung.dran?.uebung, 0)
        XCTAssertEqual(a.sitzung.dran?.satz, 1)
    }

    // MARK: - Steuerung ohne Oberfläche

    func testSatzFertigLaeuftOhneOberflaecheUndMeldetDieLiveAnzeige() async throws {
        let a = try aufbau()
        // Die App startet im Hintergrund: das Training steht nur im Store, eine frische Sitzung kennt es noch nicht.
        _ = a.daten.training.einchecken(tag: "push")
        let intent = GymSitzung(umgebung: a.umgebung)
        XCTAssertNil(intent.sessionId)
        intent.satzFertig()
        XCTAssertEqual(intent.liste[0].saetze[0].ok, true)
        XCTAssertEqual(a.daten.training.laufende()?.laeufe.first?.stand?.first?.ok, true, "der Haken ist im Store")
        XCTAssertNotNil(intent.pause)
        await intent.liveAufgabe?.value
        let letzter = try XCTUnwrap(a.live.staende.last ?? nil)
        XCTAssertEqual(letzter.satz, 2)
        XCTAssertEqual(letzter.von, 3)
        XCTAssertNotNil(letzter.pauseEnde)
        XCTAssertEqual(letzter.planName, "Push")
    }

    func testSatzFertigOhneLaufendesTrainingTutNichts() throws {
        let a = try aufbau()
        a.sitzung.satzFertig()
        XCTAssertNil(a.sitzung.sessionId)
        XCTAssertTrue(a.daten.training.sessions.isEmpty)
    }

    func testDieSitzungDerAppIstDieSteuerungDesPorts() throws {
        let u = AppUmgebung.vorschau()
        let s = GymSitzung.von(u)
        XCTAssertTrue(u.trainingSteuerung === s)
        XCTAssertTrue(GymSitzung.von(u) === s)
    }

    func testStarteUeberDenPortLaeuftDurch() throws {
        let a = try aufbau()
        let port: any TrainingSteuerung = a.umgebung.trainingSteuerung
        port.starte(planTag: "push")
        port.satzFertig()
        port.pauseAendern(sekunden: 15)
        XCTAssertEqual(a.sitzung.saetzeZahl, 1)
        XCTAssertEqual(a.sitzung.pause?.ziel, 105)
        port.beende()
        XCTAssertNil(a.daten.training.laufende())
    }

    // MARK: - Beenden

    func testBeendenSendetSaetzeRekordeUndPulsAnAuschecken() async throws {
        let a = try aufbau()
        a.fruehereEinheit(kg: 60, wdh: 10)
        a.sitzung.starte(planTag: "push")
        a.sitzung.gewicht(0, 0, richtung: 1)
        a.sitzung.haken(0, 0)
        a.sitzung.haken(0, 1)
        a.uhr.vor(sekunden: 1800)
        a.sitzung.beende()
        await a.sitzung.endeAufgabe?.value
        let fertig = try XCTUnwrap(a.daten.training.sessions.first { $0.ende != nil && $0.id != "frueher-7" })
        XCTAssertEqual(fertig.puls, 118)
        XCTAssertEqual(fertig.kcal, 240)
        XCTAssertNil(a.sitzung.sessionId)
        await a.sitzung.liveAufgabe?.value
        let letzteAnzeige = try XCTUnwrap(a.live.staende.last)
        XCTAssertNil(letzteAnzeige, "die Live-Anzeige wird beendet")
        let ops = a.daten.raum.ops(arten: ["gym.checkout"]).compactMap { $0.daten(GymD.self) }.filter { $0.status == "ende" }
        XCTAssertEqual(ops.first?.zahl, 2)
        XCTAssertEqual(ops.first?.rekorde, 1)
        XCTAssertEqual(ops.first?.minuten, 30)
    }

    func testHealthBekommtDasTrainingNurMitDemSchalter() async throws {
        let aus = try aufbau(healthSchreiben: false)
        aus.sitzung.starte(planTag: "push")
        aus.sitzung.haken(0, 0)
        aus.sitzung.beende()
        await aus.sitzung.endeAufgabe?.value
        XCTAssertTrue(aus.schreiber.trainings.isEmpty, "Schalter aus: nichts nach Health")
        XCTAssertEqual(aus.puls.beendet, [false])

        let an = try aufbau(healthSchreiben: true)
        an.sitzung.starte(planTag: "push")
        an.sitzung.haken(0, 0)
        an.uhr.vor(sekunden: 600)
        an.sitzung.beende()
        await an.sitzung.endeAufgabe?.value
        XCTAssertEqual(an.schreiber.trainings.count, 1)
        XCTAssertEqual(an.schreiber.trainings.first?.ende != nil, true)
        XCTAssertEqual(an.puls.beendet, [true])
    }

    func testHatDieMessungDasTrainingSelbstGeschriebenSchreibtDerSchreiberNichtNochEinmal() async throws {
        let a = try aufbau(healthSchreiben: true)
        a.puls.schreibtSelbst = true
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.sitzung.beende()
        await a.sitzung.endeAufgabe?.value
        XCTAssertTrue(a.schreiber.trainings.isEmpty, "sonst stünde es doppelt in Health")
    }

    func testVerwerfenSpeichertNichts() async throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        a.sitzung.verwerfen()
        await a.sitzung.endeAufgabe?.value
        XCTAssertTrue(a.daten.training.sessions.isEmpty)
        XCTAssertNil(a.sitzung.sessionId)
    }

    // MARK: - Studio-Hinweis, Tausch, Auslassen, Plan

    func testStudioHinweisBeimEinchecken() throws {
        let a = try aufbau()
        a.sitzung.studio?.aendere { $0.name = "Testhalle"; $0.oeffnung = StudioOeffnung(werktage: .init(von: 8 * 60, bis: 22 * 60)) }
        a.sitzung.starte(planTag: "push") // 12:00 an einem Mittwoch: offen
        XCTAssertNil(a.sitzung.studioHinweis)
        a.sitzung.beende()
        a.uhr.setze(Datum.datum("2026-09-24").addingTimeInterval(5 * 3600)) // Donnerstag 05:00
        a.sitzung.starte(planTag: "push")
        XCTAssertEqual(a.sitzung.studioHinweis, "Das Studio öffnet erst um 08:00.")
        a.sitzung.hinweisGelesen()
        XCTAssertNil(a.sitzung.studioHinweis)
    }

    func testAusweichenTauschtDieUebungVorDemErstenHaken() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        let alt = try XCTUnwrap(UebungsKatalog.nachId["znQUdHY"])
        a.sitzung.ausweichen(1, zu: alt)
        XCTAssertEqual(a.sitzung.liste[1].planUebung.uebung, "znQUdHY")
        XCTAssertEqual(a.sitzung.liste[1].ersatzFuer, "903mzG8")
        XCTAssertEqual(a.sitzung.liste[1].id, "b", "die Plan-Id bleibt")
        XCTAssertEqual(a.daten.training.laufende()?.laeufe.first { $0.plan == "b" }?.uebung, "znQUdHY")
        // Nach dem ersten Haken geht es nicht mehr.
        a.sitzung.haken(1, 0)
        let noch = try XCTUnwrap(UebungsKatalog.nachId["67n3r98"])
        a.sitzung.ausweichen(1, zu: noch)
        XCTAssertEqual(a.sitzung.liste[1].planUebung.uebung, "znQUdHY")
    }

    func testAuslassenUndWiederAufnehmen() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.auslassen(0)
        XCTAssertTrue(a.sitzung.liste[0].ausgelassen)
        XCTAssertEqual(a.sitzung.dran?.uebung, 1)
        a.sitzung.wiederAufnehmen(0)
        XCTAssertFalse(a.sitzung.liste[0].ausgelassen)
        XCTAssertEqual(a.sitzung.liste[0].saetze.count, 3)
        XCTAssertEqual(a.sitzung.dran?.uebung, 0)
    }

    func testNotizUndEigenePauseBleibenImPlan() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.notiz(0, "  Sitz auf Stufe 4  ")
        a.sitzung.pauseZiel(0, 60)
        let u = try XCTUnwrap(a.daten.training.plan.tage[0].uebungen.first { $0.id == "a" })
        XCTAssertEqual(u.notiz, "Sitz auf Stufe 4")
        XCTAssertEqual(u.pause, 60)
        a.sitzung.notiz(0, " ")
        XCTAssertNil(a.daten.training.plan.tage[0].uebungen[0].notiz)
    }

    func testSupersatzKoppelnSchreibtDenPlan() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.supersatz(0, an: true)
        XCTAssertEqual(a.daten.training.plan.tage[0].uebungen[0].supersatz, true)
        XCTAssertEqual(a.sitzung.liste[0].planUebung.supersatz, true)
        a.sitzung.supersatz(0, an: false)
        XCTAssertNil(a.daten.training.plan.tage[0].uebungen[0].supersatz)
    }

    func testEinUebungDazuUndAufwaermsaetze() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        let k = try XCTUnwrap(UebungsKatalog.nachId["znQUdHY"])
        a.sitzung.uebungDazu(k)
        XCTAssertEqual(a.sitzung.liste.count, 3)
        XCTAssertTrue(a.sitzung.liste[2].extra)
        a.sitzung.aufwaermen(0, arbeit: 60)
        XCTAssertEqual(a.sitzung.liste[0].saetze.map(\.typ), ["w", "w", "w", nil, nil, nil])
        XCTAssertEqual(a.sitzung.liste[0].saetze.first?.kg, 25)
        a.sitzung.uebungWeg(2)
        XCTAssertEqual(a.sitzung.liste.count, 2)
    }

    func testPauseUeberlebtEinenNeustartDerSitzung() throws {
        let a = try aufbau()
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        let neu = GymSitzung(umgebung: a.umgebung)
        neu.ladeWennNoetig()
        XCTAssertEqual(neu.pause, a.sitzung.pause)
        XCTAssertEqual(neu.liste[0].saetze[0].ok, true)
    }

    func testCardioAbschliessenTraegtLaufbandEin() throws {
        let a = try aufbau()
        var plan = GymTestAufbau.plan()
        // Eine Cardio-Übung aus dem Katalog, die das Laufband meint.
        let laufband = try XCTUnwrap(UebungsKatalog.alle.first { TrainingLogik.cardioGeraet($0) == "laufband" })
        plan.tage[0].uebungen.append(PlanUebung(id: "c", uebung: laufband.id, name: nil, saetze: [], minuten: 20))
        a.daten.training.planSichern(plan)
        a.sitzung.starte(planTag: "push")
        a.sitzung.cardioAbschliessen(2, minuten: 22, km: 3.1, kcal: 210, puls: 135)
        XCTAssertTrue(a.sitzung.liste[2].cardioFertig)
        let eintrag = try XCTUnwrap(a.daten.training.cardio(am: Datum.text(a.uhr.lesen)).first)
        XCTAssertEqual(eintrag.minuten, 22)
        XCTAssertEqual(eintrag.km, 3.1)
        XCTAssertEqual(a.sitzung.cardioPuls?.puls(eintrag.id), 135)
        a.sitzung.cardioPuls?.setze(eintrag.id, puls: 5)
        XCTAssertNil(a.sitzung.cardioPuls?.puls(eintrag.id), "ein unmöglicher Puls wird nicht gespeichert")
    }
}
