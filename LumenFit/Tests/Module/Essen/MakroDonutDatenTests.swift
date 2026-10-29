import XCTest
@testable import LumenFit

final class MakroDonutDatenTests: XCTestCase {
    func testAnteileAnDerEnergie() {
        // 100 g Protein (400 kcal), 100 g Kohlenhydrate (400 kcal), 22,2 g Fett (200 kcal) = 1000 kcal.
        let d = MakroDonutDaten.aus(Naehrwerte(kcal: 1000, protein: 100, kohlenhydrate: 100, fett: 200.0 / 9))
        XCTAssertEqual(d.segmente.map(\.art), [.protein, .kohlenhydrate, .fett])
        XCTAssertEqual(d.segmente.map(\.prozent), [40, 40, 20])
        XCTAssertEqual(d.segmente[0].kcal, 400, accuracy: 0.001)
        XCTAssertEqual(d.segmente[2].kcal, 200, accuracy: 0.001)
        XCTAssertFalse(d.istLeer)
    }

    func testProzenteErgebenImmer100() {
        for (p, k, f) in [(33.3, 33.3, 33.3), (1.0, 1.0, 1.0), (142.0, 190.0, 58.0), (0.1, 99.0, 0.3)] {
            let d = MakroDonutDaten.aus(Naehrwerte(kcal: 0, protein: p, kohlenhydrate: k, fett: f))
            XCTAssertEqual(d.segmente.map(\.prozent).reduce(0, +), 100, "\(p) \(k) \(f)")
        }
    }

    func testLeerUndNegativeWerte() {
        XCTAssertTrue(MakroDonutDaten.aus(.null).istLeer)
        XCTAssertEqual(MakroDonutDaten.aus(.null).segmente.map(\.prozent), [0, 0, 0])
        XCTAssertEqual(MakroDonutDaten.aus(.null).beschreibung, "Noch nichts gegessen")
        let negativ = MakroDonutDaten.aus(Naehrwerte(kcal: 0, protein: -5, kohlenhydrate: 10, fett: 0))
        XCTAssertEqual(negativ.segmente[0].gramm, 0)
        XCTAssertEqual(negativ.segmente[1].prozent, 100)
    }

    /// Idee 43: ohne Farbe. Jede Art hat ein eigenes Muster und einen eigenen Grauton, dazu die Beschriftung.
    func testJedeArtIstOhneFarbeUnterscheidbar() {
        XCTAssertEqual(Set(MakroArt.allCases.map(\.muster)).count, 3)
        XCTAssertEqual(Set(MakroArt.allCases.map(\.grau)).count, 3)
        let abstand = MakroArt.allCases.map(\.grau).sorted()
        XCTAssertGreaterThanOrEqual(abstand[1] - abstand[0], 0.2)
        XCTAssertGreaterThanOrEqual(abstand[2] - abstand[1], 0.2)
    }

    func testBeschriftungNenntNameGrammUndProzent() {
        let d = MakroDonutDaten.aus(Naehrwerte(kcal: 0, protein: 142, kohlenhydrate: 190, fett: 58))
        XCTAssertTrue(d.segmente[0].beschriftung.hasPrefix("Protein: 142 g, "))
        XCTAssertTrue(d.beschreibung.contains("Kohlenhydrate: 190 g"))
        XCTAssertTrue(d.beschreibung.contains("Fett: 58 g"))
    }

    func testKcalProGramm() {
        XCTAssertEqual(MakroArt.protein.kcalProGramm, 4)
        XCTAssertEqual(MakroArt.kohlenhydrate.kcalProGramm, 4)
        XCTAssertEqual(MakroArt.fett.kcalProGramm, 9)
    }
}
