import XCTest
@testable import LumenFit

/// Die Medaillen (Idee 37), 25 alte und 8 Ziel-Medaillen: Katalog als Daten, Prüfung als Funktion von den Daten zur Liste der Kennungen.
final class MeilensteinPruefungTests: XCTestCase {
    /// Mittwoch 14.10.2026; die Woche geht vom 12. bis 18.10.
    private let heute = "2026-10-14"
    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench", muskel: "Brust", koerper: "Brust", geraet: "", neben: [])

    private func katalog(_ id: String) -> Uebung? { id == "bank" ? bank : nil }

    private func einheit(_ tag: String, _ saetze: [PlanSatz], uebung: String = "bank", minuten: Double = 45) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let lauf = UebungsLauf(plan: "p", uebung: uebung, start: start, ende: start.addingTimeInterval(600), fertig: true, saetze: saetze)
        return GymSession(id: "s-\(tag)-\(uebung)", tag: nil, start: start, ende: start.addingTimeInterval(minuten * 60), laeufe: [lauf])
    }

    private func satz(_ kg: Double = 60, _ wdh: Int = 8, typ: String? = nil) -> PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ) }

    private func faellig(_ d: MeilensteinDaten, schon: Set<String> = []) -> [String] {
        MeilensteinPruefung.faellig(d, schon: schon, katalog: katalog)
    }

    // MARK: Katalog

    func testKatalogHatDreiunddreissigMedaillenMitEindeutigenKennungen() {
        XCTAssertEqual(MeilensteinKatalog.alle.count, 33)
        XCTAssertEqual(Set(MeilensteinKatalog.alle.map(\.id)).count, 33)
        for m in MeilensteinKatalog.alle {
            XCTAssertFalse(m.titel.isEmpty, m.id)
            XCTAssertFalse(m.bedingung.isEmpty, m.id)
            XCTAssertFalse(m.symbol.isEmpty, m.id)
        }
        XCTAssertEqual(MeilensteinKatalog.nachId.count, 33)
    }

    /// Die Demo legt diese drei an (`Demo.swift`); fehlt eine im Katalog, zählt sie in Lumis Stufe, hat aber keine Medaille.
    func testDemoKennungenGibtEsImKatalog() {
        for id in ["erster-satz", "erste-woche", "fruehstueck"] { XCTAssertNotNil(MeilensteinKatalog.nachId[id], id) }
    }

    /// Jede Kennung im Katalog hat eine Regel: leere Daten erfüllen keine, und `erfuellt` kennt jede Kennung.
    func testLeereDatenErfuellenNichtsUndJedeKennungHatEineRegel() {
        XCTAssertTrue(faellig(MeilensteinDaten()).isEmpty)
        var alles = MeilensteinZahlen()
        alles.gezaehlteSaetze = 1; alles.gymTage = 500; alles.volumenKg = 1_000_000; alles.serieWochen = 100; alles.rekorde = 100
        alles.wochenZielErreicht = true; alles.ganzerKoerperInEinerWoche = true; alles.langeEinheit = true; alles.schlafSerie = 30
        alles.schlafNaechteImZiel = 100; alles.wochenzielSerie = 30; alles.schrittSerie = 7; alles.schrittTage = 30; alles.proteinSerie = 7
        alles.proteinTage = 30; alles.kalorienTage = 7; alles.gewichtGewogen = true; alles.gewichtZielErreicht = true; alles.essenTage = 100; alles.fruehstueck = true
        for m in MeilensteinKatalog.alle { XCTAssertTrue(MeilensteinPruefung.erfuellt(m.id, alles), m.id) }
        XCTAssertFalse(MeilensteinPruefung.erfuellt("gibt-es-nicht", alles))
    }

    // MARK: Training

    func testErsterSatzZaehltNurMitGezaehltemSatz() {
        XCTAssertEqual(faellig(MeilensteinDaten(sessions: [einheit("2026-10-13", [satz(typ: "w")])], heute: heute)), [])
        XCTAssertEqual(faellig(MeilensteinDaten(sessions: [einheit("2026-10-13", [satz()])], heute: heute)), ["erster-satz"])
    }

    func testBereitsErreichteKommenNichtNochMal() {
        let d = MeilensteinDaten(sessions: [einheit("2026-10-13", [satz()])], heute: heute)
        XCTAssertEqual(faellig(d, schon: ["erster-satz"]), [])
    }

    func testGymTageZaehlenEinheitenUndHaekchenEinmalJeTag() {
        var gym: [String: Int] = [:]
        for i in 0..<9 { gym[Datum.addTage("2026-10-01", i)] = 1 }              // 9 Häkchen
        gym["2026-10-10"] = 0                                                    // 0 = nicht abgehakt
        let s = [einheit("2026-10-01", [satz()]), einheit("2026-10-13", [satz()])]   // 1.10. doppelt, 13.10. neu
        let z = MeilensteinPruefung.zahlen(MeilensteinDaten(sessions: s, gymTage: gym, heute: heute), katalog: katalog)
        XCTAssertEqual(z.gymTage, 10)
        XCTAssertTrue(faellig(MeilensteinDaten(sessions: s, gymTage: gym, heute: heute)).contains("gym-10"))
    }

    func testErsteWocheBrauchtDasWochenziel() {
        let s = [einheit("2026-10-12", [satz()]), einheit("2026-10-13", [satz()])]
        XCTAssertFalse(faellig(MeilensteinDaten(sessions: s, gymTageProWoche: 3, heute: heute)).contains("erste-woche"))
        XCTAssertTrue(faellig(MeilensteinDaten(sessions: s, gymTageProWoche: 2, heute: heute)).contains("erste-woche"))
        XCTAssertTrue(faellig(MeilensteinDaten(sessions: [einheit("2026-10-12", [satz()])], gymTageProWoche: 0, heute: heute)).contains("erste-woche"), "Ziel 0 verlangt einen Tag")
    }

    func testVolumenZaehltAufwaermenNicht() {
        let s = [einheit("2026-10-12", [satz(100, 100), satz(500, 100, typ: "w")])]   // 10.000 kg und ein Aufwärmsatz mit 50.000 kg
        let z = MeilensteinPruefung.zahlen(MeilensteinDaten(sessions: s, heute: heute), katalog: katalog)
        XCTAssertEqual(z.volumenKg, 10_000)
        XCTAssertTrue(faellig(MeilensteinDaten(sessions: s, heute: heute)).contains("volumen-10000"))
        XCTAssertFalse(faellig(MeilensteinDaten(sessions: s, heute: heute)).contains("volumen-50000"))
    }

    func testSerieZaehltWochenInFolgeUndDieLeereLaufendeWocheBrichtNicht() {
        XCTAssertEqual(MeilensteinPruefung.serieWochen(tage: ["2026-10-13", "2026-10-06", "2026-09-30", "2026-09-22"], heute: heute), 4)
        XCTAssertEqual(MeilensteinPruefung.serieWochen(tage: ["2026-10-06", "2026-09-30"], heute: heute), 2, "diese Woche noch leer")
        XCTAssertEqual(MeilensteinPruefung.serieWochen(tage: ["2026-10-13", "2026-09-30"], heute: heute), 1, "eine Lücke bricht die Serie")
        XCTAssertEqual(MeilensteinPruefung.serieWochen(tage: [], heute: heute), 0)
        XCTAssertEqual(MeilensteinPruefung.serieWochen(tage: ["2026-08-01"], heute: heute), 0)
    }

    func testRekordeZaehlenNurSteigerungenNachDemErstenMal() {
        let s = [einheit("2026-10-01", [satz(60, 8)]), einheit("2026-10-05", [satz(65, 8)]), einheit("2026-10-08", [satz(60, 8)]),
                 einheit("2026-10-12", [satz(70, 5)])]
        // 60x8 = 76, 65x8 = 82,3 (Rekord), 60x8 (nein), 70x5 = 81,7 (nein): ein Rekord.
        XCTAssertEqual(MeilensteinPruefung.rekorde(s), 1)
        XCTAssertEqual(MeilensteinPruefung.rekorde([einheit("2026-10-01", [satz(60, 8)])]), 0, "das erste Mal ist kein Rekord")
        XCTAssertEqual(MeilensteinPruefung.rekorde([einheit("2026-10-01", [satz(60, 8)]), einheit("2026-10-05", [satz(200, 8, typ: "w")])]), 0, "Aufwärmen zählt nicht")
    }

    func testGanzerKoerperBrauchtSiebenGruppenInEinerWoche() {
        func u(_ id: String, _ muskel: String, _ neben: [String] = []) -> Uebung { Uebung(id: id, name: id, en: id, muskel: muskel, koerper: "", geraet: "", neben: neben) }
        let kat = [u("a", "Brust", ["Trizeps"]), u("b", "Latissimus", ["Bizeps"]), u("c", "Schultern"), u("d", "Bauch"), u("e", "Quadrizeps")]
        let nachId = Dictionary(uniqueKeysWithValues: kat.map { ($0.id, $0) })
        func woche(_ ids: [String], tag: String = "2026-10-13") -> [GymSession] { ids.map { einheit(tag, [satz()], uebung: $0) } }
        XCTAssertTrue(MeilensteinPruefung.hatGanzerKoerperWoche(woche(["a", "b", "c", "d", "e"]), katalog: { nachId[$0] }))
        XCTAssertFalse(MeilensteinPruefung.hatGanzerKoerperWoche(woche(["a", "b", "c", "d"]), katalog: { nachId[$0] }), "Beine fehlen")
        let verteilt = woche(["a", "b", "c"], tag: "2026-10-13") + woche(["d", "e"], tag: "2026-10-20")
        XCTAssertFalse(MeilensteinPruefung.hatGanzerKoerperWoche(verteilt, katalog: { nachId[$0] }), "alles in einer Woche")
    }

    func testLangeEinheitBrauchtEineStundeUndKeinVergessenesAuschecken() {
        XCTAssertTrue(faellig(MeilensteinDaten(sessions: [einheit("2026-10-13", [satz()], minuten: 60)], heute: heute)).contains("lange-einheit"))
        XCTAssertFalse(faellig(MeilensteinDaten(sessions: [einheit("2026-10-13", [satz()], minuten: 59)], heute: heute)).contains("lange-einheit"))
        XCTAssertFalse(faellig(MeilensteinDaten(sessions: [einheit("2026-10-13", [satz()], minuten: 300)], heute: heute)).contains("lange-einheit"), "länger als 3 Stunden: vergessen")
    }

    // MARK: Schlaf, Gewicht, Essen

    func testSchlafSerieZaehltTageInFolge() {
        let ziel = 420
        let minuten = ["2026-10-01": 430, "2026-10-02": 440, "2026-10-03": 400, "2026-10-04": 450, "2026-10-05": 450, "2026-10-06": 421]
        XCTAssertEqual(MeilensteinPruefung.schlafSerie(minuten, ziel: ziel), 3)
        XCTAssertEqual(MeilensteinPruefung.schlafSerie([:], ziel: ziel), 0)
        XCTAssertEqual(MeilensteinPruefung.schlafSerie(minuten, ziel: 0), 0)
        var sieben: [String: Int] = [:]
        for i in 0..<7 { sieben[Datum.addTage("2026-10-01", i)] = 480 }
        XCTAssertTrue(faellig(MeilensteinDaten(heute: heute, schlafMinuten: sieben, schlafZiel: 480)).contains("schlaf-7"))
        XCTAssertFalse(faellig(MeilensteinDaten(heute: heute, schlafMinuten: sieben, schlafZiel: 481)).contains("schlaf-7"))
    }

    func testDreissigNaechteImZielMuessenNichtInFolgeSein() {
        var n: [String: Int] = [:]
        for i in 0..<45 where i % 3 != 2 { n[Datum.addTage("2026-08-01", i)] = 500 }
        let d = MeilensteinDaten(heute: heute, schlafMinuten: n, schlafZiel: 480)
        XCTAssertEqual(n.count, 30)
        XCTAssertTrue(faellig(d).contains("schlaf-30"))
        XCTAssertFalse(faellig(d).contains("schlaf-7"))
    }

    func testGewichtErsteWiegungUndZielNurWennManVomZielWegStartete() {
        XCTAssertTrue(faellig(MeilensteinDaten(heute: heute, gewicht: ["2026-10-01": 800])).contains("wiegen-erste"))
        XCTAssertFalse(faellig(MeilensteinDaten(heute: heute, gewicht: ["2026-10-01": 0])).contains("wiegen-erste"))
        let weg = MeilensteinDaten(heute: heute, gewicht: ["2026-08-01": 820, "2026-10-12": 752], gewichtZielKg: 75)
        XCTAssertTrue(faellig(weg).contains("gewicht-ziel"))
        let schonDa = MeilensteinDaten(heute: heute, gewicht: ["2026-08-01": 752, "2026-10-12": 751], gewichtZielKg: 75)
        XCTAssertFalse(faellig(schonDa).contains("gewicht-ziel"), "wer am Ziel anfängt, hat nichts erreicht")
        let nochNicht = MeilensteinDaten(heute: heute, gewicht: ["2026-08-01": 820, "2026-10-12": 780], gewichtZielKg: 75)
        XCTAssertFalse(faellig(nochNicht).contains("gewicht-ziel"))
        XCTAssertFalse(faellig(MeilensteinDaten(heute: heute, gewicht: ["2026-08-01": 820, "2026-10-12": 752])).contains("gewicht-ziel"), "ohne Ziel")
    }

    func testTagebuchUndFruehstueck() {
        var tage = Set<String>()
        for i in 0..<7 { tage.insert(Datum.addTage("2026-10-01", i)) }
        let d = MeilensteinDaten(heute: heute, essenTage: tage, fruehstueckTage: 0)
        XCTAssertTrue(faellig(d).contains("tagebuch-7"))
        XCTAssertFalse(faellig(d).contains("tagebuch-30"))
        XCTAssertFalse(faellig(d).contains("fruehstueck"))
        XCTAssertTrue(faellig(MeilensteinDaten(heute: heute, essenTage: ["2026-10-13"], fruehstueckTage: 1)).contains("fruehstueck"))
    }

    // MARK: Toast-Text

    func testToastTextEineMedailleMehrereUndNeueStufe() {
        XCTAssertEqual(MeilensteinWaechter.toastInhalt(["erster-satz"], neueStufe: nil)?.titel, "Neue Medaille: Erster Satz")
        XCTAssertEqual(MeilensteinWaechter.toastInhalt(["erster-satz"], neueStufe: nil)?.stimmung, .ziel)
        XCTAssertEqual(MeilensteinWaechter.toastInhalt(["erster-satz", "gym-10", "wiegen-erste"], neueStufe: nil)?.titel, "3 neue Medaillen")
        XCTAssertEqual(MeilensteinWaechter.toastInhalt(["erster-satz"], neueStufe: 2)?.titel, "Lumi ist jetzt Stufe 2")
        XCTAssertEqual(MeilensteinWaechter.toastInhalt(["erster-satz"], neueStufe: 2)?.zeile, "Neue Medaille: Erster Satz")
        XCTAssertNil(MeilensteinWaechter.toastInhalt(["gibt-es-nicht"], neueStufe: nil))
        XCTAssertNil(MeilensteinWaechter.toastInhalt([], neueStufe: nil))
    }
}

