// Quelle: Lovea Tests/EssenAmpelTests.swift
import XCTest
@testable import LumenFit

final class EssenAmpelTests: XCTestCase {
    private func halal(_ z: String?, siegel: [String]? = nil) -> AmpelStufe { EssenAmpel.halal(zutaten: z, siegel: siegel).stufe }

    private func essen(zucker: Double?, fluessig: Bool = false, zutaten: String? = nil) -> Lebensmittel {
        Lebensmittel(id: "off-1", name: "Test", fluessig: fluessig,
                     pro100: Naehrwerte(kcal: 50, protein: 0, kohlenhydrate: 10, fett: 0, zucker: zucker), zutaten: zutaten)
    }

    func testHalalRotDeutschUndEnglisch() {
        XCTAssertEqual(halal("Weizenmehl, Schweineschmalz, Salz"), .rot)
        XCTAssertEqual(halal("Zucker, Gelatine, Zitronensäure"), .rot)
        XCTAssertEqual(halal("Sugar, pork gelatin, flavouring"), .rot)
        XCTAssertEqual(halal("Wasser, Alkohol 5 %"), .rot)
        XCTAssertEqual(halal("Water, red wine, bacon"), .rot)
        XCTAssertEqual(halal("Geliermittel: E441"), .rot)
        XCTAssertEqual(halal("Geliermittel: E 441"), .rot)
    }

    func testHalalGelb() {
        XCTAssertEqual(halal("Zucker, Farbstoff E120"), .gelb)
        XCTAssertEqual(halal("Zucker, Farbstoff: Karmin"), .gelb)
        XCTAssertEqual(halal("Emulgator E472a, Wasser"), .gelb)
        XCTAssertEqual(halal("Hähnchenfleisch, Salz"), .gelb)
        XCTAssertEqual(halal("Überzug: Schellack"), .gelb)
        XCTAssertEqual(halal(nil), .gelb)
        XCTAssertEqual(halal("   "), .gelb)
    }

    func testHalalGruen() {
        XCTAssertEqual(halal("Wasser, Haferflocken, Salz"), .gruen)
        XCTAssertEqual(halal("Weinsäure, Weintrauben, Schweizer Käse"), .gruen)
        XCTAssertEqual(halal("Wasser, Fruchtfleisch, alkoholfrei"), .gruen)
        XCTAssertEqual(halal("Zucker, Farbstoff E120", siegel: ["en:halal"]), .gruen)
        XCTAssertEqual(halal(nil, siegel: ["de:halal-zertifiziert"]), .gruen)
    }

    func testHalalRotSchlaegtSiegel() {
        XCTAssertEqual(halal("Gelatine", siegel: ["en:halal"]), .rot)
    }

