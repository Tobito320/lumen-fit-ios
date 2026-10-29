// Quelle: Lovea Tests/TrackerVerlaufTests.swift
import XCTest
@testable import LumenFit

/// Verlauf-Karten der Tracker-Seite: nur die Rechnung dahinter (Schritte je Stunde, Pulswerte des Tages, Akku-Verlauf, Schlafphasen
/// fürs Diagramm). Reine Logik, ohne Gerät.
final class TrackerVerlaufTests: XCTestCase {
    private func zeile(_ schritte: Int) -> BandTag.Zeile { BandTag.Zeile(schritte: schritte, meter: schritte / 2) }

    // MARK: Schritte je Stunde

    func testViertelstundenWerdenZuStundenZusammengezaehlt() {
        var tag = BandTag()
        tag.zeilen = [0: zeile(10), 3: zeile(5), 4: zeile(7), 68: zeile(100), 71: zeile(1), 95: zeile(9)]
        let stunden = TrackerVerlauf.schritteJeStunde(tag)
        XCTAssertEqual(stunden.count, 24)
        XCTAssertEqual(stunden[0].schritte, 15, "Slot 0 bis 3 sind die Stunde 0")
        XCTAssertEqual(stunden[1].schritte, 7, "Slot 4 ist 01:00 Uhr")
        XCTAssertEqual(stunden[17].schritte, 101, "Slot 0x44 = 68 ist 17:00 Uhr (belegt am Gerät)")
        XCTAssertEqual(stunden[23].schritte, 9)
        XCTAssertEqual(stunden.map(\.schritte).reduce(0, +), tag.schritte, "keine Schritte gehen verloren")
    }

    func testSlotAusserhalbDesTagesZaehltNicht() {
        var tag = BandTag()
        tag.zeilen = [96: zeile(50), -1: zeile(50), 8: zeile(3)]
        XCTAssertEqual(TrackerVerlauf.schritteJeStunde(tag).map(\.schritte).reduce(0, +), 3)
    }

    // MARK: Puls

    func testPulsStatistik() {
        let punkte = [BandReihen.Punkt(minute: 600, wert: 70), BandReihen.Punkt(minute: 300, wert: 55),
                      BandReihen.Punkt(minute: 900, wert: 120)]
        XCTAssertEqual(TrackerVerlauf.pulsStatistik(punkte), TrackerVerlauf.PulsStatistik(niedrig: 55, hoch: 120, letzter: 120, anzahl: 3))
        XCTAssertNil(TrackerVerlauf.pulsStatistik([]))
    }

    func testPulsVerlaufGibtMinutenDesTagesOhneZukunftUndOhneUnsinn() {
        var verlauf = PulsVerlauf(tag: 0)
        // Abstand 5 Minuten; Werte: 60 (00:00), 0 (nicht gemessen), 250 (kein Puls), 72 (00:15), 80 (00:20, liegt in der Zukunft).
        _ = verlauf.aufnehmen(.pulsKopf(pakete: 2, abstand: 5))
        _ = verlauf.aufnehmen(.pulsStart(zeit: 0, werte: [60, 0, 250, 72, 80, 0, 0, 0, 0]))
        let anfang = Date(timeIntervalSince1970: 1_000_000)
        let jetzt = anfang.addingTimeInterval(16 * 60)
        let punkte = verlauf.punkte(tagesanfang: anfang, bis: jetzt)
        XCTAssertEqual(punkte, [BandReihen.Punkt(minute: 0, wert: 60), BandReihen.Punkt(minute: 15, wert: 72)])
    }

    // MARK: Wann Stress und HRV gelesen werden

    func testStressUndHrvWerdenHoechstensAlleDreissigMinutenGelesen() {
        let jetzt = Date(timeIntervalSince1970: 1_791_800_000)
        XCTAssertTrue(TrackerVerlauf.verlaufFaellig(letzte: nil, jetzt: jetzt), "nie gelesen: fällig")
        XCTAssertFalse(TrackerVerlauf.verlaufFaellig(letzte: jetzt.addingTimeInterval(-10 * 60), jetzt: jetzt), "der Tracker misst nur alle 30 Minuten")
        XCTAssertTrue(TrackerVerlauf.verlaufFaellig(letzte: jetzt.addingTimeInterval(-30 * 60), jetzt: jetzt))
        XCTAssertTrue(TrackerVerlauf.verlaufFaellig(letzte: jetzt.addingTimeInterval(3600), jetzt: jetzt), "Uhr zurückgesprungen: fällig")
    }

