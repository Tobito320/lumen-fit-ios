import XCTest
@testable import LumenFit

/// Anzeige-Rechnung der Widgets, dazu die portierten Lovea-Tests der Sperrbildschirm-Rechnung (`LockscreenLogikTests`) und der Datumshilfen (`WidgetStandTests`).
final class WidgetAnzeigeTests: XCTestCase {
    private let jetzt = TestUhr().lesen   // Mittwoch 23.09.2026, 12:00 Berlin

    private func beispiel() -> WidgetSnapshot { WidgetSnapshot.beispiel(jetzt: jetzt) }

    // MARK: - Bögen

    func testBoegenZeigenSchritteTrainingUndSchlaf() {
        let b = WidgetAnzeige.boegen(beispiel(), jetzt: jetzt)
        XCTAssertEqual(b.map(\.id), [.bewegen, .trainieren, .erholen])
        XCTAssertEqual(b[0].zahl, "8.412")
        XCTAssertEqual(b[0].anteil, 0.8412, accuracy: 0.0001)
        XCTAssertEqual(b[1].zahl, "2 von 3")
        XCTAssertEqual(b[1].anteil, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(b[2].zahl, "7:12 h")
        XCTAssertEqual(b[2].anteil, 0.9, accuracy: 0.0001)
    }

    func testBoegenOhneSnapshotOderVonGesternSindLeer() {
        let morgen = jetzt.addingTimeInterval(24 * 3600)
        for b in [WidgetAnzeige.boegen(nil, jetzt: jetzt), WidgetAnzeige.boegen(beispiel(), jetzt: morgen)] {
            XCTAssertEqual(b.map(\.zahl), ["–", "–", "–"])
            XCTAssertEqual(b.map(\.anteil), [0, 0, 0])
        }
    }

    func testAnteilWirdGekappt() {
        XCTAssertEqual(WidgetAnzeige.anteil(15_000, 10_000), 1)
        XCTAssertEqual(WidgetAnzeige.anteil(-5, 10), 0)
        XCTAssertEqual(WidgetAnzeige.anteil(5, 0), 0)
        XCTAssertEqual(WidgetAnzeige.anteil(nil, 10), 0)
    }

    func testVorlesetextNenntAlleWerte() {
        let text = WidgetAnzeige.sprechtext(beispiel(), jetzt: jetzt)
        XCTAssertTrue(text.contains("Schritte 8.412 von 10.000"), text)
        XCTAssertTrue(text.contains("Training 2 von 3"), text)
        XCTAssertTrue(text.contains("Schlaf 7 Stunden 12 Minuten"), text)
        XCTAssertEqual(WidgetAnzeige.sprechtext(nil, jetzt: jetzt), "Lumen Fit: noch keine Werte von heute")
    }

    // MARK: - Tag

    func testNachMitternachtGiltDerSnapshotNichtMehrAlsHeute() {
        XCTAssertTrue(WidgetAnzeige.istVonHeute(beispiel(), jetzt: jetzt))
        XCTAssertFalse(WidgetAnzeige.istVonHeute(beispiel(), jetzt: jetzt.addingTimeInterval(13 * 3600)))
        XCTAssertFalse(WidgetAnzeige.istVonHeute(nil, jetzt: jetzt))
    }

    func testNaechsteMitternachtIstBerlinerMitternacht() {
        let ende = WidgetAnzeige.naechsteMitternacht(jetzt)
        XCTAssertEqual(Datum.text(ende), "2026-09-24")
        XCTAssertEqual(Datum.uhrzeit(ende), "00:00")
        // 25.10.2026: die Uhren gehen zurück, der Tag hat 25 Stunden; die Mitternacht davor bleibt die richtige.
        let vorUmstellung = Datum.datum("2026-10-24").addingTimeInterval(12 * 3600)
        XCTAssertEqual(WidgetAnzeige.naechsteMitternacht(vorUmstellung), Datum.datum("2026-10-25"))
    }

    func testErscheinungSystemFolgtDemSystem() {
        XCTAssertTrue(WidgetAnzeige.dunkel(erscheinung: nil, system: true))
        XCTAssertFalse(WidgetAnzeige.dunkel(erscheinung: .system, system: false))
        XCTAssertFalse(WidgetAnzeige.dunkel(erscheinung: .hell, system: true))
        XCTAssertTrue(WidgetAnzeige.dunkel(erscheinung: .dunkel, system: false))
    }

    // MARK: - Plan, Serie, Essen, Gewohnheiten

    func testPlanTextRechnetHeuteMorgenUndSpaeter() {
        let heute = Datum.text(jetzt)
        XCTAssertEqual(WidgetAnzeige.planText(WidgetPlanTag(name: "Push", tag: heute), jetzt: jetzt).wann, "heute")
        XCTAssertEqual(WidgetAnzeige.planText(WidgetPlanTag(name: "Pull", tag: Datum.addTage(heute, 1)), jetzt: jetzt).wann, "morgen")
        let spaeter = WidgetAnzeige.planText(WidgetPlanTag(name: "Beine", tag: Datum.addTage(heute, 3)), jetzt: jetzt)
        XCTAssertEqual(spaeter.titel, "Beine")
        XCTAssertEqual(spaeter.wann, "in 3 Tagen")
    }

    func testPlanTextOhnePlanOderMitVergangenemTag() {
        XCTAssertEqual(WidgetAnzeige.planText(nil, jetzt: jetzt).titel, "Kein Training geplant")
        XCTAssertNil(WidgetAnzeige.planText(nil, jetzt: jetzt).wann)
        XCTAssertEqual(WidgetAnzeige.planText(WidgetPlanTag(name: "Alt", tag: "2026-09-01"), jetzt: jetzt).titel, "Kein Training geplant")
    }

    func testSerieText() {
        XCTAssertEqual(WidgetAnzeige.serieText(nil), "Noch keine Serie")
        XCTAssertEqual(WidgetAnzeige.serieText(0), "Noch keine Serie")
        XCTAssertEqual(WidgetAnzeige.serieText(1), "1 Woche in Folge")
        XCTAssertEqual(WidgetAnzeige.serieText(4), "4 Wochen in Folge")
    }

    func testEssenRestUndUeberschreitung() throws {
        let rest = try XCTUnwrap(WidgetAnzeige.essenRest(beispiel(), jetzt: jetzt))
        XCTAssertEqual(rest.kcal, 840)
        XCTAssertEqual(rest.protein, 42)
        XCTAssertEqual(rest.anteil, 0.65, accuracy: 0.0001)
        XCTAssertEqual(WidgetAnzeige.restText(840), "840")
        XCTAssertEqual(WidgetAnzeige.restText(-1_120), "1.120 drüber")
        var drueber = beispiel()
        drueber.essen = WidgetEssenStand(kcal: 2_500, kcalZiel: 2_400, protein: 150, proteinZiel: 140)
        let r = try XCTUnwrap(WidgetAnzeige.essenRest(drueber, jetzt: jetzt))
        XCTAssertEqual(r.kcal, -100)
        XCTAssertEqual(r.protein, 0, "Protein-Rest wird nie negativ")
        XCTAssertNil(WidgetAnzeige.essenRest(beispiel(), jetzt: jetzt.addingTimeInterval(24 * 3600)))
    }

    func testNaechsterWertZaehlendUndWechselnd() {
        XCTAssertEqual(WidgetAnzeige.naechsterWert(zaehlen: true, heute: 5, ziel: 8), 6)
        XCTAssertEqual(WidgetAnzeige.naechsterWert(zaehlen: true, heute: 8, ziel: 8), 0, "nach dem Ziel zurück auf null")
        XCTAssertEqual(WidgetAnzeige.naechsterWert(zaehlen: false, heute: 0, ziel: 1), 1)
        XCTAssertEqual(WidgetAnzeige.naechsterWert(zaehlen: false, heute: 1, ziel: 1), 0)
    }

    func testHabitWertUndTextNachMitternacht() throws {
        let s = beispiel()
        let wasser = try XCTUnwrap(s.habits?[1])
        XCTAssertEqual(WidgetAnzeige.wertHeute(wasser, snapshot: s, jetzt: jetzt), 5)
        XCTAssertEqual(WidgetAnzeige.wertHeute(wasser, snapshot: s, jetzt: jetzt.addingTimeInterval(24 * 3600)), 0)
        XCTAssertEqual(WidgetAnzeige.habitText(wasser, wert: 5), "5 von 8")
        XCTAssertFalse(WidgetAnzeige.erledigt(wasser, wert: 5))
        XCTAssertTrue(WidgetAnzeige.erledigt(wasser, wert: 8))
        let gym = try XCTUnwrap(s.habits?[0])
        XCTAssertEqual(WidgetAnzeige.habitText(gym, wert: 0), "Offen")
        XCTAssertEqual(WidgetAnzeige.habitText(gym, wert: 1), "Erledigt")
    }

    func testSchlafZeileFuerDenSperrbildschirm() {
        let z = WidgetAnzeige.schlafZeile(beispiel(), jetzt: jetzt)
        XCTAssertEqual(z.schlaf, "7:12 h")
        XCTAssertEqual(z.erholung, "HRV 68 ms")
        XCTAssertEqual(z.anteil, 0.9, accuracy: 0.0001)
        let leer = WidgetAnzeige.schlafZeile(nil, jetzt: jetzt)
        XCTAssertNil(leer.schlaf)
        XCTAssertNil(leer.erholung)
    }

    // MARK: - Portiert: LockscreenLogikTests (Lovea)

    func testTageBisTermin() {
        XCTAssertEqual(LockscreenLogik.tageBis(tag: "2026-10-18", heute: "2026-10-08"), 10)
        XCTAssertEqual(LockscreenLogik.tageBis(tag: "2026-10-08", heute: "2026-10-08"), 0)
    }

    func testVergangenerOderFehlenderTagGibtNil() {
        XCTAssertNil(LockscreenLogik.tageBis(tag: "2026-10-01", heute: "2026-10-08"))
        XCTAssertNil(LockscreenLogik.tageBis(tag: nil, heute: "2026-10-08"))
    }

    func testCountdownText() {
        XCTAssertEqual(LockscreenLogik.countdownText(tage: 0), "heute")
        XCTAssertEqual(LockscreenLogik.countdownText(tage: 1), "morgen")
        XCTAssertEqual(LockscreenLogik.countdownText(tage: 12), "in 12 Tagen")
    }

    func testDatumKurzUndSchlafText() {
        XCTAssertEqual(LockscreenLogik.datumKurz("2026-10-08"), "8.10.")
        XCTAssertEqual(LockscreenLogik.schlafText(minuten: 432), "7:12")
        XCTAssertEqual(LockscreenLogik.schlafText(minuten: 485), "8:05")
    }

    func testKurzZahl() {
        XCTAssertEqual(LockscreenLogik.kurzZahl(950), "950")
        XCTAssertEqual(LockscreenLogik.kurzZahl(4_210), "4,2k")
    }

    // MARK: - Portiert: WidgetStandTests (Lovea), `WidgetDatum` ist hier `Datum`

    func testHeuteFolgtBerlinerZeitzone() {
        var utc = DateComponents()
        utc.year = 2026; utc.month = 9; utc.day = 23; utc.hour = 23; utc.minute = 30
        var kalenderUTC = Calendar(identifier: .gregorian)
        kalenderUTC.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let datum = kalenderUTC.date(from: utc) ?? Date()
        // 23:30 UTC ist am 24.09. bereits 01:30 in Berlin (Sommerzeit, UTC+2).
        XCTAssertEqual(Datum.text(datum), "2026-09-24")
    }

    func testTageZwischenUeberZeitumstellung() {
        // 25.10.2026: deutsche Uhren stellen von Sommer- auf Normalzeit zurück.
        XCTAssertEqual(Datum.tageZwischen("2026-10-24", "2026-10-26"), 2)
    }
}
