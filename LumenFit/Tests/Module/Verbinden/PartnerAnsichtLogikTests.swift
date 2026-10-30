import XCTest
@testable import LumenFit

/// Die Ansichten des Partners, Leserseite: Lage (nicht freigegeben, ohne Daten, veraltet), Einstiege, Worte und Rechnung der vier Ansichten als reine Logik.
@MainActor
final class PartnerAnsichtLogikTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt   // Donnerstag 29.10.2026, 10:00 (9:00 UTC)
    private let heute = "2026-10-29"

    private func fixture() throws -> ZusammenfassungDatei {
        try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: FixtureOrt.daten("Verbinden", "partner-ansichten.json"))
    }

    private func ohne(_ datei: ZusammenfassungDatei, _ art: FreigabeArt) -> ZusammenfassungDatei {
        var d = datei
        d.freigaben.removeAll { $0 == art }
        return d
    }

    // MARK: Lage

    func testKeinPartnerOderUnbekannteVersionHatKeineLage() throws {
        let d = try fixture()
        XCTAssertEqual(PartnerAnsichtLogik.lage(.nichtVerbunden, art: .plan), .keinPartner)
        XCTAssertEqual(PartnerAnsichtLogik.lage(.unbekannteVersion, art: .plan), .keinPartner)
        XCTAssertNil(PartnerAnsichtLogik.datei(.nichtVerbunden))
        XCTAssertEqual(PartnerAnsichtLogik.datei(.verbunden(d)), d)
        XCTAssertEqual(PartnerAnsichtLogik.datei(.veraltet(d)), d, "auch ältere Daten, dann mit Hinweis")
    }

    func testNichtFreigegebenSagtEsDeutlich() throws {
        let d = ohne(try fixture(), .plan)
        let lage = PartnerAnsichtLogik.lage(.verbunden(d), art: .plan)
        XCTAssertEqual(lage, .nichtFreigegeben("Beispiel Partner"))
        XCTAssertEqual(PartnerAnsichtLogik.leerSatz(lage, art: .plan), "Dein Partner hat das nicht freigegeben.")
        XCTAssertTrue(PartnerAnsichtLogik.einstiege(d, jetzt: jetzt).map(\.art).allSatisfy { $0 != .plan }, "ohne Freigabe auch kein Einstieg")
    }

    func testFreigegebenOhneDatenBleibtLeerAberAnders() throws {
        var d = try fixture()
        d.heute.plan = nil
        d.heute.tagebuch = []
        let plan = PartnerAnsichtLogik.lage(.verbunden(d), art: .plan)
        XCTAssertEqual(plan, .keineDaten("Beispiel Partner"))
        XCTAssertTrue(PartnerAnsichtLogik.leerSatz(plan, art: .plan).contains("noch nichts"))
        XCTAssertEqual(PartnerAnsichtLogik.lage(.verbunden(d), art: .tagebuch), .keineDaten("Beispiel Partner"))
        XCTAssertFalse(PartnerAnsichtLogik.einstiege(d, jetzt: jetzt).map(\.art).contains(.plan))
    }

    func testBereitUndVeraltetMitHinweis() throws {
        let d = try fixture()
        XCTAssertEqual(PartnerAnsichtLogik.lage(.verbunden(d), art: .koerper), .bereit(d, veraltet: false))
        XCTAssertEqual(PartnerAnsichtLogik.lage(.veraltet(d), art: .koerper), .bereit(d, veraltet: true))
        XCTAssertNil(PartnerAnsichtLogik.veraltetHinweis(d, veraltet: false))
        XCTAssertEqual(PartnerAnsichtLogik.veraltetHinweis(d, veraltet: true), "Stand vom 29.10. Beispiel Partner hat sich länger nicht gemeldet.")
    }

    // MARK: Einstiege

    func testEinstiegeInFesterReihenfolgeMitKernzeile() throws {
        let e = PartnerAnsichtLogik.einstiege(try fixture(), jetzt: jetzt)
        XCTAssertEqual(e.map(\.art), [.plan, .verlauf, .tagebuch, .koerper])
        XCTAssertEqual(e.map(\.untertitel), ["Push Pull Beine · 4 Trainingstage", "Im Gym (Push) seit 105 min", "Heute 1.450 kcal", "Gewicht 63,5 kg"])
        XCTAssertEqual(e.map(\.titel), ["Trainingsplan", "Training und Verlauf", "Tagebuch", "Körperwerte"])
        XCTAssertEqual(Set(e.map(\.symbol)).count, 4)
    }

    func testAlteDateiOhneAnsichtenHatKeinenEinstieg() throws {
        let alt = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: FixtureOrt.daten("Verbinden", "partner-beispiel.json"))
        XCTAssertTrue(PartnerAnsichtLogik.einstiege(alt, jetzt: jetzt).isEmpty)
    }

    func testFreigabeAllein_ohneDatenAberKeinEinstieg() throws {
        var d = try fixture()
        d.heute.koerper = nil
        XCTAssertFalse(PartnerAnsichtLogik.einstiege(d, jetzt: jetzt).map(\.art).contains(.koerper))
    }

    // MARK: Plan

    func testWocheZeigtTrainingRuheUndOffen() throws {
        let plan = try XCTUnwrap(try fixture().heute.plan)
        let s = PartnerAnsichtLogik.spalten(plan, heute: 4)
        XCTAssertEqual(s.map(\.titel), ["Push", "Pull", "Ruhe", "Push", "Pull", "Ruhe", "Ruhe"])
        XCTAssertEqual(s.filter(\.istHeute).map(\.kuerzel), ["Do"])
        XCTAssertEqual(s[2].beschreibung, "Ruhetag")
        XCTAssertEqual(s[3].langerName, "Donnerstag")
        let offen = PartnerAnsichtLogik.spalten(PartnerPlan(name: nil, tage: [PartnerPlanTag(name: "", wochentage: [1], uebungen: [])], ruhetage: nil), heute: 2)
        XCTAssertEqual(offen.map(\.titel), ["Training", "?", "?", "?", "?", "?", "?"])
        XCTAssertEqual(offen[1].beschreibung, "noch nicht geplant")
        XCTAssertEqual(PartnerAnsichtLogik.trainingsTage(plan), 4)
    }

    func testHeutigerTagUndTexte() throws {
        let plan = try XCTUnwrap(try fixture().heute.plan)
        XCTAssertEqual(PartnerAnsichtLogik.heutigerTag(plan, wochentag: 4)?.name, "Push")
        XCTAssertNil(PartnerAnsichtLogik.heutigerTag(plan, wochentag: 3), "Mittwoch ist Ruhetag")
        XCTAssertEqual(PartnerAnsichtLogik.wochentageText(plan.tage[0]), "Mo, Do")
        XCTAssertEqual(PartnerAnsichtLogik.wochentageText(PartnerPlanTag(name: "Frei", wochentage: [], uebungen: [])), "an jedem Tag möglich")
        XCTAssertEqual([0, 1, 3].map { PartnerAnsichtLogik.uebungText(PartnerPlanUebung(name: "x", saetze: $0)) }, ["Cardio oder frei", "1 Satz", "3 Sätze"])
    }

    // MARK: Verlauf

    func testStatusZeileNurWaehrendDieEinheitLaeuft() {
        let seit = jetzt.addingTimeInterval(-30 * 60)
        func v(_ imGym: Bool?, seit: Date?, name: String? = "Push") -> PartnerVerlauf { PartnerVerlauf(imGym: imGym, imGymSeit: seit, imGymName: name, trainings: []) }
        XCTAssertEqual(PartnerAnsichtLogik.statusZeile(v(true, seit: seit), jetzt: jetzt), "Im Gym (Push) seit 30 min")
        XCTAssertEqual(PartnerAnsichtLogik.statusZeile(v(true, seit: seit, name: nil), jetzt: jetzt), "Im Gym seit 30 min")
        XCTAssertEqual(PartnerAnsichtLogik.statusZeile(v(true, seit: jetzt.addingTimeInterval(-20), name: nil), jetzt: jetzt), "Im Gym")
        XCTAssertNil(PartnerAnsichtLogik.statusZeile(v(true, seit: jetzt.addingTimeInterval(-4 * 3600)), jetzt: jetzt), "nach drei Stunden gilt sie als vergessen")
        XCTAssertNil(PartnerAnsichtLogik.statusZeile(v(nil, seit: seit), jetzt: jetzt))
        XCTAssertNil(PartnerAnsichtLogik.statusZeile(v(true, seit: nil), jetzt: jetzt))
    }

    func testKennzahlenUndZeilen() throws {
        let verlauf = try XCTUnwrap(try fixture().heute.verlauf)
        XCTAssertEqual(PartnerAnsichtLogik.kennzahlen(verlauf).map(\.wert), [2, 5, 41])
        XCTAssertEqual(PartnerAnsichtLogik.kennzahlen(PartnerVerlauf(trainings: [])).map(\.wert), [0, 0, 0])
        let z = PartnerAnsichtLogik.trainingZeile(verlauf.trainings[0])
        XCTAssertEqual(z.titel, "Pull")
        XCTAssertEqual(z.detail, "Mi 28.10. · 58 min · 14 Sätze · 5 Übungen")
        let knapp = PartnerAnsichtLogik.trainingZeile(PartnerTrainingKurz(tag: "2026-10-23", name: nil, minuten: nil, saetze: 1, uebungen: 0))
        XCTAssertEqual(knapp.titel, "Training")
        XCTAssertEqual(knapp.detail, "Fr 23.10. · 1 Satz")
    }

    func testDauerPunkteAelteresZuerstUndGleicherTagZaehltZusammen() {
        let v = PartnerVerlauf(trainings: [
            PartnerTrainingKurz(tag: "2026-10-28", name: nil, minuten: 30, saetze: 1, uebungen: 1),
            PartnerTrainingKurz(tag: "2026-10-28", name: nil, minuten: 20, saetze: 1, uebungen: 1),
            PartnerTrainingKurz(tag: "2026-10-26", name: nil, minuten: nil, saetze: 1, uebungen: 1),
            PartnerTrainingKurz(tag: "2026-10-25", name: nil, minuten: 45, saetze: 1, uebungen: 1)])
        XCTAssertEqual(PartnerAnsichtLogik.dauerPunkte(v), [.init(tag: "2026-10-25", minuten: 45), .init(tag: "2026-10-28", minuten: 50)])
    }

    // MARK: Tagebuch

    func testTagebuchTageNeuesterZuerstUndNurMitFreigabe() throws {
        let d = try fixture()
        XCTAssertEqual(PartnerAnsichtLogik.tagebuchTage(d).map(\.tag), ["2026-10-29", "2026-10-28"])
        XCTAssertTrue(PartnerAnsichtLogik.tagebuchTage(ohne(d, .tagebuch)).isEmpty)
    }

    func testBlaetternBleibtInDenSiebenTagen() {
        XCTAssertEqual(PartnerAnsichtLogik.blaetterTage(heute: heute).count, 7)
        XCTAssertEqual(PartnerAnsichtLogik.blaettern(von: heute, richtung: -1, heute: heute), "2026-10-28")
        XCTAssertEqual(PartnerAnsichtLogik.blaettern(von: "2026-10-28", richtung: 1, heute: heute), heute)
        XCTAssertEqual(PartnerAnsichtLogik.blaettern(von: heute, richtung: 1, heute: heute), heute, "nicht über heute hinaus")
        XCTAssertEqual(PartnerAnsichtLogik.blaettern(von: "2026-10-23", richtung: -1, heute: heute), "2026-10-23", "nicht vor den siebten Tag")
        XCTAssertEqual(PartnerAnsichtLogik.blaettern(von: "2020-01-01", richtung: -1, heute: heute), heute, "ein fremder Tag springt auf heute")
    }

    func testGruppenInReihenfolgeMitSummenUndUnbekanntemAlsSnack() {
        let tag = PartnerTagebuchTag(tag: heute, kcal: 0, protein: 0, kohlenhydrate: 0, fett: 0, mahlzeiten: [
            PartnerMahlzeitKurz(mahlzeit: "abend", name: "Suppe", kcal: 300),
            PartnerMahlzeitKurz(mahlzeit: "fruehstueck", name: "Brot", kcal: 200),
            PartnerMahlzeitKurz(mahlzeit: "fruehstueck", name: "Ei", kcal: 80),
            PartnerMahlzeitKurz(mahlzeit: "nachts", name: "Keks", kcal: 50),
            PartnerMahlzeitKurz(mahlzeit: "snack", name: "Apfel", kcal: 60)])
        let g = PartnerAnsichtLogik.gruppen(tag)
        XCTAssertEqual(g.map(\.mahlzeit), [.fruehstueck, .abend, .snack])
        XCTAssertEqual(g.map(\.kcal), [280, 300, 110])
        XCTAssertEqual(g[2].eintraege.map(\.name), ["Apfel", "Keks"])
        XCTAssertTrue(PartnerAnsichtLogik.gruppen(PartnerTagebuchTag(tag: heute, kcal: 0, protein: 0, kohlenhydrate: 0, fett: 0, mahlzeiten: [])).isEmpty)
    }

    func testAnteilTitelUndZahl() {
        XCTAssertEqual(PartnerAnsichtLogik.anteil(50, ziel: 200), 0.25)
        XCTAssertEqual(PartnerAnsichtLogik.anteil(400, ziel: 200), 1, "über dem Ziel bleibt der Balken voll")
        XCTAssertEqual(PartnerAnsichtLogik.anteil(10, ziel: 0), 0)
        XCTAssertEqual(PartnerAnsichtLogik.tagTitel(heute, heute: heute), "Heute")
        XCTAssertEqual(PartnerAnsichtLogik.tagTitel("2026-10-28", heute: heute), "Gestern")
        XCTAssertEqual(PartnerAnsichtLogik.tagTitel("2026-10-27", heute: heute), Datum.anzeige("2026-10-27"))
        XCTAssertEqual(PartnerAnsichtLogik.zahl(1450), "1.450")
        XCTAssertEqual(PartnerAnsichtLogik.kurzDatum("2026-10-05"), "5.10.")
        XCTAssertEqual(PartnerAnsichtLogik.kurzDatum("kaputt"), "kaputt")
    }

    // MARK: Körper und Umschalter

    func testKoerperArtenPunkteUndFreigabe() throws {
        let d = try fixture()
        XCTAssertEqual(PartnerAnsichtLogik.koerperArten(d), [.gewicht, .taille])
        XCTAssertEqual(PartnerAnsichtLogik.punkte(d, .gewicht).map(\.zehntel), [642, 638, 635])
        XCTAssertTrue(PartnerAnsichtLogik.punkte(d, .brust).isEmpty)
        let ohneFreigabe = ohne(d, .koerper)
        XCTAssertTrue(PartnerAnsichtLogik.koerperArten(ohneFreigabe).isEmpty)
        XCTAssertTrue(PartnerAnsichtLogik.punkte(ohneFreigabe, .gewicht).isEmpty)
        var durcheinander = d
        durcheinander.heute.koerper = ["gewicht": [PartnerMesspunkt(tag: "2026-10-28", zehntel: 635), PartnerMesspunkt(tag: "2026-10-01", zehntel: 642), PartnerMesspunkt(tag: "2026-10-10", zehntel: 0)]]
        XCTAssertEqual(PartnerAnsichtLogik.punkte(durcheinander, .gewicht).map(\.tag), ["2026-10-01", "2026-10-28"], "älteste zuerst, 0 ist kein Wert")
    }

    func testUmschalterNurWennDerPartnerKoerperwerteGibt() throws {
        let d = try fixture()
        XCTAssertTrue(PartnerAnsichtLogik.umschalterSichtbar(.verbunden(d)))
        XCTAssertTrue(PartnerAnsichtLogik.umschalterSichtbar(.veraltet(d)))
        XCTAssertFalse(PartnerAnsichtLogik.umschalterSichtbar(.verbunden(ohne(d, .koerper))))
        XCTAssertFalse(PartnerAnsichtLogik.umschalterSichtbar(.nichtVerbunden))
        XCTAssertFalse(PartnerAnsichtLogik.umschalterSichtbar(.unbekannteVersion))
        var leer = d
        leer.heute.koerper = nil
        XCTAssertFalse(PartnerAnsichtLogik.umschalterSichtbar(.verbunden(leer)), "freigegeben, aber nichts da: kein Umschalter")
    }

    func testHatDatenJeArt() throws {
        let d = try fixture()
        for art in PartnerAnsichtLogik.ansichtsArten { XCTAssertTrue(PartnerAnsichtLogik.hatDaten(d, art), "\(art)") }
        let leer = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "x", freigaben: [], heute: TagesZusammenfassung(tag: heute), ereignisse: [])
        for art in PartnerAnsichtLogik.ansichtsArten { XCTAssertFalse(PartnerAnsichtLogik.hatDaten(leer, art), "\(art)") }
    }
}
