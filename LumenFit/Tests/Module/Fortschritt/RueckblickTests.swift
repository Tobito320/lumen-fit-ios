import XCTest
@testable import LumenFit

/// Wochen- und Monatsrückblick (Idee 39) und FitPassport (Idee 40).
final class RueckblickTests: XCTestCase {
    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench", muskel: "Brust", koerper: "Brust", geraet: "", neben: [])
    private let knie = Uebung(id: "knie", name: "Kniebeuge", en: "squat", muskel: "Quadrizeps", koerper: "Beine", geraet: "", neben: [])

    private func katalog(_ id: String) -> Uebung? { [bank.id: bank, knie.id: knie][id] }

    private func satz(_ kg: Double, _ wdh: Int, typ: String? = nil) -> PlanSatz { PlanSatz(wdh: wdh, kg: kg, failure: false, typ: typ) }

    private func einheit(_ tag: String, _ laeufe: [(uebung: String, saetze: [PlanSatz])]) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let runden = laeufe.map { UebungsLauf(plan: $0.uebung, uebung: $0.uebung, start: start, ende: start.addingTimeInterval(900), fertig: true, saetze: $0.saetze) }
        return GymSession(id: "s-\(tag)", tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: runden)
    }

    /// Eine Einheit vor der Woche (Bankdrücken 60 x 8) und eine in der Woche (Bankdrücken 70 x 8 zweimal, Kniebeuge zum ersten Mal).
    private var sessions: [GymSession] {
        [einheit("2026-10-01", [("bank", [satz(60, 8)])]),
         einheit("2026-10-13", [("bank", [satz(70, 8), satz(70, 8), satz(20, 10, typ: "w")]), ("knie", [satz(100, 5)])])]
    }

    private func woche(_ gym: [String: Int] = [:], schlaf: [String: Int] = [:], bezug: String = "2026-10-18", sessions: [GymSession]? = nil) -> RueckblickDaten {
        Rueckblick.bauen(.woche, bezug: bezug, sessions: sessions ?? self.sessions, gym: gym, schlafMinuten: schlaf, katalog: katalog)
    }

    // MARK: Zeitraum

    func testWocheGehtVonMontagBisSonntag() {
        for bezug in ["2026-10-12", "2026-10-14", "2026-10-18"] {
            let g = Rueckblick.grenzen(.woche, bezug: bezug)
            XCTAssertEqual(g.von, "2026-10-12", bezug)
            XCTAssertEqual(g.bis, "2026-10-18", bezug)
        }
    }

    func testMonatGehtVomErstenBisZumLetztenTag() {
        XCTAssertEqual(Rueckblick.grenzen(.monat, bezug: "2026-10-18").bis, "2026-10-31")
        XCTAssertEqual(Rueckblick.grenzen(.monat, bezug: "2026-10-18").von, "2026-10-01")
        XCTAssertEqual(Rueckblick.grenzen(.monat, bezug: "2026-02-10").bis, "2026-02-28")
        XCTAssertEqual(Rueckblick.grenzen(.monat, bezug: "2028-02-10").bis, "2028-02-29")
        XCTAssertEqual(Rueckblick.grenzen(.monat, bezug: "2026-12-05").bis, "2026-12-31")
    }

    // MARK: Zahlen

    func testWochenzahlen() {
        let r = woche(["2026-10-15": 1, "2026-10-14": 0, "2026-10-05": 1], schlaf: ["2026-10-13": 420, "2026-10-14": 480, "2026-10-20": 600])
        XCTAssertEqual(r.gymTage, 2, "Einheit am 13. und Häkchen am 15.; die Häkchen davor und danach zählen nicht")
        XCTAssertEqual(r.einheiten, 1)
        XCTAssertEqual(r.saetze, 3, "der Aufwärmsatz zählt nicht")
        XCTAssertEqual(r.volumenKg, 70 * 8 * 2 + 500)
        XCTAssertEqual(r.schlafSchnitt, 450)
        XCTAssertEqual(r.schlafNaechte, 2)
        XCTAssertEqual(r.titel, "Deine Woche: 2 Gym-Tage")
        XCTAssertEqual(r.zeile, "Volumen 1.620 kg · 3 Sätze · Schlaf im Schnitt 7 h 30 min")
        XCTAssertEqual(r.stimmung, .stolz)
    }

    func testMonatZaehltAlleEinheitenDesMonats() {
        let r = Rueckblick.bauen(.monat, bezug: "2026-10-18", sessions: sessions, gym: [:], schlafMinuten: [:], katalog: katalog)
        XCTAssertEqual(r.einheiten, 2)
        XCTAssertEqual(r.gymTage, 2)
        XCTAssertEqual(r.titel, "Dein Monat: 2 Gym-Tage")
        XCTAssertNil(r.schlafSchnitt)
        XCTAssertEqual(r.zeile, "Volumen 2.100 kg · 4 Sätze")
    }

    func testLeerFreundlichMitWartesatz() {
        let r = woche(sessions: [])
        XCTAssertEqual(r.titel, "Noch kein Training in dieser Woche")
        XCTAssertEqual(r.gymTage, 0)
        XCTAssertEqual(r.besterMoment, "Dein bester Moment kommt noch. Lumi wartet.")
        XCTAssertEqual(r.stimmung, .bereit)
        XCTAssertEqual(r.sprechtext, "Noch kein Training in dieser Woche. Dein bester Moment kommt noch. Lumi wartet.")
        XCTAssertEqual(Rueckblick.bauen(.monat, bezug: "2026-10-18", sessions: [], gym: [:], schlafMinuten: [:], katalog: katalog).titel, "Noch kein Training in diesem Monat")
    }

    func testEinGymTagIstEinzahl() {
        XCTAssertEqual(woche(["2026-10-15": 1], sessions: []).titel, "Deine Woche: 1 Gym-Tag")
    }

    // MARK: Bester Moment

    func testRekordSchlaegtSchwerstenSatz() {
        // Bankdrücken: 76 vor der Woche, 88,7 in der Woche. Kniebeuge (100 kg) ist schwerer, hat aber keinen Vorgänger.
        XCTAssertEqual(woche().besterMoment, "Rekord: Bankdrücken, 70 kg × 8")
    }

    func testOhneRekordDerSchwersteSatz() {
        let nur = [einheit("2026-10-13", [("bank", [satz(70, 8)]), ("knie", [satz(100, 5)])])]
        XCTAssertEqual(woche(sessions: nur).besterMoment, "Schwerster Satz: Kniebeuge, 100 kg × 5")
    }

    func testRekordMitKleinererSteigerungUnterliegtDemGroesseren() {
        let s = [einheit("2026-10-01", [("bank", [satz(60, 8)]), ("knie", [satz(100, 5)])]),
                 einheit("2026-10-13", [("bank", [satz(62.5, 8)]), ("knie", [satz(120, 5)])])]
        XCTAssertEqual(woche(sessions: s).besterMoment, "Rekord: Kniebeuge, 120 kg × 5")
    }

    func testAufwaermsatzIstNieDerBesteMoment() {
        let s = [einheit("2026-10-13", [("bank", [satz(200, 5, typ: "w"), satz(60, 8)])])]
        XCTAssertEqual(woche(sessions: s).besterMoment, "Schwerster Satz: Bankdrücken, 60 kg × 8")
    }

    func testOhneTrainingNimmtDieBesteNacht() {
        let r = woche(schlaf: ["2026-10-13": 480, "2026-10-14": 450], sessions: [])
        XCTAssertEqual(r.besterMoment, "Beste Nacht: 8 h 00 min am Dienstag, 13. Oktober")
    }

    func testEigeneUebungOhneKatalogGibtKeinenMoment() {
        let s = [einheit("2026-10-13", [("eigen", [satz(50, 10)])])]
        XCTAssertEqual(woche(sessions: s).besterMoment, "Dein bester Moment kommt noch. Lumi wartet.")
    }

    func testTexteSindDeutschUndKurz() {
        XCTAssertEqual(Rueckblick.dauer(450), "7 h 30 min")
        XCTAssertEqual(Rueckblick.dauer(65), "1 h 05 min")
        XCTAssertEqual(Rueckblick.zahl(12_400), "12.400")
        XCTAssertEqual(Rueckblick.satzText(PlanSatz(wdh: 12, kg: nil, failure: false)), "12 Wdh")
        XCTAssertEqual(Rueckblick.satzText(satz(62.5, 8)), "62,5 kg × 8")
        XCTAssertEqual(RueckblickDaten.Zeitraum.allCases.map(\.name), ["Woche", "Monat"])
    }
}

