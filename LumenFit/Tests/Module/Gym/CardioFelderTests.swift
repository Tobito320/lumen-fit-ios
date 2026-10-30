import SwiftUI
import XCTest
@testable import LumenFit

/// Cardio-Felder: alle Werte des Geräts kommen in den Eintrag; 0 heißt "ohne".
@MainActor
final class CardioFelderTests: XCTestCase {
    func testBindungNullIstNilUndUmgekehrt() {
        var wert: Int? = 5
        let b = CardioBindung.zahl(Binding(get: { wert }, set: { wert = $0 }))
        XCTAssertEqual(b.wrappedValue, 5)
        b.wrappedValue = 0
        XCTAssertNil(wert)
        b.wrappedValue = 12
        XCTAssertEqual(wert, 12)
        var d: Double? = nil
        let k = CardioBindung.kommazahl(Binding(get: { d }, set: { d = $0 }))
        XCTAssertEqual(k.wrappedValue, 0)
        k.wrappedValue = 2.5
        XCTAssertEqual(d, 2.5)
    }

    func testAbschliessenMitAllenGeraeteWertenUndSchrittenSchaetzung() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner(), healthSchreiben: false)
        var plan = GymTestAufbau.plan()
        let laufband = try XCTUnwrap(UebungsKatalog.alle.first { TrainingLogik.cardioGeraet($0) == "laufband" })
        plan.tage[0].uebungen.append(PlanUebung(id: "c", uebung: laufband.id, name: nil, saetze: [], minuten: 20))
        a.daten.training.planSichern(plan)
        a.sitzung.starte(planTag: "push")
        var e = CardioEintrag(datum: "", geraet: "stairmaster", minuten: 25, kcal: 200, km: 2)
        e.hoehe = 40
        e.steigung = 6
        e.kmh = 5.5
        e.stufe = 7
        a.sitzung.cardioAbschliessen(2, eintrag: e, puls: 130)
        let gespeichert = try XCTUnwrap(a.daten.training.cardio(am: Datum.text(a.uhr.lesen)).first)
        XCTAssertEqual(gespeichert.geraet, "laufband", "das Gerät kommt aus der Übung, nicht aus der Vorlage")
        XCTAssertEqual(gespeichert.hoehe, 40)
        XCTAssertEqual(gespeichert.steigung, 6)
        XCTAssertEqual(gespeichert.kmh, 5.5)
        XCTAssertEqual(gespeichert.stufe, 7)
        XCTAssertEqual(gespeichert.schritteCa, 2600)
        XCTAssertEqual(a.sitzung.cardioPuls?.puls(gespeichert.id), 130)
    }
}
