import XCTest
@testable import LumenFit

final class EinheitZeitenLogikTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testPruefungErkenntOkLangUndUngueltig() {
        let jetzt = start.addingTimeInterval(10 * 3600)
        XCTAssertEqual(EinheitZeitenLogik.pruefe(start: start, ende: start.addingTimeInterval(3600), jetzt: jetzt), .ok)
        XCTAssertEqual(EinheitZeitenLogik.pruefe(start: start, ende: start.addingTimeInterval(4 * 3600), jetzt: jetzt), .zuLang(stunden: 4))
        XCTAssertEqual(EinheitZeitenLogik.pruefe(start: start, ende: start.addingTimeInterval(-60), jetzt: jetzt), .ungueltig)
        XCTAssertEqual(EinheitZeitenLogik.pruefe(start: start, ende: jetzt.addingTimeInterval(3600), jetzt: jetzt), .ungueltig)
    }

    func testGenau3StundenFragenNochNicht() {
        let jetzt = start.addingTimeInterval(10 * 3600)
        XCTAssertEqual(EinheitZeitenLogik.pruefe(start: start, ende: start.addingTimeInterval(TrainingLogik.langNach), jetzt: jetzt), .ok)
    }

    func testEndeVorschlagIstAnderthalbStundenNachStartUndNieInDerZukunft() {
        XCTAssertEqual(EinheitZeitenLogik.endeVorschlag(start: start, jetzt: start.addingTimeInterval(10 * 3600)), start.addingTimeInterval(5400))
        XCTAssertEqual(EinheitZeitenLogik.endeVorschlag(start: start, jetzt: start.addingTimeInterval(600)), start.addingTimeInterval(600))
    }

    func testStartBereichGehtHoechstensDreiStundenZurueck() {
        let jetzt = start.addingTimeInterval(3600)
        let bereich = EinheitZeitenLogik.startBereich(aktuell: start, jetzt: jetzt)
        XCTAssertEqual(bereich.upperBound, jetzt)
        XCTAssertLessThanOrEqual(bereich.lowerBound, start)
        XCTAssertEqual(bereich.lowerBound, min(start, TrainingLogik.fruehesterStart(jetzt: jetzt)))
    }

    func testLangeFrageNenntDieStunden() {
        XCTAssertEqual(EinheitZeitenLogik.langeFrage(stunden: 4.5), "Das sind 4,5 Stunden. Warst du wirklich so lange im Gym?")
    }

    func testMonatTitelUndUntertitel() {
        let gitter = HealthLogik.monatsGitter(heute: "2026-09-15", monateZurueck: 0)
        XCTAssertEqual(EinheitZeitenLogik.monatTitel(gitter), "September 2026")
        XCTAssertEqual(EinheitZeitenLogik.monatTitel([nil, nil]), "")
        let s = GymSession(id: "a", tag: nil, start: start, ende: nil, laeufe: [])
        XCTAssertEqual(EinheitZeitenLogik.untertitel(s, tag: nil), "Freies Training")
        let tag = TrainingsTag(id: "t", name: "Push", wochentage: [1], uebungen: [])
        XCTAssertEqual(EinheitZeitenLogik.untertitel(s, tag: tag), "Push · 0 von 0 Übungen")
    }
}

final class EinheitMonatsRasterTests: XCTestCase {
    func testMonateAnzahlRechnetVomAeltestenTagUndKlemmt() {
        XCTAssertEqual(EinheitZeitenLogik.monateAnzahl(aeltesterTag: nil, heute: "2026-10-30"), 3)
        XCTAssertEqual(EinheitZeitenLogik.monateAnzahl(aeltesterTag: "2026-10-01", heute: "2026-10-30"), 3)
        XCTAssertEqual(EinheitZeitenLogik.monateAnzahl(aeltesterTag: "2026-01-05", heute: "2026-10-30"), 10)
        XCTAssertEqual(EinheitZeitenLogik.monateAnzahl(aeltesterTag: "2015-01-05", heute: "2026-10-30"), 60)
    }

    func testGitter42HatImmerSechsZeilen() {
        for zurueck in 0..<4 {
            let g = EinheitZeitenLogik.gitter42(heute: "2026-10-30", monateZurueck: zurueck)
            XCTAssertEqual(g.count, 42)
        }
        XCTAssertEqual(EinheitZeitenLogik.gitter42(heute: "2026-10-30", monateZurueck: 0).compactMap { $0 }.count, 31)
    }

    func testTagSprechtext() {
        XCTAssertTrue(EinheitZeitenLogik.tagSprechtext("2026-10-12", training: true, nurHaken: false).hasSuffix("Training"))
        XCTAssertTrue(EinheitZeitenLogik.tagSprechtext("2026-10-12", training: false, nurHaken: true).contains("keine Einheit gespeichert"))
        XCTAssertEqual(EinheitZeitenLogik.tagSprechtext("2026-10-12", training: false, nurHaken: false), Datum.anzeige("2026-10-12"))
    }
}
