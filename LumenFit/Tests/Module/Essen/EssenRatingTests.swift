// Quelle: Lovea Tests/ErnaehrungTests.swift (testRating...)
import XCTest
@testable import LumenFit

final class EssenRatingTests: XCTestCase {
    private let skyr = Lebensmittel(id: "off-1", name: "Skyr", pro100: Naehrwerte(kcal: 62, protein: 11, kohlenhydrate: 4, fett: 0.2),
                                    portionMenge: 150, packungMenge: 450)

    private func texte(_ l: Lebensmittel) -> [String] { FoodRating.schilder(l).map(\.text) }

    func testRatingSkyrVielEiweissZuckerarmFettarm() {
        let t = texte(skyr)
        XCTAssertTrue(t.contains("Viel Eiweiß"))
        XCTAssertFalse(t.contains("Stark zuckerhaltig"))
        XCTAssertTrue(t.contains("Fettarm"))
    }

    func testRatingSchokoladeHinweise() {
        let schoko = Lebensmittel(id: "s", name: "Schokolade",
                                  pro100: Naehrwerte(kcal: 540, protein: 6, kohlenhydrate: 57, fett: 31, zucker: 55, salz: 0.2, gesFett: 19))
        let t = texte(schoko)
        XCTAssertEqual(Array(t.prefix(3)), ["Stark zuckerhaltig", "Viel Fett", "Viele gesättigte Fettsäuren"])
        XCTAssertTrue(t.contains("Salzarm"))
        XCTAssertFalse(t.contains("Eiweißquelle"))
    }

    func testRatingGetraenkeGrenzenHalbiert() {
        let cola = Lebensmittel(id: "c", name: "Cola", fluessig: true, pro100: Naehrwerte(kcal: 42, protein: 0, kohlenhydrate: 10.6, fett: 0, zucker: 10.6))
        XCTAssertFalse(texte(cola).contains("Stark zuckerhaltig"))
        let saft = Lebensmittel(id: "o", name: "Saft", fluessig: true, pro100: Naehrwerte(kcal: 50, protein: 0.7, kohlenhydrate: 12, fett: 0.2, zucker: 12))
        XCTAssertTrue(texte(saft).contains("Stark zuckerhaltig"))
    }

    func testRatingReichAnVitaminen() {
        let paprika = Lebensmittel(id: "p", name: "Paprika", pro100: Naehrwerte(kcal: 31, protein: 1, kohlenhydrate: 6, fett: 0.3,
                                   mikro: ["vitaminC": 128, "vitaminA": 157, "kalium": 211]))
        let t = texte(paprika)
        XCTAssertTrue(t.contains("Reich an Vitamin C"))
        XCTAssertFalse(t.contains("Reich an Kalium"))
        XCTAssertEqual(FoodRating.kurzName(.vitaminB1), "Vitamin B1")
    }

    /// Ersatz für `MahlzeitArt.vorschlag` aus Loveas `EssenModelleTests`: im Grundgerüst heißt es `Mahlzeit.zurZeit`.
    func testMahlzeitNachUhrzeit() {
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 8), .fruehstueck)
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 12), .mittag)
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 19), .abend)
        XCTAssertEqual(Mahlzeit.zurZeit(stunde: 23), .snack)
    }
}
