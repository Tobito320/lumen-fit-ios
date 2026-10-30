import XCTest
@testable import LumenFit

final class HabitRasterTests: XCTestCase {
    /// Freitag, 30.10.2026.
    private let heute = "2026-10-30"

    private func zaehler(ziel: Int = 4) -> Habit {
        Habit(id: "z", name: "Zähler", symbol: "star.fill", farbe: HabitFarbe.mint.rawValue, zaehlen: true, tagesziel: ziel, haeufigkeit: .taeglich, fuer: "ich")
    }

    private func haken(_ h: Haeufigkeit = .taeglich) -> Habit {
        Habit(id: "h", name: "Haken", symbol: "star.fill", farbe: HabitFarbe.amber.rawValue, zaehlen: false, tagesziel: nil, haeufigkeit: h, fuer: "ich")
    }

    func testWochenAnteileFuellenNachZielUndZukunftIstNull() {
        let w = HabitRaster.wochenAnteile(zaehler(), werte: ["2026-10-26": 2, "2026-10-27": 4, "2026-10-30": 1, "2026-10-31": 9], ziel: nil, heute: heute)
        XCTAssertEqual(w, [0.5, 1, 0, 0, 0.25, 0, 0])
    }

    func testWochenErledigtZaehltNurBisHeute() {
        let n = HabitRaster.wochenErledigt(haken(), werte: ["2026-10-26": 1, "2026-10-30": 1, "2026-10-31": 1], ziel: nil, heute: heute)
        XCTAssertEqual(n, 2)
    }

    func testZellenSindImmerSechsWochen() {
        for zurueck in 0..<12 { XCTAssertEqual(HabitRaster.zellen(heute: heute, monateZurueck: zurueck).count, 42) }
        let okt = HabitRaster.zellen(heute: heute, monateZurueck: 0)
        XCTAssertEqual(okt.firstIndex { $0 != nil }, 3)
        XCTAssertEqual(okt.compactMap { $0 }.first, "2026-10-01")
        XCTAssertEqual(okt.compactMap { $0 }.last, "2026-10-31")
        let sep = HabitRaster.zellen(heute: heute, monateZurueck: 1)
        XCTAssertEqual(sep.firstIndex { $0 != nil }, 1)
        XCTAssertEqual(sep.compactMap { $0 }.count, 30)
    }

    func testMonatsErsterUndTitel() {
        XCTAssertEqual(HabitRaster.monatsErster(heute: heute, monateZurueck: 0), "2026-10-01")
        XCTAssertEqual(HabitRaster.monatsErster(heute: heute, monateZurueck: 11), "2025-11-01")
        XCTAssertEqual(HabitRaster.monatsErster(heute: heute, monateZurueck: -3), "2026-10-01")
        XCTAssertEqual(HabitRaster.monatsTitel(heute: heute, monateZurueck: 0), "Oktober 2026")
        XCTAssertTrue(HabitRaster.monatsKurz(heute: heute, monateZurueck: 0).hasPrefix("Okt"))
    }

    func testJahrHatZwoelfMonateAeltesterZuerst() {
        XCTAssertEqual(HabitRaster.jahrMonate.count, 12)
        XCTAssertEqual(HabitRaster.jahrMonate.first, 11)
        XCTAssertEqual(HabitRaster.jahrMonate.last, 0)
    }

    func testMonatErledigtZaehltNurVergangeneTage() {
        let werte = ["2026-10-02": 1, "2026-10-15": 1, "2026-10-30": 1, "2026-10-31": 1, "2026-09-30": 1]
        XCTAssertEqual(HabitRaster.monatErledigt(haken(), werte: werte, ziel: nil, heute: heute, monateZurueck: 0), 3)
        XCTAssertEqual(HabitRaster.monatErledigt(haken(), werte: werte, ziel: nil, heute: heute, monateZurueck: 1), 1)
    }

    func testTagesnummerUndTexte() {
        XCTAssertEqual(HabitRaster.tagesnummer("2026-10-07"), "7")
        XCTAssertEqual(HabitRaster.tagesnummer("kaputt"), "")
        XCTAssertEqual(HabitRaster.serieText(haken(), 1), "1 Tag")
        XCTAssertEqual(HabitRaster.serieText(haken(), 5), "5 Tage")
        XCTAssertEqual(HabitRaster.serieText(haken(.proWoche(3)), 1), "1 Woche")
        XCTAssertEqual(HabitRaster.serieText(haken(.proWoche(3)), 2), "2 Wochen")
        XCTAssertTrue(HabitRaster.prozent(0.4).contains("40"))
    }

    func testFormularBrauchtNamenUndBeiFestenTagenMindestensEinen() {
        XCTAssertFalse(HabitRaster.formularGueltig(name: "  ", festeTageArt: false, tage: []))
        XCTAssertTrue(HabitRaster.formularGueltig(name: "Lesen", festeTageArt: false, tage: []))
        XCTAssertFalse(HabitRaster.formularGueltig(name: "Lesen", festeTageArt: true, tage: []))
        XCTAssertFalse(HabitRaster.formularGueltig(name: "Lesen", festeTageArt: true, tage: [0, 8]))
        XCTAssertTrue(HabitRaster.formularGueltig(name: "Lesen", festeTageArt: true, tage: [3]))
        XCTAssertEqual(HabitRaster.festeTage([5, 1, 9, 3]), [1, 3, 5])
    }

    func testFarbeMitUnbekanntemNamenIstGrau() {
        XCTAssertEqual(HabitFarbe.von("mint"), .mint)
        XCTAssertEqual(HabitFarbe.von("neonlila"), .grau)
        XCTAssertEqual(Set(HabitFarbe.allCases.map(\.anzeigename)).count, 8)
    }
}
