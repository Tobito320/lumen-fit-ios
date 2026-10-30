import XCTest
@testable import LumenFit

/// Eintrags-, Diagramm-, Gedächtnis- und Training-Marker des Coachs: Form prüfen, zum Vorschlag zusammenrechnen, Zeile bilden. Reine Logik.
final class CoachTrackingMarkerTests: XCTestCase {
    private func marker(_ roh: String) -> [CoachMarker.Art] { CoachMarker.zerlegen(roh).marker }

    // MARK: - Marker

    func testWasserMitUndOhneEinheitUndGrenzen() {
        XCTAssertEqual(marker("[[wasser: 250]]"), [.wasser(ml: 250)])
        XCTAssertEqual(marker("[[wasser: 500 ml]]"), [.wasser(ml: 500)])
        XCTAssertTrue(marker("[[wasser: 10]]").isEmpty)
        XCTAssertTrue(marker("[[wasser: 5000]]").isEmpty)
        XCTAssertTrue(marker("[[wasser: viel]]").isEmpty)
    }

    func testKreatinNurKreatinMitStandardportion() {
        XCTAssertEqual(marker("[[supplement: Kreatin]]"), [.kreatin(gramm: Habit.creatinGramm)])
        XCTAssertEqual(marker("[[supplement: kreatin | 7 g]]"), [.kreatin(gramm: 7)])
        XCTAssertTrue(marker("[[supplement: Koffein]]").isEmpty)
        XCTAssertTrue(marker("[[supplement: kreatin | 50]]").isEmpty)
    }

    func testSchlafGefuehl() {
        XCTAssertEqual(marker("[[gefuehl: schlaf | gut]]"), [.schlafGefuehl(.gut)])
        XCTAssertEqual(CoachMarker.Gefuehl.schlecht.wert, 1)
        XCTAssertTrue(marker("[[gefuehl: laune | gut]]").isEmpty)
        XCTAssertTrue(marker("[[gefuehl: schlaf | super]]").isEmpty)
    }

    func testGewichtNimmtNurEineNachkommastelleUndEinenSinnvollenBereich() {
        XCTAssertEqual(marker("[[gewicht: 81,3]]"), [.gewicht(kg: 81.3)])
        XCTAssertEqual(marker("[[gewicht: 81 kg]]"), [.gewicht(kg: 81)])
        XCTAssertTrue(marker("[[gewicht: 81,35]]").isEmpty)
        XCTAssertTrue(marker("[[gewicht: 12]]").isEmpty)
        XCTAssertTrue(marker("[[gewicht: 900]]").isEmpty)
    }

    func testEssenKurzformUndMahlzeitVollform() {
        guard case .essen(let e)? = marker("[[essen: Haferflocken | fruehstueck | 380 | 14 | 60 | 7]]").first else { return XCTFail("kein essen") }
        XCTAssertEqual(e.name, "Haferflocken")
        XCTAssertEqual(e.kcal, 380)
        XCTAssertEqual(e.art, .fruehstueck)
        XCTAssertEqual(e.protein, 14)
        guard case .mahlzeit(let m)? = marker("[[mahlzeit: mittag | Reis mit Huhn | 600 | 40 | 70 | 15]]").first else { return XCTFail("keine mahlzeit") }
        XCTAssertEqual(m.mahlzeit, .mittag)
        XCTAssertEqual(m.kcal, 600)
        // 4*40 + 4*70 + 9*15 = 575 passt zu 600; 100 kcal mit 100 g Eiweiß passt nicht.
        XCTAssertTrue(marker("[[mahlzeit: mittag | Luft | 100 | 100 | 0 | 0]]").isEmpty)
        XCTAssertTrue(marker("[[essen: Nichts | snack | 0]]").isEmpty)
    }

