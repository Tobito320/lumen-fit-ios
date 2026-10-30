import XCTest
@testable import LumenFit

/// Periode 1. bis 5. September 2026, Zyklus 28 Tage: Eisprung 15.9., fruchtbar 10. bis 16.9., nächste Periode 29.9.
private func periodenTage() -> [String: ZyklusTag] {
    Dictionary(uniqueKeysWithValues: (1...5).map { n in
        let id = String(format: "2026-09-%02d", n)
        return (id, ZyklusTag(id: id, blutung: .mittel))
    })
}

final class ZyklusModiLogikTests: XCTestCase {
    func testWocheUndTag() {
        let s = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-09-01")
        XCTAssertEqual(s.woche, 0)
        XCTAssertEqual(s.tag, 0)
        let t = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-13")
        XCTAssertEqual(t.woche, 6)
        XCTAssertEqual(t.tag, 0)
        let u = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-16")
        XCTAssertEqual(u.woche, 6)
        XCTAssertEqual(u.tag, 3)
    }

    func testTerminIstStartPlus280() {
        let s = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-09-01")
        XCTAssertEqual(s.termin, Datum.addTage("2026-09-01", 280))
        XCTAssertEqual(s.tageBisTermin, 280)
    }

    func testEigenerTerminHatVorrang() {
        let termin = "2027-06-01"
        let s = ZyklusModiLogik.schwangerStand(start: "2026-01-01", termin: termin, heute: Datum.addTage(termin, -280 + 14))
        XCTAssertEqual(s.termin, termin)
        XCTAssertEqual(s.woche, 2)
    }

    func testTerminVorbeiIstNegativ() {
        let s = ZyklusModiLogik.schwangerStand(start: "2026-01-01", heute: Datum.addTage("2026-01-01", 285))
        XCTAssertEqual(s.tageBisTermin, -5)
    }