    func testZuckerStufen() {
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: 0)).stufe, .gruen)
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: 0.5)).stufe, .gruen)
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: 2.5, fluessig: true)).stufe, .gelb)
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: 3, fluessig: true)).stufe, .rot)
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: 3)).stufe, .gelb)
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: 10.6, fluessig: true)).stufe, .rot)
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: 40)).stufe, .rot)
    }

    func testZuckerFehltWert() {
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: nil)).grund, "Zuckerwert fehlt")
        XCTAssertEqual(EssenAmpel.zucker(essen(zucker: nil, zutaten: "Wasser, Glukosesirup")).grund, "Zucker in den Zutaten, Menge fehlt")
    }

    func testOffLiefertZutatenUndSiegel() throws {
        let json = #"{"code":"1","status":1,"product":{"code":"1","product_name":"Bonbon","ingredients_text_de":"Zucker, Gelatine","labels_tags":["en:halal"],"nutriments":{"energy-kcal_100g":350,"sugars_100g":60}}}"#
        let l = try XCTUnwrap(ErnaehrungLogik.offProdukt(Data(json.utf8)))
        XCTAssertEqual(l.zutaten, "Zucker, Gelatine")
        XCTAssertEqual(l.siegel, ["en:halal"])
    }

    // MARK: - Anzeige: immer Symbol und Text, fehlende Daten heißen "unklar"

    func testFehlendeZutatenHeissenUnklar() {
        for z in [nil, "", "   "] as [String?] {
            let u = EssenAmpel.halal(zutaten: z, siegel: nil)
            XCTAssertTrue(u.unklar, "\(String(describing: z))")
            XCTAssertTrue(EssenAmpelAnzeige.halal(u).text.contains("unklar"))
        }
        XCTAssertFalse(EssenAmpel.halal(zutaten: nil, siegel: ["en:halal"]).unklar, "mit Siegel ist es nicht unklar")
    }

    func testFehlenderZuckerwertHeisstUnklar() {
        XCTAssertTrue(EssenAmpelAnzeige.zucker(EssenAmpel.zucker(essen(zucker: nil))).text.contains("unklar"))
        XCTAssertTrue(EssenAmpelAnzeige.zucker(EssenAmpel.zucker(essen(zucker: nil, zutaten: "Wasser, Glukosesirup"))).text.contains("unklar"))
        XCTAssertFalse(EssenAmpel.zucker(essen(zucker: 12)).unklar)
    }

    func testJederFallHatSymbolUndText() {
        let urteile: [AmpelUrteil] = [
            EssenAmpel.halal(zutaten: "Gelatine", siegel: nil), EssenAmpel.halal(zutaten: "Farbstoff E120", siegel: nil),
            EssenAmpel.halal(zutaten: "Haferflocken", siegel: nil), EssenAmpel.halal(zutaten: nil, siegel: nil),
            EssenAmpel.zucker(essen(zucker: 0)), EssenAmpel.zucker(essen(zucker: 3)), EssenAmpel.zucker(essen(zucker: 40)),
            EssenAmpel.zucker(essen(zucker: nil)),
        ]
        for u in urteile {
            for a in [EssenAmpelAnzeige.halal(u), EssenAmpelAnzeige.zucker(u)] {
                XCTAssertFalse(a.symbol.isEmpty)
                XCTAssertFalse(a.text.isEmpty)
                XCTAssertFalse(a.grund.isEmpty)
            }
        }
    }

    func testStufenHabenVerschiedeneSymbole() {
        let gruen = EssenAmpelAnzeige.halal(AmpelUrteil(stufe: .gruen, grund: "a")).symbol
        let gelb = EssenAmpelAnzeige.halal(AmpelUrteil(stufe: .gelb, grund: "a")).symbol
        let rot = EssenAmpelAnzeige.halal(AmpelUrteil(stufe: .rot, grund: "a")).symbol
        let unklar = EssenAmpelAnzeige.halal(AmpelUrteil(stufe: .gelb, grund: "a", unklar: true)).symbol
        XCTAssertEqual(Set([gruen, gelb, rot, unklar]).count, 4, "ohne Farbe unterscheidbar")
    }

    // MARK: - Zutaten nachladen

    func testNachladenNurMitBarcodeOhneZutatenUndNichtBeimBearbeiten() {
        var l = essen(zucker: nil)
        XCTAssertFalse(EssenAmpelNachladen.braucht(l, bearbeiten: false), "ohne Barcode gibt es nichts zu fragen")
        l.barcode = "4311501679715"
        XCTAssertTrue(EssenAmpelNachladen.braucht(l, bearbeiten: false))
        XCTAssertFalse(EssenAmpelNachladen.braucht(l, bearbeiten: true), "beim Bearbeiten eines Eintrags kein Netz")
        l.zutaten = "   "
        XCTAssertTrue(EssenAmpelNachladen.braucht(l, bearbeiten: false), "leere Zutaten zählen als fehlend")
        l.zutaten = "Wasser, Zucker"
        XCTAssertFalse(EssenAmpelNachladen.braucht(l, bearbeiten: false))
    }

    func testZusammenfuehrenUebernimmtZutatenUndSiegelUndBehaeltVorhandenenZucker() {
        var l = essen(zucker: 4)
        l.barcode = "1"
        var geladen = essen(zucker: 60)
        geladen.zutaten = "Zucker, Gelatine"
        geladen.siegel = ["en:halal"]
        let z = EssenAmpelNachladen.zusammen(l, geladen: geladen)
        XCTAssertEqual(z.zutaten, "Zucker, Gelatine")
        XCTAssertEqual(z.siegel, ["en:halal"])
        XCTAssertEqual(z.pro100.zucker, 4, "ein vorhandener Zuckerwert bleibt")
        XCTAssertEqual(EssenAmpel.halal(z).stufe, .rot, "mit den Zutaten greift die Halal-Ampel")
    }

    func testZusammenfuehrenFuelltFehlendenZuckerUndLaesstNilUnveraendert() {
        let l = essen(zucker: nil)
        var geladen = essen(zucker: 12)
        geladen.zutaten = "Wasser"
        XCTAssertEqual(EssenAmpelNachladen.zusammen(l, geladen: geladen).pro100.zucker, 12)
        XCTAssertEqual(EssenAmpelNachladen.zusammen(l, geladen: nil), l)
        XCTAssertNil(EssenAmpelNachladen.zusammen(l, geladen: nil).zutaten)
    }
}
