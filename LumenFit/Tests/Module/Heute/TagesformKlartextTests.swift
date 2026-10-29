import XCTest
@testable import LumenFit

/// Tagesform in Klartext: Gründe mit echten Werten und die Empfehlung mit Grund (Ahmed 15.10.: "so vage").
final class TagesformKlartextTests: XCTestCase {
    private typealias K = TagesformKlartext

    /// Ein Trainingstag im Plan, noch nicht trainiert.
    private func plan(trainingstag: Bool = true, ruhetag: Bool = false, planLeer: Bool = false, gymInFolge: Int = 0,
                      schonGym: Bool = false) -> EnergieEingabe {
        EnergieEingabe(naechte: [], wasser: 0, wasserZiel: 8, stunde: 11, schritteGestern: nil, trainingstag: trainingstag,
                       ruhetag: ruhetag, planLeer: planLeer, gymInFolge: gymInFolge, heuteSchonGym: schonGym)
    }

    private func faktor(_ art: TagesformArt, kurz: String = "kurz") -> TagesformFaktor {
        TagesformFaktor(art: art, wert: 50, gewicht: 0.2, einfluss: -3, kurz: kurz, detail: nil)
    }

    private func muskel(_ gruppe: String, _ prozent: Int) -> TagesformMuskel { TagesformMuskel(gruppe: gruppe, prozent: prozent) }

    // MARK: Gründe

    func testSchlafNenntDauerUndAbstandZumZiel() {
        var e = TagesformEingabe()
        e.schlaf = [356]
        XCTAssertEqual(K.text(faktor(.schlaf), e, kappe: nil), "Schlaf 5 h 56 min, 2 h 04 min unter deinem Ziel")
        e.schlaf = [440]
        XCTAssertEqual(K.text(faktor(.schlaf), e, kappe: nil), "Schlaf 7 h 20 min, 40 min unter deinem Ziel")
        e.schlaf = [470]
        XCTAssertEqual(K.text(faktor(.schlaf), e, kappe: nil), "Schlaf 7 h 50 min, Ziel erreicht")
    }

    func testSchlafNenntDieObergrenzeNurWennSieSchlafMeint() {
        var e = TagesformEingabe()
        e.schlaf = [356]
        let schlaf = TagesformKappe(grenze: 82, text: "Schlaf deckelt", art: .schlaf)
        XCTAssertEqual(K.text(faktor(.schlaf), e, kappe: schlaf), "Schlaf 5 h 56 min, 2 h 04 min unter deinem Ziel, deckelt dich bei 82 %")
        let warnung = TagesformKappe(grenze: 60, text: "HRV tief", art: nil)
        XCTAssertEqual(K.text(faktor(.schlaf), e, kappe: warnung), "Schlaf 5 h 56 min, 2 h 04 min unter deinem Ziel")
    }

    func testSchlafOhneWertFaelltAufDenKurzTextZurueck() {
        XCTAssertEqual(K.text(faktor(.schlaf, kurz: "Schlaf fehlt"), TagesformEingabe(), kappe: nil), "Schlaf fehlt")
    }

    func testMuskelnNennenGruppeUndProzentMuedesteZuerst() {
        var e = TagesformEingabe()
        e.muskeln = [muskel("Beine", 60), muskel("Beine", 54), muskel("Rücken", 85), muskel("Brust", 95)]
        XCTAssertEqual(K.text(faktor(.erholung), e, kappe: nil), "Noch nicht erholt: Beine 54 %, Rücken 85 %")
        e.muskeln = [muskel("Brust", 95)]
        XCTAssertEqual(K.text(faktor(.erholung, kurz: "Muskeln erholt"), e, kappe: nil), "Muskeln erholt")
    }

    func testAndereFaktorenBehaltenIhrenKonkretenKurzText() {
        XCTAssertEqual(K.text(faktor(.ruhepuls, kurz: "Ruhepuls 64, 6 über deinem Schnitt"), TagesformEingabe(), kappe: nil),
                       "Ruhepuls 64, 6 über deinem Schnitt")
    }

    // MARK: Empfehlung

    func testEmpfehlungOhneZahlOderPlanGibtEsNicht() {
        XCTAssertNil(K.empfehlung(akku: nil, muskeln: [], hauptgrund: nil, plan: plan()))
        XCTAssertNil(K.empfehlung(akku: 60, muskeln: [], hauptgrund: nil, plan: nil))
    }

    func testPlanTatsachenGehenVorDerZahl() {
        XCTAssertEqual(K.empfehlung(akku: 30, muskeln: [], hauptgrund: .schlaf, plan: plan(schonGym: true)), "Gym heute erledigt.")
        XCTAssertEqual(K.empfehlung(akku: 30, muskeln: [], hauptgrund: .schlaf, plan: plan(ruhetag: true)), "Ruhetag laut Plan.")
        XCTAssertEqual(K.empfehlung(akku: 90, muskeln: [], hauptgrund: nil, plan: plan(trainingstag: false)), "Kein Gym geplant.")
        // Ganz ohne Plan gibt es keinen Trainingstag zum Absagen: die Zahl entscheidet.
        XCTAssertEqual(K.empfehlung(akku: 90, muskeln: [], hauptgrund: nil, plan: plan(trainingstag: false, planLeer: true)),
                       "Volles Training passt.")
    }