    // MARK: Halbstunden-Reihen (Stress und HRV)

    private func werte(_ von: Int, _ anzahl: Int) -> [UInt8] { (0..<anzahl).map { UInt8(von + $0) } }

    func testHalbstundenReiheSetztDiePaketeAnDieRichtigenSlots() {
        var reihe = Halbstundenreihe()
        XCTAssertFalse(reihe.aufnehmen(.werte(nr: 1, werte: werte(1, 12))))
        XCTAssertFalse(reihe.aufnehmen(.werte(nr: 2, werte: werte(13, 13))))
        XCTAssertFalse(reihe.aufnehmen(.werte(nr: 3, werte: werte(26, 13))))
        XCTAssertTrue(reihe.aufnehmen(.werte(nr: 4, werte: werte(39, 13))), "Paket 4 ist das letzte")
        XCTAssertEqual(reihe.werte[0], 1)
        XCTAssertEqual(reihe.werte[11], 12)
        XCTAssertEqual(reihe.werte[12], 13)
        XCTAssertEqual(reihe.werte[25], 26)
        XCTAssertEqual(reihe.werte[38], 39)
        XCTAssertEqual(reihe.werte[47], 48, "Slot 47 ist 23:30 Uhr; was dahinter liegt, fällt weg")
        XCTAssertEqual(reihe.werte.count, 48)
    }

    func testHalbstundenReiheEndetBeiKeineDaten() {
        var reihe = Halbstundenreihe()
        XCTAssertTrue(reihe.aufnehmen(.ende))
        XCTAssertTrue(reihe.werte.allSatisfy { $0 == 0 })
    }

    func testHalbstundenReiheUeberlebtFehlendeUndDoppeltePakete() {
        var reihe = Halbstundenreihe()
        _ = reihe.aufnehmen(.werte(nr: 3, werte: werte(100, 13)))
        _ = reihe.aufnehmen(.werte(nr: 3, werte: werte(100, 13)))
        _ = reihe.aufnehmen(.werte(nr: 0, werte: werte(1, 13)))
        XCTAssertEqual(reihe.werte[25], 100)
        XCTAssertEqual(reihe.werte[0], 0, "Paket 0 ist kein Datenpaket")
    }

    func testHalbstundenPunkteNurImBereichUndNichtInDerZukunft() {
        var reihe = Halbstundenreihe()
        // Slot 0: 50 (gültig), Slot 1: 0 (nicht gemessen), Slot 2: 200 (über dem Bereich), Slot 3: 40 (Minute 90 = 01:30 Uhr).
        _ = reihe.aufnehmen(.werte(nr: 1, werte: [50, 0, 200, 40, 0, 0, 0, 0, 0, 0, 0, 0]))
        let anfang = Date(timeIntervalSince1970: 1_000_000)
        let punkte = reihe.punkte(bereich: 1...100, tagesanfang: anfang, bis: anfang.addingTimeInterval(80 * 60))
        XCTAssertEqual(punkte, [BandReihen.Punkt(minute: 0, wert: 50)])
        let spaeter = reihe.punkte(bereich: 1...100, tagesanfang: anfang, bis: anfang.addingTimeInterval(95 * 60))
        XCTAssertEqual(spaeter.map(\.minute), [0, 90])
    }

    // MARK: Reihen

    func testReihenEinesAnderenTagesGeltenNicht() {
        let gestern = BandReihen(tag: "2026-10-14", puls: [BandReihen.Punkt(minute: 5, wert: 60)])
        XCTAssertEqual(gestern.fuer("2026-10-14").puls.count, 1)
        XCTAssertEqual(gestern.fuer("2026-10-15"), BandReihen(tag: "2026-10-15"))
    }

    // MARK: Akku-Verlauf

    private func zeit(_ minuten: Int) -> Date { Date(timeIntervalSince1970: 1_791_800_000 + Double(minuten) * 60) }

    func testAkkuVerlaufNimmtAenderungenUndAlteWerteAuf() {
        var verlauf = TrackerAkkuVerlauf()
        verlauf.aufnehmen(zeit: zeit(0), prozent: 80, laedt: false)
        verlauf.aufnehmen(zeit: zeit(10), prozent: 80, laedt: false) // gleich und jung: übersprungen
        verlauf.aufnehmen(zeit: zeit(20), prozent: 79, laedt: false) // geändert: dabei
        verlauf.aufnehmen(zeit: zeit(60), prozent: 79, laedt: false) // gleich, aber 40 Minuten alt: dabei
        verlauf.aufnehmen(zeit: zeit(65), prozent: 79, laedt: true)  // Laden gewechselt: dabei
        XCTAssertEqual(verlauf.punkte.map(\.prozent), [80, 79, 79, 79])
        XCTAssertEqual(verlauf.punkte.map(\.laedt), [false, false, false, true])
    }

