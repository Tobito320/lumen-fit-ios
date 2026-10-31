import XCTest
@testable import LumenFit

/// Die Ansichten des Partners, Senderseite: die Freigaben plan, verlauf, tagebuch und koerper (Standard aus, jedes Feld genau einer Freigabe),
/// die Rechnung aus den Stores (Zusammenfassung ohne Rohdaten, begrenzt) und die Zeilen der Freigaben-Vorschau.
@MainActor
final class PartnerAnsichtenBauerTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt   // Donnerstag 29.10.2026, 10:00
    private let heute = "2026-10-29"

    private let plan = PartnerPlan(name: "Push Pull", tage: [PartnerPlanTag(name: "Push", wochentage: [1, 4], uebungen: [PartnerPlanUebung(name: "Bankdrücken", saetze: 3)])],
                                   ruhetage: [7])
    private let verlauf = PartnerVerlauf(imGym: true, imGymSeit: Date(timeIntervalSince1970: 1_793_000_000), imGymName: "Push",
                                         trainings: [PartnerTrainingKurz(tag: "2026-10-28", name: "Pull", minuten: 58, saetze: 14, uebungen: 5, kcal: 310)],
                                         woche: 2, serieWochen: 5, gesamt: 41)
    private let tagebuch = [PartnerTagebuchTag(tag: "2026-10-29", kcal: 1450, protein: 98, kohlenhydrate: 160, fett: 48,
                                               mahlzeiten: [PartnerMahlzeitKurz(mahlzeit: "mittag", name: "Reis", kcal: 720)])]
    private let koerper = ["gewicht": [PartnerMesspunkt(tag: "2026-10-28", zehntel: 635)]]

    private func eingabe(_ frei: Set<FreigabeArt>) -> ZusammenfassungBauer.Eingabe {
        ZusammenfassungBauer.Eingabe(
            name: "Beispiel Profil", jetzt: jetzt, freigaben: frei, schritte: 8_000, gymTageWoche: 2, schlafMinuten: 450, kcal: 1_900, ereignisse: [],
            plan: plan, verlauf: verlauf, tagebuch: tagebuch, tagebuchZiele: PartnerMakros(kcal: 2_100, protein: 120, kohlenhydrate: 230, fett: 70), koerper: koerper)
    }

    private func schluessel(_ frei: Set<FreigabeArt>) throws -> Set<String> {
        let daten = try LoveaVertrag.encoder().encode(ZusammenfassungBauer.baue(eingabe(frei)))
        let heuteJSON = try XCTUnwrap((try JSONSerialization.jsonObject(with: daten) as? [String: Any])?["heute"] as? [String: Any])
        return Set(heuteJSON.keys)
    }

    // MARK: Standard aus, jede Art allein

    func testOhneFreigabeKommtNichtsVonDenAnsichten() throws {
        XCTAssertEqual(try schluessel([]), ["tag"])
        XCTAssertEqual(ZusammenfassungBauer.baue(eingabe([])).heute, TagesZusammenfassung(tag: heute))
        XCTAssertTrue(VerbindungStore().freigaben.isEmpty, "Standard: nichts geteilt")
    }

    func testJedeNeueArtGibtNurIhreFelderFrei() throws {
        XCTAssertEqual(try schluessel([.plan]), ["tag", "plan"])
        XCTAssertEqual(try schluessel([.verlauf]), ["tag", "verlauf"])
        XCTAssertEqual(try schluessel([.tagebuch]), ["tag", "tagebuch", "tagebuchZiele"])
        XCTAssertEqual(try schluessel([.koerper]), ["tag", "koerper"])
        XCTAssertEqual(try schluessel([.schritte, .gym, .schlaf, .essen]).intersection(["plan", "verlauf", "tagebuch", "tagebuchZiele", "koerper"]), [],
                       "die alten Arten verraten nichts davon")
    }

    func testFelderUndInhalteKommenUnveraendertAn() {
        let alle = ZusammenfassungBauer.baue(eingabe(Set(FreigabeArt.allCases)))
        XCTAssertEqual(alle.heute.plan, plan)
        XCTAssertEqual(alle.heute.verlauf, verlauf)
        XCTAssertEqual(alle.heute.tagebuch, tagebuch)
        XCTAssertEqual(alle.heute.tagebuchZiele?.kcal, 2_100)
        XCTAssertEqual(alle.heute.koerper, koerper)
        XCTAssertEqual(alle.freigaben, FreigabeArt.allCases)
    }

    func testLeereQuellenWerdenKeinFeld() {
        var leer = eingabe(Set(FreigabeArt.allCases))
        leer.plan = nil
        leer.verlauf = nil
        leer.tagebuch = []
        leer.koerper = [:]
        let heuteWerte = ZusammenfassungBauer.baue(leer).heute
        XCTAssertNil(heuteWerte.plan)
        XCTAssertNil(heuteWerte.verlauf)
        XCTAssertNil(heuteWerte.tagebuch)
        XCTAssertNil(heuteWerte.tagebuchZiele, "Ziele ohne Tagebuch sagen nichts")
        XCTAssertNil(heuteWerte.koerper)
    }

    func testDateiMitAllemUeberlebtSchreibenUndLesen() throws {
        let original = ZusammenfassungBauer.baue(eingabe(Set(FreigabeArt.allCases)))
        let zurueck = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: LoveaVertrag.encoder().encode(original))
        XCTAssertEqual(zurueck, original)
    }

    func testAlleZehnArtenHabenNameErklaerungUndSymbol() {
        XCTAssertEqual(FreigabeArt.allCases.count, 10)
        for art in FreigabeArt.allCases {
            XCTAssertFalse(FreigabenVorschau.name(art).isEmpty)
            XCTAssertFalse(FreigabenVorschau.erklaerung(art).isEmpty)
            XCTAssertFalse(FreigabenVorschau.symbol(art).isEmpty)
        }
        XCTAssertTrue(FreigabenVorschau.erklaerung(.tagebuch).contains("Keine Fotos"), "das Versprechen steht im Text")
    }

    // MARK: Vorschau

    func testVorschauHatEineZeileJeFreigegebenerAnsicht() {
        let alle = ZusammenfassungBauer.baue(eingabe(Set(FreigabeArt.allCases)))
        XCTAssertEqual(FreigabenVorschau.ansichtsZeilen(alle).map(\.titel), ["Trainingsplan", "Training", "Tagebuch", "Körperwerte"])
        XCTAssertEqual(FreigabenVorschau.ansichtsZeilen(alle).map(\.wert), ["2 Tage", "Im Gym", "1 Tag", "63,5 kg"])
        XCTAssertTrue(FreigabenVorschau.ansichtsZeilen(ZusammenfassungBauer.baue(eingabe([.schritte]))).isEmpty)
        XCTAssertEqual(FreigabenVorschau.ansichtsZeilen(ZusammenfassungBauer.baue(eingabe([.plan]))).map(\.titel), ["Trainingsplan"])
    }

    // MARK: Rechnung aus den Stores

    private func satz(_ ok: Bool = true) -> PlanSatz { PlanSatz(wdh: 8, kg: 80, failure: false, ok: ok) }

    private func uebung(_ name: String, saetze: Int) -> PlanUebung {
        PlanUebung(id: "u-\(name)", uebung: PlanUebung.eigen, name: name, saetze: Array(repeating: satz(), count: saetze), minuten: nil)
    }

    func testPlanNurNamenWochentageUndSaetzeZahl() throws {
        let p = TrainingsPlan(tage: [TrainingsTag(id: "t1", name: "  Push ", wochentage: [4, 1, 1, 9, 0], uebungen: [uebung("Bankdrücken", saetze: 3)])],
                              ruhetage: [7, 3, 12], splitName: "Push Pull")
        let aus = try XCTUnwrap(PartnerAnsichtsDaten.plan(p))
        XCTAssertEqual(aus.name, "Push Pull")
        XCTAssertEqual(aus.tage, [PartnerPlanTag(name: "Push", wochentage: [1, 4], uebungen: [PartnerPlanUebung(name: "Bankdrücken", saetze: 3)])])
        XCTAssertEqual(aus.ruhetage, [3, 7])
        XCTAssertNil(PartnerAnsichtsDaten.plan(.leer), "ohne Tage gibt es keinen Plan")
    }

    func testPlanIstBegrenzt() throws {
        let viele = (0..<20).map { TrainingsTag(id: "t\($0)", name: "T", wochentage: [], uebungen: (0..<30).map { uebung("U\($0)", saetze: 1) }) }
        let aus = try XCTUnwrap(PartnerAnsichtsDaten.plan(TrainingsPlan(tage: viele)))
        XCTAssertEqual(aus.tage.count, PartnerAnsichtsDaten.planTage)
        XCTAssertEqual(aus.tage[0].uebungen.count, PartnerAnsichtsDaten.uebungenJeTag)
        XCTAssertNil(aus.name)
        XCTAssertNil(aus.ruhetage)
    }

    private func einheit(_ id: String, tag: String, minuten: Double?, saetze: Int, planTag: String? = nil) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let lauf = UebungsLauf(plan: "p-\(id)", uebung: "x", start: start, ende: start.addingTimeInterval(600), fertig: true,
                               saetze: Array(repeating: satz(), count: saetze))
        return GymSession(id: id, tag: planTag, start: start, ende: minuten.map { start.addingTimeInterval($0 * 60) }, laeufe: saetze > 0 ? [lauf] : [], kcal: 300)
    }

    func testVerlaufFasstZusammenOhneSaetzeUndGewichte() throws {
        let plan = TrainingsPlan(tage: [TrainingsTag(id: "t1", name: "Push", wochentage: [1], uebungen: [])])
        let sessions = [
            einheit("a", tag: "2026-10-26", minuten: 61, saetze: 18, planTag: "t1"),
            einheit("b", tag: "2026-10-28", minuten: nil, saetze: 6),
            einheit("c", tag: "2026-10-20", minuten: 40, saetze: 10),
            einheit("leer", tag: "2026-10-27", minuten: 30, saetze: 0),
        ]
        let laufend = einheit("l", tag: "2026-10-29", minuten: nil, saetze: 1, planTag: "t1")
        let v = PartnerAnsichtsDaten.verlauf(sessions: sessions + [laufend], plan: plan, laufende: laufend, heute: heute)
        XCTAssertEqual(v.imGym, true)
        XCTAssertEqual(v.imGymName, "Push")
        XCTAssertEqual(v.imGymSeit, laufend.start)
        XCTAssertEqual(v.trainings.map(\.tag), ["2026-10-29", "2026-10-28", "2026-10-26", "2026-10-20"], "neueste zuerst, die Einheit ohne Sätze fehlt")
        let a = try XCTUnwrap(v.trainings.first { $0.tag == "2026-10-26" })
        XCTAssertEqual(a, PartnerTrainingKurz(tag: "2026-10-26", name: "Push", minuten: 61, saetze: 18, uebungen: 1, kcal: 300))
        XCTAssertNil(v.trainings.first { $0.tag == "2026-10-28" }?.minuten, "ohne Ende keine Dauer")
        XCTAssertEqual(v.woche, 4, "26., 27., 28. und 29. liegen in dieser Woche")
        XCTAssertEqual(v.gesamt, 5)
    }

    func testVerlaufMitSaetzenGibtTageUndEinheitenNurAufWunsch() throws {
        let plan = TrainingsPlan(tage: [TrainingsTag(id: "t1", name: "Push", wochentage: [1], uebungen: [])])
        let a = einheit("a", tag: "2026-10-26", minuten: 61, saetze: 2, planTag: "t1")
        let b = einheit("b", tag: "2026-10-20", minuten: 40, saetze: 1)
        XCTAssertNil(PartnerAnsichtsDaten.verlauf(sessions: [a, b], plan: plan, laufende: nil, heute: heute).einheiten, "ohne gym keine Sätze")
        let v = PartnerAnsichtsDaten.verlauf(sessions: [a, b], plan: plan, laufende: nil, heute: heute, mitSaetzen: true)
        XCTAssertEqual(v.tage, ["2026-10-26", "2026-10-20"])
        let e = try XCTUnwrap(v.einheiten?.first)
        XCTAssertEqual(e.tag, "2026-10-26")
        XCTAssertEqual(e.name, "Push")
        XCTAssertEqual(e.uebungen.count, 1)
        XCTAssertEqual(e.uebungen[0].saetze.count, 2)
        XCTAssertEqual(e.uebungen[0].saetze[0], PartnerSatzKurz(wdh: 8, kg: 800, typ: nil))
    }

    func testVerlaufMitSaetzenBleibtInDenGrenzen() {
        let viele = (0..<500).map { einheit("s\($0)", tag: Datum.addTage("2026-10-29", -$0), minuten: 50, saetze: 20) }
        let v = PartnerAnsichtsDaten.verlauf(sessions: viele, plan: .leer, laufende: nil, heute: heute, mitSaetzen: true)
        XCTAssertEqual(v.tage?.count, PartnerAnsichtsDaten.tageMax)
        XCTAssertEqual(v.einheiten?.count, PartnerAnsichtsDaten.einheitenMax)
        XCTAssertEqual(v.einheiten?.first?.uebungen.first?.saetze.count, PartnerAnsichtsDaten.saetzeJeUebung)
    }

    func testVerlaufOhneTrainingIstLeerUndNichtImGym() {
        let v = PartnerAnsichtsDaten.verlauf(sessions: [], plan: .leer, laufende: nil, heute: heute)
        XCTAssertNil(v.imGym)
        XCTAssertTrue(v.trainings.isEmpty)
        XCTAssertEqual(v.gesamt, 0)
    }

    func testVerlaufZeigtHoechstensZehnEinheiten() {
        let viele = (0..<15).map { einheit("s\($0)", tag: Datum.addTage("2026-10-29", -$0), minuten: 50, saetze: 3) }
        XCTAssertEqual(PartnerAnsichtsDaten.verlauf(sessions: viele, plan: .leer, laufende: nil, heute: heute).trainings.count, PartnerAnsichtsDaten.trainingsMax)
    }

    private func essen(_ id: String, tag: String, name: String, kcal: Double, menge: Double = 100, mahlzeit: Mahlzeit = .mittag, weg: Bool? = nil) -> EssenEintrag {
        let l = Lebensmittel(id: "eigen-\(id)", name: name, pro100: Naehrwerte(kcal: kcal, protein: 10, kohlenhydrate: 20, fett: 5), bild: "foto.jpg")
        return EssenEintrag(id: id, datum: tag, mahlzeit: mahlzeit, menge: menge, einheit: .g, lebensmittel: l, geloescht: weg)
    }

    func testTagebuchNurNamenKalorienUndMakrosDerLetztenSiebenTage() {
        let tage: [String: [EssenEintrag]] = [
            "2026-10-29": [essen("1", tag: "2026-10-29", name: "Reis", kcal: 130, menge: 200), essen("2", tag: "2026-10-29", name: "Gelöscht", kcal: 999, weg: true)],
            "2026-10-27": [essen("3", tag: "2026-10-27", name: "Apfel", kcal: 52, mahlzeit: .snack)],
            "2026-10-22": [essen("4", tag: "2026-10-22", name: "Zu alt", kcal: 100)],
        ]
        let aus = PartnerAnsichtsDaten.tagebuch(heute: heute) { tage[$0] ?? [] }
        XCTAssertEqual(aus.map(\.tag), ["2026-10-29", "2026-10-27"], "neuester zuerst, nur Tage mit Einträgen, 22.10. ist älter als sieben Tage")
        XCTAssertEqual(aus[0].kcal, 260)
        XCTAssertEqual(aus[0].protein, 20)
        XCTAssertEqual(aus[0].mahlzeiten, [PartnerMahlzeitKurz(mahlzeit: "mittag", name: "Reis", kcal: 260)])
        XCTAssertEqual(aus[1].mahlzeiten.first?.mahlzeit, "snack")
        XCTAssertFalse(String(describing: aus).contains("foto"), "keine Fotos")
    }

    func testTagebuchIstBegrenzt() {
        let viele = (0..<50).map { essen("e\($0)", tag: heute, name: "Essen \($0)", kcal: 10) }
        XCTAssertEqual(PartnerAnsichtsDaten.tagebuch(heute: heute) { _ in viele }.first?.mahlzeiten.count, PartnerAnsichtsDaten.eintraegeJeTag)
    }

    func testKoerperNurArtenMitWertenUndHoechstensNeunzigPunkte() {
        let viele = Dictionary(uniqueKeysWithValues: (0..<120).map { (Datum.addTage("2026-06-01", $0), 700 + $0) })
        let aus = PartnerAnsichtsDaten.koerper([.gewicht: viele, .taille: ["2026-10-01": 0], .brust: [:], .koerperfett: ["2026-10-02": 185, "2026-10-01": 190]])
        XCTAssertEqual(Set(aus.keys), ["gewicht", "koerperfett"], "0 heißt kein Wert, leere Arten fehlen")
        XCTAssertEqual(aus["gewicht"]?.count, PartnerAnsichtsDaten.messpunkteJeArt)
        XCTAssertEqual(aus["gewicht"]?.last?.zehntel, 819, "die neuesten bleiben")
        XCTAssertEqual(aus["koerperfett"]?.map(\.tag), ["2026-10-01", "2026-10-02"], "älteste zuerst")
    }
}
