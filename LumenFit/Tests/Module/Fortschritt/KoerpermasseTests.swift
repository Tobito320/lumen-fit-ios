import XCTest
@testable import LumenFit

/// Ein Ort für Gewicht-Grenzen und Maß-Arten (`Koerpermasse`): dieselben Maße und Grenzen in Heute, Essen-Körperwerte, Messungen und Coach.
final class KoerpermasseTests: XCTestCase {
    func testGewichtGrenzeIstUeberallDieselbe() {
        XCTAssertEqual(Koerpermasse.gewichtZehntel, 300...2499)
        XCTAssertEqual(HeuteQuellen.gewichtBereich, Koerpermasse.gewichtZehntel)
        XCTAssertEqual(MessArt.gewicht.erlaubt, Koerpermasse.gewichtZehntel)
        XCTAssertFalse(HeuteQuellen.gewichtBereich.contains(2500))
        XCTAssertEqual(CoachMarker.kilo("249,9"), 249.9)
        XCTAssertNil(CoachMarker.kilo("250"))
        XCTAssertNil(CoachMarker.kilo("29,9"))
    }

    func testDieselbenMasseInEssenUndMessungen() {
        let ohneGewicht = MessArt.allCases.filter { $0 != .gewicht }
        XCTAssertEqual(ohneGewicht.map(\.titel), ["Körperfett", "Taille", "Hüfte", "Brust", "Schulter", "Oberarm", "Oberschenkel"])
        XCTAssertEqual(KoerperArt.allCases.map(\.name), ohneGewicht.map(\.titel))
        XCTAssertEqual(KoerperArt.allCases.map(\.messArt), ohneGewicht)
        XCTAssertEqual(ohneGewicht.compactMap(\.essenArt), KoerperArt.allCases)
        XCTAssertEqual(KoerperArt.allCases.map(\.einheit), ohneGewicht.map(\.einheit))
        XCTAssertNil(MessArt.gewicht.essenArt)
    }

    func testGespeicherteArtenBleibenUnveraendert() {
        XCTAssertEqual(MessArt.bizeps.rawValue, "bizeps")
        XCTAssertEqual(MessArt.bizeps.habitId, "mass.bizeps")
        XCTAssertEqual(KoerperArt.oberarm.rawValue, "oberarm")
        XCTAssertEqual(MessArt.gewicht.habitId, Habit.gewicht.id)
    }

    func testReiheOhneDoppelteTage() {
        let r = Koerpermasse.reihe(habit: ["2026-10-02": 380, "2026-10-05": 0], essen: ["2026-10-01": 36.5, "2026-10-02": 37, "2026-10-04": -1])
        XCTAssertEqual(r, ["2026-10-01": 365, "2026-10-02": 380], "Tagebuch-Werte bleiben lesbar, am selben Tag gewinnt der Habit-Wert, 0 und negativ fallen weg")
    }

    func testAlteWerteAusserhalbDerGrenzeBleibenInDerReihe() {
        XCTAssertEqual(Koerpermasse.reihe(habit: ["2026-10-01": 2600], essen: [:]), ["2026-10-01": 2600])
        XCTAssertFalse(MessArt.gewicht.erlaubt.contains(2600))
    }
}
