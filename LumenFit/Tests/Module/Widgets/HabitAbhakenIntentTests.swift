import XCTest
@testable import LumenFit

/// Der Haken im Widget schreibt nur Dateien in die Gruppe (hier ein Temp-Ordner, `containerURL` ist in Tests nil); die App übernimmt sie später (`WidgetOpsImportTests`).
/// Dazu die portierten Lovea-Tests der wartenden Ops (`WidgetPendingMerge`).
final class HabitAbhakenIntentTests: XCTestCase {
    private func op(_ id: String, wert: Int? = 1, profil: String = "p1") -> WidgetHabitOp {
        WidgetHabitOp(opId: id, profil: profil, habit: "gym", tag: "2026-09-23", wert: wert, zeit: Date(timeIntervalSince1970: 1_790_157_600))
    }

    func testAbhakenHaengtEineZeileAnUndZeigtDenHakenSofort() throws {
        let ordner = try tempOrdner()
        var snapshot = WidgetSnapshot.beispiel(jetzt: TestUhr().lesen)
        snapshot.profilKennung = "p1"
        WidgetSnapshotDatei.schreibe(snapshot, ordner: ordner)

        XCTAssertTrue(WidgetHabitAktion.abhaken(habit: "gym", wert: 1, tag: "2026-09-23", profil: "p1", ordner: ordner))

        let ops = WidgetOpsDatei.lies(WidgetOpsDatei.url(ordner: ordner))
        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(ops.first?.habit, "gym")
        XCTAssertEqual(ops.first?.wert, 1)
        XCTAssertEqual(ops.first?.profil, "p1")
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.habits?.first { $0.id == "gym" }?.heute, 1, "Vorab-Anzeige im Snapshot")
    }

    func testAbhakenOhneSnapshotSchreibtNurDieOp() throws {
        let ordner = try tempOrdner()
        XCTAssertTrue(WidgetHabitAktion.abhaken(habit: "wasser", wert: 6, tag: "2026-09-23", profil: "p1", ordner: ordner))
        XCTAssertEqual(WidgetOpsDatei.lies(WidgetOpsDatei.url(ordner: ordner)).count, 1)
        XCTAssertNil(WidgetSnapshotDatei.lade(ordner: ordner))
    }

    func testVorabAnzeigeNurFuerGleichenTagUndGleichesProfil() throws {
        let ordner = try tempOrdner()
        var snapshot = WidgetSnapshot.beispiel(jetzt: TestUhr().lesen)
        snapshot.profilKennung = "p1"
        WidgetSnapshotDatei.schreibe(snapshot, ordner: ordner)
        WidgetHabitAktion.abhaken(habit: "gym", wert: 1, tag: "2026-09-22", profil: "p1", ordner: ordner)
        WidgetHabitAktion.abhaken(habit: "gym", wert: 1, tag: "2026-09-23", profil: "fremd", ordner: ordner)
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.habits?.first { $0.id == "gym" }?.heute, 0)
        XCTAssertEqual(WidgetOpsDatei.lies(WidgetOpsDatei.url(ordner: ordner)).count, 2, "die Tipps selbst gehen trotzdem in die Datei")
    }

    func testMehrereTippsBleibenInReihenfolge() throws {
        let ordner = try tempOrdner()
        let datei = WidgetOpsDatei.url(ordner: ordner)
        for i in 1...3 { XCTAssertTrue(WidgetOpsDatei.haengeAn(op("op-\(i)", wert: i), an: datei)) }
        XCTAssertEqual(WidgetOpsDatei.lies(datei).map(\.opId), ["op-1", "op-2", "op-3"])
        XCTAssertEqual(WidgetOpsDatei.lies(datei).map(\.wert), [1, 2, 3])
    }

    func testKaputteZeileWirdUebersprungen() throws {
        let ordner = try tempOrdner()
        let datei = WidgetOpsDatei.url(ordner: ordner)
        WidgetOpsDatei.haengeAn(op("a"), an: datei)
        let handle = try FileHandle(forUpdating: datei)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{ halb\n".utf8))
        try handle.close()
        WidgetOpsDatei.haengeAn(op("b"), an: datei)
        XCTAssertEqual(WidgetOpsDatei.lies(datei).map(\.opId), ["a", "b"])
    }

    func testFehlendeDateiIstLeer() throws {
        XCTAssertEqual(WidgetOpsDatei.lies(WidgetOpsDatei.url(ordner: try tempOrdner())), [])
    }

    func testDerAnstossHatEinenFestenNamen() {
        XCTAssertEqual(WidgetAnstoss.name, "com.onlyus.lumen-fit.widget-ops")
    }

    // MARK: - Portiert: WidgetPendingMerge (Lovea)

    func testEindeutigBehaeltJedeIdNurEinmal() {
        let a = op("1", wert: 1)
        let aErneut = op("1", wert: 0)
        let b = op("2", wert: 1)
        let ergebnis = WidgetOpsMerge.eindeutig([a, aErneut, b])
        XCTAssertEqual(ergebnis.map(\.opId), ["1", "2"])
        // Die erste Fassung gewinnt: ein zweiter Lesevorgang vor dem Löschen darf die schon eingereihte Op nicht ersetzen.
        XCTAssertEqual(ergebnis.first?.wert, 1)
    }

    func testAlteZeileOhneWertUndZeitLaesstSichLesen() throws {
        let alt = Data(#"{"opId":"1","profil":"p1","habit":"gym","tag":"2026-09-23"}"#.utf8)
        let op = try JSONDecoder().decode(WidgetHabitOp.self, from: alt)
        XCTAssertNil(op.wert)
        XCTAssertNil(op.zeit)
        XCTAssertEqual(op.id, "1")
    }

    func testEindeutigMitLeererListe() {
        XCTAssertEqual(WidgetOpsMerge.eindeutig([]), [])
    }
}
