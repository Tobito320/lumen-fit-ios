// Quelle: Lovea Tests/TrackerModusTests.swift
import XCTest
@testable import LumenFit

/// Tracker-Modus "Sparen" und "Viele Daten": die Tabelle (welcher Befehl, welcher Wert), was am Tracker noch abweicht und was Lumen Fit
/// nach einem Versuch nicht noch einmal schreibt. Reine Logik, ohne Gerät.
final class TrackerModusTests: XCTestCase {
    // MARK: Tabelle

    func testSparenMisstSeltenUndSchaltetDieAutomatikAus() {
        XCTAssertEqual(TrackerModus.sparen.aenderungen, [
            .puls(an: true, minuten: 30),
            .messung(.spo2, an: false),
            .messung(.stress, an: false),
            .messung(.hrv, an: false),
        ])
    }

    func testVieleDatenMisstDichtUndSchaltetAllesAn() {
        XCTAssertEqual(TrackerModus.daten.aenderungen, [
            .puls(an: true, minuten: 5),
            .messung(.spo2, an: true),
            .messung(.stress, an: true),
            .messung(.hrv, an: true),
        ])
    }

    func testSparAbstandKommtAusTrackerEnergie() {
        XCTAssertEqual(TrackerModus.sparen.pulsMinuten, TrackerEnergie.sparMinuten)
        XCTAssertLessThan(TrackerModus.daten.pulsMinuten, TrackerEnergie.standardMinuten)
    }

    func testBeideModiNutzenNurSchreibbefehleDieDasProtokollBelegt() {
        let erlaubt: Set<UInt8> = [0x16, 0x2C, 0x36, 0x38]
        for modus in TrackerModus.allCases {
            for aenderung in modus.aenderungen {
                XCTAssertTrue(erlaubt.contains([UInt8](aenderung.schreiben)[0]), "\(modus) schreibt \(aenderung)")
            }
        }
    }

    func testPulsAbstandDerModiIstWaehlbar() {
        for modus in TrackerModus.allCases {
            XCTAssertTrue(TrackerModus.pulsAbstaende.contains(modus.pulsMinuten), "\(modus)")
        }
    }

    func testSparenFragtSeltenerAbAlsVieleDatenUndAlsOhneModus() {
        XCTAssertGreaterThan(TrackerModus.sparen.abfrageAbstand, TrackerModus.standardAbstand)
        XCTAssertLessThanOrEqual(TrackerModus.daten.abfrageAbstand, TrackerModus.standardAbstand)
    }

    /// Die Am-Arm-Erkennung (`TrackerArm`) lässt den letzten Puls zwei Abstände plus fünf Minuten gelten. Fragt die App seltener ab,
    /// sähe sie nie einen frischen Puls und das Band gälte als unbekannt.
    func testAbfrageAbstandPasstInDasFensterDerAmArmErkennung() {
        for modus in TrackerModus.allCases {
            let fenster = TimeInterval((2 * modus.pulsMinuten + 5) * 60)
            XCTAssertLessThanOrEqual(modus.abfrageAbstand, fenster, "\(modus)")
        }
    }

    // MARK: Abweichung

    func testPasstDerTrackerZumModusGibtEsNichtsZuSchreiben() {
        let puls = TrackerProtokoll.PulsEinstellung(an: true, intervallMinuten: 30)
        let aus: [TrackerProtokoll.Dauermessung: Bool] = [.spo2: false, .stress: false, .hrv: false]
        XCTAssertEqual(TrackerModus.sparen.abweichungen(puls: puls, messungen: aus), [])
    }

    func testNurWasAbweichtWirdGeschrieben() {
        let puls = TrackerProtokoll.PulsEinstellung(an: true, intervallMinuten: 10)
        let messungen: [TrackerProtokoll.Dauermessung: Bool] = [.spo2: true, .stress: true, .hrv: false]
        XCTAssertEqual(TrackerModus.daten.abweichungen(puls: puls, messungen: messungen), [
            .puls(an: true, minuten: 5),
            .messung(.hrv, an: true),
        ])
    }

    func testAusgeschalteterPulsWirdBeiBeidenModiEingeschaltet() {
        let puls = TrackerProtokoll.PulsEinstellung(an: false, intervallMinuten: 30)
        let aus: [TrackerProtokoll.Dauermessung: Bool] = [.spo2: false, .stress: false, .hrv: false]
        XCTAssertEqual(TrackerModus.sparen.abweichungen(puls: puls, messungen: aus), [.puls(an: true, minuten: 30)])
    }

    func testUngelesenerStandWirdGeschriebenNichtGeraten() {
        XCTAssertEqual(TrackerModus.sparen.abweichungen(puls: nil, messungen: [:]), TrackerModus.sparen.aenderungen)
    }

    func testEinVersuchWirdNichtWiederholt() {
        let puls = TrackerProtokoll.PulsEinstellung(an: true, intervallMinuten: 10)
        let aus: [TrackerProtokoll.Dauermessung: Bool] = [.spo2: false, .stress: false, .hrv: false]
        let erster = TrackerModus.sparen.offene(puls: puls, messungen: aus, versucht: [])
        XCTAssertEqual(erster, [.puls(an: true, minuten: 30)])
        // Der Tracker hat den Abstand nicht übernommen: beim zweiten Blick ist er versucht und bleibt es.
        XCTAssertEqual(TrackerModus.sparen.offene(puls: puls, messungen: aus, versucht: erster), [])
    }

    // MARK: Texte

    func testAbfrageText() {
        XCTAssertEqual(TrackerModus.abfrageText(nil), "alle 10 Minuten")
        XCTAssertEqual(TrackerModus.abfrageText(.daten), "alle 10 Minuten")
        XCTAssertEqual(TrackerModus.abfrageText(.sparen), "alle 60 Minuten")
    }

    func testStatusOhneModusAendertNichts() {
        let text = TrackerModus.status(modus: nil, offen: false, verbunden: true, gelesen: true, abweichungen: [])
        XCTAssertTrue(text.contains("nichts"))
    }

    func testStatusOffenJeNachVerbindung() {
        XCTAssertTrue(TrackerModus.status(modus: .sparen, offen: true, verbunden: true, gelesen: true, abweichungen: []).contains("gerade"))
        XCTAssertTrue(TrackerModus.status(modus: .sparen, offen: true, verbunden: false, gelesen: false, abweichungen: []).contains("verbunden"))
    }

    func testStatusNenntWasAbweicht() {
        let text = TrackerModus.status(modus: .daten, offen: false, verbunden: true, gelesen: true,
                                       abweichungen: [.puls(an: true, minuten: 5), .messung(.hrv, an: true)])
        XCTAssertTrue(text.contains("Puls"), text)
        XCTAssertTrue(text.contains("HRV"), text)
    }

    func testStatusPasstWennNichtsAbweicht() {
        let text = TrackerModus.status(modus: .daten, offen: false, verbunden: true, gelesen: true, abweichungen: [])
        XCTAssertTrue(text.contains("hat die Einstellungen"), text)
    }

    func testStatusUngelesenBehauptetNichts() {
        // Noch nie gelesen: "weicht ab" wäre geraten.
        let text = TrackerModus.status(modus: .sparen, offen: false, verbunden: false, gelesen: false,
                                       abweichungen: TrackerModus.sparen.aenderungen)
        XCTAssertFalse(text.contains("weicht"), text)
    }
}