    func testNiedrigeZahlSagtPauseMitDemGroesstenGrund() {
        XCTAssertEqual(K.empfehlung(akku: 42, muskeln: [muskel("Beine", 30)], hauptgrund: .schlaf, plan: plan()),
                       "Besser kein Gym und kein Cardio – vor allem wegen Schlaf.")
        XCTAssertEqual(K.empfehlung(akku: 42, muskeln: [], hauptgrund: nil, plan: plan()), "Besser kein Gym und kein Cardio.")
    }

    func testMuedeBeineGebenOberkoerperMitErholungswert() {
        XCTAssertEqual(K.empfehlung(akku: 62, muskeln: [muskel("Beine", 54), muskel("Beine", 60)], hauptgrund: .schlaf, plan: plan()),
                       "Lieber Oberkörper leicht, Cardio höchstens 15 min – Beine erst zu 54 % erholt.")
        XCTAssertEqual(K.empfehlung(akku: 85, muskeln: [muskel("Beine", 54)], hauptgrund: nil, plan: plan()),
                       "Lieber Oberkörper – Beine erst zu 54 % erholt.")
    }

    func testAndereMuedeGruppenWerdenAusgelassen() {
        XCTAssertEqual(K.empfehlung(akku: 85, muskeln: [muskel("Rücken", 60), muskel("Brust", 41), muskel("Bizeps", 65)], hauptgrund: nil, plan: plan()),
                       "Ohne Brust und Rücken trainieren – Brust erst zu 41 % erholt.")
        // Beine und Brust müde: nicht nur Beine, also keine Oberkörper-Empfehlung.
        XCTAssertEqual(K.empfehlung(akku: 60, muskeln: [muskel("Beine", 50), muskel("Brust", 55)], hauptgrund: nil, plan: plan()),
                       "Leichter, ohne Beine und Brust trainieren, Cardio höchstens 15 min – Beine erst zu 50 % erholt.")
    }

    func testMuskelnUeberDerGrenzeZaehlenNichtAlsMuede() {
        XCTAssertEqual(K.empfehlung(akku: 85, muskeln: [muskel("Beine", 85)], hauptgrund: nil, plan: plan()), "Volles Training passt.")
    }

    func testMittlereZahlUndLangeTrainingsReihe() {
        XCTAssertEqual(K.empfehlung(akku: 60, muskeln: [], hauptgrund: .wasser, plan: plan()),
                       "Leichter trainieren, Cardio höchstens 15 min – vor allem wegen Wasser.")
        XCTAssertEqual(K.empfehlung(akku: 85, muskeln: [], hauptgrund: nil, plan: plan(gymInFolge: 3)),
                       "Leichter trainieren – schon 3 Tage am Stück Gym.")
    }

    // MARK: Ganze Karte

    /// Eine kurze Nacht (4 h) bei sonst gutem Tag: der Schlaf ist der einzige Grund, deckelt die Zahl, und die Empfehlung nennt ihn.
    func testKurzeNachtGibtSchlafAlsGrundUndLeichtesTraining() {
        var e = TagesformBeispiele.voll()
        e.schlaf = TagesformBeispiele.schlafReihe([240, 450, 460])
        let r = TagesformRechnung.rechnen(e)
        let inhalt = K.inhalt(e, r, plan: plan())
        XCTAssertEqual(inhalt.gruende.count, 1)
        XCTAssertEqual(inhalt.gruende.first?.art, .schlaf)
        XCTAssertEqual(inhalt.gruende.first?.bremst, true)
        XCTAssertEqual(inhalt.gruende.first?.text, "Schlaf 4 h 00 min, 4 h 00 min unter deinem Ziel, deckelt dich bei 58 %")
        XCTAssertEqual(inhalt.empfehlung, "Leichter trainieren, Cardio höchstens 15 min – vor allem wegen Schlaf.")
        XCTAssertNil(inhalt.hinweis)
    }

    func testGuterTagZeigtDenHelfendenGrundUndVollesTraining() {
        let e = TagesformBeispiele.voll()
        let inhalt = K.inhalt(e, TagesformRechnung.rechnen(e), plan: plan())
        XCTAssertEqual(inhalt.gruende.first?.bremst, false)
        XCTAssertEqual(inhalt.gruende.first?.text, "Schlaf 7 h 50 min, Ziel erreicht")
        XCTAssertEqual(inhalt.empfehlung, "Volles Training passt.")
    }

    func testOhneZahlKeineEmpfehlungUndKeinHinweis() {
        let inhalt = K.inhalt(TagesformEingabe(), TagesformRechnung.rechnen(TagesformEingabe()), plan: plan())
        XCTAssertTrue(inhalt.gruende.isEmpty)
        XCTAssertNil(inhalt.empfehlung)
        XCTAssertNil(inhalt.hinweis)
    }
}
