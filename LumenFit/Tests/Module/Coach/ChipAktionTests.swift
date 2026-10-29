import XCTest
@testable import LumenFit

/// Chips mit Handlung (Idee 65): "Mach ich" legt eine Gewohnheit an, "Morgen leicht" macht das Training von morgen leichter, "Zeig mir" öffnet
/// eine Seite. Jede Handlung hat einen Weg zurück, und nichts läuft ohne Tipp.
final class ChipAktionTests: XCTestCase {
    private let donnerstag = "2026-09-24"

    // MARK: - Plan leichter (rein)

    func testLeichterKuerztLetztenArbeitssatzUndCardio() throws {
        let plan = CoachTestBau.plan()
        let aenderung = try XCTUnwrap(CoachPlan.leichter(plan, datum: donnerstag))
        let uebungen = aenderung.plan.tage[0].uebungen
        XCTAssertEqual(uebungen[0].saetze.count, plan.tage[0].uebungen[0].saetze.count - 1, "ein Arbeitssatz weniger")
        XCTAssertEqual(uebungen[0].saetze.first?.typ, "w", "der Aufwärmsatz bleibt")
        XCTAssertEqual(uebungen[0].saetze.compactMap(\.kg), [20, 60, 60, 60], "das Gewicht bleibt")
        XCTAssertEqual(uebungen[1].saetze.count, 2, "mit zwei Sätzen schon leicht")
        XCTAssertEqual(uebungen[2].minuten, 16, "Cardio 20 Prozent kürzer")
        XCTAssertEqual(aenderung.tagName, "Push")
        XCTAssertEqual(aenderung.wenigerSaetze, 2)
    }

    func testCardioBleibtBeiMindestensFuenfMinuten() throws {
        XCTAssertEqual(try XCTUnwrap(CoachPlan.leichter(CoachTestBau.plan(minutenCardio: 6), datum: donnerstag)).plan.tage[0].uebungen[2].minuten, 5)
        XCTAssertEqual(try XCTUnwrap(CoachPlan.leichter(CoachTestBau.plan(minutenCardio: 10), datum: donnerstag)).plan.tage[0].uebungen[2].minuten, 8)
    }

    func testNichtsZuKuerzenGibtNil() {
        let leicht = CoachTestBau.plan(minutenCardio: 5, saetze: 2)
        XCTAssertNil(CoachPlan.leichter(leicht, datum: donnerstag), "schon leicht")
        XCTAssertNil(CoachPlan.leichter(CoachTestBau.plan(), datum: "2026-09-25"), "Freitag steht nichts an")
        XCTAssertNil(CoachPlan.leichter(.leer, datum: donnerstag))
    }

    func testNurDerGewaehlteTagWirdLeichter() throws {
        var plan = CoachTestBau.plan()
        var zweiter = plan.tage[0]
        zweiter.id = "t2"
        zweiter.name = "Pull"
        zweiter.wochentage = [6]
        plan.tage.append(zweiter)
        let neu = try XCTUnwrap(CoachPlan.leichter(plan, datum: donnerstag)).plan
        XCTAssertEqual(neu.tage[1], plan.tage[1], "Samstag bleibt wie er war")
        XCTAssertNotEqual(neu.tage[0], plan.tage[0])
    }

    // MARK: - Ausführen über die Stores

    @MainActor
    func testMorgenLeichtSchreibtDenPlanUndRueckgaengigStelltIhnHer() throws {
        let (u, daten, _) = try CoachTestBau.umgebung(stunde: 8)
        let alt = CoachTestBau.plan()
        daten.training.planSichern(alt)
        let ergebnis = CoachTracking.morgenLeicht(umgebung: u, daten: daten)
        XCTAssertEqual(ergebnis.text, "Push morgen ist leichter")
        XCTAssertNotEqual(daten.training.plan, alt)
        XCTAssertEqual(daten.training.plan.tage[0].uebungen[2].minuten, 16)

        let zurueck = try XCTUnwrap(ergebnis.zurueck)
        zurueck()
        XCTAssertEqual(daten.training.plan, alt, "Rückgängig: wie vorher")
    }

    @MainActor
    func testMorgenLeichtOhneTrainingOderSchonLeichtAendertNichts() throws {
        let (u, daten, _) = try CoachTestBau.umgebung(stunde: 8)
        daten.training.planSichern(CoachTestBau.plan(wochentag: 6))
        let keins = CoachTracking.morgenLeicht(umgebung: u, daten: daten)
        XCTAssertEqual(keins.text, "Morgen steht kein Training an.")
        XCTAssertNil(keins.zurueck)

        let leicht = CoachTestBau.plan(minutenCardio: 5, saetze: 2)
        daten.training.planSichern(leicht)
        let schon = CoachTracking.morgenLeicht(umgebung: u, daten: daten)
        XCTAssertEqual(schon.text, "Push morgen ist schon leicht.")
        XCTAssertNil(schon.zurueck)
        XCTAssertEqual(daten.training.plan, leicht)
    }

