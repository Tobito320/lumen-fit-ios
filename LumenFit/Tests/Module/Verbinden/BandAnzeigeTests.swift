// Quelle: Lovea Health/Tracker/TrackerSeite.swift
import XCTest
@testable import LumenFit

/// Die Texte und Zustände der Band-Seite: ein Zustand, ein Titel, ein Satz, der hilft.
@MainActor
final class BandAnzeigeTests: XCTestCase {
    private func status(_ z: TrackerModell.Zustand, gekoppelt: Bool = false, liest: Bool = false) -> BandAnzeige.Status {
        BandAnzeige.status(z, gekoppelt: gekoppelt, abfrageLaeuft: liest)
    }

    func testJederZustandHatTitelUndSymbol() {
        let alle: [TrackerModell.Zustand] = [.getrennt, .sucht, .nichtGefunden, .wartet, .verbunden, .bluetoothAus, .nichtErlaubt, .nichtVerfuegbar, .fehler("x")]
        for z in alle {
            let s = status(z)
            XCTAssertFalse(s.titel.isEmpty)
            XCTAssertFalse(s.symbol.isEmpty)
        }
    }

    func testVerbundenLiestOderRuht() {
        XCTAssertEqual(status(.verbunden).titel, "Verbunden")
        XCTAssertFalse(status(.verbunden).arbeitet)
        XCTAssertEqual(status(.verbunden, liest: true).titel, "Verbunden, liest")
        XCTAssertTrue(status(.verbunden, liest: true).arbeitet)
        XCTAssertNil(status(.verbunden).hilfe)
    }

    func testGetrenntUnterscheidetGekoppeltUndNeu() {
        XCTAssertEqual(status(.getrennt, gekoppelt: true).titel, "Getrennt")
        XCTAssertEqual(status(.getrennt, gekoppelt: false).titel, "Nicht verbunden")
        XCTAssertTrue(status(.getrennt, gekoppelt: true).hilfe?.contains("Verbinden") == true)
    }

    func testRoteZustaendeWarnenUndSagenWasHilft() {
        let rot: [TrackerModell.Zustand] = [.bluetoothAus, .nichtErlaubt, .nichtVerfuegbar, .nichtGefunden, .fehler("Zeit um")]
        for z in rot {
            XCTAssertTrue(status(z).warnung, "\(z)")
            XCTAssertNotNil(status(z).hilfe, "\(z)")
        }
        XCTAssertTrue(status(.fehler("Zeit um")).hilfe?.hasPrefix("Zeit um.") == true)
        XCTAssertFalse(status(.wartet).warnung)
        XCTAssertEqual(status(.wartet).hilfe, BandAnzeige.wecken)
    }

    func testSuchenArbeitet() {
        XCTAssertTrue(status(.sucht).arbeitet)
        XCTAssertFalse(status(.getrennt).arbeitet)
    }

    func testAkkuTexte() {
        XCTAssertEqual(BandAnzeige.akkuText(prozent: 80, laedt: false, vermutet: false), "80 %")
        XCTAssertEqual(BandAnzeige.akkuText(prozent: 80, laedt: true, vermutet: false), "80 %, lädt")
        XCTAssertEqual(BandAnzeige.akkuText(prozent: 80, laedt: true, vermutet: true), "80 %, lädt vermutlich")
        XCTAssertEqual(BandAnzeige.akkuSprechtext(prozent: 41, laedt: false, vermutet: false, veraltet: true), "41 Prozent, nicht aktuell")
        XCTAssertEqual(BandAnzeige.akkuSprechtext(prozent: 41, laedt: true, vermutet: true, veraltet: false), "41 Prozent, lädt vermutlich")
    }

    func testAkkuSymbolNachFuellung() {
        XCTAssertEqual(BandAnzeige.akkuSymbol(prozent: 100, laedt: false), "battery.100percent")
        XCTAssertEqual(BandAnzeige.akkuSymbol(prozent: 70, laedt: false), "battery.75percent")
        XCTAssertEqual(BandAnzeige.akkuSymbol(prozent: 40, laedt: false), "battery.50percent")
        XCTAssertEqual(BandAnzeige.akkuSymbol(prozent: 15, laedt: false), "battery.25percent")
        XCTAssertEqual(BandAnzeige.akkuSymbol(prozent: 5, laedt: false), "battery.0percent")
        XCTAssertEqual(BandAnzeige.akkuSymbol(prozent: 5, laedt: true), "battery.100percent.bolt")
    }

    func testAkkuAnteilBleibtZwischenNullUndEins() {
        XCTAssertEqual(BandAnzeige.akkuAnteil(-5), 0)
        XCTAssertEqual(BandAnzeige.akkuAnteil(50), 0.5)
        XCTAssertEqual(BandAnzeige.akkuAnteil(140), 1)
    }

    func testFruehereTageNeuesteZuerstHoechstensSechsOhneLeere() {
        func tag(_ schritte: Int) -> BandTag {
            var t = BandTag()
            t.zeilen[0] = BandTag.Zeile(schritte: schritte, meter: 0)
            return t
        }
        var tage: [String: BandTag] = ["2026-10-29": tag(100), "2026-10-30": tag(999)]
        for t in 20...27 { tage["2026-10-\(t)"] = tag(t) }
        tage["2026-10-19"] = tag(0)
        let liste = BandAnzeige.fruehereTage(tage, heute: "2026-10-30")
        XCTAssertEqual(liste.count, 6)
        XCTAssertEqual(liste.first?.tag, "2026-10-29")
        XCTAssertFalse(liste.contains { $0.tag == "2026-10-30" }, "heute zählt nicht")
        XCTAssertFalse(liste.contains { $0.tag == "2026-10-19" }, "ohne Schritte")
    }

    func testAbstandsListeEnthaeltDenWertDesBandesSortiert() {
        XCTAssertEqual(BandAnzeige.abstandsListe(aktuell: 20), (TrackerModus.pulsAbstaende + [20]).sorted())
        XCTAssertEqual(BandAnzeige.abstandsListe(aktuell: 10), TrackerModus.pulsAbstaende.sorted(), "bekannter Wert doppelt sich nicht")
    }

    func testPulsMessungText() {
        XCTAssertNil(BandAnzeige.pulsMessungText(.aus))
        XCTAssertTrue(BandAnzeige.pulsMessungText(.misst(seit: Date()))?.contains("45 Sekunden") == true)
        XCTAssertEqual(BandAnzeige.pulsMessungText(.fehler("kein Wert")), "kein Wert")
        XCTAssertTrue(BandAnzeige.pulsMessungText(.fertig(wert: 62, um: Date()))?.hasPrefix("Zuletzt 62 Schläge/Min. um ") == true)
    }

    func testKilometerMitKomma() {
        XCTAssertEqual(BandAnzeige.kilometer(meter: 3456), "3,46 km")
        XCTAssertEqual(BandAnzeige.kilometer(meter: 0), "0,00 km")
    }
}
