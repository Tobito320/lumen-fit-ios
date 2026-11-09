import XCTest
@testable import LumenFit

/// Update-Probe: `Fixtures/Gym/gym-lauf-stand.jsonl` ist ein Stand, wie ihn Build 16 (08.11.2026) schreibt: Plan, eine alte Einheit und ein laufendes
/// Training mit einem abgehakten Satz, dazu `gym-pause.json`. Eine neue Version muss daraus das laufende Training samt Pause, "Letztes Mal" und Plan
/// wiederherstellen. Die Datei bleibt eingefroren: ändert sich ein gespeicherter Typ unverträglich, fällt dieser Test, bevor ein Update Daten verliert.
@MainActor
final class AlteDateienLadenGymLaufTests: XCTestCase {
    /// Start des laufenden Trainings in der Datei (2026-11-09 17:37:16 UTC).
    private let start = Date(timeIntervalSince1970: 1_794_245_836)

    /// Eine App-Umgebung, deren Profilordner die alten Dateien schon enthält, bevor die App ihn das erste Mal liest (wie nach einem Update).
    private func umgebungMitAltemStand(jetzt: Date) throws -> (AppUmgebung, TestUhr) {
        let uhr = TestUhr()
        uhr.setze(jetzt)
        UserDefaults.standard.set(true, forKey: GymAnzeige.pausenTimerSchluessel)   // der Test rechnet mit der Pause nach dem Haken
        let wurzel = try tempOrdner()
        let u = AppUmgebung(ordner: wurzel, schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        let profil = try u.profil.anlegen(name: "Beispiel", passwort: "")
        let ordner = u.profilOrdner(profil.id)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let roh = try FixtureOrt.daten("Gym", "gym-lauf-stand.jsonl")
        let ops = String(decoding: roh, as: UTF8.self).replacingOccurrences(of: "test-a", with: profil.id.rawValue)
        try Data(ops.utf8).write(to: ordner.appendingPathComponent("ops.jsonl"))
        try Data(#"{"plan":"a","satz":0,"seit":1794246436,"session":"lauf-1","ziel":90}"#.utf8).write(to: ordner.appendingPathComponent("gym-pause.json"))
        return (u, uhr)
    }

    func testLaufendesTrainingPauseLetztesMalUndPlanKommenAusDenAltenDateien() throws {
        let (u, _) = try umgebungMitAltemStand(jetzt: start + 650)
        let sitzung = GymSitzung(umgebung: u)
        sitzung.ladeWennNoetig()
        XCTAssertEqual(sitzung.sessionId, "lauf-1")
        XCTAssertEqual(sitzung.liste.map(\.id), ["a", "b"])
        let a = sitzung.liste[0]
        XCTAssertEqual(a.saetze.map(\.ok), [true, nil, nil])
        XCTAssertEqual(a.saetze.map(\.kg), [62.5, 62.5, 62.5])
        XCTAssertEqual(a.saetze[0].pause, 95.2)
        XCTAssertEqual(a.vorher.map(\.kg), [60, 60], "Letztes Mal kommt aus der alten Einheit")
        XCTAssertEqual(LetztesMal.text(zeile: 1, in: a.saetze, vorher: a.vorher), "60 kg × 8")
        XCTAssertEqual(sitzung.liste[1].saetze.map(\.kg), [20, 20], "ohne Vorgänger stehen die Planwerte")
        XCTAssertEqual(sitzung.pause, GymPauseStand(session: "lauf-1", plan: "a", satz: 0, seit: start + 600, ziel: 90))
        XCTAssertEqual(sitzung.dran?.uebung, 0)
        XCTAssertEqual(sitzung.dran?.satz, 1)
        let plan = try XCTUnwrap(sitzung.training?.plan)
        XCTAssertEqual(plan.splitName, "Beispiel Push Pull")
        XCTAssertEqual(plan.ruhetage, [6, 7])
        XCTAssertEqual(plan.tage.first?.uebungen.first?.saetze.map(\.kg), [60, 60, 60])
        XCTAssertEqual(sitzung.training?.sessions.count, 2)
    }

    func testNachDemLadenGehtDasTrainingOhneBruchWeiter() throws {
        let (u, uhr) = try umgebungMitAltemStand(jetzt: start + 650)
        let sitzung = GymSitzung(umgebung: u)
        sitzung.ladeWennNoetig()
        sitzung.haken(0, 1)
        uhr.vor(sekunden: 5)
        // Noch ein Neustart: beide Haken und die neue Pause stehen auf der Platte.
        let neu = GymSitzung(umgebung: u)
        neu.ladeWennNoetig()
        XCTAssertEqual(neu.liste[0].saetze.map(\.ok), [true, true, nil])
        XCTAssertEqual(neu.pause?.satz, 1)
        XCTAssertEqual(neu.pause?.ziel, 90)
    }

    func testNachDreiStundenGiltDieEinheitAlsVergessenAberNichtsIstWeg() throws {
        let (u, _) = try umgebungMitAltemStand(jetzt: start + 4 * 3600)
        let sitzung = GymSitzung(umgebung: u)
        sitzung.ladeWennNoetig()
        XCTAssertNil(sitzung.sessionId, "nach drei Stunden läuft nichts mehr")
        let training = try XCTUnwrap(u.daten?.training)
        XCTAssertEqual(training.vergessene()?.id, "lauf-1", "die Startseite bietet das Nachtragen der Endzeit an")
        let stand = training.sessions.first { $0.id == "lauf-1" }?.laeufe.first?.stand
        XCTAssertEqual(stand?.filter { $0.ok == true }.count, 1, "der abgehakte Satz bleibt")
    }
}
