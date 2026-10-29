// Quelle: Lovea Tests/VerlaufRuhigTests.swift
import XCTest
@testable import LumenFit

/// Gym-Tab aufräumen (25.10.): Wochen-Zusammenfassung mit Besuchen, Gruppenliste, Start-Knopf-Text, Highlights.
final class VerlaufRuhigTests: XCTestCase {
    /// Mittwoch 14.10.2026; die Woche geht vom 12. bis 18.10.
    private let heute = "2026-10-14"

    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
    private let curl = Uebung(id: "curl", name: "Curls", en: "curl", muskel: "Bizeps", koerper: "Oberarme", geraet: "Kurzhantel", neben: [])

    private func zeit(_ tag: String, _ stunde: Double = 18) -> Date { Datum.datum(tag).addingTimeInterval(stunde * 3600) }

    private func lauf(_ u: Uebung, _ tag: String, _ saetze: [(kg: Double, wdh: Int)]) -> VerlaufLogik.Lauf {
        VerlaufLogik.Lauf(session: "s-\(tag)", tag: tag, uebung: u, saetze: saetze.map { PlanSatz(wdh: $0.wdh, kg: $0.kg, failure: false) })
    }

    private func einheit(_ tag: String, dauerMin: Double?) -> GymSession {
        GymSession(id: "s-\(tag)", tag: nil, start: zeit(tag), ende: dauerMin.map { zeit(tag).addingTimeInterval($0 * 60) }, laeufe: [])
    }

    // MARK: - Zusammenfassung

    func testBesucheZaehlenEinheitenUndNurHakenOhneDoppelte() {
        let s = [einheit("2026-10-12", dauerMin: 60), einheit("2026-10-12", dauerMin: 10), einheit("2026-10-05", dauerMin: 50)]
        // 13.10. nur Haken, 12.10. Haken plus Einheit (zählt einmal), 09.10. Haken der Vorwoche.
        let gym = ["2026-10-13": 1, "2026-10-12": 1, "2026-10-09": 1, "2026-10-14": 0]
        let z = VerlaufWoche.zusammenfassung(s, laeufe: [], gym: gym, heute: heute)
        XCTAssertEqual(z.besuche, 2)
    }

    func testMinutenNurAusgechecktUndGedeckelt() {
        let s = [einheit("2026-10-12", dauerMin: 60), einheit("2026-10-13", dauerMin: nil), einheit("2026-10-14", dauerMin: 24 * 60)]
        let z = VerlaufWoche.zusammenfassung(s, laeufe: [], gym: [:], heute: heute)
        XCTAssertEqual(z.minuten, 60 + Int(TrainingLogik.langNach / 60))
        XCTAssertEqual(z.besuche, 3)
    }

    func testSaetzeSindDieGezaehltenSaetzeDerWoche() {
        let laeufe = [
            lauf(bank, "2026-10-12", [(60, 8), (60, 8), (60, 8)]),
            lauf(curl, "2026-10-13", [(14, 10), (14, 10)]),
            lauf(bank, "2026-10-05", [(60, 8)]),
        ]
        let z = VerlaufWoche.zusammenfassung([], laeufe: laeufe, gym: [:], heute: heute)
        XCTAssertEqual(z.saetze, 5)
    }

    func testLeereWocheIstNull() {
        XCTAssertEqual(VerlaufWoche.zusammenfassung([], laeufe: [], gym: [:], heute: heute), VerlaufWoche.Zusammenfassung())
    }

    // MARK: - Gruppenliste

    func testGruppenOhneSaetzeKlappenZusammen() {
        let l = VerlaufWoche.liste(saetze: [.brust: 6, .bizeps: 3], ziele: [.brust: 12], erholung: [.brust: .fast])
        XCTAssertEqual(l.aktiv.map(\.gruppe), [.brust, .bizeps])
        XCTAssertEqual(l.weitere.count, MuskelGruppe.allCases.count - 2)
        XCTAssertEqual(l.aktiv.first?.erholung, .fast)
        XCTAssertNil(l.aktiv.last?.erholung, "ohne erfasstes Training kein Punkt")
    }

