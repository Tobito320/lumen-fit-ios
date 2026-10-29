// Quelle: Lovea Tests/SchlafNachtTests.swift
import XCTest
@testable import LumenFit

/// Nacht-Diagramm: Phasen einer Nacht zur Zeitleiste (`SchlafNacht.swift`). Reine Logik, Berliner Zeit.
final class SchlafNachtTests: XCTestCase {

    private func zeit(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        Datum.kalender.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde, minute: minute))!
    }

    private func roh(_ phase: SchlafPhase, _ von: Date, _ bis: Date) -> SchlafNachtLogik.Roh {
        SchlafNachtLogik.Roh(phase: phase, von: von, bis: bis)
    }

    /// 23:00 bis 06:00, dazwischen 10 Minuten wach (03:00 bis 03:10): 410 Minuten Schlaf.
    private var typischeNacht: [SchlafNachtLogik.Roh] {
        [
            roh(.kern, zeit(10, 23), zeit(11, 0, 30)),
            roh(.tief, zeit(11, 0, 30), zeit(11, 1, 30)),
            roh(.rem, zeit(11, 1, 30), zeit(11, 2)),
            roh(.kern, zeit(11, 2), zeit(11, 3)),
            roh(.kern, zeit(11, 3, 10), zeit(11, 6)),
        ]
    }

    // MARK: - Zeitleiste

    func testNachtVonEinschlafenBisAufwachenMitWachLuecke() throws {
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(typischeNacht, tag: "2026-10-11"))
        XCTAssertEqual(nacht.tag, "2026-10-11")
        XCTAssertEqual(nacht.von, zeit(10, 23))
        XCTAssertEqual(nacht.bis, zeit(11, 6))
        XCTAssertEqual(nacht.abschnitte.map(\.phase), [.kern, .tief, .rem, .kern, .wach, .kern])
        XCTAssertEqual(nacht.minuten(.wach), 10)
        XCTAssertEqual(nacht.minuten(.tief), 60)
        XCTAssertEqual(nacht.minuten(.rem), 30)
        XCTAssertEqual(nacht.minuten(.kern), 90 + 60 + 170)
        XCTAssertEqual(nacht.schlafMinuten, 410)
        XCTAssertEqual(nacht.phasen, [.wach, .rem, .kern, .tief])
    }

    func testAbschnitteSindLueckenlosUndSortiert() throws {
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(typischeNacht.reversed(), tag: "2026-10-11"))
        XCTAssertEqual(nacht.abschnitte.first?.von, nacht.von)
        XCTAssertEqual(nacht.abschnitte.last?.bis, nacht.bis)
        for (a, b) in zip(nacht.abschnitte, nacht.abschnitte.dropFirst()) {
            XCTAssertEqual(a.bis, b.von)
            XCTAssertNotEqual(a.phase, b.phase)
        }
    }

    func testMinutenWieImSchlafTab() throws {
        let intervalle = typischeNacht.map { HealthLogik.SchlafIntervall(von: $0.von, bis: $0.bis) }
        let tab = try XCTUnwrap(HealthLogik.schlafNacht(intervalle, tag: "2026-10-11"))
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(typischeNacht, tag: "2026-10-11"))
        XCTAssertEqual(nacht.schlafMinuten, tab.minuten)
        XCTAssertEqual(nacht.von, tab.von)
        XCTAssertEqual(nacht.bis, tab.bis)
    }

    func testBenachbarteGleichePhasenWerdenZusammengelegt() throws {
        let liste = [roh(.kern, zeit(10, 23), zeit(11, 1)), roh(.kern, zeit(11, 1), zeit(11, 3)), roh(.tief, zeit(11, 3), zeit(11, 5))]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertEqual(nacht.abschnitte.map(\.phase), [.kern, .tief])
        XCTAssertEqual(nacht.abschnitte[0].bis, zeit(11, 3))
    }

    // MARK: - Überlappung mehrerer Quellen

    func testGenauePhaseSchlaegtSchlafOhnePhase() throws {
        // Das iPhone meldet die ganze Nacht "Schlaf", die Watch dazu Tief 00:00 bis 03:00.
        let liste = [roh(.unbestimmt, zeit(10, 23), zeit(11, 5)), roh(.tief, zeit(11, 0), zeit(11, 3))]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertEqual(nacht.abschnitte.map(\.phase), [.unbestimmt, .tief, .unbestimmt])
        XCTAssertEqual(nacht.minuten(.tief), 180)
        XCTAssertEqual(nacht.minuten(.unbestimmt), 180)
        XCTAssertEqual(nacht.schlafMinuten, 360, "nichts doppelt gezählt")
    }

    func testTiefSchlaegtKernBeiUeberlappung() throws {
        let liste = [roh(.kern, zeit(10, 23), zeit(11, 5)), roh(.tief, zeit(11, 1), zeit(11, 2))]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertEqual(nacht.abschnitte.map(\.phase), [.kern, .tief, .kern])
        XCTAssertEqual(nacht.schlafMinuten, 360)
    }

    func testWachWerteVerlaengernDieNachtNicht() throws {
        // Wach vor dem Einschlafen und nach dem Aufwachen ist nicht Teil der Nacht.
        let liste = typischeNacht + [roh(.wach, zeit(10, 22), zeit(10, 23)), roh(.wach, zeit(11, 6), zeit(11, 7))]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertEqual(nacht.von, zeit(10, 23))
        XCTAssertEqual(nacht.bis, zeit(11, 6))
    }

    // MARK: - Keine Daten, keine Nacht

    func testOhneSchlafKeineNacht() {
        XCTAssertNil(SchlafNachtLogik.nacht([], tag: "2026-10-11"))
        XCTAssertNil(SchlafNachtLogik.nacht([roh(.wach, zeit(11, 3), zeit(11, 4))], tag: "2026-10-11"))
    }

    func testAnderesAufwachDatumIstKeineNacht() {
        XCTAssertNil(SchlafNachtLogik.nacht(typischeNacht, tag: "2026-10-12"))
        XCTAssertNil(SchlafNachtLogik.nacht(typischeNacht, tag: "2026-10-10"))
    }

    func testNurSchlafOhnePhaseZeigtKeinDiagramm() {
        XCTAssertNil(SchlafNachtLogik.nacht([roh(.unbestimmt, zeit(10, 23), zeit(11, 6))], tag: "2026-10-11"))
    }

    func testMindestensDieHaelfteMitPhase() throws {
        // 1 h Kern, 3 h ohne Phase: ein Viertel, zu wenig.
        let zuWenig = [roh(.kern, zeit(11, 1), zeit(11, 2)), roh(.unbestimmt, zeit(11, 2), zeit(11, 5))]
        XCTAssertNil(SchlafNachtLogik.nacht(zuWenig, tag: "2026-10-11"))
        // 2 h Kern, 2 h ohne Phase: genau die Hälfte reicht.
        let genug = [roh(.kern, zeit(11, 1), zeit(11, 3)), roh(.unbestimmt, zeit(11, 3), zeit(11, 5))]
        XCTAssertNotNil(SchlafNachtLogik.nacht(genug, tag: "2026-10-11"))
    }

    func testNickerchenAmAufwachTagVerschiebtDieNachtNicht() throws {
        let liste = typischeNacht + [roh(.kern, zeit(11, 14), zeit(11, 14, 30))]
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(liste, tag: "2026-10-11"))
        XCTAssertEqual(nacht.von, zeit(10, 23))
        XCTAssertEqual(nacht.bis, zeit(11, 6))
        XCTAssertEqual(nacht.schlafMinuten, 410)
    }

    // MARK: - Text

    func testBeschreibungNenntZeitenUndPhasen() throws {
        let nacht = try XCTUnwrap(SchlafNachtLogik.nacht(typischeNacht, tag: "2026-10-11"))
        XCTAssertTrue(nacht.beschreibung.contains("eingeschlafen 23:00"), nacht.beschreibung)
        XCTAssertTrue(nacht.beschreibung.contains("aufgewacht 06:00"), nacht.beschreibung)
        XCTAssertTrue(nacht.beschreibung.contains("6 h 50 min geschlafen"), nacht.beschreibung)
        XCTAssertTrue(nacht.beschreibung.contains("Tief 1 h 00 min"), nacht.beschreibung)
    }

    // MARK: - Tag

    func testGueltigerTag() {
        XCTAssertTrue(SchlafNachtLogik.gueltigerTag("2026-10-11"))
        XCTAssertTrue(SchlafNachtLogik.gueltigerTag("2028-02-29"))
        for text in ["2026-02-30", "2026-13-01", "2026-00-10", "2026-10-00", "2026-1-5", "26-10-11", "2026/10/11",
                     "2026-10-11x", "", "heute", "2026-10-1١", "1999-12-31", "2101-01-01"] {
            XCTAssertFalse(SchlafNachtLogik.gueltigerTag(text), text)
        }
    }
}
