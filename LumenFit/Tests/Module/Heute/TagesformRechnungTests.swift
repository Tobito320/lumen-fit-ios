import XCTest
@testable import LumenFit

/// W-028: je Regel der Tagesform-Rechnung ein Test. Reine Logik, ohne Modelle und ohne HealthKit.
/// Erwartete Zahlen kommen aus einer Nachrechnung der Regeln in Python, nicht aus dem Swift-Code abgelesen.
final class TagesformRechnungTests: XCTestCase {
    private typealias B = TagesformBeispiele

    // MARK: Hilfen

    private func wert(_ e: TagesformEingabe, _ art: TagesformArt) -> Double {
        TagesformRechnung.rechnen(e).faktoren.first { $0.art == art }?.wert ?? -1
    }

    private func fehlt(_ e: TagesformEingabe, _ art: TagesformArt) -> Bool {
        TagesformRechnung.rechnen(e).fehlend.contains(art)
    }

    private func masse(_ ist: Double, _ ziel: Double) -> TagesformMass {
        TagesformMass(ist: ist, ziel: ziel, bezug: .tag)
    }

    // MARK: Gewichte und fehlende Daten

    func testGewichteSummierenZuEins() {
        XCTAssertEqual(TagesformArt.gesamtGewicht, 1, accuracy: 1e-9)
        for art in TagesformArt.allCases { XCTAssertGreaterThan(art.gewicht, 0, "\(art)") }
    }

    func testAlleQuellenGebenEineGuteZahl() {
        let r = TagesformRechnung.rechnen(B.voll())
        XCTAssertEqual(r.akku, 90)
        XCTAssertEqual(r.urteil, "Voll geladen")
        XCTAssertEqual(r.faktoren.count, TagesformArt.allCases.count)
        XCTAssertTrue(r.fehlend.isEmpty)
        XCTAssertEqual(r.deckung, 1, accuracy: 1e-9)
        XCTAssertEqual(r.faktoren.map { $0.gewicht }.reduce(0, +), 1, accuracy: 1e-9)
        XCTAssertEqual(r.datenlage, "gut")
    }

    func testFehlendeQuelleVerteiltDieGewichteNeu() {
        let mit = TagesformRechnung.rechnen(B.voll())
        var e = B.voll()
        e.hrv = []
        let ohne = TagesformRechnung.rechnen(e)
        XCTAssertEqual(ohne.fehlend, [.hrv])
        XCTAssertEqual(ohne.faktoren.count, TagesformArt.allCases.count - 1)
        XCTAssertEqual(ohne.faktoren.map { $0.gewicht }.reduce(0, +), 1, accuracy: 1e-9)
        XCTAssertEqual(ohne.deckung, 1 - TagesformArt.hrv.gewicht, accuracy: 1e-9)
        let schlafMit = mit.faktoren.first { $0.art == .schlaf }?.gewicht ?? 0
        let schlafOhne = ohne.faktoren.first { $0.art == .schlaf }?.gewicht ?? 0
        XCTAssertGreaterThan(schlafOhne, schlafMit)
        // Die Verhältnisse der übrigen untereinander bleiben, wie sie sind.
        let pulsOhne = ohne.faktoren.first { $0.art == .ruhepuls }?.gewicht ?? 0
        XCTAssertEqual(schlafOhne / pulsOhne, TagesformArt.schlaf.gewicht / TagesformArt.ruhepuls.gewicht, accuracy: 1e-9)
    }

    func testOhneGenugDatenKeineZahl() {
        let leer = TagesformRechnung.rechnen(TagesformEingabe())
        XCTAssertNil(leer.akku)
        XCTAssertEqual(leer.urteil, "Zu wenig Daten")
        XCTAssertTrue(leer.gruende.isEmpty)
        XCTAssertEqual(leer.fehlend.count, TagesformArt.allCases.count)
        // Wasser allein (0,04) und HRV allein (0,16) reichen nicht.
        var nurWasser = TagesformEingabe()
        nurWasser.wasser = masse(8, 8)
        XCTAssertNil(TagesformRechnung.rechnen(nurWasser).akku)
        var nurHrv = TagesformEingabe()
        nurHrv.hrv = B.reihe(60, B.hrvBasis)
        XCTAssertNil(TagesformRechnung.rechnen(nurHrv).akku)
        // Mit zu wenig Daten zeigt die Liste trotzdem, was da ist, aber ohne Gewicht.
        XCTAssertEqual(TagesformRechnung.rechnen(nurHrv).faktoren.map { $0.gewicht }, [0])
    }

    func testOhneSchlafGibtKeineZahlEgalWasSonstDaIst() {
        // Der gemeldete Fehler: Wasser hob die Zahl trotz kaum Schlaf. Ohne Schlafwert gibt es keine Obergrenze, also keine Zahl.
        var e = B.voll()
        e.schlaf = []
        e.bett = []
        let r = TagesformRechnung.rechnen(e)
        XCTAssertNil(r.akku)
        XCTAssertEqual(r.urteil, "Schlaf fehlt")
        XCTAssertEqual(r.satz, "Ohne Schlafwert gibt es keine Tagesform. Trag deinen Schlaf ein oder erlaube Apple Health.")
        XCTAssertTrue(r.fehlend.contains(.schlaf))
        XCTAssertTrue(r.gruende.isEmpty)
        XCTAssertNil(r.kappe)
        XCTAssertEqual(r.faktoren.map { $0.gewicht }.reduce(0, +), 0, "ohne Zahl zählt nichts")
        // Mehr Wasser und Schritte ändern daran nichts.
        e.wasser = masse(20, 8)
        e.schritte = masse(30_000, 10_000)
        XCTAssertNil(TagesformRechnung.rechnen(e).akku)
        // Ein Schlafziel von 0 gilt wie fehlender Schlaf.
        e.schlaf = B.schlafReihe([470, 450, 460])
        e.schlafZiel = 0
        XCTAssertEqual(TagesformRechnung.rechnen(e).urteil, "Schlaf fehlt")
        // Mit Schlaf gibt es die Zahl wieder.
        e.schlafZiel = 480
        XCTAssertNotNil(TagesformRechnung.rechnen(e).akku)
    }