    func testAnteilZielFehltNullOderUeberschritten() {
        let l = VerlaufWoche.liste(saetze: [.brust: 20, .bizeps: 3, .nacken: 2], ziele: [.brust: 12, .bizeps: 0], erholung: [:])
        XCTAssertEqual(l.aktiv.first { $0.gruppe == .brust }?.anteil, 1)
        XCTAssertNil(l.aktiv.first { $0.gruppe == .bizeps }?.ziel, "Ziel 0 gilt als kein Ziel")
        XCTAssertNil(l.aktiv.first { $0.gruppe == .nacken }?.anteil)
    }

    func testReihenfolgeFolgtDerVorgabe() {
        let l = VerlaufWoche.liste(saetze: [.brust: 1, .schulter: 1], ziele: [:], erholung: [:], reihenfolge: [.brust] + MuskelGruppe.allCases.filter { $0 != .brust })
        XCTAssertEqual(l.aktiv.map(\.gruppe), [.brust, .schulter])
    }

    // MARK: - Texte

    func testStartText() {
        XCTAssertEqual(VerlaufWoche.startText(.starten, tagName: "Push"), "Heute: Push starten")
        XCTAssertEqual(VerlaufWoche.startText(.starten, tagName: ""), "Heute: Training starten")
        XCTAssertEqual(VerlaufWoche.startText(.starten, tagName: nil), "Heute: Freies Training starten")
        XCTAssertEqual(VerlaufWoche.startText(.weiter, tagName: "Pull"), "Heute: Pull weiter")
        XCTAssertEqual(VerlaufWoche.startText(.fortsetzen, tagName: "Pull"), "Heute: Pull fortsetzen")
    }

    func testOhneSaetzeText() {
        XCTAssertEqual(VerlaufWoche.ohneSaetzeText(1), "1 Besuch ohne Sätze")
        XCTAssertEqual(VerlaufWoche.ohneSaetzeText(2), "2 Besuche ohne Sätze")
    }

    // MARK: - Highlights

    func testRekordNurMitVorgaenger() {
        let neu = [lauf(bank, "2026-10-13", [(80, 8)])]
        XCTAssertTrue(VerlaufHighlights.berechnen(neu, heute: heute).isEmpty, "erster Wert ist kein Rekord")
        let mit = neu + [lauf(bank, "2026-10-01", [(60, 8)])]
        let h = VerlaufHighlights.berechnen(mit, heute: heute)
        XCTAssertEqual(h.map(\.art), [.rekord])
        XCTAssertEqual(h.first?.uebung.id, "bank")
    }

    func testKeinRekordWennDieseWocheNichtUeberbietet() {
        let l = [lauf(bank, "2026-10-13", [(60, 8)]), lauf(bank, "2026-10-01", [(80, 8)])]
        XCTAssertTrue(VerlaufHighlights.berechnen(l, heute: heute).isEmpty)
    }

    func testPlateauNachVierEinheitenOhneNeuenBestwert() {
        let l = [lauf(bank, "2026-09-20", [(80, 8)]), lauf(bank, "2026-09-27", [(75, 8)]),
                 lauf(bank, "2026-10-04", [(75, 8)]), lauf(bank, "2026-10-08", [(75, 8)])]
        let h = VerlaufHighlights.berechnen(l, heute: heute)
        XCTAssertEqual(h.map(\.art), [.plateau])
    }

    func testPlateauBrauchtAktuelleUebung() {
        let l = [lauf(bank, "2026-06-01", [(80, 8)]), lauf(bank, "2026-06-08", [(75, 8)]),
                 lauf(bank, "2026-06-15", [(75, 8)]), lauf(bank, "2026-06-22", [(75, 8)])]
        XCTAssertTrue(VerlaufHighlights.berechnen(l, heute: heute).isEmpty)
    }

    func testKappenZeigtDreiRestHinterMehr() {
        let e = (0..<5).map { VerlaufHighlights.Eintrag(art: .rekord, uebung: Uebung(id: "u\($0)", name: "U\($0)", en: "", muskel: "", koerper: "", geraet: "", neben: []), e1rm: 50) }
        let k = VerlaufHighlights.kappen(e)
        XCTAssertEqual(k.offen.count, 3)
        XCTAssertEqual(k.mehr.count, 2)
        XCTAssertTrue(VerlaufHighlights.kappen([]).offen.isEmpty)
    }
}
