// Quelle: Lovea Tests/TrackerAkkuLogTests.swift
import XCTest
@testable import LumenFit

/// Anzeige-Regel des Akku-Werts. Die Tests zu Messpunkt, Puffer und Server-Paket entfallen mit dem Server-Teil (client-only).
final class TrackerAkkuLogTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_791_800_000)

    // MARK: Anzeige

    func testWertOhneVerbindungIstVeraltet() {
        XCTAssertTrue(TrackerAkkuLog.veraltet(gelesen: jetzt.addingTimeInterval(-60), verbunden: false, jetzt: jetzt))
    }

    func testFrischerWertBeiVerbindungIstNichtVeraltet() {
        XCTAssertFalse(TrackerAkkuLog.veraltet(gelesen: jetzt.addingTimeInterval(-10 * 60), verbunden: true, jetzt: jetzt))
    }

    func testSeltenereAbfrageDehntDieGrenzeAus() {
        // Modus Sparen fragt stündlich ab: ein Wert von vor 90 Minuten ist dann nicht veraltet, einer von vor 3 Stunden schon.
        XCTAssertFalse(TrackerAkkuLog.veraltet(gelesen: jetzt.addingTimeInterval(-90 * 60), verbunden: true, jetzt: jetzt, grenze: 2 * 3600))
        XCTAssertTrue(TrackerAkkuLog.veraltet(gelesen: jetzt.addingTimeInterval(-180 * 60), verbunden: true, jetzt: jetzt, grenze: 2 * 3600))
    }

    func testVerbundenAberSeitZweiRundenStummIstVeraltet() {
        XCTAssertFalse(TrackerAkkuLog.veraltet(gelesen: jetzt.addingTimeInterval(-20 * 60), verbunden: true, jetzt: jetzt))
        XCTAssertTrue(TrackerAkkuLog.veraltet(gelesen: jetzt.addingTimeInterval(-21 * 60), verbunden: true, jetzt: jetzt))
    }
}
