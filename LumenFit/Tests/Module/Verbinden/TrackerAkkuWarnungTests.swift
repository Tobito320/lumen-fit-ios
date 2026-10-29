// Quelle: Lovea Tests/TrackerAkkuWarnungTests.swift
import XCTest
@testable import LumenFit

/// Wann der Tracker-Akku eine Warnung auslöst.
final class TrackerAkkuWarnungTests: XCTestCase {
    func testWarntEinmalUnterDerGrenze() {
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 15, laedt: false, gewarnt: false), .warnen)
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 10, laedt: false, gewarnt: true), .nichts)
    }

    func testDarueberKeineWarnung() {
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 16, laedt: false, gewarnt: false), .nichts)
    }

    func testLadenOderErholenLoeschtDasMerken() {
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 5, laedt: true, gewarnt: true), .vergessen)
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 30, laedt: false, gewarnt: true), .vergessen)
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 80, laedt: false, gewarnt: false), .nichts)
    }

    func testZwischenGrenzeUndErholungBleibtDasMerken() {
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 20, laedt: false, gewarnt: true), .nichts)
    }

    func testLaedtUnterDerGrenzeWarntNicht() {
        XCTAssertEqual(TrackerAkkuWarnung.schritt(prozent: 5, laedt: true, gewarnt: false), .nichts)
    }
}

/// Wann Lumen Fit glaubt, dass der Tracker lädt. Das Ladebit (Byte 2) ist nur nach der Referenz belegt, der echte
/// Mitschnitt zeigt es nicht beim Laden; darum zählt zusätzlich, was sich aus dem Verlauf ableiten lässt.
final class TrackerLadenTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_791_800_000)

    private func urteil(prozent: Int, byte: Bool = false, vorher: Int? = nil, vorMinuten: Double = 10,
                        abgelegt: Bool = false) -> TrackerLaden.Urteil {
        TrackerLaden.urteil(prozent: prozent, byteLaedt: byte,
                            vorher: vorher.map { (prozent: $0, zeit: jetzt.addingTimeInterval(-vorMinuten * 60)) },
                            jetzt: jetzt, abgelegt: abgelegt)
    }

    func testLadebitGilt() {
        XCTAssertEqual(urteil(prozent: 50, byte: true), .laedt)
    }

    func testSteigenderAkkuIstVermutlichLaden() {
        XCTAssertEqual(urteil(prozent: 52, vorher: 50), .vermutlich)
        XCTAssertEqual(urteil(prozent: 51, vorher: 50), .nein)
        XCTAssertEqual(urteil(prozent: 50, vorher: 50), .nein)
        XCTAssertEqual(urteil(prozent: 48, vorher: 50), .nein)
    }

    func testAlterVergleichWirdIgnoriert() {
        XCTAssertEqual(urteil(prozent: 90, vorher: 20, vorMinuten: 31), .nein)
        XCTAssertEqual(urteil(prozent: 90, vorher: 20, vorMinuten: 30), .vermutlich)
    }

    func testHundertZweimalNurBeiAbgelegtemBand() {
        XCTAssertEqual(urteil(prozent: 100, vorher: 100, abgelegt: true), .vermutlich)
        XCTAssertEqual(urteil(prozent: 100, vorher: 100, abgelegt: false), .nein)
        XCTAssertEqual(urteil(prozent: 99, vorher: 99, abgelegt: true), .nein)
    }

    func testErsteMessungOhneVergleichIstNein() {
        XCTAssertEqual(urteil(prozent: 100, vorher: nil, abgelegt: true), .nein)
    }
}
