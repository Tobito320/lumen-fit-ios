import XCTest
@testable import LumenFit

/// Der Coach kennt den Tag (Idee 66): Bereitschaft, Dauer, Schnitte und der Kontext aus den Stores. Alle Zahlen sind erfunden.
final class CoachGesundheitTests: XCTestCase {
    private func wert(_ tag: String, _ w: Double) -> VitalMesswert { VitalMesswert(art: .hrv, tag: tag, wert: w) }

    func testDauerOhnePunkte() {
        XCTAssertEqual(CoachGesundheit.dauer(minuten: 450), "7 h 30 min")
        XCTAssertEqual(CoachGesundheit.dauer(minuten: 480), "8 h")
        XCTAssertEqual(CoachGesundheit.dauer(minuten: 45), "45 min")
        XCTAssertEqual(CoachGesundheit.dauer(minuten: -5), "0 min")
    }

    func testBereitschaftNurMitDaten() {
        XCTAssertNil(CoachGesundheit.bereitschaft(schlafMinuten: nil, schlafZiel: 480, hrv: nil, hrvSchnitt: nil, ruhepuls: nil, ruhepulsSchnitt: nil))
        XCTAssertNil(CoachGesundheit.bereitschaft(schlafMinuten: 400, schlafZiel: 0, hrv: nil, hrvSchnitt: nil, ruhepuls: nil, ruhepulsSchnitt: nil))
    }

    func testBereitschaftAusSchlafAllein() {
        XCTAssertEqual(CoachGesundheit.bereitschaft(schlafMinuten: 480, schlafZiel: 480, hrv: nil, hrvSchnitt: nil, ruhepuls: nil, ruhepulsSchnitt: nil), 100)
        XCTAssertEqual(CoachGesundheit.bereitschaft(schlafMinuten: 240, schlafZiel: 480, hrv: nil, hrvSchnitt: nil, ruhepuls: nil, ruhepulsSchnitt: nil), 50)
        XCTAssertEqual(CoachGesundheit.bereitschaft(schlafMinuten: 700, schlafZiel: 480, hrv: nil, hrvSchnitt: nil, ruhepuls: nil, ruhepulsSchnitt: nil), 100, "mehr als das Ziel zählt nicht mehr")
    }

    func testBereitschaftMitHerzfrequenzvariabilitaetUndRuhepuls() {
        XCTAssertEqual(CoachGesundheit.bereitschaft(schlafMinuten: nil, schlafZiel: 480, hrv: 50, hrvSchnitt: 50, ruhepuls: nil, ruhepulsSchnitt: nil), 50, "auf dem eigenen Schnitt")
        XCTAssertEqual(CoachGesundheit.bereitschaft(schlafMinuten: nil, schlafZiel: 480, hrv: 60, hrvSchnitt: 50, ruhepuls: nil, ruhepulsSchnitt: nil), 80)
        XCTAssertEqual(CoachGesundheit.bereitschaft(schlafMinuten: nil, schlafZiel: 480, hrv: 10, hrvSchnitt: 50, ruhepuls: nil, ruhepulsSchnitt: nil), 0, "nie unter 0")
        XCTAssertEqual(CoachGesundheit.bereitschaft(schlafMinuten: nil, schlafZiel: 480, hrv: nil, hrvSchnitt: nil, ruhepuls: 56, ruhepulsSchnitt: 60), 70, "niedriger als üblich ist besser")
        let alle = CoachGesundheit.bereitschaft(schlafMinuten: 480, schlafZiel: 480, hrv: 50, hrvSchnitt: 50, ruhepuls: 60, ruhepulsSchnitt: 60)
        XCTAssertEqual(alle, 80, "(60 + 12,5 + 7,5) / 1")
    }

    func testSchnittNimmtVierzehnTageOhneHeuteUndBrauchtDreiWerte() {
        let heute = "2026-09-23"
        let werte = [wert("2026-09-20", 40), wert("2026-09-21", 50), wert("2026-09-22", 60)]
        XCTAssertEqual(CoachGesundheit.schnitt(werte, heute: heute), 50)
        XCTAssertNil(CoachGesundheit.schnitt(Array(werte.prefix(2)), heute: heute), "unter drei Werten kein Schnitt")
        XCTAssertEqual(CoachGesundheit.schnitt(werte + [wert(heute, 500)], heute: heute), 50, "heute zählt nicht")
        XCTAssertEqual(CoachGesundheit.schnitt(werte + [wert("2026-08-01", 500)], heute: heute), 50, "zu alt")
    }

    func testWertDesTagesIstDerLetzte() {
        XCTAssertEqual(CoachGesundheit.wert([wert("2026-09-22", 1), wert("2026-09-23", 2), wert("2026-09-23", 3)], tag: "2026-09-23"), 3)
        XCTAssertNil(CoachGesundheit.wert([wert("2026-09-22", 1)], tag: "2026-09-23"))
    }

    // MARK: - Kontext und Eingabe aus den Stores

    @MainActor
    func testKontextEinesLeerenTags() throws {
        let (u, daten, _) = try CoachTestBau.umgebung()
        let kontext = CoachDaten.kontext(u, daten)
        XCTAssertEqual(kontext.tag, "2026-09-23")
        XCTAssertNil(kontext.schlafMinuten, "keine Daten, keine erfundene Zahl")
        XCTAssertNil(kontext.bereitschaft)
        XCTAssertNil(kontext.letztesTraining)
        XCTAssertEqual(kontext.stimmung, .bereit)
        XCTAssertEqual(kontext.merkzettel, [])
    }

    @MainActor
    func testKontextTraegtStimmungUndMerkzettel() throws {
        let (u, daten, _) = try CoachTestBau.umgebung(stunde: 8)
        daten.coach.merke("Linkes Knie vorsichtig belasten")
        CoachModell(umgebung: u).morgenCheckBeantworten(1)
        let kontext = CoachDaten.kontext(u, daten)
        XCTAssertEqual(kontext.stimmung, .muede)
        XCTAssertEqual(kontext.merkzettel, ["Linkes Knie vorsichtig belasten"])
        XCTAssertTrue(CoachPersona.schwererTag(kontext), "müde Stimmung ist ein schwerer Tag")
    }

    @MainActor
    func testEingabeOhneDatenIstLeerUndOhneEingerichteteZiele() throws {
        let (u, daten, _) = try CoachTestBau.umgebung()
        let eingabe = CoachDaten.eingabe(u, daten)
        XCTAssertEqual(eingabe.heute, "2026-09-23")
        XCTAssertFalse(eingabe.zieleEingerichtet)
        XCTAssertTrue(eingabe.essenKcal.isEmpty)
        XCTAssertTrue(eingabe.gruppen.isEmpty)
        XCTAssertTrue(eingabe.uebungen.isEmpty)
    }
}
