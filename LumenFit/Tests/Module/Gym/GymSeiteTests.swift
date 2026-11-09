import SwiftUI
import XCTest
@testable import LumenFit

/// Der Gym-Tab: Wahl der Seite, ein laufendes Training übersteht den Seitenwechsel, getippte Werte.
@MainActor
final class GymSeiteTests: XCTestCase {
    func testLaufendesTrainingZeigtDieLaufSeite() {
        XCTAssertEqual(GymSeite.wahl(bereich: .training, laeuft: true), .lauf)
    }

    func testOhneTrainingGiltDieStartseite() {
        XCTAssertEqual(GymSeite.wahl(bereich: .training, laeuft: false), .start)
    }

    func testPlanUndFortschrittFolgenDemBereich() {
        for laeuft in [false, true] {
            XCTAssertEqual(GymSeite.wahl(bereich: .plaene, laeuft: laeuft), .plan)
            XCTAssertEqual(GymSeite.wahl(bereich: .fortschritt, laeuft: laeuft), .fortschritt)
        }
    }

    func testDasTrainingUeberstehtDenSeitenwechsel() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        let sid = a.sitzung.sessionId
        let pause = a.sitzung.pause
        XCTAssertNotNil(sid)
        // Die Seite wechselt (Training, Pläne, Training): dieselbe Sitzung, dieselbe Pause, dasselbe Training.
        for bereich in [GymBereich.training, .plaene, .training] {
            _ = GymSeite.wahl(bereich: bereich, laeuft: a.sitzung.sessionId != nil)
            XCTAssertEqual(a.sitzung.sessionId, sid)
            XCTAssertEqual(a.sitzung.pause, pause)
            XCTAssertEqual(a.sitzung.liste[0].saetze[0].ok, true)
        }
        XCTAssertEqual(a.daten.training.sessions.count, 1)
    }

    func testGetippteWerteGehenInDieZeileUndWerdenBeimSichernGesendet() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        a.sitzung.werteSetzen(0, 1, kg: 72.5, wdh: 6)
        XCTAssertEqual(a.sitzung.liste[0].saetze[1].kg, 72.5)
        XCTAssertEqual(a.sitzung.liste[0].saetze[1].wdh, 6)
        a.sitzung.uebungSichern(0)
        XCTAssertEqual(a.daten.training.laufende()?.laeufe.first?.stand?[1].kg, 72.5)
    }

    func testWerteSetzenBegrenztUndLaesstUngueltigeIndizesUnberuehrt() {
        let zeilen = [PlanSatz(wdh: 8, kg: 60, failure: false)]
        XCTAssertNil(LetztesMal.setzeWerte(zeilen, 0, kg: 0, wdh: 8)[0].kg, "0 heißt ohne Gewicht")
        XCTAssertEqual(LetztesMal.setzeWerte(zeilen, 0, kg: 900, wdh: 8)[0].kg, LetztesMal.kgMaximum)
        XCTAssertEqual(LetztesMal.setzeWerte(zeilen, 0, kg: 60, wdh: -3)[0].wdh, 0)
        XCTAssertEqual(LetztesMal.setzeWerte(zeilen, 0, kg: 60, wdh: 500)[0].wdh, 100)
        XCTAssertEqual(LetztesMal.setzeWerte(zeilen, 4, kg: 10, wdh: 5), zeilen)
    }
}