    func testSchlafAlleinGibtEineGrobeZahl() {
        var e = TagesformEingabe()
        e.schlaf = [480]
        let r = TagesformRechnung.rechnen(e)
        XCTAssertEqual(r.akku, 100)
        XCTAssertEqual(r.datenlage, "dünn")
        XCTAssertTrue(r.satz.hasSuffix("Wenig Daten, die Zahl ist grob."))
    }

    func testZahlBleibtZwischenNullUndHundert() {
        var oben = B.voll()
        oben.schlaf = B.schlafReihe([100_000], rest: 100_000)
        oben.hrv = B.reihe(500, B.hrvBasis)
        oben.ruhepuls = B.reihe(40, B.pulsBasis)
        oben.schritte = masse(1e9, 10_000)
        oben.wasser = masse(1000, 8)
        oben.kalorien = masse(2600, 2600)
        oben.eiweiss = masse(1000, 160)
        var unten = B.voll()
        unten.schlaf = B.schlafReihe([0], rest: 0)
        unten.hrv = B.reihe(1, B.hrvBasis)
        unten.ruhepuls = B.reihe(200, B.pulsBasis)
        unten.kalorien = masse(0, 2600)
        unten.eiweiss = masse(-50, 160)
        unten.saetze = B.saetze(300, sonst: 0)
        for e in [oben, unten] {
            let r = TagesformRechnung.rechnen(e)
            XCTAssertTrue((0...100).contains(r.akku ?? -1))
            for f in r.faktoren { XCTAssertTrue((0.0...100.0).contains(f.wert), "\(f.art) \(f.wert)") }
        }
        XCTAssertEqual(TagesformRechnung.rechnen(oben).akku, 100)
        XCTAssertEqual(TagesformRechnung.rechnen(unten).akku, 15, "ohne Schlaf bleibt die Schlaf-Grenze 15")
    }

    func testNichtEndlicheWerteZaehlenNicht() {
        var e = B.voll()
        e.kalorien = masse(.nan, 2600)
        e.eiweiss = masse(.infinity, 160)
        e.schritte = masse(5000, 0)
        e.hrv = B.reihe(.nan, B.hrvBasis)
        let r = TagesformRechnung.rechnen(e)
        XCTAssertEqual(Set(r.fehlend), [.kalorien, .eiweiss, .schritte, .hrv])
        XCTAssertNotNil(r.akku)
    }

    // MARK: Schlaf

    func testSchlafMischtLetzteNachtUndDieZweiDavor() {
        var e = TagesformEingabe()
        e.schlaf = [240, 480, 480]
        XCTAssertEqual(wert(e, .schlaf), 51.25, accuracy: 0.001, "0,65 mal 25 plus 0,35 mal 100")
        e.schlaf = [480]
        XCTAssertEqual(wert(e, .schlaf), 100, accuracy: 0.001)
        e.schlaf = [240]
        XCTAssertEqual(wert(e, .schlaf), 25, accuracy: 0.001, "halber Schlaf gibt ein Viertel der Punkte")
        e.schlaf = [nil, 480, 480]
        XCTAssertTrue(fehlt(e, .schlaf), "ohne die letzte Nacht kein Schlafwert")
        e.schlaf = [480]
        e.schlafZiel = 0
        XCTAssertTrue(fehlt(e, .schlaf))
    }

    func testMehrSchlafNieWenigerZahl() {
        var letzte = -1
        for minuten in stride(from: 0, through: 540, by: 60) {
            var e = B.voll()
            e.schlaf = B.schlafReihe([minuten])
            let a = TagesformRechnung.rechnen(e).akku ?? -1
            XCTAssertGreaterThanOrEqual(a, letzte, "\(minuten) min")
            letzte = a
        }
    }

    func testSchlafTextVergleichtMitDemEigenenSchnitt() {
        func kurz(_ schlaf: [Int?]) -> String {
            var e = TagesformEingabe()
            e.schlaf = schlaf
            return TagesformRechnung.rechnen(e).faktoren.first?.kurz ?? ""
        }
        XCTAssertEqual(kurz(B.schlafReihe([370], rest: 425)), "Schlaf 6:10 h, unter deinem Schnitt")
        XCTAssertEqual(kurz(B.schlafReihe([400], rest: 360)), "Schlaf 6:40 h, über deinem Schnitt")
        XCTAssertEqual(kurz(B.schlafReihe([430], rest: 425)), "Schlaf 7:10 h, wie dein Schnitt")
        XCTAssertEqual(kurz(B.schlafReihe([470], rest: 360)), "Schlaf 7:50 h, Ziel erreicht")
        XCTAssertEqual(kurz([370, 425, 425]), "Schlaf 6:10 h von 8:00 h", "unter drei Nächten davor gibt es keinen Schnitt")
    }

