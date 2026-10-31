import XCTest
@testable import LumenFit

/// Die Übernahme aus Lovea: Dateien wandern unverändert von `<Lovea-Gruppe>/AlarmUebergabe/` nach `<Lumen-Fit-Gruppe>/LumenAlarm/uebernahme/`, nur mit Freigabe
/// (Lovea-Person laut Server, dieselbe im Manifest), nur Änderungen, Zählung zuletzt. Alles in Temp-Ordnern, Personen heißen "person-a" und "person-b".
@MainActor
final class AlarmUebernahmeTests: XCTestCase {
    private var lovea: URL!
    private var alarm: URL!
    private var quelle: URL!
    private var ziel: URL!

    override func setUp() async throws {
        lovea = try tempOrdner()
        alarm = try tempOrdner().appendingPathComponent("LumenAlarm", isDirectory: true)
        quelle = lovea.appendingPathComponent("AlarmUebergabe", isDirectory: true)
        ziel = alarm.appendingPathComponent("uebernahme", isDirectory: true)
        try FileManager.default.createDirectory(at: quelle.appendingPathComponent("toene"), withIntermediateDirectories: true)
    }

    private var dienst: AlarmUebernahme { AlarmUebernahme(loveaGruppe: lovea, alarmOrdner: alarm) }

