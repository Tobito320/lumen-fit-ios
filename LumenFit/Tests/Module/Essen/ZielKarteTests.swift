import XCTest
@testable import LumenFit

final class ZielKarteTests: XCTestCase {
    /// 2026-10-29 als "heute".
    private let heute = Datum.datum("2026-10-29")

    private func mann(groesse: Int? = 180, jahr: Int? = 1996) -> Koerperdaten { Koerperdaten(groesseCm: groesse, geburtsjahr: jahr, geschlecht: .maennlich) }

    private func aktiv() -> ErnaehrungsZiele {
        var z = ErnaehrungsZiele()
        z.aktivitaet = 2   // 1,55
        return z
    }

    /// Zielart und Richtung laufen gegenläufig: aufbauen = 2, abnehmen = 0.
    func testRichtungIstGegenlaeufig() {
        XCTAssertEqual(ZielKarteLogik.richtung(.abnehmen), 0)
        XCTAssertEqual(ZielKarteLogik.richtung(.halten), 1)
        XCTAssertEqual(ZielKarteLogik.richtung(.aufbauen), 2)
    }

    func testAlterAusGeburtsjahr() {
        XCTAssertEqual(ZielKarteLogik.alter(geburtsjahr: 1996, heute: heute), 30)
        XCTAssertEqual(ZielKarteLogik.alter(geburtsjahr: 2030, heute: heute), 0)
    }

    // Mann, 30, 180 cm, 80 kg: Grundumsatz 800 + 1125 - 150 + 5 = 1780, mal 1,55 = 2759 kcal Bedarf.
    func testHaltenRechnetDenBedarf() throws {
        let v = ZielKarteLogik.vorschlag(koerper: mann(), art: .halten, kg: 80, aktuell: aktiv(), heute: heute)
        let z = try XCTUnwrap(v.ziele)
        XCTAssertEqual(v.grundumsatz, 1780)
        XCTAssertEqual(v.bedarf, 2759)
        XCTAssertEqual(v.aenderung, 0)
        XCTAssertEqual(z.kcal, 2760)
        XCTAssertEqual(z.protein, 138, "ausgewogen: 20 % der Energie")
        XCTAssertTrue(v.fehlt.isEmpty)
    }

    func testAbnehmenZiehtKalorienAbUndHaeltDasProteinHoch() throws {
        let v = ZielKarteLogik.vorschlag(koerper: mann(), art: .abnehmen, kg: 80, aktuell: aktiv(), heute: heute)
        let z = try XCTUnwrap(v.ziele)
        XCTAssertEqual(z.richtung, 0)
        XCTAssertEqual(v.aenderung, -550)
        XCTAssertEqual(z.kcal, 2210)
        XCTAssertEqual(z.protein, 166)
        XCTAssertGreaterThanOrEqual(Double(z.protein), 2 * 80 * 0.99, "mindestens etwa 2 g je kg")
    }

    func testAufbauenGibtKalorienDazu() throws {
        let v = ZielKarteLogik.vorschlag(koerper: mann(), art: .aufbauen, kg: 80, aktuell: aktiv(), heute: heute)
        let z = try XCTUnwrap(v.ziele)
        XCTAssertEqual(z.richtung, 2)
        XCTAssertEqual(v.aenderung, 275)
        XCTAssertEqual(z.kcal, 3030)
        XCTAssertGreaterThan(z.kcal, ZielKarteLogik.vorschlag(koerper: mann(), art: .halten, kg: 80, aktuell: aktiv(), heute: heute).ziele?.kcal ?? 0)
    }

    func testFrauRechnetMitDerFrauenFormel() throws {
        let frau = Koerperdaten(groesseCm: 165, geburtsjahr: 1996, geschlecht: .weiblich)
        var a = ErnaehrungsZiele(); a.aktivitaet = 1   // 1,375
        let v = ZielKarteLogik.vorschlag(koerper: frau, art: .halten, kg: 60, aktuell: a, heute: heute)
        XCTAssertEqual(v.ziele?.geschlecht, 1)
        XCTAssertEqual(v.grundumsatz, 1320)   // 600 + 1031,25 - 150 - 161 = 1320,25
        XCTAssertEqual(v.ziele?.kcal, 1820)
    }

