import XCTest
@testable import LumenFit

/// Die App übernimmt die Tipps aus dem Widget: nur für das aktive Profil, genau einmal (Op-Id), ohne einen währenddessen angekommenen Tipp zu verlieren.
@MainActor
final class WidgetOpsImportTests: XCTestCase {
    private let uhr = TestUhr()
    private var heute: String { Datum.text(uhr.lesen) }

    private struct Aufbau {
        let ordner: URL
        let umgebung: AppUmgebung
        let daten: DatenSatz
        var datei: URL { WidgetOpsDatei.url(ordner: ordner) }
    }

    private func aufbau() throws -> Aufbau {
        let ordner = try tempOrdner()
        let u = try WidgetsTestUmgebung.neu(ordner: ordner, uhr: uhr)
        return Aufbau(ordner: ordner, umgebung: u, daten: try XCTUnwrap(u.daten))
    }

    private func tipp(_ id: String, profil: String, habit: String = "wasser", wert: Int? = 4, zeit: Date? = nil) -> WidgetHabitOp {
        WidgetHabitOp(opId: id, profil: profil, habit: habit, tag: "2026-09-23", wert: wert, zeit: zeit ?? uhr.lesen)
    }

    @discardableResult
    private func uebernimm(_ a: Aufbau) -> [String] {
        WidgetOpsImport.uebernimm(ordner: a.ordner, profil: a.daten.profil, raum: a.daten.raum, jetzt: uhr.lesen)
    }

    func testTippWirdZurHabitOpUndDieDateiIstDanachLeer() throws {
        let a = try aufbau()
        WidgetOpsDatei.haengeAn(tipp("t1", profil: a.daten.profil.rawValue), an: a.datei)
        XCTAssertEqual(uebernimm(a), ["2026-09-23"])
        XCTAssertEqual(a.daten.habits.wert("wasser", "2026-09-23"), 4)
        let ops = a.daten.raum.ops(arten: ["habit.setzen"])
        XCTAssertEqual(ops.map(\.id), ["t1"], "die Op-Id des Tipps bleibt erhalten")
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.datei.path))
        XCTAssertEqual(uebernimm(a), [], "zweiter Lauf: nichts mehr da")
    }

    func testDoppelteOpIdWirdUebersprungen() throws {
        let a = try aufbau()
        let kennung = a.daten.profil.rawValue
        WidgetOpsDatei.haengeAn(tipp("gleich", profil: kennung, wert: 2), an: a.datei)
        WidgetOpsDatei.haengeAn(tipp("gleich", profil: kennung, wert: 7), an: a.datei)
        uebernimm(a)
        // Eine liegen gebliebene Lese-Datei mit derselben Op (Abbruch nach dem Einreihen) zählt auch nicht doppelt.
        WidgetOpsDatei.haengeAn(tipp("gleich", profil: kennung, wert: 2), an: a.ordner.appendingPathComponent("\(WidgetOpsImport.leseVorsilbe)alt.jsonl"))
        uebernimm(a)
        XCTAssertEqual(a.daten.raum.ops(arten: ["habit.setzen"]).count, 1)
        XCTAssertEqual(a.daten.habits.wert("wasser", "2026-09-23"), 2, "die erste Fassung gewinnt")
    }

    func testTippFuerEinFremdesProfilWirdUebersprungenUndBleibtLiegen() throws {
        let a = try aufbau()
        WidgetOpsDatei.haengeAn(tipp("fremd", profil: "anderes-profil"), an: a.datei)
        WidgetOpsDatei.haengeAn(tipp("eigen", profil: a.daten.profil.rawValue, habit: "gym", wert: 1), an: a.datei)
        XCTAssertEqual(uebernimm(a), ["2026-09-23"])
        XCTAssertEqual(a.daten.raum.ops(arten: ["habit.setzen"]).map(\.id), ["eigen"])
        XCTAssertEqual(WidgetOpsDatei.lies(a.datei).map(\.opId), ["fremd"], "für das andere Profil bleibt der Tipp bis zu dessen Anmeldung")
    }

    func testEinAlterTippFuerEinFremdesProfilWirdVerworfen() throws {
        let a = try aufbau()
        let alt = uhr.lesen.addingTimeInterval(-8 * 24 * 3600)
        WidgetOpsDatei.haengeAn(tipp("uralt", profil: "anderes-profil", zeit: alt), an: a.datei)
        uebernimm(a)
        XCTAssertEqual(WidgetOpsDatei.lies(a.datei), [])
    }

    func testLiegengebliebeneLeseDateiWirdNachgeholt() throws {
        let a = try aufbau()
        let lese = a.ordner.appendingPathComponent("\(WidgetOpsImport.leseVorsilbe)liegt.jsonl")
        WidgetOpsDatei.haengeAn(tipp("rest", profil: a.daten.profil.rawValue, wert: 3), an: lese)
        XCTAssertEqual(uebernimm(a), ["2026-09-23"])
        XCTAssertEqual(a.daten.habits.wert("wasser", "2026-09-23"), 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: lese.path))
    }

    func testKaputteZeilenUndFehlendeDateiSindKeinProblem() throws {
        let a = try aufbau()
        XCTAssertEqual(uebernimm(a), [])
        try Data("{ kaputt\nnoch eine\n".utf8).write(to: a.datei)
        XCTAssertEqual(uebernimm(a), [])
        XCTAssertTrue(a.daten.raum.ops(arten: ["habit.setzen"]).isEmpty)
    }

    func testTippOhneWertHakeltAbUndNegativeWerteWerdenZuNull() throws {
        let a = try aufbau()
        let kennung = a.daten.profil.rawValue
        WidgetOpsDatei.haengeAn(tipp("ohne", profil: kennung, habit: "gym", wert: nil), an: a.datei)
        WidgetOpsDatei.haengeAn(tipp("minus", profil: kennung, habit: "wasser", wert: -3), an: a.datei)
        uebernimm(a)
        XCTAssertEqual(a.daten.habits.wert("gym", "2026-09-23"), 1)
        XCTAssertEqual(a.daten.habits.wert("wasser", "2026-09-23"), 0)
    }

    /// Die Laufzeit meldet danach `habitGeaendert` und übernimmt beim Vordergrund.
    func testVordergrundUebernimmtDieTippsUndMeldetDasEreignis() async throws {
        let ordner = try tempOrdner()
        let u = try WidgetsTestUmgebung.neu(ordner: ordner, uhr: uhr)
        let daten = try XCTUnwrap(u.daten)
        WidgetsModul.start(u, senke: WidgetsTestSenke(), fabrik: WidgetsTestFabrik(), neuladen: {})
        let laufzeit = try XCTUnwrap(WidgetsModul.laufzeit(u))
        let strom = u.ereignisse.strom()
        WidgetOpsDatei.haengeAn(tipp("vg", profil: daten.profil.rawValue, wert: 5), an: WidgetOpsDatei.url(ordner: ordner))
        await laufzeit.verarbeite(.vordergrund)
        XCTAssertEqual(daten.habits.wert("wasser", "2026-09-23"), 5)
        var gesehen: String?
        for await ereignis in strom {
            if case .habitGeaendert(let tag) = ereignis { gesehen = tag; break }
        }
        XCTAssertEqual(gesehen, "2026-09-23")
    }
}
