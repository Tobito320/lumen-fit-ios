import XCTest
@testable import LumenFit

/// Live Activity: Zeile "kg × Wdh", Satz-Uhr ab Pausenende, Zeile "x von y Übungen fertig".
@MainActor
final class GymLiveStandTests: XCTestCase {
    func testSatzZeile() {
        var s = TrainingLiveStand(uebung: "x", satz: 1, von: 3, pauseEnde: nil, start: Date(), planName: nil)
        XCTAssertNil(s.satzZeile)
        s.wdh = 8
        XCTAssertEqual(s.satzZeile, "8 Wdh.")
        s.kg = 62.5
        XCTAssertEqual(s.satzZeile, "\(TrainingLogik.kgText(62.5)) kg × 8")
    }

    func testAlterStandOhneNeueFelderIstLesbar() throws {
        let json = #"{"uebung":"x","satz":1,"von":3,"start":0}"#
        let s = try JSONDecoder().decode(TrainingLiveStand.self, from: Data(json.utf8))
        XCTAssertNil(s.kg)
        XCTAssertNil(s.uebungenGesamt)
    }

    func testStandMitKgSatzUhrUndUebungenFertig() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner(), healthSchreiben: false)
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        let s = try XCTUnwrap(a.sitzung.laufende)
        let jetzt = a.uhr.lesen
        let start = try XCTUnwrap(GymLive.stand(session: s, liste: a.sitzung.liste, pause: nil, planName: "Push", jetzt: jetzt))
        XCTAssertEqual(start.kg, 60)
        XCTAssertEqual(start.wdh, 8)
        XCTAssertNil(start.satzSeit)
        XCTAssertEqual(start.uebungenFertig, 0)
        XCTAssertEqual(start.uebungenGesamt, 2)
        let pause = GymPauseStand(session: s.id, plan: "a", satz: 0, seit: jetzt, ziel: 60)
        let laeuft = try XCTUnwrap(GymLive.stand(session: s, liste: a.sitzung.liste, pause: pause, planName: nil, jetzt: jetzt.addingTimeInterval(30)))
        XCTAssertNil(laeuft.satzSeit)
        let vorbei = try XCTUnwrap(GymLive.stand(session: s, liste: a.sitzung.liste, pause: pause, planName: nil, jetzt: jetzt.addingTimeInterval(90)))
        XCTAssertEqual(vorbei.satzSeit, jetzt.addingTimeInterval(60))
    }

    func testAllesFertigZeigtDieUebungenZahl() throws {
        let a = try GymTestAufbau(ordner: try tempOrdner(), healthSchreiben: false)
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        for u in a.sitzung.liste.indices { for i in a.sitzung.liste[u].saetze.indices { a.sitzung.haken(u, i) } }
        let s = try XCTUnwrap(a.sitzung.laufende)
        let stand = try XCTUnwrap(GymLive.stand(session: s, liste: a.sitzung.liste, pause: nil, planName: nil, jetzt: a.uhr.lesen))
        XCTAssertEqual(stand.von, 0)
        XCTAssertEqual(stand.uebungenFertig, 2)
        XCTAssertEqual(stand.uebungenGesamt, 2)
    }
}