    func testDiagrammBrauchDreiBisAchtPunkte() {
        guard case .chart(let titel, let punkte)? = marker("[[chart: Schritte | Mo 8200 | Di 7400 | Mi 9100]]").first else { return XCTFail("kein chart") }
        XCTAssertEqual(titel, "Schritte")
        XCTAssertEqual(punkte, [.init(label: "Mo", wert: 8200), .init(label: "Di", wert: 7400), .init(label: "Mi", wert: 9100)])
        guard case .linie? = marker("[[linie: Gewicht | 1 80,5 | 2 80,1 | 3 79,8]]").first else { return XCTFail("keine linie") }
        XCTAssertTrue(marker("[[chart: Zu wenig | Mo 1 | Di 2]]").isEmpty)
    }

    func testFortschrittZielUndSchlafNacht() {
        XCTAssertEqual(marker("[[fortschritt: Schritte | 6200 | 8000]]"), [.fortschritt(label: "Schritte", aktuell: 6200, ziel: 8000)])
        XCTAssertTrue(marker("[[fortschritt: Schritte | 6200 | 0]]").isEmpty)
        XCTAssertEqual(marker("[[ziel: Dreimal pro Woche trainieren]]"), [.ziel("Dreimal pro Woche trainieren")])
        XCTAssertTrue(marker("[[ziel: 5 kg abnehmen]]").isEmpty, "Gewicht und Abnehmen nie als Ziel vorschlagen")
        XCTAssertEqual(marker("[[schlaf: 2026-10-08]]"), [.schlafNacht(tag: "2026-10-08")])
        XCTAssertTrue(marker("[[schlaf: gestern]]").isEmpty)
    }

    func testGedaechtnisMarker() {
        XCTAssertEqual(marker("[[aendere: knie | Rechtes Knie schonen]]"), [.aendere(id: "knie", text: "Rechtes Knie schonen")])
        XCTAssertEqual(marker("[[vergiss: knie]]"), [.vergiss(id: "knie")])
        XCTAssertTrue(marker("[[aendere: | x]]").isEmpty)
    }

    func testTrainingMarker() {
        XCTAssertEqual(marker("[[training: start]]"), [.trainingStart(name: nil)])
        XCTAssertEqual(marker("[[training: start | Push]]"), [.trainingStart(name: "Push")])
        XCTAssertEqual(marker("[[training: ende]]"), [.trainingEnde])
        XCTAssertEqual(marker("[[satz: u1 | 62,5 | 8]]"), [.satz(uebung: "u1", kg: 62.5, wdh: 8)])
        XCTAssertTrue(marker("[[satz: u1 | 62,5 | 0]]").isEmpty)
        XCTAssertTrue(marker("[[satz: u1 | 900 | 8]]").isEmpty)
        XCTAssertEqual(marker("[[tausche: u1 | bankdruecken]]"), [.tausche(uebung: "u1", katalogId: "bankdruecken")])
        XCTAssertTrue(marker("[[training: pause]]").isEmpty)
    }

    func testHoechstensVierMarkerProAntwort() {
        let roh = (1...6).map { "[[wasser: \($0 * 100)]]" }.joined()
        XCTAssertEqual(marker(roh).count, CoachMarker.maxMarker)
    }

    // MARK: - Vorschlag

    func testGleicheMarkerWerdenZusammengezaehlt() {
        let liste = CoachTracking.eintraege(marker("[[wasser: 250]][[wasser: 250]][[gewicht: 80]][[gewicht: 81]]"), stunde: 9)
        XCTAssertEqual(liste, [.wasser(glaeser: 2), .gewicht(kg: 81)])
    }

    func testGlaeserKlicksUndZehntel() {
        XCTAssertEqual(CoachTracking.glaeser(ml: 50), 1, "mindestens ein Glas")
        XCTAssertEqual(CoachTracking.glaeser(ml: 500), 2)
        XCTAssertEqual(CoachTracking.klicks(gramm: 7), 2)
        XCTAssertEqual(CoachTracking.klicks(gramm: 0.5), 1)
        XCTAssertEqual(CoachTracking.zehntel(kg: 81.3), 813)
    }