    func testBettzeitStreuung() {
        func bett(_ zeiten: [Int?]) -> Double {
            var e = TagesformEingabe()
            e.bett = zeiten
            return wert(e, .rhythmus)
        }
        XCTAssertEqual(bett([570, 630, 570, 630]), 100, accuracy: 0.001, "30 min Streuung sind volle Punkte")
        XCTAssertEqual(bett([540, 660, 540, 660]), 200.0 / 3, accuracy: 0.001, "60 min Streuung")
        XCTAssertEqual(bett([480, 720, 480, 720]), 0, accuracy: 0.001, "120 min Streuung")
        XCTAssertEqual(bett([600, 600, 600, 600]), 100, accuracy: 0.001)
        var e = TagesformEingabe()
        e.bett = [600, nil, 620, 640]
        XCTAssertTrue(fehlt(e, .rhythmus), "unter vier Nächten gibt es keine Streuung")
        e.bett = [600, 620, 640, 610, 600, 600, 600, 100, 100]
        XCTAssertGreaterThan(wert(e, .rhythmus), 80, "nur die letzten sieben zählen")
    }

    func testBettMinutenFaltetUeberMitternacht() {
        let tag = Datum.datum("2026-10-12")
        XCTAssertEqual(TagesformRechnung.bettMinuten(tag.addingTimeInterval(22 * 3600)), 600)
        XCTAssertEqual(TagesformRechnung.bettMinuten(tag.addingTimeInterval(30 * 60)), 750, "00:30 liegt nach 22:00")
        XCTAssertEqual(TagesformRechnung.bettMinuten(tag.addingTimeInterval(12 * 3600)), 0)
    }