    /// Lovea legt eine Übergabe ab: Manifest und Töne zuerst, die Zählung als Fertig-Marke zuletzt.
    private func uebergabe(person: String = "person-a", hash: String = "h1", toene: [String: String] = ["ton-1.caf": "eins"], manifestPerson: String? = nil) throws {
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: quelle.appendingPathComponent("toene").path)) ?? [] {
            try fm.removeItem(at: quelle.appendingPathComponent("toene").appendingPathComponent(name))
        }
        for (name, inhalt) in toene { try Data(inhalt.utf8).write(to: quelle.appendingPathComponent("toene").appendingPathComponent(name)) }
        try Data(#"{"version":1,"person":"\#(manifestPerson ?? person)","wecker":[]}"#.utf8).write(to: quelle.appendingPathComponent("uebergabe.json"))
        let z = #"{"version":1,"person":"\#(person)","wecker":2,"toene":\#(toene.count),"erinnerungen":3,"hash":"\#(hash)"}"#
        try Data(z.utf8).write(to: quelle.appendingPathComponent("zaehlung.json"))
    }

    private func liste(_ ordner: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: ordner.path)) ?? []).filter { !$0.hasPrefix(".") }.sorted()
    }

    func testKopiertDasManifestDieToeneUndSchreibtFitJson() throws {
        try uebergabe()
        guard case .weitergereicht(let fit) = dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt) else { return XCTFail("nichts weitergereicht") }
        XCTAssertEqual([fit.wecker, fit.toene, fit.erinnerungen], [2, 1, 3])
        XCTAssertEqual(liste(ziel), ["fit.json", "toene", "uebergabe.json", "zaehlung.json"])
        XCTAssertEqual(liste(ziel.appendingPathComponent("toene")), ["ton-1.caf"])
        XCTAssertEqual(try String(contentsOf: ziel.appendingPathComponent("toene/ton-1.caf"), encoding: .utf8), "eins")
        XCTAssertEqual(dienst.weitergereicht()?.person, "person-a")
    }

    func testFitJsonHatGenauDieFelderDesVertrags() throws {
        try uebergabe()
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        let roh = try JSONSerialization.jsonObject(with: Data(contentsOf: ziel.appendingPathComponent("fit.json"))) as? [String: Any]
        XCTAssertEqual(Set(roh?.keys.map { $0 } ?? []), ["version", "weitergereicht", "person", "wecker", "toene", "erinnerungen"])
    }

    func testOhneFreigabeWirdNichtsKopiertUndEineAlteKopieEntfernt() throws {
        try uebergabe()
        XCTAssertEqual(dienst.weitergeben(person: nil), .keineFreigabe)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ziel.path))
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ziel.path))
        XCTAssertEqual(dienst.weitergeben(person: "  "), .keineFreigabe, "leer ist keine Person")
        XCTAssertFalse(FileManager.default.fileExists(atPath: ziel.path))
    }

    func testAndereLoveaPersonImManifestKopiertNichtUndEntfernt() throws {
        try uebergabe(person: "person-b")
        XCTAssertEqual(dienst.weitergeben(person: "person-a"), .keineFreigabe)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ziel.path))
        try uebergabe(person: "person-a")
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        try uebergabe(person: "person-b", hash: "h2")
        XCTAssertEqual(dienst.weitergeben(person: "person-a"), .keineFreigabe)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ziel.path), "die Kopie der anderen Person bleibt nicht liegen")
    }

    func testPersonImManifestWeichtVonDerZaehlungAbDannSchreibtLoveaGerade() throws {
        try uebergabe(person: "person-a", manifestPerson: "person-b")
        XCTAssertEqual(dienst.weitergeben(person: "person-a"), .unvollstaendig)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ziel.appendingPathComponent("zaehlung.json").path))
    }

    func testOhneZaehlungKeineKopie() throws {
        try uebergabe()
        try FileManager.default.removeItem(at: quelle.appendingPathComponent("zaehlung.json"))
        XCTAssertEqual(dienst.weitergeben(person: "person-a"), .keineQuelle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ziel.path))
    }

    func testOhneOrdnerTutNichtsWeh() {
        let leer = AlarmUebernahme(loveaGruppe: nil, alarmOrdner: nil)
        XCTAssertEqual(leer.weitergeben(person: "person-a"), .keineQuelle)
        XCTAssertNil(leer.zeile())
    }

    func testUnveraenderteUebergabeWirdNichtNochEinmalKopiert() throws {
        try uebergabe()
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        let ton = ziel.appendingPathComponent("toene/ton-1.caf")
        let vorher = try FileManager.default.attributesOfItem(atPath: ton.path)[.creationDate] as? Date
        XCTAssertEqual(dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt.addingTimeInterval(60)), .unveraendert)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: ton.path)[.creationDate] as? Date, vorher)
        XCTAssertEqual(dienst.weitergereicht()?.weitergereicht, VerbindenTest.jetzt, "fit.json bleibt, wie sie war")
    }

    func testNurGeaenderteTraegerKommenNeuUndGeloeschteToeneVerschwinden() throws {
        try uebergabe(toene: ["ton-1.caf": "eins", "ton-2.caf": "zwei"])
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        let ton1 = ziel.appendingPathComponent("toene/ton-1.caf")
        let vorher = try FileManager.default.attributesOfItem(atPath: ton1.path)[.creationDate] as? Date
        // Neue Übergabe: ton-1 gleich, ton-2 fort, ton-3 neu.
        try uebergabe(hash: "h2", toene: ["ton-1.caf": "eins", "ton-3.caf": "drei"])
        guard case .weitergereicht(let fit) = dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt) else { return XCTFail("nichts weitergereicht") }
        XCTAssertEqual(fit.toene, 2)
        XCTAssertEqual(liste(ziel.appendingPathComponent("toene")), ["ton-1.caf", "ton-3.caf"])
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: ton1.path)[.creationDate] as? Date, vorher, "der gleiche Ton wird nicht neu kopiert")
    }

    func testDieZaehlungKommtZuletztDaZwischenzeitlichKeineFertigMarke() throws {
        try uebergabe()
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        // Lovea schreibt neu, aber noch ohne neue Zählung: die alte Zählung steht noch, die Übergabe ist schon neu.
        try uebergabe(hash: "h2", toene: ["ton-9.caf": "neun"])
        let alt = ziel.appendingPathComponent("zaehlung.json")
        XCTAssertEqual(try JSONDecoder().decode(AlarmUebernahme.Zaehlung.self, from: Data(contentsOf: alt)).hash, "h1")
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        XCTAssertEqual(try JSONDecoder().decode(AlarmUebernahme.Zaehlung.self, from: Data(contentsOf: alt)).hash, "h2")
        XCTAssertNotNil(dienst.weitergereicht())
    }

    func testEntfernenLaesstDasErgebnisVonLumenAlarmStehen() throws {
        try uebergabe()
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        try Data(#"{"version":1,"uebernommen":{"wecker":2}}"#.utf8).write(to: alarm.appendingPathComponent("uebernahme-ergebnis.json"))
        dienst.entferne()
        XCTAssertFalse(FileManager.default.fileExists(atPath: ziel.path))
        XCTAssertNotNil(dienst.ergebnis())
    }

    func testZeileNenntNurZahlenUndDasErgebnisVonLumenAlarm() throws {
        try uebergabe(toene: ["ton-1.caf": "eins"])
        XCTAssertNil(dienst.zeile(), "nichts weitergereicht")
        dienst.weitergeben(person: "person-a", jetzt: VerbindenTest.jetzt)
        XCTAssertEqual(dienst.zeile(), "Aus Lovea weitergereicht: 2 Wecker, 1 Ton, 3 Erinnerungen.")
        try Data(#"{"version":1,"uebernommen":{"wecker":1,"toene":1}}"#.utf8).write(to: alarm.appendingPathComponent("uebernahme-ergebnis.json"))
        XCTAssertEqual(dienst.zeile(), "Aus Lovea weitergereicht: 2 Wecker, 1 Ton, 3 Erinnerungen. Von Lumen Alarm übernommen: 1 Wecker, 1 Ton, 0 Erinnerungen.")
    }

    func testErgebnisIstTolerantGelesen() {
        XCTAssertNil(AlarmUebernahme.ergebnis(Data("kein json".utf8)))
        let e = AlarmUebernahme.ergebnis(Data(#"{"version":1,"schonDa":{"toene":4},"fremd":true}"#.utf8))
        XCTAssertEqual(e?.uebernommen, AlarmUebernahme.Zahlen())
        XCTAssertEqual(e?.schonDa.toene, 4)
    }
}
