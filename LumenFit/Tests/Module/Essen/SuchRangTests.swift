import XCTest
@testable import LumenFit

/// Rangfolge der Online-Suche, Fall aus dem Bildschirmfoto: "Bueno" muss "Kinder Bueno" zeigen, nicht spanisches Salz.
final class SuchRangTests: XCTestCase {
    private func k(_ code: String, _ name: String, _ marke: String?, _ laender: [String], _ beliebt: Double = 0, kcal: Double = 100) -> SuchKandidat {
        SuchKandidat(essen: Lebensmittel(id: "off-\(code)", name: name, marke: marke, barcode: code,
                                         pro100: Naehrwerte(kcal: kcal, protein: 1, kohlenhydrate: 1, fett: 1)),
                     laender: laender, beliebtheit: beliebt)
    }

    /// Reihenfolge wie im Bildschirmfoto (Open Food Facts liefert die Marke "bueno" zuerst).
    private var bildschirmfoto: [SuchKandidat] {
        [k("1", "Sal fina mesa", "bueno", ["en:spain"], kcal: 0),
         k("2", "Sazonador para preparar pescado ahumadoq", "bueno", ["en:spain"], 1, kcal: 204),
         k("3", "Chopped green chile", "Bueno", ["en:united-states"], kcal: 17),
         k("4", "Hand-made red chile & stone ground corn pork tamales", "Bueno", ["en:united-states"], kcal: 247),
         k("5", "Beef Enchiladas with Chili con Carne Sauce", "Bueno", ["en:united-states"], kcal: 190),
         k("6", "Unbekanntes Produkt", "Kinder", ["en:germany"], 22_900_000_011, kcal: 572),
         k("7", "Kinder Bueno", "Kinder", ["en:germany"], 22_950_000_026, kcal: 572),
         k("8000500137984", "8000500137984", "Kinder bueno", ["en:germany"], 22_950_000_033, kcal: 384),
         k("9", "Mayonesa Baja en Grasa", "Justo & Bueno", ["en:spain"], kcal: 200)]
    }

    func testBuenoZeigtKinderBuenoVorAllenFremdprodukten() {
        let namen = SuchRang.rangfolge(bildschirmfoto, text: "Bueno").map(\.name)
        XCTAssertEqual(namen.first, "Kinder Bueno")
        let fremd = ["Sal fina mesa", "Sazonador para preparar pescado ahumadoq", "Chopped green chile",
                     "Hand-made red chile & stone ground corn pork tamales", "Beef Enchiladas with Chili con Carne Sauce", "Mayonesa Baja en Grasa"]
        for f in fremd { XCTAssertTrue(namen.firstIndex(of: f).map { $0 > 0 } ?? true, f) }
    }

    func testMuellnamenUndZiffernnamenVerschwindenOderWerdenMarke() {
        let namen = SuchRang.rangfolge(bildschirmfoto, text: "Bueno").map(\.name)
        XCTAssertFalse(namen.contains("Unbekanntes Produkt"))
        XCTAssertFalse(namen.contains("8000500137984"))
        XCTAssertEqual(namen.filter { $0.lowercased() == "kinder bueno" }.count, 1, "Doppelte zusammengeführt")
    }

    func testMuellOhneMarkeWirdAusgeblendet() {
        let ohne = [k("1", "", nil, ["en:germany"]), k("2", "Unbekanntes Produkt", nil, ["en:germany"]), k("3", "12345", nil, ["en:germany"]),
                    k("4", "Haferflocken", nil, ["en:germany"])]
        XCTAssertEqual(SuchRang.rangfolge(ohne, text: "Hafer").map(\.name), ["Haferflocken"])
    }

    func testNameVorMarkeGanzesWortVorTeilLandVorBeliebtheit() {
        let liste = [k("a", "Nuss Mix", "Bueno", ["en:germany"], 9),
                     k("b", "Bueno Riegel", "X", ["en:spain"], 1),
                     k("c", "Superbueno", "X", ["en:germany"], 9),
                     k("d", "Bueno Riegel", "Y", ["en:austria"], 1),
                     k("e", "Bueno Creme", "Z", ["en:germany"], 5),
                     k("f", "Bueno Kekse", "Z", ["en:germany"], 7)]
        XCTAssertEqual(SuchRang.rangfolge(liste, text: "bueno").map(\.id), ["off-f", "off-e", "off-d", "off-b", "off-c", "off-a"])
    }

    func testOhneNaehrwerteUndVorneSortierung() {
        let liste = [k("a", "Bueno Leer", nil, ["en:germany"], 9, kcal: 0).mitNull,
                     k("b", "Bueno", nil, ["en:spain"]),
                     k("c", "Bueno Eigen", nil, ["en:united-states"])]
        XCTAssertEqual(SuchRang.rangfolge(liste, text: "bueno").map(\.id), ["off-b", "off-c", "off-a"])
        XCTAssertEqual(SuchRang.rangfolge(liste, text: "bueno", vorne: ["off-c"]).first?.id, "off-c")
    }

    func testKandidatenLiestLandUndBeliebtheitAusDerAntwort() throws {
        let json = #"{"hits":[{"code":"4008400322728","product_name":"Kinder Bueno","brands":["Kinder"],"countries_tags":["en:germany"],"popularity_key":22950000033,"nutriments":{"energy-kcal_100g":572}}]}"#
        let k = try XCTUnwrap(SuchRang.kandidaten(Data(json.utf8)).first)
        XCTAssertEqual(k.laender, ["en:germany"])
        XCTAssertEqual(k.beliebtheit, 22_950_000_033)
        XCTAssertEqual(SuchRang.landStufe(k.laender), 0)
    }

    func testLaenderFilterNenntDachUndEU() {
        XCTAssertTrue(SuchRang.laenderFilter.hasPrefix("countries_tags:(\"en:germany\" OR \"en:austria\""))
        XCTAssertTrue(SuchRang.laenderFilter.contains("\"en:france\""))
    }
}

private extension SuchKandidat {
    /// Alle Nährwerte null.
    var mitNull: SuchKandidat {
        var neu = self
        neu.essen.pro100 = Naehrwerte(kcal: 0, protein: 0, kohlenhydrate: 0, fett: 0)
        return neu
    }
}