    func testMahlzeitNachUhrzeitUndKurzform() {
        XCTAssertEqual(CoachTracking.mahlzeit(stunde: 8), .fruehstueck)
        XCTAssertEqual(CoachTracking.mahlzeit(stunde: 13), .mittag)
        XCTAssertEqual(CoachTracking.mahlzeit(stunde: 19), .abend)
        XCTAssertEqual(CoachTracking.mahlzeit(stunde: 23), .snack)
        let e = CoachMarker.Essen(name: "Apfel", art: nil, kcal: 80, protein: nil, kohlenhydrate: 20, fett: nil)
        let m = CoachTracking.mahlzeit(aus: e, stunde: 15)
        XCTAssertEqual(m.mahlzeit, .mittag)
        XCTAssertEqual(m.eiweiss, 0)
        XCTAssertEqual(m.kohlenhydrate, 20)
    }

    func testTrainingMarkerKommenGeordnetStartZuerstEndeZuletzt() {
        let marker = marker("[[training: ende]][[satz: u1 | 60 | 8]][[training: start]]")
        let geordnet = CoachTrainingMarker.geordnet(marker)
        XCTAssertEqual(geordnet, [.trainingStart(name: nil), .satz(uebung: "u1", kg: 60, wdh: 8), .trainingEnde])
        XCTAssertTrue(CoachTrainingMarker.istTraining(.trainingEnde))
        XCTAssertFalse(CoachTrainingMarker.istTraining(.wasser(ml: 250)))
    }

    func testZeilenSagenWasEingetragenWird() {
        let wasser = CoachTracking.zeile(.wasser(glaeser: 2))
        XCTAssertEqual(wasser.text, "Wasser +2 Gläser (500 ml)")
        XCTAssertNotNil(wasser.route)
        XCTAssertTrue(CoachTracking.zeile(.merke("Knie schonen")).oeffnetGedaechtnis)
    }

    // MARK: - Training gegen den Stand

    private func stand(session: GymSession? = nil, tage: [TrainingsTag] = [], heute: TrainingsTag? = nil) -> CoachTrainingMarker.Stand {
        CoachTrainingMarker.Stand(session: session, tag: nil, frueher: [], tage: tage, heute: heute)
    }

    func testStartPlanFindetTagNachNamenOderNimmtHeute() {
        let plan = CoachTestBau.plan()
        let tag = plan.tage[0]
        XCTAssertEqual(CoachTrainingMarker.plan(.trainingStart(name: "push"), stand: stand(tage: plan.tage)), .start(tag: tag))
        XCTAssertEqual(CoachTrainingMarker.plan(.trainingStart(name: nil), stand: stand(tage: plan.tage, heute: tag)), .start(tag: tag))
        XCTAssertNil(CoachTrainingMarker.plan(.trainingStart(name: "Beine"), stand: stand(tage: plan.tage)), "unbekannter Tag: nichts")
    }

    func testEndeOhneEinheitUndSatzOhneEinheitTunNichts() {
        XCTAssertNil(CoachTrainingMarker.plan(.trainingEnde, stand: stand()))
        XCTAssertNil(CoachTrainingMarker.plan(.satz(uebung: "u1", kg: 60, wdh: 8), stand: stand()))
    }

    func testTrainingstagNachTeilDesNamens() {
        let tage = [TrainingsTag(id: "a", name: "Pull Day", wochentage: [1], uebungen: []), TrainingsTag(id: "b", name: "Push Day", wochentage: [2], uebungen: [])]
        XCTAssertEqual(CoachTrainingMarker.trainingstag("pull", in: tage)?.id, "a")
        XCTAssertEqual(CoachTrainingMarker.trainingstag("b", in: tage)?.id, "b")
        XCTAssertNil(CoachTrainingMarker.trainingstag("day", in: tage), "mehrere Treffer: der Coach rät nicht")
        XCTAssertNil(CoachTrainingMarker.trainingstag("", in: tage))
    }
}
