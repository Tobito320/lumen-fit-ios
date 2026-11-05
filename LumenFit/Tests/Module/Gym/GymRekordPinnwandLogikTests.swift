import XCTest
@testable import LumenFit

/// Rekord-Pinnwand: bester Arbeitssatz der letzten 14 Tage gegen alle früheren Einheiten derselben Person, lokal berechnet.
final class GymRekordPinnwandLogikTests: XCTestCase {
    private typealias T = CrewTestDaten

    private func tag(_ vor: Int) -> String { Datum.addTage(T.heute, -vor) }

    private func datei(_ einheiten: [PartnerEinheit], freigaben: [FreigabeArt] = [.gym, .verlauf]) -> ZusammenfassungDatei {
        var v = PartnerVerlauf(trainings: [])
        v.einheiten = einheiten
        return T.datei(freigaben: freigaben, verlauf: v)
    }

    private func rekorde(_ d: ZusammenfassungDatei, name: String? = nil) -> [PinnwandRekord] {
        GymRekordPinnwandLogik.rekorde(d, name: name, jetzt: T.jetzt)
    }

    func testRekordErkanntMitUebungUndWert() {
        let d = datei([T.einheit(tag(2), [("Kniebeuge", [T.satz(5, 1200)])]), T.einheit(tag(20), [("Kniebeuge", [T.satz(5, 1100)])])])
        XCTAssertEqual(rekorde(d), [PinnwandRekord(name: "Freund A", uebung: "Kniebeuge", kg: 120, wdh: 5, tag: tag(2))])
    }

    func testErsteEinheitEinerUebungIstKeinRekord() {
        XCTAssertEqual(rekorde(datei([T.einheit(tag(1), [("Kniebeuge", [T.satz(5, 1200)])])])), [])
    }

    func testGleicherOderNiedrigererWertIstKeinRekord() {
        let d = datei([T.einheit(tag(2), [("Kniebeuge", [T.satz(5, 1000)])]), T.einheit(tag(20), [("Kniebeuge", [T.satz(5, 1000)])])])
        XCTAssertEqual(rekorde(d), [])
    }

    func testAufwaermUndDropsatzZaehlenNicht() {
        let d = datei([T.einheit(tag(2), [("Kniebeuge", [T.satz(5, 2000, "w"), T.satz(5, 2000, "d"), T.satz(5, 900)])]), T.einheit(tag(20), [("Kniebeuge", [T.satz(5, 1000)])])])
        XCTAssertEqual(rekorde(d), [], "nur Aufwärm- und Dropsätze sind höher")
        let mit = datei([T.einheit(tag(2), [("Kniebeuge", [T.satz(5, 2000, "w"), T.satz(5, 1100)])]), T.einheit(tag(20), [("Kniebeuge", [T.satz(5, 1000)])])])
        XCTAssertEqual(rekorde(mit).first?.kg, 110)
    }

    func testNamenMitKlammerUndGrossschreibungGehoerenZusammen() {
        let d = datei([T.einheit(tag(1), [("Bankdrücken (Langhantel)", [T.satz(5, 1000)])]), T.einheit(tag(30), [("bankdrücken", [T.satz(5, 900)])])])
        XCTAssertEqual(rekorde(d).map(\.uebung), ["Bankdrücken"], "Anzeige ohne Klammerzusatz")
    }

    func testZehntelKgUndEinsRepMax() {
        let d = datei([T.einheit(tag(1), [("Curl", [T.satz(10, 125)])]), T.einheit(tag(30), [("Curl", [T.satz(10, 120)])])])
        XCTAssertEqual(rekorde(d).first?.kg, 12.5)
        // 1RM statt Gewicht: 100 kg x 1 (100) schlägt 80 kg x 8 (101,3) nicht, 90 x 5 (105) schon.
        let e1 = datei([T.einheit(tag(1), [("Kreuzheben", [T.satz(1, 1000)])]), T.einheit(tag(30), [("Kreuzheben", [T.satz(8, 800)])])])
        XCTAssertEqual(rekorde(e1), [])
        let e2 = datei([T.einheit(tag(1), [("Kreuzheben", [T.satz(5, 900)])]), T.einheit(tag(30), [("Kreuzheben", [T.satz(8, 800)])])])
        XCTAssertEqual(rekorde(e2).first?.wdh, 5)
    }

