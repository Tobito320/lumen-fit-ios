// Quelle: Lovea Tests/TrackerEnergieTests.swift
import XCTest
@testable import LumenFit

/// Energiesparen ist ein Schalter (W-030) und setzt den Abstand der Puls-Dauermessung, den einzigen, den das Protokoll kennt.
final class TrackerEnergieTests: XCTestCase {
    func testAbstandAbWerkIstAus() {
        XCTAssertFalse(TrackerEnergie.an(minuten: 10))
    }

    func testSeltenerAlsAbWerkIstAn() {
        for minuten in [15, 30, 45, 60] {
            XCTAssertTrue(TrackerEnergie.an(minuten: minuten), "\(minuten) Minuten")
        }
    }

    func testFruehererDichterAbstandIstAus() {
        XCTAssertFalse(TrackerEnergie.an(minuten: 5))
        XCTAssertTrue(TrackerEnergie.erklaerung(minuten: 5).contains("alle 5 Minuten"), "der Satz nennt, was der Tracker wirklich hat")
    }

    func testSchalterSchreibtDreissigOderZehn() {
        XCTAssertEqual(TrackerEnergie.minuten(an: true), 30)
        XCTAssertEqual(TrackerEnergie.minuten(an: false), 10)
    }

    func testWasDerSchalterSchreibtLiestSichWiederAlsDerselbeZustand() {
        for an in [true, false] {
            XCTAssertEqual(TrackerEnergie.an(minuten: TrackerEnergie.minuten(an: an)), an)
        }
    }

    func testErklaerungNenntDenAbstandDesTrackers() {
        XCTAssertTrue(TrackerEnergie.erklaerung(minuten: 45).contains("alle 45 Minuten"))
        XCTAssertTrue(TrackerEnergie.erklaerung(minuten: 10).contains("alle 10 Minuten"))
    }
}
