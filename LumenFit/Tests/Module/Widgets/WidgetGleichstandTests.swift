import XCTest
@testable import LumenFit

/// Gleichstand Health, Widget-Teil: Gym-Woche, Gym-Duell und Schritte-Duell (Partner nur mit Freigabe), Schlaf-Zeile, Gewohnheit zur Wahl, Gym-Haken ohne App.
final class WidgetGleichstandTests: XCTestCase {
    private let jetzt = TestUhr().lesen   // Mittwoch 23.09.2026, 12:00 Berlin
    private let heute = "2026-09-23"

    private func partnerDatei(_ frei: [FreigabeArt]) -> ZusammenfassungDatei {
        var h = TagesZusammenfassung(tag: heute, schritte: 9_000, gymTageWoche: 2, schlafMinuten: 420, kcal: 2_000)
        h.schritteZiel = 10_000; h.gymTage = ["2026-09-21", "2026-09-22"]; h.gymZiel = 3; h.schlafZiel = 480
        return ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Beispiel Partner", freigaben: frei, heute: h, ereignisse: [])
    }

    // MARK: Partner nur mit Freigabe

    func testPartnerStandHatNurFreigegebeneFelder() {
        let nurGym = WidgetPartnerStand.aus(partnerDatei([.gym]))
        XCTAssertEqual(nurGym.gymTage, ["2026-09-21", "2026-09-22"])
        XCTAssertEqual(nurGym.gymZiel, 3)
        XCTAssertNil(nurGym.schritte)
        XCTAssertNil(nurGym.schlafMinuten)
        let nurSchritte = WidgetPartnerStand.aus(partnerDatei([.schritte]))
        XCTAssertEqual(nurSchritte.schritte, 9_000)
        XCTAssertEqual(nurSchritte.schritteZiel, 10_000)
        XCTAssertNil(nurSchritte.gymTage, "nicht geteilt heißt nil")
        let nichts = WidgetPartnerStand.aus(partnerDatei([]))
        XCTAssertEqual(nichts, WidgetPartnerStand(name: "Beispiel Partner", tag: heute))
    }

    func testFreigegebenesGymOhneTageIstLeerNichtNil() {
        var d = partnerDatei([.gym])
        d.heute.gymTage = nil
        d.heute.gymTageWoche = 0
        XCTAssertEqual(WidgetPartnerStand.aus(d).gymTage, [])
        d.heute.gymTageWoche = 2
        XCTAssertNil(WidgetPartnerStand.aus(d).gymTage, "ältere Datei ohne Tage: unbekannt")
    }

    func testPartnerSchritteVonGesternZaehlenNicht() {
        var s = WidgetSnapshot.beispiel(jetzt: jetzt)
        s.partner = WidgetPartnerStand(name: "P", tag: "2026-09-22", schritte: 9_000, gymTage: ["2026-09-22"], schlafMinuten: 400)
        let p = WidgetAnzeige.partner(s, jetzt: jetzt)
        XCTAssertNil(p?.schritte)
        XCTAssertNil(p?.schlafMinuten)
        XCTAssertEqual(p?.gymTage, ["2026-09-22"], "Gym-Tage tragen ihr eigenes Datum")
        XCTAssertNil(WidgetAnzeige.partner(s, jetzt: jetzt.addingTimeInterval(24 * 3600)), "der Snapshot selbst ist von gestern")
        s.partner = nil
        XCTAssertNil(WidgetAnzeige.partner(s, jetzt: jetzt))
    }

    // MARK: Gym-Woche

    func testGymWocheHatSiebenTageUndZaehltBisHeute() {
        var s = WidgetSnapshot.beispiel(jetzt: jetzt)
        let tage = WidgetAnzeige.gymWoche(s, jetzt: jetzt)
        XCTAssertEqual(tage.map(\.tag).first, "2026-09-21")
        XCTAssertEqual(tage.count, 7)
        XCTAssertEqual(tage.filter(\.erledigt).map(\.tag), ["2026-09-21", "2026-09-23"])
        XCTAssertEqual(WidgetAnzeige.gymZahl(tage, jetzt: jetzt), 2)
        XCTAssertTrue(WidgetAnzeige.gymHeuteErledigt(s, jetzt: jetzt))
        s.gymWoche?[6].erledigt = true   // ein Haken in der Zukunft zählt nicht
        XCTAssertEqual(WidgetAnzeige.gymZahl(WidgetAnzeige.gymWoche(s, jetzt: jetzt), jetzt: jetzt), 2)
    }

    func testNachWochenwechselStartetDieGymWocheLeer() {
        let naechsteWoche = jetzt.addingTimeInterval(7 * 24 * 3600)
        let tage = WidgetAnzeige.gymWoche(WidgetSnapshot.beispiel(jetzt: jetzt), jetzt: naechsteWoche)
        XCTAssertEqual(tage.map(\.tag).first, "2026-09-28")
        XCTAssertTrue(tage.allSatisfy { !$0.erledigt })
        XCTAssertFalse(WidgetAnzeige.gymHeuteErledigt(nil, jetzt: jetzt))
    }

    func testPartnerGymWocheNurMitTagen() {
        let mit = WidgetPartnerStand(name: "P", tag: heute, gymTage: ["2026-09-22"])
        XCTAssertEqual(WidgetAnzeige.partnerGymWoche(mit, jetzt: jetzt)?.filter(\.erledigt).map(\.tag), ["2026-09-22"])
        XCTAssertNil(WidgetAnzeige.partnerGymWoche(WidgetPartnerStand(name: "P", tag: heute), jetzt: jetzt))
    }