/// Der Wächter gegen echte Ops in einem Temp-Ordner (Naht 1 aus SPEC 11): nie doppelt, überlebt den Neustart, ein Toast je Vergabe.
@MainActor
final class MeilensteinWaechterTests: XCTestCase {
    private let uhr = TestUhr()
    private var heute: String { Datum.text(uhr.lesen) }

    private func satz(_ ordner: URL, kanal: EreignisKanal = EreignisKanal()) -> DatenSatz {
        DatenSatz(profil: .testA, ordner: ordner, ereignisse: kanal, uhr: uhr.uhr)
    }

    /// Eine halbe Stunde, zwei gezählte Sätze: genug für "Erster Satz", zu kurz für "Eine volle Stunde".
    private func trainiere(_ s: DatenSatz) {
        let start = uhr.lesen
        let saetze = [PlanSatz(wdh: 8, kg: 60, failure: false, ok: true), PlanSatz(wdh: 8, kg: 62.5, failure: false, ok: true)]
        let eintraege: [(String, GymD, Date)] = [
            ("gym.checkin", GymD(session: "w-einheit", tag: "push", start: start), start),
            ("gym.uebung", GymD(session: "w-einheit", plan: "p1", uebung: "bank", status: "satz", saetze: saetze), start + 600),
            ("gym.checkout", GymD(session: "w-einheit", ende: start + 1800, status: "ende"), start + 1800),
        ]
        for (art, d, zeit) in eintraege {
            s.raum.einreihen(Op(id: "w-\(art)-\(zeit.timeIntervalSince1970)", art: art, von: .testA, zeit: zeit, d: (try? JSONEncoder().encode(d)) ?? Data()))
        }
    }