    func testSchlafSicherheit() {
        let watch = TagesformSchlafQuelle.appleWatch.rawValue
        let eigen = TagesformSchlafQuelle.eingetragen.rawValue
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: watch, abweichung: nil), 1)
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: eigen, abweichung: 10), 1)
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: TagesformSchlafQuelle.armband.rawValue, abweichung: nil), 1, "Armband zählt wie die Uhr")
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: "Punktesystem, sicher", abweichung: nil), 0.9)
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: "Punktesystem, wahrscheinlich", abweichung: nil), 0.8)
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: "Punktesystem, unsicher", abweichung: nil), 0.65)
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: nil, abweichung: nil), 0.8)
        // Weichen Uhr und Schätzung um 45 min oder mehr ab, sinkt es noch einmal.
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: watch, abweichung: 44), 1)
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: watch, abweichung: -45), 0.85, accuracy: 1e-9)
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: "Punktesystem, sicher", abweichung: 60), 0.9 * 0.85, accuracy: 1e-9)
        XCTAssertEqual(TagesformRechnung.schlafHinweis(quelle: watch, abweichung: 52), "Quelle: Apple Watch. Uhr und Schätzung weichen 52 min ab")
        XCTAssertEqual(TagesformRechnung.schlafHinweis(quelle: watch, abweichung: 10), "Quelle: Apple Watch")
        // Ein eigener Eintrag ist die Wahrheit: Uhr und Schätzung dürfen auseinanderliegen, er verliert nichts und nennt es nicht.
        XCTAssertEqual(TagesformRechnung.schlafSicherheit(quelle: eigen, abweichung: 60), 1)
        XCTAssertEqual(TagesformRechnung.schlafHinweis(quelle: eigen, abweichung: 60), "Quelle: eingetragen")
        XCTAssertNil(TagesformRechnung.schlafHinweis(quelle: nil, abweichung: 90))
    }

    func testUnsichererSchlafSenktNurDasGewichtNichtDenWert() {
        let sicher = TagesformRechnung.rechnen(B.voll())
        var e = B.voll()
        e.schlafSicherheit = 0.65
        let unsicher = TagesformRechnung.rechnen(e)
        let a = sicher.faktoren.first { $0.art == .schlaf }
        let b = unsicher.faktoren.first { $0.art == .schlaf }
        XCTAssertEqual(a?.wert ?? -1, b?.wert ?? -2, accuracy: 1e-9)
        XCTAssertLessThan(b?.gewicht ?? 1, a?.gewicht ?? 0)
        XCTAssertLessThan(unsicher.deckung, sicher.deckung)
        XCTAssertEqual(unsicher.faktoren.map { $0.gewicht }.reduce(0, +), 1, accuracy: 1e-9)
    }

    func testObergrenzeNenntEinenUnsicherenSchlaf() {
        var e = B.voll()
        e.schlaf = B.schlafReihe([120])
        XCTAssertEqual(TagesformRechnung.rechnen(e).kappe?.text, "Schlaf 2:00 h deckelt dich bei 36 %")
        e.schlafSicherheit = 0.65
        let unsicher = TagesformRechnung.rechnen(e)
        XCTAssertEqual(unsicher.kappe?.text, "Schlaf 2:00 h (unsicher) deckelt dich bei 36 %")
        XCTAssertEqual(unsicher.kappe?.grenze, 36, "sie deckelt trotzdem genauso hart")
        XCTAssertEqual(unsicher.akku, 36)
        e.schlafSicherheit = TagesformRechnung.schlafUnsicherUnter
        XCTAssertEqual(TagesformRechnung.rechnen(e).kappe?.text, "Schlaf 2:00 h deckelt dich bei 36 %", "ab der Grenze gilt der Wert als sicher genug")
    }

    // MARK: Erholungswerte

    func testHrvGegenDenEigenenSchnitt() {
        var e = TagesformEingabe()
        e.hrv = B.reihe(58, B.hrvBasis)
        XCTAssertEqual(wert(e, .hrv), 75, accuracy: 0.001, "genau der Schnitt")
        e.hrv = B.reihe(62.64, B.hrvBasis)
        XCTAssertEqual(wert(e, .hrv), 95, accuracy: 0.001, "eine Streuung darüber (Boden 8 Prozent des Schnitts)")
        e.hrv = B.reihe(10, B.hrvBasis)
        XCTAssertEqual(wert(e, .hrv), 0, accuracy: 0.001)
        e.hrv = B.reihe(nil, B.hrvBasis)
        XCTAssertTrue(fehlt(e, .hrv), "ohne Wert von heute")
        e.hrv = B.reihe(58, [Double?](B.hrvBasis.prefix(4)))
        XCTAssertTrue(fehlt(e, .hrv), "unter fünf Tagen Vergleich")
        e.hrv = B.reihe(58, [nil, 54, nil, 62, 54, nil, 62, 54])
        XCTAssertFalse(fehlt(e, .hrv), "fünf Tage Vergleich reichen, Lücken zählen nicht")
    }

    func testHrvTextNenntDieLage() {
        func kurz(_ heute: Double) -> String {
            var e = TagesformEingabe()
            e.hrv = B.reihe(heute, B.hrvBasis)
            return TagesformRechnung.rechnen(e).faktoren.first?.kurz ?? ""
        }
        XCTAssertEqual(kurz(48), "HRV 48 ms, unter deinem Schnitt")
        XCTAssertEqual(kurz(66), "HRV 66 ms, über deinem Schnitt")
        XCTAssertEqual(kurz(58), "HRV 58 ms, wie dein Schnitt")
    }

    func testRuhepulsGegenDenEigenenSchnitt() {
        func ruhepuls(_ heute: Double) -> Double {
            var e = TagesformEingabe()
            e.ruhepuls = B.reihe(heute, B.pulsBasis)
            return wert(e, .ruhepuls)
        }
        XCTAssertEqual(ruhepuls(56), 75, accuracy: 0.001)
        XCTAssertEqual(ruhepuls(60), 51, accuracy: 0.001, "vier Schläge drüber, sechs Punkte je Schlag")
        XCTAssertEqual(ruhepuls(52), 99, accuracy: 0.001)
        XCTAssertEqual(ruhepuls(48), 100, accuracy: 0.001)
        XCTAssertEqual(ruhepuls(90), 0, accuracy: 0.001)
        var e = TagesformEingabe()
        e.ruhepuls = B.reihe(60, B.pulsBasis)
        XCTAssertEqual(TagesformRechnung.rechnen(e).faktoren.first?.kurz, "Ruhepuls 60, 4 über deinem Schnitt")
        e.ruhepuls = B.reihe(54, B.pulsBasis)
        XCTAssertEqual(TagesformRechnung.rechnen(e).faktoren.first?.kurz, "Ruhepuls 54, 2 unter deinem Schnitt")
        e.ruhepuls = B.reihe(57, B.pulsBasis)
        XCTAssertEqual(TagesformRechnung.rechnen(e).faktoren.first?.kurz, "Ruhepuls 57, wie dein Schnitt")
    }

    func testHrvTiefUndRuhepulsHochDeckeltAufSechzig() {
        var e = B.voll()
        e.hrv = B.reihe(58 - 2 * 4.64, B.hrvBasis)
        e.ruhepuls = B.reihe(62, B.pulsBasis)
        let r = TagesformRechnung.rechnen(e)
        XCTAssertEqual(r.kappe?.grenze, 60)
        XCTAssertEqual(r.akku, 60)
        XCTAssertTrue(r.satz.hasPrefix("Bremst: HRV tief und Ruhepuls hoch"))
        // Eins allein ist noch kein Warnsignal.
        var nurHrv = B.voll()
        nurHrv.hrv = B.reihe(58 - 2 * 4.64, B.hrvBasis)
        XCTAssertNil(TagesformRechnung.rechnen(nurHrv).kappe)
        var nurPuls = B.voll()
        nurPuls.ruhepuls = B.reihe(62, B.pulsBasis)
        XCTAssertNil(TagesformRechnung.rechnen(nurPuls).kappe)
    }

    // MARK: Training

    func testErholungIstDasMittelDerMuedestenTeile() {
        var e = TagesformEingabe()
        e.saetze = [5]
        e.muskeln = [TagesformMuskel(gruppe: "Brust", prozent: 40), TagesformMuskel(gruppe: "Brust", prozent: 40), TagesformMuskel(gruppe: "Trizeps", prozent: 40)]
        XCTAssertEqual(wert(e, .erholung), 70, accuracy: 0.001, "drei Teile bei 40, die anderen drei der sechs bei 100")
        e.muskeln = [TagesformMuskel](repeating: TagesformMuskel(gruppe: "Beine", prozent: 50), count: MuskelTeil.allCases.count)
        XCTAssertEqual(wert(e, .erholung), 50, accuracy: 0.001)
        e.muskeln = []
        XCTAssertEqual(wert(e, .erholung), 100, accuracy: 0.001, "alles erholt")
        e.saetze = [Int](repeating: 0, count: 29)
        XCTAssertTrue(fehlt(e, .erholung), "ohne ein Training in vier Wochen sagt die Erholung nichts")
    }

    func testErholungTextNenntDieMuedestenGruppen() {
        var e = TagesformEingabe()
        e.saetze = [5]
        e.muskeln = [
            TagesformMuskel(gruppe: "Brust", prozent: 40), TagesformMuskel(gruppe: "Brust", prozent: 55),
            TagesformMuskel(gruppe: "Trizeps", prozent: 60), TagesformMuskel(gruppe: "Beine", prozent: 95),
            TagesformMuskel(gruppe: "Rücken", prozent: 80),
        ]
        XCTAssertEqual(TagesformRechnung.rechnen(e).faktoren.first?.kurz, "Brust 40 %, Trizeps 60 % noch müde")
        e.muskeln = [TagesformMuskel(gruppe: "Beine", prozent: 95)]
        XCTAssertEqual(TagesformRechnung.rechnen(e).faktoren.first?.kurz, "Muskeln erholt")
    }

    func testTrainingslastGegenDieLetztenVierWochen() {
        func last(_ drei: Int, sonst: Int) -> Double {
            var e = TagesformEingabe()
            e.saetze = B.saetze(drei, sonst: sonst)
            return wert(e, .last)
        }
        XCTAssertEqual(last(10, sonst: 10), 100, accuracy: 0.001, "wie sonst")
        XCTAssertEqual(last(14, sonst: 10), 96.36, accuracy: 0.01, "knapp über 1,3 mal sonst")
        XCTAssertEqual(last(20, sonst: 10), 56.59, accuracy: 0.01)
        XCTAssertEqual(last(30, sonst: 0), 0, accuracy: 0.001, "dreimal so viel wie sonst und mehr")
        XCTAssertEqual(last(0, sonst: 10), 100, accuracy: 0.001, "Pause ist keine Überlast")
        var e = TagesformEingabe()
        e.saetze = B.saetze(0, sonst: 0)
        XCTAssertTrue(fehlt(e, .last), "kein Training in vier Wochen")
        e.saetze = [12]
        XCTAssertTrue(fehlt(e, .last), "heutiges Training allein ist keine Vorbelastung")
    }

    func testTrainingslastWirdMitMehrTrainingNieBesser() {
        var letzter = 101.0
        for drei in stride(from: 5, through: 50, by: 5) {
            var e = TagesformEingabe()
            e.saetze = B.saetze(drei, sonst: 10)
            let w = wert(e, .last)
            XCTAssertLessThanOrEqual(w, letzter, "\(drei)")
            letzter = w
        }
    }

    // MARK: Essen, Schritte, Wasser

    func testKalorienGegenDasZiel() {
        func kal(_ anteil: Double) -> Double {
            var e = TagesformEingabe()
            e.kalorien = masse(anteil * 2000, 2000)
            return wert(e, .kalorien)
        }
        XCTAssertEqual(kal(1), 100, accuracy: 0.001)
        XCTAssertEqual(kal(0.9), 100, accuracy: 0.001)
        XCTAssertEqual(kal(1.1), 100, accuracy: 0.001)
        XCTAssertEqual(kal(0.65), 50, accuracy: 0.001)
        XCTAssertEqual(kal(0.4), 0, accuracy: 0.001)
        XCTAssertEqual(kal(1.3), 77.78, accuracy: 0.01)
        XCTAssertEqual(kal(2), 0, accuracy: 0.001)
    }

    func testEiweissGegenDasZiel() {
        func eiweiss(_ anteil: Double) -> Double {
            var e = TagesformEingabe()
            e.eiweiss = masse(anteil * 160, 160)
            return wert(e, .eiweiss)
        }
        XCTAssertEqual(eiweiss(1), 100, accuracy: 0.001)
        XCTAssertEqual(eiweiss(1.5), 100, accuracy: 0.001, "mehr als das Ziel gibt nicht mehr")
        XCTAssertEqual(eiweiss(0.7), 50, accuracy: 0.001)
        XCTAssertEqual(eiweiss(0.4), 0, accuracy: 0.001)
    }

    func testSchritteUndWasserSindLinearGegenDasZiel() {
        var e = TagesformEingabe()
        e.schritte = masse(5000, 10_000)
        e.wasser = masse(2, 8)
        XCTAssertEqual(wert(e, .schritte), 50, accuracy: 0.001)
        XCTAssertEqual(wert(e, .wasser), 25, accuracy: 0.001)
        e.schritte = masse(15_000, 10_000)
        XCTAssertEqual(wert(e, .schritte), 100, accuracy: 0.001)
    }

    func testEssenstextNenntDenBezug() {
        func kurz(_ m: TagesformMass, stunde: Int = 24) -> String {
            var e = TagesformEingabe()
            e.stunde = stunde
            e.eiweiss = m
            return TagesformRechnung.rechnen(e).faktoren.first?.kurz ?? ""
        }
        XCTAssertEqual(kurz(TagesformMass(ist: 112, ziel: 160, bezug: .vortag), stunde: 10), "Eiweiß gestern 112 von 160 g")
        XCTAssertEqual(kurz(TagesformMass(ist: 112, ziel: 160, bezug: .vortag)), "Eiweiß am Vortag 112 von 160 g")
        XCTAssertEqual(kurz(TagesformMass(ist: 112, ziel: 160, bezug: .tag)), "Eiweiß 112 von 160 g")
        var e = TagesformEingabe()
        e.schritte = TagesformMass(ist: 3100, ziel: 4000, bezug: .bisJetzt)
        XCTAssertEqual(TagesformRechnung.rechnen(e).faktoren.first?.kurz, "Schritte bis jetzt 3.100, Soll 4.000")
    }

    func testSollAnteilUndTagesmass() {
        XCTAssertEqual(TagesformRechnung.sollAnteil(stunde: 5), 0)
        XCTAssertEqual(TagesformRechnung.sollAnteil(stunde: 8), 0)
        XCTAssertEqual(TagesformRechnung.sollAnteil(stunde: 15), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TagesformRechnung.sollAnteil(stunde: 22), 1)
        XCTAssertEqual(TagesformRechnung.sollAnteil(stunde: 24), 1)

        // Vergangener Tag: ganz.
        let tag = TagesformRechnung.tagesmass(heute: 8000, vortag: 5000, ziel: 10_000, stunde: 24, ab: 12)
        XCTAssertEqual(tag, TagesformMass(ist: 8000, ziel: 10_000, bezug: .tag))
        // Heute gegen das Soll bis jetzt (15 Uhr: die Hälfte), sobald der Übergang vorbei ist (ab 8, bis 14 Uhr).
        let jetzt = TagesformRechnung.tagesmass(heute: 3000, vortag: 5000, ziel: 10_000, stunde: 15, ab: 8)
        XCTAssertEqual(jetzt, TagesformMass(ist: 3000, ziel: 5000, bezug: .bisJetzt))
        // Davor der Vortag.
        let morgens = TagesformRechnung.tagesmass(heute: 100, vortag: 5000, ziel: 10_000, stunde: 9, ab: 12)
        XCTAssertEqual(morgens, TagesformMass(ist: 5000, ziel: 10_000, bezug: .vortag))
        // `ab` 24: heute nie, nur der Vortag (Essen).
        let essen = TagesformRechnung.tagesmass(heute: 1500, vortag: 2400, ziel: 2600, stunde: 20, ab: 24)
        XCTAssertEqual(essen, TagesformMass(ist: 2400, ziel: 2600, bezug: .vortag))
        // Nichts bekannt oder kein Ziel.
        XCTAssertNil(TagesformRechnung.tagesmass(heute: nil, vortag: nil, ziel: 10_000, stunde: 15, ab: 12))
        XCTAssertNil(TagesformRechnung.tagesmass(heute: 100, vortag: 100, ziel: 0, stunde: 24, ab: 12))
        // Heute ohne Wert fällt auf den Vortag zurück.
        let ohneHeute = TagesformRechnung.tagesmass(heute: nil, vortag: 4000, ziel: 10_000, stunde: 15, ab: 12)
        XCTAssertEqual(ohneHeute, TagesformMass(ist: 4000, ziel: 10_000, bezug: .vortag))
    }

    func testVortagBlendetAmVormittagLangsamInHeuteUeber() {
        // Ab 8 Uhr, sechs Stunden Übergang: um 11 Uhr zählt heute zur Hälfte, ab 14 Uhr ganz.
        XCTAssertEqual(TagesformRechnung.heuteAnteil(stunde: 5, ab: 8), 0)
        XCTAssertEqual(TagesformRechnung.heuteAnteil(stunde: 8, ab: 8), 0)
        XCTAssertEqual(TagesformRechnung.heuteAnteil(stunde: 11, ab: 8), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TagesformRechnung.heuteAnteil(stunde: 14, ab: 8), 1)
        XCTAssertEqual(TagesformRechnung.heuteAnteil(stunde: 23, ab: 8), 1)
        XCTAssertEqual(TagesformRechnung.heuteAnteil(stunde: 23, ab: 24), 0, "ab 24 zählt heute nie")
        // 11 Uhr: heute bis jetzt (Soll 3 von 14 Teilen des Ziels), der Vortag zählt die andere Hälfte.
        let mitte = TagesformRechnung.tagesmass(heute: 1500, vortag: 9000, ziel: 10_000, stunde: 11, ab: 8)
        XCTAssertEqual(mitte?.bezug, .bisJetzt)
        XCTAssertEqual(mitte?.ist, 1500)
        XCTAssertEqual(mitte?.ziel ?? 0, 10_000 * 3.0 / 14, accuracy: 1e-9)
        XCTAssertEqual(mitte?.davor, TagesformDavor(ist: 9000, ziel: 10_000, anteil: 0.5))
        // Davor der Vortag allein, danach heute allein.
        XCTAssertEqual(TagesformRechnung.tagesmass(heute: 100, vortag: 9000, ziel: 10_000, stunde: 8, ab: 8), TagesformMass(ist: 9000, ziel: 10_000, bezug: .vortag))
        XCTAssertNil(TagesformRechnung.tagesmass(heute: 1500, vortag: 9000, ziel: 10_000, stunde: 14, ab: 8)?.davor)
        // Ohne Vortag zählt heute allein, auch im Übergang. Ein Ziel-Soll von 0 (vor 8 Uhr) lässt heute nie zu.
        XCTAssertNil(TagesformRechnung.tagesmass(heute: 1500, vortag: nil, ziel: 10_000, stunde: 11, ab: 8)?.davor)
        XCTAssertEqual(TagesformRechnung.tagesmass(heute: 100, vortag: 9000, ziel: 10_000, stunde: 7, ab: 5)?.bezug, .vortag)
    }

    func testAmVormittagMischtDerVortagDiePunkteMit() {
        // 11 Uhr: 1.500 Schritte bei Soll 2.143 sind 70 Punkte, der Vortag 9.000 von 10.000 sind 90, je zur Hälfte: 80.
        var e = TagesformEingabe()
        e.schritte = TagesformRechnung.tagesmass(heute: 1500, vortag: 9000, ziel: 10_000, stunde: 11, ab: 8)
        XCTAssertEqual(wert(e, .schritte), 80, accuracy: 0.001)
        let f = TagesformRechnung.rechnen(e).faktoren.first
        XCTAssertEqual(f?.kurz, "Schritte bis jetzt 1.500, Soll 2.143")
        XCTAssertEqual(f?.detail, "Am Vormittag zählt noch der Vortag: gestern 9.000 von 10.000, zu 50 %.")
        // Gemischt wird in Punkten, nicht im Anteil: der Vortag über dem Ziel kappt bei 100 und gleicht heute nicht aus.
        e.schritte = TagesformRechnung.tagesmass(heute: 0, vortag: 30_000, ziel: 10_000, stunde: 11, ab: 8)
        XCTAssertEqual(wert(e, .schritte), 50, accuracy: 0.001)
        // Am Nachmittag gibt es keinen Hinweis mehr.
        e.schritte = TagesformRechnung.tagesmass(heute: 1500, vortag: 9000, ziel: 10_000, stunde: 15, ab: 8)
        XCTAssertNil(TagesformRechnung.rechnen(e).faktoren.first?.detail)
    }

    func testDieZahlSpringtAmVormittagNicht() {
        // Gleiche Daten, nur die Uhr läuft: Vortag 9.000 Schritte und 7 Gläser, heute noch nichts getan. Früher wechselte
        // die Zahl um 12 Uhr auf einmal um 10 Punkte, jetzt höchstens um 2 je Stunde.
        var vorher: Int? = nil
        for stunde in 7...15 {
            var e = B.voll()
            e.stunde = stunde
            e.schritte = TagesformRechnung.tagesmass(heute: 0, vortag: 9000, ziel: 10_000, stunde: stunde, ab: TagesformQuellenLogik.heuteAb)
            e.wasser = TagesformRechnung.tagesmass(heute: 0, vortag: 7, ziel: 8, stunde: stunde, ab: TagesformQuellenLogik.heuteAb)
            let akku = TagesformRechnung.rechnen(e).akku ?? -100
            if let vorher { XCTAssertLessThanOrEqual(abs(akku - vorher), 2, "\(stunde) Uhr: \(vorher) zu \(akku)") }
            vorher = akku
        }
        XCTAssertEqual(vorher, 80, "ab 14 Uhr zählt nur noch heute")
    }

    func testStundeHeuteUndVergangeneTage() {
        let jetzt = Datum.datum("2026-10-12").addingTimeInterval(15 * 3600 + 600)
        XCTAssertEqual(TagesformRechnung.stunde(tag: "2026-10-12", jetzt: jetzt), 15)
        XCTAssertEqual(TagesformRechnung.stunde(tag: "2026-10-11", jetzt: jetzt), 24)
    }

    // MARK: Gründe und Zahl

    func testGruendeSindNachEinflussSortiertUndHoechstDrei() {
        var e = B.voll()
        e.schlaf = B.schlafReihe([300])
        e.wasser = TagesformMass(ist: 0, ziel: 8, bezug: .vortag)
        e.hrv = B.reihe(70, B.hrvBasis)
        let r = TagesformRechnung.rechnen(e)
        XCTAssertFalse(r.gruende.isEmpty)
        XCTAssertLessThanOrEqual(r.gruende.count, TagesformRechnung.hoechstGruende)
        for (a, b) in zip(r.gruende, r.gruende.dropFirst()) {
            XCTAssertGreaterThanOrEqual(abs(a.einfluss), abs(b.einfluss))
        }
        for g in r.gruende { XCTAssertGreaterThanOrEqual(abs(g.einfluss), TagesformRechnung.mindestEinfluss) }
        let groesster = r.faktoren.max { abs($0.einfluss) < abs($1.einfluss) }
        XCTAssertEqual(r.gruende.first?.art, groesster?.art)
        // Wer draußen bleibt, hat höchstens so viel Einfluss wie der letzte Grund.
        let letzterEinfluss = abs(r.gruende.last?.einfluss ?? 0)
        for f in r.faktoren where !r.gruende.contains(where: { $0.art == f.art }) {
            XCTAssertLessThanOrEqual(abs(f.einfluss), letzterEinfluss + 1e-9, "\(f.art)")
        }
    }

    func testSatzNenntBremstUndHilft() {
        // 1.000 von 2.600 kcal bremsen am meisten (-6,0), Schlaf (+4,9) und HRV (+4,0) helfen. Erholte Muskeln, das gewohnte
        // Training und die Bettzeit sind normal und zählen nicht als Grund.
        var e = B.voll()
        e.kalorien = TagesformMass(ist: 1000, ziel: 2600, bezug: .vortag)
        e.hrv = B.reihe(70, B.hrvBasis)
        let r = TagesformRechnung.rechnen(e)
        XCTAssertNil(r.kappe)
        XCTAssertEqual(r.gruende.map { $0.art }, [.kalorien, .schlaf, .hrv])
        XCTAssertEqual(r.gruende.count, TagesformRechnung.hoechstGruende)
        let zeilen = r.satz.components(separatedBy: "\n")
        XCTAssertLessThanOrEqual(zeilen.count, TagesformRechnung.hoechstGruende)
        XCTAssertTrue(zeilen.contains { $0.hasPrefix("Bremst: ") })
        XCTAssertTrue(zeilen.contains { $0.hasPrefix("Hilft: ") })
        // Jede Zeile gehört zu einem Grund, in derselben Reihenfolge.
        let erwartet = r.gruende.map { ($0.einfluss < 0 ? "Bremst: " : "Hilft: ") + $0.kurz }
        XCTAssertEqual(Array(zeilen.suffix(erwartet.count)), erwartet)
    }

    func testEineWirkendeObergrenzeStehtZuerstUndNenntSchlafNurEinmal() {
        var e = B.voll()
        e.schlaf = B.schlafReihe([120])
        e.wasser = TagesformMass(ist: 0, ziel: 8, bezug: .vortag)
        e.hrv = B.reihe(50, B.hrvBasis)
        let r = TagesformRechnung.rechnen(e)
        XCTAssertEqual(r.kappe?.art, .schlaf)
        let zeilen = r.satz.components(separatedBy: "\n")
        XCTAssertEqual(zeilen.first, "Bremst: Schlaf 2:00 h deckelt dich bei 36 %")
        XCTAssertEqual(zeilen.count, TagesformRechnung.hoechstGruende, "die Obergrenze zählt als einer der drei Gründe")
        XCTAssertEqual(zeilen.filter { $0.contains("Schlaf") }.count, 1, "der Schlaf-Grund steht nicht noch einmal da")
        // Im Detail bleibt der Schlaf trotzdem der größte Einfluss.
        XCTAssertEqual(r.gruende.first?.art, .schlaf)
    }

    func testEinNormalerTagHatKeineGruende() {
        // 416 min von 480 geben 75,1 Punkte: kein Einfluss ab einem Punkt, also kein Grund.
        var e = TagesformEingabe()
        e.schlaf = [416]
        let r = TagesformRechnung.rechnen(e)
        XCTAssertTrue(r.gruende.isEmpty)
        XCTAssertEqual(r.satz, "Alles im normalen Bereich.\nWenig Daten, die Zahl ist grob.")
        XCTAssertEqual(r.akku, 75)
    }

    func testEinFaktorAufSeinemNormalwertHatKeinenEinfluss() {
        // Jeder Faktor steht auf seinem Normalwert: Schlaf (416 von 480 min = 75 Punkte), HRV und Ruhepuls beim eigenen Schnitt,
        // alles andere am Ziel. Dann hilft und bremst nichts, auch wenn die Zahl dabei hoch ist (87).
        var e = TagesformEingabe()
        e.schlaf = B.schlafReihe([416, 416, 416], rest: 416)
        e.bett = [Int?](repeating: 600, count: 7)
        e.hrv = B.reihe(58, B.hrvBasis)
        e.ruhepuls = B.reihe(56, B.pulsBasis)
        e.saetze = B.saetze(10, sonst: 10)
        e.kalorien = masse(2600, 2600)
        e.eiweiss = masse(160, 160)
        e.schritte = masse(10_000, 10_000)
        e.wasser = masse(8, 8)
        let r = TagesformRechnung.rechnen(e)
        XCTAssertEqual(r.faktoren.count, TagesformArt.allCases.count)
        for f in r.faktoren { XCTAssertEqual(f.einfluss, 0, accuracy: 0.05, "\(f.art)") }
        XCTAssertTrue(r.gruende.isEmpty)
        XCTAssertEqual(r.satz, "Alles im normalen Bereich.")
        XCTAssertEqual(r.akku, 87)
    }

    func testEinflussIstAnteilMalAbstandZumNormalwertDerArt() {
        // Wasser 2 von 8 Gläsern: 25 Punkte bei einem Normalwert von 100, Anteil 4 %: minus 3 Punkte.
        var e = B.voll()
        e.wasser = masse(2, 8)
        let r = TagesformRechnung.rechnen(e)
        let wasser = r.faktoren.first { $0.art == .wasser }
        XCTAssertEqual(wasser?.einfluss ?? 0, -3, accuracy: 1e-6)
        // HRV beim eigenen Schnitt (75 Punkte) ist normal; Schlaf von 7:50 h (93,77 Punkte) hebt um 0,26 mal 18,77 auf 4,88.
        XCTAssertEqual(r.faktoren.first { $0.art == .hrv }?.einfluss ?? 1, 0, accuracy: 1e-6)
        XCTAssertEqual(r.faktoren.first { $0.art == .schlaf }?.einfluss ?? 0, 4.88, accuracy: 0.005)
        // Der Normalwert eines Ziel-Faktors ist das Ziel: mehr als 100 gibt es nicht, also hilft er nie.
        let nachSeinemSchnitt: [TagesformArt] = [.schlaf, .hrv, .ruhepuls]
        for art in TagesformArt.allCases {
            let erwartet: Double = nachSeinemSchnitt.contains(art) ? TagesformRechnung.neutral : 100
            XCTAssertEqual(art.normal, erwartet, "\(art)")
        }
        XCTAssertEqual(r.gruende.map { $0.art }, [.schlaf, .wasser], "alles andere liegt unter einem Punkt")
    }

    func testJederFaktorSagtWasErBraucht() {
        for art in TagesformArt.allCases { XCTAssertFalse(art.braucht.isEmpty, "\(art)") }
        // Das Band liefert Ruhepuls und HRV noch nicht: das Detail sagt es, statt die beiden still unter "Ohne Daten" zu lassen.
        for art in [TagesformArt.hrv, .ruhepuls] {
            XCTAssertTrue(art.braucht.contains("Apple Health"), "\(art)")
            XCTAssertTrue(art.braucht.contains("Band"), "\(art)")
        }
    }

    func testDatenlageStufen() {
        XCTAssertEqual(TagesformRechnung.datenlage(1), "gut")
        XCTAssertEqual(TagesformRechnung.datenlage(0.8), "gut")
        XCTAssertEqual(TagesformRechnung.datenlage(0.79), "mittel")
        XCTAssertEqual(TagesformRechnung.datenlage(0.55), "mittel")
        XCTAssertEqual(TagesformRechnung.datenlage(0.54), "dünn")
    }
}