    func testAkkuVerlaufIgnoriertEineZurueckgesprungeneUhr() {
        var verlauf = TrackerAkkuVerlauf()
        verlauf.aufnehmen(zeit: zeit(100), prozent: 50, laedt: false)
        verlauf.aufnehmen(zeit: zeit(40), prozent: 60, laedt: false)
        XCTAssertEqual(verlauf.punkte.count, 1)
    }

    func testAkkuVerlaufWirftAltesNachSiebenTagenWeg() {
        var verlauf = TrackerAkkuVerlauf()
        verlauf.aufnehmen(zeit: zeit(0), prozent: 90, laedt: false)
        verlauf.aufnehmen(zeit: zeit(8 * 24 * 60), prozent: 40, laedt: false)
        XCTAssertEqual(verlauf.punkte.map(\.prozent), [40])
    }

    // MARK: Schlafphasen fürs Diagramm

    private func nacht(phasen: [TrackerSchlaf.Phasenzeit], minuten: Int = 420) -> TrackerSchlaf.Nacht {
        let von = Date(timeIntervalSince1970: 1_791_800_000)
        return TrackerSchlaf.Nacht(tag: "2026-10-15", von: von, bis: von.addingTimeInterval(7 * 3600), minuten: minuten, phasen: phasen)
    }

    func testPhasenDesBandsWerdenZurZeitleisteDerNacht() throws {
        let n = nacht(phasen: [.init(art: 2, minuten: 100), .init(art: 3, minuten: 60), .init(art: 4, minuten: 30), .init(art: 5, minuten: 10),
                               .init(art: 2, minuten: 220)])
        let leiste = try XCTUnwrap(TrackerSchlaf.diagramm(n))
        XCTAssertEqual(leiste.abschnitte.map(\.phase), [.kern, .tief, .rem, .wach, .kern])
        XCTAssertEqual(leiste.von, n.von)
        XCTAssertEqual(leiste.bis, n.bis)
        XCTAssertEqual(leiste.schlafMinuten, 420)
        // Lückenlos: jeder Abschnitt beginnt, wo der vorige endet.
        for (a, b) in zip(leiste.abschnitte, leiste.abschnitte.dropFirst()) { XCTAssertEqual(a.bis, b.von) }
    }

    func testGleicheNachbarphasenWerdenZusammengelegt() throws {
        let leiste = try XCTUnwrap(TrackerSchlaf.diagramm(nacht(phasen: [.init(art: 2, minuten: 30), .init(art: 2, minuten: 30), .init(art: 3, minuten: 60)],
                                                                minuten: 120)))
        XCTAssertEqual(leiste.abschnitte.map(\.phase), [.kern, .tief])
        XCTAssertEqual(leiste.minuten(.kern), 60)
    }

    func testZuLangePhasenEndenSpaetestensBeimAufwachen() throws {
        // 8 Stunden Phasen in einer Nacht von 7 Stunden: das Diagramm endet beim Aufwachen.
        let n = nacht(phasen: [.init(art: 2, minuten: 300), .init(art: 3, minuten: 180)])
        let leiste = try XCTUnwrap(TrackerSchlaf.diagramm(n))
        XCTAssertEqual(leiste.abschnitte.last?.bis, n.bis)
    }

    func testZuKurzePhasenEndenBeiDerLetztenPhase() throws {
        // 6:50 Stunden Phasen bei 7 Stunden Nacht (die Toleranz erlaubt 15 Minuten): das Diagramm endet, wo die Phasen enden.
        let n = nacht(phasen: [.init(art: 2, minuten: 200), .init(art: 3, minuten: 210)])
        let leiste = try XCTUnwrap(TrackerSchlaf.diagramm(n))
        XCTAssertEqual(leiste.bis, n.von.addingTimeInterval(410 * 60))
    }

    func testUnbekanntePhaseGibtKeinDiagramm() {
        XCTAssertNil(TrackerSchlaf.diagramm(nacht(phasen: [.init(art: 9, minuten: 400)])))
        XCTAssertNil(TrackerSchlaf.diagramm(nacht(phasen: [])))
    }
}