    func testVergibtEinmalUndSchreibtDenOp() throws {
        let s = satz(try tempOrdner())
        let w = MeilensteinWaechter()
        XCTAssertEqual(w.pruefe(s, naechte: [:], heute: heute), [])
        trainiere(s)
        XCTAssertEqual(w.pruefe(s, naechte: [:], heute: heute), ["erster-satz"])
        XCTAssertTrue(s.meilensteine.istErreicht("erster-satz"))
        XCTAssertEqual(s.raum.ops(arten: [MeilensteinStore.art]).count, 1)
        XCTAssertEqual(w.pruefe(s, naechte: [:], heute: heute), [], "ein zweiter Lauf vergibt nichts")
        XCTAssertEqual(s.raum.ops(arten: [MeilensteinStore.art]).count, 1, "kein zweiter Op")
    }

    func testNeueStufeZeigtEinenToastUndZaehltDieHaptik() throws {
        let s = satz(try tempOrdner())
        let w = MeilensteinWaechter()
        trainiere(s)
        w.pruefe(s, naechte: [:], heute: heute)
        XCTAssertEqual(s.meilensteine.stufe, 2)
        XCTAssertEqual(w.toast?.titel, "Lumi ist jetzt Stufe 2")
        XCTAssertEqual(w.stufenZaehler, 1)
        w.toast = nil
        w.pruefe(s, naechte: [:], heute: heute)
        XCTAssertNil(w.toast, "derselbe Meilenstein zeigt den Toast nicht noch einmal")
        XCTAssertEqual(w.stufenZaehler, 1)
    }

