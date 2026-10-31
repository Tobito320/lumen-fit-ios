import XCTest
@testable import LumenFit

/// Die Rückfragen beim Beenden im Lovea-Aufbau: Reihenfolge, wann welche kommt, Endzeit ändern, freier Tag.
@MainActor
final class BeendenAblaufTests: XCTestCase {
    func testDieReihenfolgeIstZeitDannPlanDannFreierTag() {
        XCTAssertEqual(BeendenAblauf.ersterSchritt(zuLang: true, planFrage: true, freiFrage: false), .zeitFrage)
        XCTAssertEqual(BeendenAblauf.ersterSchritt(zuLang: false, planFrage: true, freiFrage: false), .planFrage)
        XCTAssertEqual(BeendenAblauf.ersterSchritt(zuLang: false, planFrage: false, freiFrage: true), .freiFrage)
        XCTAssertEqual(BeendenAblauf.ersterSchritt(zuLang: false, planFrage: false, freiFrage: false), .beenden)
        XCTAssertEqual(BeendenAblauf.weiter(planFrage: true, freiFrage: true), .planFrage, "Plan hat Vorrang, beide gleichzeitig gibt es nie")
        XCTAssertEqual(BeendenAblauf.weiter(planFrage: false, freiFrage: false), .beenden)
    }

    func testOhneAenderungUndKurzFragtNichts() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        a.uhr.vor(sekunden: 3600)
        XCTAssertEqual(a.sitzung.ersterBeendenSchritt(), .beenden)
    }

    func testUeberDreiStundenFragtErstNachDerZeit() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        a.sitzung.satzDazu(0)
        a.uhr.vor(sekunden: 3 * 3600 + 120)
        XCTAssertEqual(a.sitzung.ersterBeendenSchritt(), .zeitFrage)
        XCTAssertEqual(a.sitzung.naechsterBeendenSchritt(), .planFrage, "nach \"Ja, stimmt\" kommt die Plan-Frage")
    }

    func testGeaenderterAufbauFragtNachDemPlan() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        a.sitzung.satzDazu(0)
        XCTAssertTrue(a.sitzung.planFrageNoetig)
        XCTAssertEqual(a.sitzung.ersterBeendenSchritt(), .planFrage)
        let vorher = a.daten.training.plan.tage[0].uebungen[0].saetze.count
        a.sitzung.planAktualisieren()
        a.sitzung.beende()
        XCTAssertEqual(a.daten.training.plan.tage[0].uebungen[0].saetze.count, vorher + 1)
        XCTAssertNil(a.sitzung.sessionId)
    }

    func testOhnePlantagFragtNachDemFreienTagUndOrdnetDieEinheitZu() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(TrainingsPlan(tage: []))
        a.sitzung.starte(planTag: nil)
        XCTAssertNil(a.sitzung.tag)
        XCTAssertEqual(a.sitzung.ersterBeendenSchritt(), .beenden, "nichts abgehakt: nichts zu speichern")
        let bank = try XCTUnwrap(UebungsKatalog.nachId["EIeI8Vf"])
        a.sitzung.uebungDazu(bank)
        a.sitzung.haken(0, 0)
        XCTAssertTrue(a.sitzung.freiFrageNoetig)
        XCTAssertEqual(a.sitzung.ersterBeendenSchritt(), .freiFrage)
        a.sitzung.alsTagSpeichern(name: "Freitag", einheitZuordnen: true)
        a.sitzung.beende()
        let neu = try XCTUnwrap(a.daten.training.plan.tage.first)
        XCTAssertEqual(neu.name, "Freitag")
        XCTAssertEqual(a.daten.training.sessions.first?.tag, neu.id, "die Einheit gehört danach zu dem neuen Tag")
    }

    func testEndzeitAendernBeendetMitDenGewaehltenZeiten() async throws {
        let a = try GymTestAufbau(ordner: try tempOrdner())
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        a.sitzung.haken(0, 0)
        let start = a.uhr.lesen
        a.uhr.vor(sekunden: 5 * 3600)
        let neuerStart = start.addingTimeInterval(-600)
        let ende = start.addingTimeInterval(4200)
        a.sitzung.beendeMitZeiten(start: neuerStart, ende: ende)
        await a.sitzung.endeAufgabe?.value
        let s = try XCTUnwrap(a.daten.training.sessions.first)
        XCTAssertEqual(s.start, neuerStart)
        XCTAssertEqual(s.ende, ende)
        XCTAssertNil(a.sitzung.sessionId, "die Sitzung räumt Pause, Puls und Live-Anzeige auf")
        XCTAssertNil(a.sitzung.pause)
        let minuten = a.daten.raum.ops(arten: ["gym.checkout"]).compactMap { $0.daten(GymD.self) }.first { $0.status == "ende" }?.minuten
        XCTAssertEqual(minuten, 80)
    }
}
