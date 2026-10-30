import XCTest
@testable import LumenFit

final class HabitFeierTests: XCTestCase {
    private func speicher() -> UserDefaults {
        let name = "habit-feier-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name) ?? .standard
        d.removePersistentDomain(forName: name)
        return d
    }

    func testFeierEinmalJeTagUndGewohnheit() {
        let s = speicher()
        XCTAssertTrue(HabitFeier.darfFeiern(habitId: "wasser", tag: "2026-10-30", speicher: s))
        XCTAssertFalse(HabitFeier.darfFeiern(habitId: "wasser", tag: "2026-10-30", speicher: s))
        XCTAssertTrue(HabitFeier.darfFeiern(habitId: "gym", tag: "2026-10-30", speicher: s))
        XCTAssertTrue(HabitFeier.darfFeiern(habitId: "wasser", tag: "2026-10-31", speicher: s))
    }

    func testErreichtZielNurBeimLetztenSchritt() {
        let wasser = Habit.wasser
        XCTAssertFalse(HabitFeier.erreichtZiel(wasser, wert: 3, ziel: 8))
        XCTAssertTrue(HabitFeier.erreichtZiel(wasser, wert: 7, ziel: 8))
        XCTAssertFalse(HabitFeier.erreichtZiel(wasser, wert: 8, ziel: 8))
        let haken = Habit(id: "h", name: "Haken", symbol: "star.fill", farbe: HabitFarbe.mint.rawValue, zaehlen: false, tagesziel: nil, haeufigkeit: .taeglich, fuer: "ich")
        XCTAssertTrue(HabitFeier.erreichtZiel(haken, wert: 0, ziel: nil))
        XCTAssertFalse(HabitFeier.erreichtZiel(haken, wert: 1, ziel: nil))
    }
}
