import XCTest
@testable import LumenFit

/// Das Heute-Modell mit gewähltem Tag und festem Datum (`TestUhr`: Mittwoch, 23.09.2026, 12:00 Berlin).
@MainActor
final class HeuteTagWahlModellTests: XCTestCase {
    private let uhr = TestUhr()
    private let heute = "2026-09-23"
    private let gestern = "2026-09-22"
    private let vorgestern = "2026-09-21"

    private func umgebung(leser: FakeHealthLeser = FakeHealthLeser()) throws -> AppUmgebung {
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: leser, healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        try u.profil.anlegen(name: "Test", passwort: "abcd")
        return u
    }

    private func wasser(_ m: HeuteModell) -> Int? { m.stand?.habits.first { $0.id == "wasser" }?.wert }

    func testStandardIstHeuteUndZurueckZuHeuteFindetHeim() async throws {
        let u = try umgebung()
        u.daten?.habits.setzeWasser(datum: heute, anzahl: 2)
        u.daten?.habits.setzeWasser(datum: vorgestern, anzahl: 5)
        let m = HeuteModell(umgebung: u)
        m.berechne()
        XCTAssertEqual(m.stand?.tag, heute)
        XCTAssertEqual(m.stand?.istHeute, true)
        XCTAssertNil(m.gewaehlterTag)

        m.waehleTag(vorgestern)
        XCTAssertEqual(m.stand?.tag, vorgestern)
        XCTAssertEqual(m.stand?.istHeute, false)
        XCTAssertEqual(m.stand?.stunde, 23, "ein vergangener Tag ist zu Ende")
        XCTAssertEqual(wasser(m), 5)
        XCTAssertEqual(m.stand?.woche.first?.tag, "2026-09-21")

        m.zuHeute()
        XCTAssertEqual(m.stand?.tag, heute)
        XCTAssertEqual(m.stand?.istHeute, true)
        XCTAssertNil(m.gewaehlterTag, "heute folgt wieder der Uhr")
        XCTAssertEqual(wasser(m), 2)
    }

    func testZukunftUndZuAlteTageWerdenGekappt() throws {
        let m = HeuteModell(umgebung: try umgebung())
        m.waehleTag("2026-09-30")
        XCTAssertEqual(m.stand?.tag, heute)
        XCTAssertNil(m.gewaehlterTag)
        m.waehleTag("2019-01-01")
        XCTAssertEqual(m.stand?.tag, HeuteTagWahl.aeltester(heute: heute))
    }

    func testDerGewaehlteTagBleibtBeiNeuemRechnenUndWirdMitDerUhrNichtZurZukunft() throws {
        let m = HeuteModell(umgebung: try umgebung())
        m.waehleTag(gestern)
        uhr.setze(Datum.datum("2026-09-25").addingTimeInterval(8 * 3600))
        m.berechne()
        XCTAssertEqual(m.stand?.tag, gestern, "der gewählte Tag bleibt, auch wenn die Uhr weiterläuft")
        XCTAssertEqual(m.stand?.istHeute, false)
    }

    func testSchritteGehoerenZumTagUndHeutigeWerteSickernNichtDurch() async throws {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 9_000), TagesWerte(tag: gestern, schritte: 3_000)])
        let m = HeuteModell(umgebung: try umgebung(leser: leser))
        await m.lade()
        XCTAssertEqual(m.stand?.schritte.schritte, 9_000)
        m.waehleTag(gestern)
        XCTAssertEqual(m.stand?.schritte.schritte, 3_000)
        XCTAssertEqual(m.stand?.hatTagesdaten, true)
        m.waehleTag(vorgestern)
        XCTAssertEqual(m.stand?.schritte.schritte, 0)
        XCTAssertEqual(m.stand?.hatTagesdaten, false, "kein Wert an diesem Tag: der Tab sagt es ehrlich")
    }

    func testEineEintragungMachtDenTagZumTagMitDaten() throws {
        let u = try umgebung()
        let m = HeuteModell(umgebung: u)
        m.waehleTag(vorgestern)
        XCTAssertEqual(m.stand?.hatTagesdaten, false)
        u.daten?.habits.setzeWasser(datum: vorgestern, anzahl: 1)
        m.berechne()
        XCTAssertEqual(m.stand?.hatTagesdaten, true)
    }

    func testGewichtZeigtDenStandDesTages() throws {
        let u = try umgebung()
        let daten = try XCTUnwrap(u.daten)
        daten.habits.setze(Habit.gewicht.id, datum: "2026-09-10", wert: 800)
        daten.habits.setze(Habit.gewicht.id, datum: "2026-09-22", wert: 780)
        let m = HeuteModell(umgebung: u)
        m.waehleTag("2026-09-15")
        let g = try XCTUnwrap(m.stand?.gewicht)
        XCTAssertEqual(g.aktuellKg ?? 0, 80.0, accuracy: 0.0001, "damals galt 80,0, nicht der spätere Wert")
        XCTAssertEqual(g.punkte.map(\.tag), ["2026-09-10"])
        XCTAssertFalse(g.heuteEingetragen)
        m.waehleTag("2026-09-22")
        XCTAssertEqual(m.stand?.gewicht.aktuellKg ?? 0, 78.0, accuracy: 0.0001)
        XCTAssertEqual(m.stand?.gewicht.heuteEingetragen, true, "an dem Tag eingetragen")
    }

    func testHakenAufEinemVergangenenTagSchreibenNurDiesenTag() throws {
        let u = try umgebung()
        u.daten?.habits.setzeWasser(datum: heute, anzahl: 2)
        let m = HeuteModell(umgebung: u)
        m.waehleTag(gestern)
        let zeile = try XCTUnwrap(m.stand?.habits.first { $0.id == "wasser" })
        m.tippe(zeile)
        XCTAssertEqual(wasser(m), 1)
        m.zuHeute()
        XCTAssertEqual(wasser(m), 2, "heute bleibt unberührt")
        XCTAssertEqual(u.daten?.habits.wert("wasser", gestern), 1)
    }

    func testGefuehlWirdNurHeuteGespeichert() throws {
        let m = HeuteModell(umgebung: try umgebung())
        m.waehleTag(gestern)
        m.speichereGefuehl(4)
        XCTAssertNil(m.stand?.energie.gefuehl, "für einen vergangenen Tag gibt es keine Gefühls-Zeile von jetzt")
        m.zuHeute()
        XCTAssertNil(m.stand?.energie.gefuehl, "und heute wurde dadurch nichts gespeichert")
        m.speichereGefuehl(4)
        XCTAssertEqual(m.stand?.energie.gefuehl, 4)
    }
}
