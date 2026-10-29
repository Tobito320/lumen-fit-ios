// Quelle: Lovea Tests/ZieleBefragungTests.swift (die sieben Lovea-Tests unverändert, dazu zwei für das Speichern)
import XCTest
@testable import LumenFit

final class ZieleBefragungTests: XCTestCase {
    func testPoUndHaltung() {
        let r = ZieleLogik.rechnen(ziele: ["po", "haltung"], tageProWoche: 3)
        XCTAssertEqual(r.prio.first, .beine)
        XCTAssertEqual(r.prio.count, 5)
        XCTAssertEqual(r.saetze[.beine], 14)
    }

    func testReihenfolgeOhneDoppelte() {
        let r = ZieleLogik.rechnen(ziele: ["po", "haltung"], tageProWoche: 3)
        XCTAssertEqual(r.prio, [.beine, .bauch, .ruecken, .schulter, .brust])
        XCTAssertEqual(r.saetze[.bauch], 14)
        XCTAssertEqual(r.saetze[.ruecken], 10)
        XCTAssertEqual(r.saetze[.brust], 10)
    }

    func testKeineAuswahlFuelltMitStandard() {
        let r = ZieleLogik.rechnen(ziele: [], tageProWoche: 3)
        XCTAssertEqual(r.prio, [.beine, .ruecken, .schulter, .bauch, .brust])
        XCTAssertEqual(r.saetze[.beine], 14)
        XCTAssertEqual(r.saetze[.ruecken], 14)
        XCTAssertEqual(r.saetze[.schulter], 10)
    }

    func testAlleGruppenHabenEinenSatzwert() {
        let r = ZieleLogik.rechnen(ziele: ["stark"], tageProWoche: 3)
        XCTAssertEqual(r.saetze.count, MuskelGruppe.allCases.count)
        XCTAssertEqual(r.saetze[.nacken], 6)
        XCTAssertEqual(r.saetze[.bizeps], 6)
    }

    func testZweiTage() {
        let r = ZieleLogik.rechnen(ziele: ["straff"], tageProWoche: 2)
        XCTAssertEqual(r.saetze[.beine], 12)
        XCTAssertEqual(r.saetze[.ruecken], 12)
        XCTAssertEqual(r.saetze[.schulter], 10)
    }

    func testFuenfTage() {
        let r = ZieleLogik.rechnen(ziele: ["stark"], tageProWoche: 5)
        XCTAssertEqual(r.saetze[.beine], 16)
        XCTAssertEqual(r.saetze[.ruecken], 16)
        XCTAssertEqual(r.saetze[.brust], 10)
    }

    func testUnbekannteZieleWerdenIgnoriert() {
        let r = ZieleLogik.rechnen(ziele: ["quatsch"], tageProWoche: 4)
        XCTAssertEqual(r.prio, [.beine, .ruecken, .schulter, .bauch, .brust])
    }

    @MainActor
    func testSpeichernSchreibtRangUndSaetzeAlsOps() throws {
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: .testA)
        XCTAssertNil(ZieleLogik.gespeichert(in: raum))
        let r = ZieleLogik.rechnen(ziele: ["po", "haltung"], tageProWoche: 3)
        ZieleLogik.speichern(prio: r.prio, saetze: r.saetze, in: raum)
        XCTAssertEqual(raum.ops(arten: ["einstellung.setzen"]).count, MuskelGruppe.allCases.count * 2)
        XCTAssertEqual(ZieleLogik.gespeichert(in: raum), [.beine, .bauch, .ruecken, .schulter, .brust])
    }

    @MainActor
    func testEineNeueBefragungUeberschreibtDieAlte() throws {
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: .testA)
        let erste = ZieleLogik.rechnen(ziele: ["po"], tageProWoche: 3)
        ZieleLogik.speichern(prio: erste.prio, saetze: erste.saetze, in: raum)
        let zweite = ZieleLogik.rechnen(ziele: ["haltung"], tageProWoche: 4)
        ZieleLogik.speichern(prio: zweite.prio, saetze: zweite.saetze, in: raum)
        XCTAssertEqual(ZieleLogik.gespeichert(in: raum), zweite.prio)
    }
}
