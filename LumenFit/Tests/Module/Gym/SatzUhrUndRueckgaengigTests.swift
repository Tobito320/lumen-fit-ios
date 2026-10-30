import XCTest
@testable import LumenFit

/// Satz-Uhr (Dauer nach der Pause, roter Überlauf) und "Rückgängig" nach Löschen oder Kopieren.
final class SatzUhrUndRueckgaengigTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func pause(ziel: Int) -> GymPauseStand { GymPauseStand(session: "s", plan: "p", satz: 0, seit: t0, ziel: ziel) }

    func testSatzStartIstDasPausenEndeWennSieAblief() {
        XCTAssertEqual(SatzUhrLogik.satzStart(pause: pause(ziel: 60), jetzt: t0.addingTimeInterval(90)), t0.addingTimeInterval(60))
    }

    func testSatzStartIstJetztBeiUebersprungenerPauseOderOhneZiel() {
        let jetzt = t0.addingTimeInterval(20)
        XCTAssertEqual(SatzUhrLogik.satzStart(pause: pause(ziel: 60), jetzt: jetzt), jetzt)
        XCTAssertEqual(SatzUhrLogik.satzStart(pause: pause(ziel: 0), jetzt: jetzt), jetzt)
    }

    func testDauerNurMitSchalterStartUndPlausibleLaenge() {
        let jetzt = t0.addingTimeInterval(45)
        XCTAssertEqual(SatzUhrLogik.dauer(seit: t0, jetzt: jetzt, an: true), 45)
        XCTAssertNil(SatzUhrLogik.dauer(seit: t0, jetzt: jetzt, an: false))
        XCTAssertNil(SatzUhrLogik.dauer(seit: nil, jetzt: jetzt, an: true))
        XCTAssertNil(SatzUhrLogik.dauer(seit: t0, jetzt: t0.addingTimeInterval(0.4), an: true))
        XCTAssertNil(SatzUhrLogik.dauer(seit: t0, jetzt: t0.addingTimeInterval(31 * 60), an: true))
    }

    func testUeberlaufErstAbDemZiel() {
        let p = pause(ziel: 60)
        XCTAssertFalse(SatzUhrLogik.ueberlauf(p, jetzt: t0.addingTimeInterval(59)))
        XCTAssertTrue(SatzUhrLogik.ueberlauf(p, jetzt: t0.addingTimeInterval(60)))
        XCTAssertFalse(SatzUhrLogik.ueberlauf(pause(ziel: 0), jetzt: t0.addingTimeInterval(500)))
    }

    func testRueckgaengigFindetDieUebungUeberDiePlanIdAuchNachUmsortieren() {
        let a = PlanUebung(id: "a", uebung: "x", name: nil, saetze: [], minuten: nil)
        let b = PlanUebung(id: "b", uebung: "y", name: nil, saetze: [], minuten: nil)
        let satz = PlanSatz(wdh: 8, kg: 50, failure: false)
        let liste = [b, a].map { WorkoutUebung(planUebung: $0, saetze: [], vorher: [], extra: false) }
        let r = SatzRueckgaengig(text: "Satz 1 gelöscht", plan: "a", vorher: [satz, satz])
        let ergebnis = SatzRueckgaengigLogik.wiederherstellen(r, in: liste)
        XCTAssertEqual(ergebnis?.index, 1)
        XCTAssertEqual(ergebnis?.saetze.count, 2)
        XCTAssertNil(SatzRueckgaengigLogik.wiederherstellen(SatzRueckgaengig(text: "", plan: "weg", vorher: []), in: liste))
    }

    func testJedeMeldungHatEineEigeneId() {
        let a = SatzRueckgaengig(text: "t", plan: "p", vorher: [])
        let b = SatzRueckgaengig(text: "t", plan: "p", vorher: [])
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(SatzRueckgaengigLogik.text(.geloescht, nummer: "2"), "Satz 2 gelöscht")
        XCTAssertEqual(SatzRueckgaengigLogik.text(.kopiert, nummer: "W"), "Satz W kopiert")
    }
}

/// Die Sitzung: Löschen und Kopieren merken die Zeilen, "Rückgängig" stellt sie samt Haken wieder her; Satz-Zeit beim Haken.
@MainActor
final class GymSitzungRueckgaengigTests: XCTestCase {
    private func aufbau() throws -> GymTestAufbau {
        let a = try GymTestAufbau(ordner: try tempOrdner(), healthSchreiben: false)
        a.daten.training.planSichern(GymTestAufbau.plan())
        a.sitzung.starte(planTag: "push")
        return a
    }

    func testLoeschenUndRueckgaengigStelltDieZeilenMitHakenWiederHer() throws {
        let a = try aufbau()
        a.sitzung.haken(0, 0)
        let vorher = a.sitzung.liste[0].saetze
        a.sitzung.satzLoeschen(0, 0)
        XCTAssertEqual(a.sitzung.liste[0].saetze.count, vorher.count - 1)
        XCTAssertEqual(a.sitzung.rueckgaengig?.text, "Satz 1 gelöscht")
        a.sitzung.satzRueckgaengigMachen()
        XCTAssertEqual(a.sitzung.liste[0].saetze, vorher)
        XCTAssertNil(a.sitzung.rueckgaengig)
    }

    func testKopierenMerktDieZeilenVorherUndRueckgaengigNimmtDieKopieWeg() throws {
        let a = try aufbau()
        let vorher = a.sitzung.liste[0].saetze
        a.sitzung.satzKopieren(0, 0)
        XCTAssertEqual(a.sitzung.liste[0].saetze.count, vorher.count + 1)
        XCTAssertEqual(a.sitzung.rueckgaengig?.text, "Satz 1 kopiert")
        a.sitzung.satzRueckgaengigMachen()
        XCTAssertEqual(a.sitzung.liste[0].saetze, vorher)
    }

    func testDerLetzteSatzLaesstSichNichtLoeschenUndMerktNichts() throws {
        let a = try aufbau()
        while a.sitzung.liste[0].saetze.count > 1 { a.sitzung.satzLoeschen(0, 0) }
        a.sitzung.rueckgaengigVergessen()
        a.sitzung.satzLoeschen(0, 0)
        XCTAssertEqual(a.sitzung.liste[0].saetze.count, 1)
        XCTAssertNil(a.sitzung.rueckgaengig)
    }

    func testHakenZurueckNehmenZaehltHochUndLoeschtDasRekordLabel() throws {
        let a = try aufbau()
        a.sitzung.haken(0, 0)
        XCTAssertEqual(a.sitzung.hakenZurueckZaehler, 0)
        a.sitzung.haken(0, 0)
        XCTAssertEqual(a.sitzung.hakenZurueckZaehler, 1)
        XCTAssertNil(a.sitzung.rekordLabel["a|0"])
    }

    func testSatzZeitWirdNurMitSchalterGemerkt() throws {
        let a = try aufbau()
        UserDefaults.standard.set(true, forKey: GymAnzeige.satzzeitSchluessel)
        defer { UserDefaults.standard.removeObject(forKey: GymAnzeige.satzzeitSchluessel) }
        a.sitzung.haken(0, 0) // Pause 90 s
        a.uhr.vor(sekunden: 120) // Pause ist 30 s vorbei
        a.sitzung.haken(0, 1)
        XCTAssertEqual(a.sitzung.liste[0].saetze[1].sek, 30)
    }
}
