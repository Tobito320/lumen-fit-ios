import XCTest
@testable import LumenFit

/// Lokaler Stand des Coachs (`coach.json`, nur auf diesem Gerät): Name, Merkliste, "Heute nicht", gemerkte Frage. Das Dateiformat ist eingefroren:
/// neue Felder machen alte Dateien nie unlesbar (`decodeIfPresent`), unbekannte Felder werden überlesen.
@MainActor
final class CoachEinstellungenTests: XCTestCase {
    private func schreibe(_ json: String, in ordner: URL) throws {
        try Data(json.utf8).write(to: ordner.appendingPathComponent("coach.json"))
    }

    func testFrischOhneDateiIstLeerUndSchreibtNichts() throws {
        let ordner = try tempOrdner()
        let e = CoachEinstellungen(ordner: ordner)
        XCTAssertEqual(e.stand, CoachLokalStand())
        XCTAssertEqual(e.anzeigeName, "Coach")
        XCTAssertFalse(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("coach.json").path), "ohne Änderung keine Datei")
    }

    func testEingefrorenesFormatAllerFelder() throws {
        let ordner = try tempOrdner()
        try schreibe(#"{"name":"Lumi","merkliste":["a","b"],"morgenUebersprungen":"2026-09-23","wartendeFrage":"Wie war mein Schlaf?"}"#, in: ordner)
        let e = CoachEinstellungen(ordner: ordner)
        XCTAssertEqual(e.stand.name, "Lumi")
        XCTAssertEqual(e.stand.merkliste, ["a", "b"])
        XCTAssertEqual(e.stand.morgenUebersprungen, "2026-09-23")
        XCTAssertEqual(e.stand.wartendeFrage, "Wie war mein Schlaf?")
    }

    func testAlteDateiOhneNeueFelderUndMitUnbekanntenFeldernBleibtLesbar() throws {
        let ordner = try tempOrdner()
        try schreibe(#"{"name":"Lumi","zukunft":{"a":1}}"#, in: ordner)
        let e = CoachEinstellungen(ordner: ordner)
        XCTAssertEqual(e.stand.name, "Lumi")
        XCTAssertEqual(e.stand.merkliste, [])
        XCTAssertNil(e.stand.morgenUebersprungen)
        XCTAssertNil(e.stand.wartendeFrage)
    }

    func testFalscheTypenGebenStandardwerteStattEinesAbsturzes() throws {
        let ordner = try tempOrdner()
        try schreibe(#"{"name":3,"merkliste":"x","morgenUebersprungen":7,"wartendeFrage":[]}"#, in: ordner)
        XCTAssertEqual(CoachEinstellungen(ordner: ordner).stand, CoachLokalStand())
    }

    func testDefekteDateiWirdGesichertUndDerStandStartetLeer() throws {
        let ordner = try tempOrdner()
        try schreibe("das ist kein json", in: ordner)
        XCTAssertEqual(CoachEinstellungen(ordner: ordner).stand, CoachLokalStand())
        XCTAssertTrue(FileManager.default.fileExists(atPath: ordner.appendingPathComponent("coach.json.defekt").path), "die kaputte Datei bleibt als .defekt erhalten")
    }

    func testAenderungenUeberlebenDenNeustart() throws {
        let ordner = try tempOrdner()
        let e = CoachEinstellungen(ordner: ordner)
        e.setzeName("  „Lumi“  [[x]] ")
        e.merkeAntwort("n1", an: true)
        e.merkeAntwort("n2", an: true)
        e.ueberspringeMorgen(tag: "2026-09-23")
        e.merkeFrage("Wie war mein Schlaf?")

        let neu = CoachEinstellungen(ordner: ordner)
        XCTAssertEqual(neu.stand.name, "Lumi x")
        XCTAssertEqual(neu.stand.merkliste, ["n1", "n2"])
        XCTAssertEqual(neu.stand.morgenUebersprungen, "2026-09-23")
        XCTAssertEqual(neu.stand.wartendeFrage, "Wie war mein Schlaf?")

        neu.merkeFrage(nil)
        neu.merkeAntwort("n1", an: false)
        XCTAssertNil(CoachEinstellungen(ordner: ordner).stand.wartendeFrage)
        XCTAssertEqual(CoachEinstellungen(ordner: ordner).stand.merkliste, ["n2"])
    }

    func testMerklisteBegrenztAufFuenfzigUndDerAelteresteFaelltWeg() {
        let e = CoachEinstellungen()
        for i in 0..<(CoachEinstellungen.maxMerkliste + 5) { e.merkeAntwort("n\(i)", an: true) }
        XCTAssertEqual(e.stand.merkliste.count, 50)
        XCTAssertFalse(e.istGemerkt("n0"))
        XCTAssertTrue(e.istGemerkt("n54"))
    }

    func testOhneOrdnerNurImSpeicher() {
        let e = CoachEinstellungen()
        e.merkeFrage("x")
        XCTAssertEqual(e.stand.wartendeFrage, "x")
    }
}