    func testGymSprechtext() {
        let tage = WidgetAnzeige.gymWoche(WidgetSnapshot.beispiel(jetzt: jetzt), jetzt: jetzt)
        XCTAssertEqual(WidgetAnzeige.gymSprechtext(name: "Du", tage: tage, ziel: 3, jetzt: jetzt), "Du: 2 von 3 Tagen, heute erledigt")
        XCTAssertEqual(WidgetAnzeige.gymSprechtext(name: "Du", tage: [], ziel: 0, jetzt: jetzt), "Du: 0 von 1 Tagen")
    }

    // MARK: Schlaf, Gewohnheit

    func testSchlafInline() {
        XCTAssertEqual(WidgetAnzeige.schlafInline(WidgetSnapshot.beispiel(jetzt: jetzt), jetzt: jetzt), "Schlaf 7:12 h")
        XCTAssertEqual(WidgetAnzeige.schlafInline(nil, jetzt: jetzt), "Schlaf –")
        XCTAssertEqual(WidgetAnzeige.schlafInline(WidgetSnapshot.beispiel(jetzt: jetzt), jetzt: jetzt.addingTimeInterval(24 * 3600)), "Schlaf –")
    }

    func testGewaehlteGewohnheitOderDieErste() {
        let s = WidgetSnapshot.beispiel(jetzt: jetzt)
        XCTAssertEqual(WidgetAnzeige.habit(id: "wasser", snapshot: s)?.id, "wasser")
        XCTAssertEqual(WidgetAnzeige.habit(id: nil, snapshot: s)?.id, "gym")
        XCTAssertEqual(WidgetAnzeige.habit(id: "weg", snapshot: s)?.id, "gym", "eine gelöschte Gewohnheit fällt auf die erste zurück")
        XCTAssertNil(WidgetAnzeige.habit(id: "gym", snapshot: nil))
    }

    // MARK: Snapshot und Haken

    func testBauerSchreibtGymWocheUndPartner() {
        let e = WidgetEingabe(jetzt: jetzt, profilName: "Beispiel", profilKennung: "p1", thema: .monochrom, erscheinung: .system, ziele: Ziele(),
                              schritte: nil, schlafMinuten: nil, hrv: nil, sessions: [], plan: TrainingsPlan(tage: []), kcal: 0, kcalZiel: 2_000, protein: 0, proteinZiel: 100,
                              habits: [], lumi: .bereit, lumiStufe: 1, gymTage: ["2026-09-21", "2026-09-25"], partner: partnerDatei([.gym]))
        let s = WidgetSnapshotBauer.baue(e)
        XCTAssertEqual(s.gymWoche?.filter(\.erledigt).map(\.tag), ["2026-09-21"], "ein Tag in der Zukunft zählt nicht")
        XCTAssertEqual(s.partner?.gymTage?.count, 2)
        XCTAssertNil(s.partner?.schritte)
        var ohne = e
        ohne.partner = nil
        XCTAssertNil(WidgetSnapshotBauer.baue(ohne).partner)
    }

    func testAlteDateiOhneGymWocheUndPartnerBleibtLesbar() throws {
        let ordner = try tempOrdner()
        try Data(#"{"profilName":"Alt","tag":"2026-09-22","gymWoche":"kaputt","partner":{"name":1}}"#.utf8).write(to: ordner.appendingPathComponent(WidgetSnapshotDatei.name))
        let s = try XCTUnwrap(WidgetSnapshotDatei.lade(ordner: ordner))
        XCTAssertEqual(s.profilName, "Alt")
        XCTAssertNil(s.gymWoche)
        XCTAssertNil(s.partner)
    }

    func testGymAbhakenZeigtDenHakenInDerGymWocheSofort() throws {
        let ordner = try tempOrdner()
        var s = WidgetSnapshot.beispiel(jetzt: jetzt)
        s.profilKennung = "p1"
        s.gymWoche?[3].erledigt = false
        WidgetSnapshotDatei.schreibe(s, ordner: ordner)
        // Donnerstag gehört nicht zum Tag des Snapshots: nichts ändert sich in der Anzeige, die Op geht trotzdem raus.
        WidgetHabitAktion.abhaken(habit: "gym", wert: 1, tag: "2026-09-24", profil: "p1", ordner: ordner)
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.gymWoche?[3].erledigt, false)
        // Heute: ab- und wieder wegnehmen
        WidgetHabitAktion.abhaken(habit: "gym", wert: 0, tag: heute, profil: "p1", ordner: ordner)
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.gymWoche?[2].erledigt, false)
        WidgetHabitAktion.abhaken(habit: "gym", wert: 1, tag: heute, profil: "p1", ordner: ordner)
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.gymWoche?[2].erledigt, true)
        XCTAssertEqual(WidgetOpsDatei.lies(WidgetOpsDatei.url(ordner: ordner)).count, 3)
        // Eine andere Gewohnheit fasst die Gym-Woche nie an.
        WidgetHabitAktion.abhaken(habit: "wasser", wert: 0, tag: heute, profil: "p1", ordner: ordner)
        XCTAssertEqual(WidgetSnapshotDatei.lade(ordner: ordner)?.gymWoche?[2].erledigt, true)
    }
}