    func testDiversNimmtDenMittelwert() throws {
        let k = Koerperdaten(groesseCm: 180, geburtsjahr: 1996, geschlecht: .divers)
        let v = ZielKarteLogik.vorschlag(koerper: k, art: .halten, kg: 80, aktuell: aktiv(), heute: heute)
        XCTAssertEqual(v.ziele?.kcal, 2630)   // Mittel aus 2760 (Mann) und 2500 (Frau)
    }

    /// Fehlt etwas, wird nichts still mit Standardwerten gerechnet: der Vorschlag nennt, was fehlt.
    func testFehlendeAngabenWerdenGenanntStattGeraten() {
        let v = ZielKarteLogik.vorschlag(koerper: Koerperdaten(), art: .halten, kg: nil, aktuell: aktiv(), heute: heute)
        XCTAssertNil(v.ziele)
        XCTAssertEqual(v.fehlt, ["Größe", "Geburtsjahr", "Geschlecht", "Gewicht"])
        XCTAssertTrue(v.erklaerung.contains("Größe"))
        let nurGewicht = ZielKarteLogik.vorschlag(koerper: mann(), art: .halten, kg: nil, aktuell: aktiv(), heute: heute)
        XCTAssertNil(nurGewicht.ziele)
        XCTAssertEqual(nurGewicht.fehlt, ["Gewicht"])
        XCTAssertNil(ZielKarteLogik.vorschlag(koerper: mann(), art: .halten, kg: 0, aktuell: aktiv(), heute: heute).ziele)
    }

    func testRestDerZieleBleibtErhalten() throws {
        var a = aktiv()
        a.fastenStunden = 18
        a.extraKcal = 300
        let z = try XCTUnwrap(ZielKarteLogik.vorschlag(koerper: mann(), art: .halten, kg: 80, aktuell: a, heute: heute).ziele)
        XCTAssertEqual(z.fastenStunden, 18)
        XCTAssertEqual(z.extraKcal, 300)
        XCTAssertEqual(z.aktivitaet, 2)
    }

    func testErklaerungNenntDieRechnung() throws {
        let v = ZielKarteLogik.vorschlag(koerper: mann(), art: .abnehmen, kg: 80, aktuell: aktiv(), heute: heute)
        XCTAssertTrue(v.erklaerung.contains("780"), v.erklaerung)
        XCTAssertTrue(v.erklaerung.contains("759"), v.erklaerung)
        XCTAssertTrue(v.erklaerung.contains("550"), v.erklaerung)
        XCTAssertTrue(v.erklaerung.contains("1,55"), v.erklaerung)
    }

    /// "Alles überschreibbar": eigene Kalorien und eigenes Protein gelten, der Rest füllt sich passend auf.
    func testEigeneWerteUeberschreibenDenVorschlag() throws {
        let vorschlag = try XCTUnwrap(ZielKarteLogik.vorschlag(koerper: mann(), art: .halten, kg: 80, aktuell: aktiv(), heute: heute).ziele)
        let gleich = ZielKarteLogik.angepasst(vorschlag, kcal: vorschlag.kcal, protein: vorschlag.protein, kg: 80)
        XCTAssertEqual(gleich.kohlenhydrate, vorschlag.kohlenhydrate)
        XCTAssertEqual(gleich.fett, vorschlag.fett)
        let eigen = ZielKarteLogik.angepasst(vorschlag, kcal: 3000, protein: 200, kg: 80)
        XCTAssertEqual(eigen.kcal, 3000)
        XCTAssertEqual(eigen.protein, 200)
        XCTAssertEqual(eigen.fett, 100)            // 30 % von 3000 kcal / 9
        XCTAssertEqual(eigen.kohlenhydrate, 325)   // (3000 - 800 - 900) / 4
        XCTAssertEqual(eigen.fastenStunden, vorschlag.fastenStunden)
    }
}