    func testMedailleOhneNeueStufeZeigtNurDieMedaille() throws {
        let s = satz(try tempOrdner())
        let w = MeilensteinWaechter()
        trainiere(s)
        w.pruefe(s, naechte: [:], heute: heute)
        w.toast = nil
        s.habits.setze(Habit.gewicht.id, datum: heute, wert: 785)
        XCTAssertEqual(w.pruefe(s, naechte: [:], heute: heute), ["wiegen-erste"])
        XCTAssertEqual(s.meilensteine.stufe, 2, "zwei Medaillen sind noch Stufe 2")
        XCTAssertEqual(w.toast?.titel, "Neue Medaille: Erste Wiegung")
        XCTAssertEqual(w.stufenZaehler, 1)
    }

    func testMedaillenUeberlebenDenNeustartUndKommenNichtNochMal() throws {
        let ordner = try tempOrdner()
        let erster = satz(ordner)
        let w = MeilensteinWaechter()
        trainiere(erster)
        w.pruefe(erster, naechte: [:], heute: heute)

        let zweiter = satz(ordner)
        XCTAssertEqual(zweiter.meilensteine.erreicht.map(\.id), ["erster-satz"])
        XCTAssertEqual(zweiter.meilensteine.stufe, 2)
        let neu = MeilensteinWaechter()
        XCTAssertEqual(neu.pruefe(zweiter, naechte: [:], heute: heute), [])
        XCTAssertNil(neu.toast)
        XCTAssertEqual(zweiter.raum.ops(arten: [MeilensteinStore.art]).count, 1)
    }

    func testFruehstueckUndTagebuchKommenAusDemEssenStore() throws {
        let s = satz(try tempOrdner())
        let w = MeilensteinWaechter()
        for op in TestDaten.essenOps(von: .testA, datum: heute, zeit: uhr.lesen) { s.raum.einreihen(op) }
        XCTAssertEqual(w.pruefe(s, naechte: [:], heute: heute), ["fruehstueck"])
    }

    func testSchlafUndGewichtsZielKommenAusDenZielen() throws {
        let s = satz(try tempOrdner())
        s.ziele.setze({ var z = s.ziele.ziele; z.schlafMinuten = 420; z.gewichtKg = 75; return z }())
        var naechte: [String: SchlafNacht] = [:]
        for i in 0..<7 {
            let tag = Datum.addTage(Datum.addTage(heute, -10), i)
            let ende = Datum.datum(tag).addingTimeInterval(7 * 3600)
            naechte[tag] = SchlafNacht(tag: tag, von: ende.addingTimeInterval(-450 * 60), bis: ende, abschnitte: [], schlafMinuten: 450)
        }
        let w = MeilensteinWaechter()
        XCTAssertEqual(w.pruefe(s, naechte: naechte, heute: heute), ["schlaf-7"])
    }
}
