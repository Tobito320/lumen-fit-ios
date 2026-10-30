import XCTest
@testable import LumenFit

/// Die reine Rechnung der Essen-Live-Activity: Stand aus dem Tagebuch, nächste Mahlzeit, Bogenanteil, Texte, Entscheidung, Schalter.
final class EssenLiveLogikTests: XCTestCase {
    private func eintrag(_ m: Mahlzeit, kcal: Double, protein: Double = 0) -> EssenEintrag {
        let l = Lebensmittel(id: "l-\(m.rawValue)", name: "Essen \(m.rawValue)", pro100: Naehrwerte(kcal: kcal, protein: protein, kohlenhydrate: 10, fett: 5))
        return EssenEintrag(id: "e-\(m.rawValue)", datum: "2026-09-23", mahlzeit: m, menge: 100, einheit: .g, lebensmittel: l, geloescht: nil)
    }

    private func stand(kcal: Int = 800, ziel: Int = 2000, mahlzeiten: [Int] = [300, 500, 0, 0], naechste: String? = "abend") -> EssenLiveStand {
        EssenLiveStand(tag: "2026-09-23", kcal: kcal, kcalZiel: ziel, proteinG: 85, proteinZiel: 120, kohlenhydrateG: 90, kohlenhydrateZiel: 220,
                       fettG: 30, fettZiel: 70, mahlzeitenKcal: mahlzeiten, naechste: naechste)
    }

    // MARK: - Stand

    func testStandSummiertTagUndMahlzeiten() {
        let eintraege = [eintrag(.fruehstueck, kcal: 300, protein: 20), eintrag(.mittag, kcal: 500, protein: 30)]
        let s = EssenLiveLogik.stand(eintraege: eintraege, ziele: ErnaehrungsZiele(), tag: "2026-09-23", stunde: 14)
        XCTAssertEqual(s.kcal, 800)
        XCTAssertEqual(s.kcalZiel, 2000)
        XCTAssertEqual(s.proteinG, 50)
        XCTAssertEqual(s.proteinZiel, 120)
        XCTAssertEqual(s.mahlzeitenKcal, [300, 500, 0, 0])
        XCTAssertEqual(s.tag, "2026-09-23")
        XCTAssertEqual(s.naechste, "abend")
    }

    func testLeererTagHatNullenUndDieMahlzeitDerTageszeit() {
        let s = EssenLiveLogik.stand(eintraege: [], ziele: ErnaehrungsZiele(), tag: "2026-09-23", stunde: 8)
        XCTAssertEqual(s.kcal, 0)
        XCTAssertEqual(s.mahlzeitenKcal, [0, 0, 0, 0])
        XCTAssertEqual(s.naechste, "fruehstueck")
    }

    func testNaechsteMahlzeit() {
        XCTAssertEqual(EssenLiveLogik.naechsteMahlzeit(mahlzeitenKcal: [0, 0, 0, 0], stunde: 8), .fruehstueck)
        XCTAssertEqual(EssenLiveLogik.naechsteMahlzeit(mahlzeitenKcal: [200, 0, 0, 0], stunde: 8), .mittag)
        XCTAssertEqual(EssenLiveLogik.naechsteMahlzeit(mahlzeitenKcal: [200, 500, 600, 0], stunde: 12), .snack)
        XCTAssertNil(EssenLiveLogik.naechsteMahlzeit(mahlzeitenKcal: [200, 500, 600, 100], stunde: 12))
        // Nachts zählt der Snack; ist er voll, bleibt nichts offen.
        XCTAssertNil(EssenLiveLogik.naechsteMahlzeit(mahlzeitenKcal: [0, 0, 0, 100], stunde: 23))
        // Eine offene Mahlzeit vor der aktuellen Tageszeit wird nicht nachgereicht.
        XCTAssertNil(EssenLiveLogik.naechsteMahlzeit(mahlzeitenKcal: [0, 0, 600, 100], stunde: 19))
        XCTAssertNil(EssenLiveLogik.naechsteMahlzeit(mahlzeitenKcal: [0, 0], stunde: 8))
    }

    // MARK: - Anteile

    func testAnteilGrenzen() {
        XCTAssertEqual(EssenLiveLogik.anteil(50, 100), 0.5, accuracy: 0.0001)
        XCTAssertEqual(EssenLiveLogik.anteil(150, 100), 1)
        XCTAssertEqual(EssenLiveLogik.anteil(-5, 100), 0)
        XCTAssertEqual(EssenLiveLogik.anteil(50, 0), 0)
        XCTAssertEqual(EssenLiveLogik.anteil(0, 0), 0)
    }

