import XCTest
@testable import LumenFit

/// Der Snapshot, den die App für die Widgets schreibt: Fixture lesen, rund schreiben, ältere und kaputte Dateien verkraften.
final class WidgetSnapshotTests: XCTestCase {
    private func ordnerMitFixture() throws -> URL {
        let ordner = try tempOrdner()
        try FixtureOrt.daten("Widgets", "widget-snapshot-beispiel.json").write(to: ordner.appendingPathComponent(WidgetSnapshotDatei.name))
        return ordner
    }

    func testBeispielDateiLaesstSichLesen() throws {
        let s = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: try ordnerMitFixture()))
        XCTAssertEqual(s.profilName, "Beispiel")
        XCTAssertEqual(s.tag, "2026-09-23")
        XCTAssertEqual(s.thema, .wald)
        XCTAssertEqual(s.lumi, .stolz)
        XCTAssertEqual(s.boegen?.schritte, 8_412)
        XCTAssertEqual(s.boegen?.hrv, 68)
        XCTAssertEqual(s.plan, WidgetPlanTag(name: "Push", tag: "2026-09-24"))
        XCTAssertEqual(s.serieWochen, 4)
        XCTAssertEqual(s.essen?.proteinZiel, 140)
        XCTAssertEqual(s.habits?.map(\.id), ["gym", "wasser", "dehnen"])
        XCTAssertEqual(s.geschrieben, Date(timeIntervalSince1970: 1_790_157_600))
    }

    func testSchreibenUndLesenGibtDenselbenStand() throws {
        let ordner = try tempOrdner()
        let original = WidgetSnapshot.beispiel(jetzt: TestUhr().lesen, thema: .glut)
        XCTAssertTrue(WidgetSnapshotDatei.schreibe(original, ordner: ordner))
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner), original)
    }

    /// Wie Loveas `testAlterWidgetStandOhneNeueFelderLaesstSichLesen`: eine Datei mit wenigen Feldern bleibt lesbar, der Rest fehlt.
    func testAlteDateiMitWenigenFeldernLaesstSichLesen() throws {
        let ordner = try tempOrdner()
        try Data(#"{"profilName":"Alt","tag":"2026-09-22"}"#.utf8).write(to: ordner.appendingPathComponent(WidgetSnapshotDatei.name))
        let s = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: ordner))
        XCTAssertEqual(s.profilName, "Alt")
        XCTAssertNil(s.boegen)
        XCTAssertNil(s.habits)
        XCTAssertNil(s.thema)
    }

    func testUnbekanntesThemaOderFalscherWertMachtDieDateiNichtUnlesbar() throws {
        let ordner = try tempOrdner()
        let text = #"{"profilName":"Neu","thema":"zukunft","serieWochen":"vier","boegen":{"schritte":5000},"lumi":7}"#
        try Data(text.utf8).write(to: ordner.appendingPathComponent(WidgetSnapshotDatei.name))
        let s = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: ordner))
        XCTAssertEqual(s.profilName, "Neu")
        XCTAssertNil(s.thema)
        XCTAssertNil(s.serieWochen)
        XCTAssertNil(s.lumi)
        XCTAssertEqual(s.boegen?.schritte, 5_000)
    }

    func testFehlendeDateiGibtNilKeinenAbsturz() throws {
        XCTAssertNil(WidgetSnapshotDatei.lade(ordner: try tempOrdner()))
    }

    func testKaputteDateiGibtNilUndWirdGesichert() throws {
        let ordner = try tempOrdner()
        let datei = ordner.appendingPathComponent(WidgetSnapshotDatei.name)
        try Data("{ kaputt".utf8).write(to: datei)
        XCTAssertNil(WidgetSnapshotDatei.lade(ordner: ordner))
        XCTAssertTrue(FileManager.default.fileExists(atPath: datei.appendingPathExtension("defekt").path))
    }

    func testLeererSnapshotLaesstSichSchreibenUndLesen() throws {
        let ordner = try tempOrdner()
        XCTAssertTrue(WidgetSnapshotDatei.schreibe(WidgetSnapshot(), ordner: ordner))
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner), WidgetSnapshot())
    }

    /// Ohne Signierung gibt es keinen Gruppenordner: der Rückfall liefert trotzdem einen Ordner (die Widgets zeigen dann den Leerzustand).
    func testOhneGruppeGibtEsEinenOrdnerUndNichtsZuLesen() {
        XCTAssertFalse(AppGruppe.ordner().path.isEmpty)
    }
}