/// FitPassport (Idee 40): Langzeitwerte, nur eigene Daten.
final class FitPassportTests: XCTestCase {
    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench", muskel: "Brust", koerper: "Brust", geraet: "", neben: [])
    private let knie = Uebung(id: "knie", name: "Kniebeuge", en: "squat", muskel: "Quadrizeps", koerper: "Beine", geraet: "", neben: [])
    private func katalog(_ id: String) -> Uebung? { [bank.id: bank, knie.id: knie][id] }
    private let heute = "2026-10-14"

    private func einheit(_ tag: String, _ uebung: String, _ kg: Double, _ wdh: Int) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let lauf = UebungsLauf(plan: uebung, uebung: uebung, start: start, ende: start.addingTimeInterval(900), fertig: true, saetze: [PlanSatz(wdh: wdh, kg: kg, failure: false)])
        return GymSession(id: "s-\(tag)-\(uebung)", tag: nil, start: start, ende: start.addingTimeInterval(3600), laeufe: [lauf])
    }

    func testKraftSchlafKonstanzUndStufe() {
        let s = [einheit("2026-10-05", "bank", 60, 8), einheit("2026-10-12", "bank", 70, 8), einheit("2026-10-13", "knie", 100, 5)]
        let schlaf = ["2026-10-10": 420, "2026-10-11": 480, "2026-06-01": 100]
        let p = FitPassport.bauen(name: "Beispiel", sessions: s, gym: ["2026-10-08": 1], schlafMinuten: schlaf, medaillen: 5, heute: heute, katalog: katalog)
        XCTAssertEqual(p.kraft.map(\.name), ["Bankdrücken", "Kniebeuge"], "die meistgemachte zuerst")
        XCTAssertEqual(p.kraft.first?.e1rmKg, 89, "70 x 8 = 88,7")
        XCTAssertEqual(p.kraft.last?.e1rmKg, 117, "100 x 5 = 116,7")
        XCTAssertEqual(p.schlafSchnitt, 450, "die Nacht vom Juni liegt außerhalb der 60 Tage")
        XCTAssertEqual(p.schlafNaechte, 2)
        XCTAssertEqual(p.gymTage, 4)
        XCTAssertEqual(p.aktiveWochen, 2)
        XCTAssertEqual(p.serieWochen, 2)
        XCTAssertEqual(p.medaillen, 5)
        XCTAssertEqual(p.stufe, LumiStufe.stufe(erreicht: 5))
        XCTAssertEqual(p.titel, "FitPassport: Stufe 4, 4 Gym-Tage")
    }

    func testHoechstensDreiUebungen() {
        let u = (0..<5).map { Uebung(id: "u\($0)", name: "Übung \($0)", en: "", muskel: "Brust", koerper: "Brust", geraet: "", neben: []) }
        let nachId = Dictionary(uniqueKeysWithValues: u.map { ($0.id, $0) })
        let s = u.map { einheit("2026-10-12", $0.id, 50, 8) }
        let p = FitPassport.bauen(name: nil, sessions: s, gym: [:], schlafMinuten: [:], medaillen: 0, heute: heute, katalog: { nachId[$0] })
        XCTAssertEqual(p.kraft.count, 3)
    }

    func testOhneDatenIstLeerAberGueltig() {
        let p = FitPassport.bauen(name: "  ", sessions: [], gym: [:], schlafMinuten: [:], medaillen: 0, heute: heute, katalog: katalog)
        XCTAssertNil(p.name, "ein leerer Name wird keiner")
        XCTAssertTrue(p.kraft.isEmpty)
        XCTAssertNil(p.schlafSchnitt)
        XCTAssertEqual(p.stufe, 1)
        XCTAssertEqual(p.titel, "FitPassport: Stufe 1, 0 Gym-Tage")
        XCTAssertEqual(p.sprechtext, "FitPassport: Stufe 1, 0 Gym-Tage. Konstanz: 0 von 18 Wochen, Serie 0 Wochen. 0 von 33 Medaillen")
    }

    /// Nur eigene Werte: der Name steht auf der Karte, wenn der Aufrufer ihn gibt, sonst kein Name; es gibt kein Feld für Partner oder Freunde.
    func testNurDerEigeneNameUndKeinDritter() {
        let mit = FitPassport.bauen(name: "Beispiel", sessions: [], gym: [:], schlafMinuten: [:], medaillen: 0, heute: heute, katalog: katalog)
        XCTAssertEqual(mit.name, "Beispiel")
        XCTAssertFalse(mit.sprechtext.contains("Beispiel"), "der Name steht im Bild, nicht im Sprechtext der Werte")
        let felder = Mirror(reflecting: mit).children.compactMap(\.label)
        XCTAssertEqual(Set(felder), ["name", "kraft", "schlafSchnitt", "schlafNaechte", "aktiveWochen", "serieWochen", "gymTage", "medaillen", "stufe"])
    }
}