    func testAelterAlsVierzehnTageIstKeinNeuerRekord() {
        let d = datei([T.einheit(tag(15), [("Kniebeuge", [T.satz(5, 1200)])]), T.einheit(tag(40), [("Kniebeuge", [T.satz(5, 1000)])])])
        XCTAssertEqual(rekorde(d), [])
        let grenze = datei([T.einheit(tag(14), [("Kniebeuge", [T.satz(5, 1200)])]), T.einheit(tag(40), [("Kniebeuge", [T.satz(5, 1000)])])])
        XCTAssertEqual(rekorde(grenze).count, 1)
    }

    func testBesterSatzDerLetztenTageGegenFruehereAuchInnerhalbDerTage() {
        let d = datei([T.einheit(tag(1), [("Kniebeuge", [T.satz(5, 1050)])]), T.einheit(tag(5), [("Kniebeuge", [T.satz(5, 1000)])]), T.einheit(tag(30), [("Kniebeuge", [T.satz(5, 900)])])])
        XCTAssertEqual(rekorde(d).map(\.tag), [tag(1)])
        let frueherTop = datei([T.einheit(tag(1), [("Kniebeuge", [T.satz(5, 1000)])]), T.einheit(tag(5), [("Kniebeuge", [T.satz(5, 1050)])]), T.einheit(tag(30), [("Kniebeuge", [T.satz(5, 900)])])])
        XCTAssertEqual(rekorde(frueherTop).map(\.tag), [tag(5)], "der beste Satz war vor vier Tagen, der von gestern ist kein Rekord")
    }

    func testOhneFreigabeOderEinheitenNichts() {
        let e = [T.einheit(tag(2), [("Kniebeuge", [T.satz(5, 1200)])]), T.einheit(tag(20), [("Kniebeuge", [T.satz(5, 1100)])])]
        XCTAssertEqual(rekorde(datei(e, freigaben: [.verlauf])), [])
        XCTAssertEqual(rekorde(datei(e, freigaben: [.gym])), [])
        XCTAssertEqual(rekorde(T.datei(verlauf: PartnerVerlauf(trainings: []))), [])
        XCTAssertEqual(rekorde(datei([])), [])
    }

    func testPinnwandHoechstensFuenfNeuesteZuerstMitAnzeigeName() {
        func person(_ id: String, name: String, vor: Int) -> VerbindungEintrag {
            T.eintrag(id, name: name, daten: datei([T.einheit(tag(vor), [("Kniebeuge", [T.satz(5, 1200)])]), T.einheit(tag(30), [("Kniebeuge", [T.satz(5, 1000)])])]))
        }
        let liste = (0..<7).map { person("p\($0)", name: "Freund \($0)", vor: $0 + 1) }
        let pinnwand = GymRekordPinnwandLogik.pinnwand(eintraege: liste, jetzt: T.jetzt)
        XCTAssertEqual(pinnwand.map(\.name), ["Freund 0", "Freund 1", "Freund 2", "Freund 3", "Freund 4"])
        XCTAssertEqual(GymRekordPinnwandLogik.pinnwand(eintraege: [], jetzt: T.jetzt), [])
        var pausiert = person("x", name: "Freund P", vor: 1)
        pausiert.ich.pause = true
        XCTAssertEqual(GymRekordPinnwandLogik.pinnwand(eintraege: [pausiert], jetzt: T.jetzt), [], "pausiert: nichts")
    }

    func testText() {
        let r = PinnwandRekord(name: "Freund A", uebung: "Kniebeuge", kg: 120, wdh: 5, tag: tag(2))
        XCTAssertEqual(GymRekordPinnwandLogik.text(r, heute: T.heute), "Kniebeuge 120 kg × 5 · vor 2 Tagen")
        XCTAssertEqual(GymRekordPinnwandLogik.text(PinnwandRekord(name: "A", uebung: "Curl", kg: 12.5, wdh: 10, tag: tag(1)), heute: T.heute), "Curl 12,5 kg × 10 · gestern")
        XCTAssertEqual(GymRekordPinnwandLogik.text(PinnwandRekord(name: "A", uebung: "Curl", kg: 12.5, wdh: 10, tag: T.heute), heute: T.heute), "Curl 12,5 kg × 10 · heute")
    }
}