    func testMahlzeitAnteilGegenIhrenRichtwert() {
        // Mittag 35 % von 2000 = 700 kcal
        XCTAssertEqual(EssenLiveLogik.mahlzeitAnteil(stand(mahlzeiten: [0, 350, 0, 0]), .mittag), 0.5, accuracy: 0.0001)
        XCTAssertEqual(EssenLiveLogik.mahlzeitAnteil(stand(mahlzeiten: [0, 900, 0, 0]), .mittag), 1)
        XCTAssertEqual(EssenLiveLogik.mahlzeitAnteil(stand(ziel: 0), .mittag), 0)
        XCTAssertEqual(EssenLiveLogik.mahlzeitKcal(stand(mahlzeiten: [1, 2]), .abend), 0)
    }

    // MARK: - Texte

    func testTexte() {
        let s = stand(kcal: 1240)
        XCTAssertEqual(EssenLiveLogik.kcalText(s), "1.240 von 2.000 kcal")
        XCTAssertEqual(EssenLiveLogik.restText(s), "760 kcal übrig")
        XCTAssertEqual(EssenLiveLogik.restText(stand(kcal: 2240)), "240 kcal drüber")
        XCTAssertEqual(EssenLiveLogik.restText(stand(kcal: 2000)), "0 kcal übrig")
        XCTAssertEqual(EssenLiveLogik.proteinText(s), "Protein 85 von 120 g")
    }

    func testNaechsteText() {
        XCTAssertEqual(EssenLiveLogik.naechsteText(stand()), "Als Nächstes: Abendessen")
        XCTAssertEqual(EssenLiveLogik.naechsteText(stand(naechste: nil)), "Heute alles eingetragen")
        XCTAssertEqual(EssenLiveLogik.naechsteText(stand(kcal: 0, mahlzeiten: [0, 0, 0, 0], naechste: nil)), "Noch nichts eingetragen")
        XCTAssertEqual(EssenLiveLogik.naechsteText(stand(naechste: "unbekannt")), "Heute alles eingetragen")
    }

    func testSprechtextNenntAlles() {
        let text = EssenLiveLogik.sprechtext(stand(kcal: 1240))
        XCTAssertTrue(text.contains("1.240 von 2.000 kcal"))
        XCTAssertTrue(text.contains("760 kcal übrig"))
        XCTAssertTrue(text.contains("Protein 85 von 120 g"))
        XCTAssertTrue(text.contains("Als Nächstes: Abendessen"))
    }

    // MARK: - Entscheidung

    func testAktionTabelle() {
        let heute = "2026-09-23"
        func a(_ laufend: String?, an: Bool = true, training: Bool = false, beendet: Bool = false) -> EssenLiveLogik.Aktion {
            EssenLiveLogik.aktion(laufendTag: laufend, heute: heute, an: an, trainingLaeuft: training, vomNutzerBeendet: beendet)
        }
        XCTAssertEqual(a(nil), .starten)
        XCTAssertEqual(a(heute), .aktualisieren)
        XCTAssertEqual(a("2026-09-22"), .starten)
        XCTAssertEqual(a(nil, an: false), .nichts)
        XCTAssertEqual(a(heute, an: false), .beenden)
        XCTAssertEqual(a(heute, training: true), .beenden)
        XCTAssertEqual(a(nil, training: true), .nichts)
        XCTAssertEqual(a(nil, beendet: true), .nichts)
        XCTAssertEqual(a("2026-09-22", beendet: true), .starten)
    }

    // MARK: - Schalter

    func testSchalterIstStandardAusUndMerktSich() throws {
        let speicher = try XCTUnwrap(UserDefaults(suiteName: "EssenLiveLogikTests-\(UUID().uuidString)"))
        XCTAssertFalse(EssenLiveEinstellung.an(speicher))
        EssenLiveEinstellung.setze(true, speicher)
        XCTAssertTrue(EssenLiveEinstellung.an(speicher))
        XCTAssertTrue(speicher.bool(forKey: "fit.essen.live"))
        EssenLiveEinstellung.setze(false, speicher)
        XCTAssertFalse(EssenLiveEinstellung.an(speicher))
    }
}