    func testTrimester() {
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 0), 1)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 13), 1)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 14), 2)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 27), 2)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 28), 3)
        XCTAssertEqual(ZyklusModiLogik.trimester(woche: 41), 3)
    }

    func testGroessenVergleich() {
        XCTAssertNil(ZyklusModiLogik.groessenVergleich(woche: 3))
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 4), "ein Mohnkorn")
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 14), "eine Zitrone")
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 21), "eine Banane")
        XCTAssertEqual(ZyklusModiLogik.groessenVergleich(woche: 44), "eine kleine Wassermelone")
    }

    func testWochenText() {
        let a = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-13")
        XCTAssertEqual(ZyklusModiLogik.wochenText(a), "6. Woche")
        let b = ZyklusModiLogik.schwangerStand(start: "2026-09-01", heute: "2026-10-16")
        XCTAssertEqual(ZyklusModiLogik.wochenText(b), "6. Woche, Tag 3")
    }

    func testPille21Sieben() {
        let start = "2026-09-01"
        let tag1 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: start)!
        XCTAssertEqual(tag1.tagInPackung, 1)
        XCTAssertTrue(tag1.nehmen)
        XCTAssertEqual(tag1.tageBisPause, 21)
        let tag21 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 20))!
        XCTAssertEqual(tag21.tagInPackung, 21)
        XCTAssertTrue(tag21.nehmen)
        XCTAssertEqual(tag21.tageBisPause, 1)
        let tag22 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 21))!
        XCTAssertTrue(tag22.pause)
        XCTAssertFalse(tag22.nehmen)
        XCTAssertEqual(tag22.tageBisPause, 0)
        let tag28 = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 27))!
        XCTAssertEqual(tag28.tageBisNeuePackung, 1)
        let neu = ZyklusModiLogik.pillenStand(start: start, packung: .einundzwanzig, heute: Datum.addTage(start, 28))!
        XCTAssertEqual(neu.tagInPackung, 1)
        XCTAssertFalse(neu.pause)
    }

    func testPille28NimmtAuchPlatzhalter() {
        let start = "2026-09-01"
        let platzhalter = ZyklusModiLogik.pillenStand(start: start, packung: .achtundzwanzig, heute: Datum.addTage(start, 24))!
        XCTAssertTrue(platzhalter.pause)
        XCTAssertTrue(platzhalter.nehmen)
        XCTAssertFalse(platzhalter.wirkstoff)
        let wirkstoff = ZyklusModiLogik.pillenStand(start: start, packung: .achtundzwanzig, heute: Datum.addTage(start, 5))!
        XCTAssertTrue(wirkstoff.wirkstoff)
    }

    func testPilleVorStartIstNil() {
        XCTAssertNil(ZyklusModiLogik.pillenStand(start: "2026-09-10", packung: .einundzwanzig, heute: "2026-09-09"))
    }

    func testPillenStartReihenfolge() {
        let logik = ZyklusLogik(tage: Array(periodenTage().values), heute: "2026-09-10")
        XCTAssertEqual(ZyklusModiLogik.pillenStart(gesetzt: "2026-08-20", logik: logik, tage: []), "2026-08-20")
        XCTAssertEqual(ZyklusModiLogik.pillenStart(gesetzt: nil, logik: logik, tage: []), "2026-09-01")
        let ohne = ZyklusLogik(tage: [], heute: "2026-09-10")
        let tage = [ZyklusTag(id: "2026-09-04", pille: true), ZyklusTag(id: "2026-09-03", pille: true)]
        XCTAssertEqual(ZyklusModiLogik.pillenStart(gesetzt: nil, logik: ohne, tage: tage), "2026-09-03")
        XCTAssertNil(ZyklusModiLogik.pillenStart(gesetzt: nil, logik: ohne, tage: []))
    }

    func testPillenSerie() {
        let tage = Dictionary(uniqueKeysWithValues: ["2026-09-06", "2026-09-07", "2026-09-08"].map { ($0, ZyklusTag(id: $0, pille: true)) })
        XCTAssertEqual(ZyklusModiLogik.pillenSerie(tage: tage, heute: "2026-09-08"), 3)
        XCTAssertEqual(ZyklusModiLogik.pillenSerie(tage: tage, heute: "2026-09-09"), 3)
        XCTAssertEqual(ZyklusModiLogik.pillenSerie(tage: tage, heute: "2026-09-10"), 0)
        XCTAssertTrue(ZyklusModiLogik.pilleGenommen(tage: tage, heute: "2026-09-07"))
        XCTAssertFalse(ZyklusModiLogik.pilleGenommen(tage: tage, heute: "2026-09-09"))
    }

    func testKinderwunschLagen() {
        let tage = periodenTage()
        func lage(_ heute: String) -> ZyklusModiLogik.KinderwunschStand {
            let logik = ZyklusLogik(tage: Array(tage.values), heute: heute)
            return ZyklusModiLogik.kinderwunschStand(logik: logik, tage: Array(tage.values), heute: heute)
        }
        XCTAssertEqual(lage("2026-09-07").lage, .bald(tage: 3))
        XCTAssertEqual(lage("2026-09-10").lage, .fruchtbar)
        XCTAssertEqual(lage("2026-09-15").lage, .eisprung)
        XCTAssertEqual(lage("2026-09-20").lage, .vorbei)
        let leer = ZyklusLogik(tage: [], heute: "2026-09-07")
        XCTAssertEqual(ZyklusModiLogik.kinderwunschStand(logik: leer, tage: [], heute: "2026-09-07").lage, .unbekannt)
    }

    func testKinderwunschZaehltTestsImZyklus() {
        var tage = periodenTage()
        tage["2026-09-12"] = ZyklusTag(id: "2026-09-12", eisprungTest: .negativ)
        tage["2026-09-14"] = ZyklusTag(id: "2026-09-14", eisprungTest: .positiv)
        tage["2026-08-10"] = ZyklusTag(id: "2026-08-10", eisprungTest: .positiv)
        let logik = ZyklusLogik(tage: Array(tage.values), heute: "2026-09-14")
        let s = ZyklusModiLogik.kinderwunschStand(logik: logik, tage: Array(tage.values), heute: "2026-09-14")
        XCTAssertEqual(s.positiveTests, 1)
        XCTAssertEqual(s.negativeTests, 1)
    }
}