    @MainActor
    func testGewohnheitAnlegenEinmalMitSymbolUndRueckgaengig() throws {
        let (_, daten, _) = try CoachTestBau.umgebung()
        let erste = CoachTracking.gewohnheitAnlegen("  Abends spazieren ", daten: daten)
        let id = CoachTracking.gewohnheitsId("Abends spazieren")
        let habit = try XCTUnwrap(daten.habits.habits[id])
        XCTAssertEqual(habit.name, "Abends spazieren")
        XCTAssertEqual(habit.symbol, "figure.walk")
        XCTAssertFalse(habit.zaehlen)
        XCTAssertEqual(erste.text, "Gewohnheit angelegt: Abends spazieren")

        let zweite = CoachTracking.gewohnheitAnlegen("abends SPAZIEREN", daten: daten)
        XCTAssertEqual(zweite.text, "abends SPAZIEREN gibt es schon.")
        XCTAssertNil(zweite.zurueck)
        XCTAssertEqual(daten.habits.habits.values.filter { $0.id.hasPrefix("coach-") }.count, 1, "zweimal Mach ich legt nur eine an")

        try XCTUnwrap(erste.zurueck)()
        XCTAssertNil(daten.habits.habits[id], "Rückgängig löscht sie wieder")
    }

    func testSymbolZurGewohnheit() {
        XCTAssertEqual(CoachTracking.symbol(fuerGewohnheit: "Spazieren gehen"), "figure.walk")
        XCTAssertEqual(CoachTracking.symbol(fuerGewohnheit: "Mehr Wasser trinken"), "drop.fill")
        XCTAssertEqual(CoachTracking.symbol(fuerGewohnheit: "Früher ins Bett"), "bed.double.fill")
        XCTAssertEqual(CoachTracking.symbol(fuerGewohnheit: "Dehnen"), "figure.flexibility")
        XCTAssertEqual(CoachTracking.symbol(fuerGewohnheit: "Lesen"), "checkmark.circle.fill")
    }

    @MainActor
    func testZeigMirOeffnetDieSeiteUndFragenBestaetigenNichts() throws {
        let (u, daten, _) = try CoachTestBau.umgebung()
        let zeig = CoachChip(id: "z", text: "Zeig mir", aktion: .oeffne(.gym(.training)))
        XCTAssertNil(CoachTracking.ausfuehren(zeig, umgebung: u, daten: daten))
        XCTAssertEqual(u.router.tab, .gym)

        for aktion in [CoachAktion.antworten("Wie war mein Schlaf?"), .nichts] {
            XCTAssertNil(CoachTracking.ausfuehren(CoachChip(id: "x", text: "x", aktion: aktion), umgebung: u, daten: daten))
        }
    }

    // MARK: - Über den Tab (Tipp, Bestätigung, Rückgängig)

    @MainActor
    func testTippAufMachIchLegtEinmalAnUndZeigtRueckgaengig() throws {
        let (u, daten, _) = try CoachTestBau.umgebung()
        let modell = CoachModell(umgebung: u)
        let chip = CoachChip(id: "mach", text: "Mach ich", aktion: .gewohnheitAnlegen(name: "Dehnen"))
        let nachricht = CoachTestBau.nachricht("n1", .coach, "Wie wäre es mit Dehnen?", u.uhr(), chips: [chip])
        XCTAssertFalse(modell.istBenutzt(chip, in: nachricht))

        modell.tippe(chip, in: nachricht)
        XCTAssertTrue(modell.istBenutzt(chip, in: nachricht))
        XCTAssertEqual(modell.handlung?.text, "Gewohnheit angelegt: Dehnen")
        XCTAssertNotNil(daten.habits.habits[CoachTracking.gewohnheitsId("Dehnen")])

        modell.tippe(chip, in: nachricht)
        XCTAssertEqual(daten.habits.habits.values.filter { $0.id.hasPrefix("coach-") }.count, 1, "ein zweiter Tipp ändert nichts")

        modell.rueckgaengig()
        XCTAssertNil(modell.handlung)
        XCTAssertNil(daten.habits.habits[CoachTracking.gewohnheitsId("Dehnen")])
    }

    @MainActor
    func testNichtsLaeuftOhneTipp() throws {
        let (u, daten, _) = try CoachTestBau.umgebung(stunde: 8)
        let alt = CoachTestBau.plan()
        daten.training.planSichern(alt)
        let modell = CoachModell(umgebung: u)
        modell.morgenCheckBeantworten(1)
        XCTAssertEqual(daten.training.plan, alt, "der Chip bietet an, der Plan bleibt bis zum Tipp")
        XCTAssertTrue(daten.habits.habits.values.allSatisfy { !$0.id.hasPrefix("coach-") })
        XCTAssertNil(modell.handlung)
    }
}
