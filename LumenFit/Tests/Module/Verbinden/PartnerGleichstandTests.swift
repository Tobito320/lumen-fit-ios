import XCTest
@testable import LumenFit

/// Gleichstand Health, Partner-Teil: erweiterte Zusammenfassung (nur mit Freigabe), Vergleichsrechnung, Anzeige-Regeln und die Zusatzwerte aus den Stores.
@MainActor
final class PartnerGleichstandTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt   // Donnerstag 29.10.2026, 10:00
    private let heute = "2026-10-29"

    private func eingabe(_ frei: Set<FreigabeArt>) -> ZusammenfassungBauer.Eingabe {
        ZusammenfassungBauer.Eingabe(
            name: "Beispiel Profil", jetzt: jetzt, freigaben: frei, schritte: 8_000, gymTageWoche: 2, schlafMinuten: 450, kcal: 1_900, ereignisse: [],
            schritteZiel: 10_000, schritteWoche: ["2026-10-26": 7_000, "2026-10-29": 8_000], gymTage: ["2026-10-28", "2026-10-26"], gymZiel: 3,
            schlafWoche: ["2026-10-29": 450], schlafZiel: 480, energieStufe: "mittel", energieGym: "Gym ja", habitsFertig: ["gym", "wasser"], wasserGlaeser: 5)
    }

    private func datei(_ frei: [FreigabeArt], aendere: (inout TagesZusammenfassung) -> Void = { _ in }) -> ZusammenfassungDatei {
        var heuteWerte = TagesZusammenfassung(tag: heute, schritte: 8_000, gymTageWoche: 2, schlafMinuten: 450, kcal: 1_900)
        aendere(&heuteWerte)
        return ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Beispiel Partner", freigaben: frei, heute: heuteWerte, ereignisse: [])
    }

    // MARK: Bauer

    func testErweiterungenBrauchenDieFreigabeIhrerArt() {
        XCTAssertEqual(ZusammenfassungBauer.baue(eingabe([])).heute, TagesZusammenfassung(tag: heute))
        let schritte = ZusammenfassungBauer.baue(eingabe([.schritte])).heute
        XCTAssertEqual(schritte.schritteZiel, 10_000)
        XCTAssertEqual(schritte.schritteWoche?.count, 2)
        XCTAssertNil(schritte.gymTage)
        XCTAssertNil(schritte.energieStufe)
        XCTAssertNil(schritte.habitsFertig)
        let gym = ZusammenfassungBauer.baue(eingabe([.gym])).heute
        XCTAssertEqual(gym.gymTage, ["2026-10-26", "2026-10-28"], "sortiert")
        XCTAssertEqual(gym.gymZiel, 3)
        XCTAssertEqual(gym.habitsFertig, ["gym"], "Wasser gehört zur Freigabe essen")
        XCTAssertNil(gym.energieStufe)
        let essen = ZusammenfassungBauer.baue(eingabe([.essen])).heute
        XCTAssertEqual(essen.habitsFertig, ["wasser"])
        XCTAssertEqual(essen.wasserGlaeser, 5, "Wassergläser nur mit Freigabe essen")
        XCTAssertNil(gym.wasserGlaeser)
    }

    func testEnergieHaengtAmSchlafUndIhrGymSatzZusaetzlichAmGym() {
        let schlaf = ZusammenfassungBauer.baue(eingabe([.schlaf])).heute
        XCTAssertEqual(schlaf.energieStufe, "mittel")
        XCTAssertNil(schlaf.energieGym, "ohne Freigabe gym kein Gym-Satz")
        XCTAssertEqual(schlaf.schlafWoche, ["2026-10-29": 450])
        XCTAssertEqual(schlaf.schlafZiel, 480)
        let beide = ZusammenfassungBauer.baue(eingabe([.schlaf, .gym])).heute
        XCTAssertEqual(beide.energieGym, "Gym ja")
        XCTAssertNil(ZusammenfassungBauer.baue(eingabe([.gym])).heute.energieGym, "Gym allein verrät die Energie nicht")
    }

    func testAlteDateiOhneNeueFelderBleibtLesbar() throws {
        let alt = #"{"version":1,"geschrieben":"2026-10-29T08:00:00.000Z","profilName":"Alt","freigaben":["schritte"],"heute":{"tag":"2026-10-29","schritte":5000},"ereignisse":[]}"#
        let d = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: Data(alt.utf8))
        XCTAssertEqual(d.heute.schritte, 5_000)
        XCTAssertNil(d.heute.schritteWoche)
        XCTAssertNil(d.heute.energieStufe)
        XCTAssertNil(d.heute.habitsFertig)
    }

    func testNeueFelderUeberlebenSchreibenUndLesen() throws {
        let original = ZusammenfassungBauer.baue(eingabe(Set(FreigabeArt.allCases)))
        let zurueck = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: LoveaVertrag.encoder().encode(original))
        XCTAssertEqual(zurueck, original)
    }

    // MARK: Anzeige

    func testEnergieSatzNurMitFreigabeUndBekannterStufe() {
        let d = datei([.schlaf, .gym]) { $0.energieStufe = "hoch"; $0.energieGym = "Gym ja" }
        XCTAssertEqual(PartnerAnzeige.energieSatz(d), "Viel Energie heute, Gym ja")
        XCTAssertEqual(PartnerAnzeige.energieSatz(datei([.schlaf]) { $0.energieStufe = "niedrig"; $0.energieGym = "Heute besser kein Gym" }), "Heute eher wenig Energie")
        XCTAssertNil(PartnerAnzeige.energieSatz(datei([.gym]) { $0.energieStufe = "hoch" }), "ohne Freigabe schlaf nichts")
        XCTAssertNil(PartnerAnzeige.energieSatz(datei([.schlaf]) { $0.energieStufe = "unbekannt" }), "eine neue Stufe zeigt nichts")
        XCTAssertNil(PartnerAnzeige.energieSatz(datei([.schlaf])))
    }

    func testHabitFertigNurFuerEingebauteMitFreigabe() {
        let d = datei([.gym]) { $0.habitsFertig = ["gym", "wasser"] }
        XCTAssertTrue(PartnerAnzeige.habitFertig(d, id: "gym"))
        XCTAssertFalse(PartnerAnzeige.habitFertig(d, id: "wasser"), "Wasser braucht die Freigabe essen")
        XCTAssertFalse(PartnerAnzeige.habitFertig(d, id: "dehnen"))
        XCTAssertTrue(PartnerAnzeige.habitFertig(datei([.essen]) { $0.habitsFertig = ["wasser"] }, id: "wasser"))
    }

    func testGymTageNurMitFreigabe() {
        XCTAssertEqual(PartnerAnzeige.gymTage(datei([.gym]) { $0.gymTage = ["2026-10-28"] }), ["2026-10-28"])
        XCTAssertTrue(PartnerAnzeige.gymTage(datei([.schritte]) { $0.gymTage = ["2026-10-28"] }).isEmpty)
    }

    func testVorschauNenntDieEnergie() {
        let d = datei([.schlaf]) { $0.energieStufe = "mittel" }
        XCTAssertTrue(FreigabenVorschau.zeilen(d).contains { $0.titel == "Energie" && $0.wert == "Normale Energie" })
    }

    // MARK: Schritte-Vergleich

    func testSchritteWocheRechnetDifferenzJeTagUndGesamt() throws {
        let partner = datei([.schritte]) { $0.schritteWoche = ["2026-10-26": 6_000, "2026-10-27": 9_000, "2026-10-29": 4_000] }
        let mein = ["2026-10-26": 8_000, "2026-10-27": 5_000, "2026-10-28": 3_000]
        let woche = try XCTUnwrap(PartnerVergleich.schritteWoche(heute: heute, mein: mein, datei: partner))
        XCTAssertEqual(woche.tage.map(\.kuerzel), ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
        XCTAssertEqual(woche.tage[0].differenz, 2_000)
        XCTAssertEqual(woche.tage[1].differenz, -4_000)
        XCTAssertNil(woche.tage[2].differenz, "Mittwoch: nur ich hatte einen Wert")
        XCTAssertNil(woche.tage[3].differenz, "Donnerstag: ich habe noch keinen Wert")
        XCTAssertEqual(woche.meinGesamt, 16_000)
        XCTAssertEqual(woche.seinGesamt, 19_000)
        XCTAssertEqual(woche.differenz, -3_000)
        XCTAssertEqual(woche.hoechster, 9_000)
    }

    func testZukunftHatKeineWerteUndOhneFreigabeGibtEsKeinenVergleich() throws {
        let partner = datei([.schritte]) { $0.schritteWoche = ["2026-10-30": 99_999, "2026-10-29": 1_000] }
        let woche = try XCTUnwrap(PartnerVergleich.schritteWoche(heute: heute, mein: [:], datei: partner))
        XCTAssertTrue(woche.tage[4].zukunft)
        XCTAssertNil(woche.tage[4].sein, "ein Wert aus der Zukunft zählt nicht")
        XCTAssertNil(PartnerVergleich.schritteWoche(heute: heute, mein: [:], datei: datei([.gym]) { $0.schritteWoche = ["2026-10-29": 1_000] }))
    }

    func testOhneWochenwerteZaehltDerWertVonHeute() throws {
        let woche = try XCTUnwrap(PartnerVergleich.schritteWoche(heute: heute, mein: [heute: 2_000], datei: datei([.schritte])))
        XCTAssertEqual(woche.tage[3].sein, 8_000)
        XCTAssertEqual(woche.tage[3].differenz, -6_000)
    }

    func testDifferenzTextUndAuswahl() {
        XCTAssertEqual(PartnerVergleich.differenzText(1_234), "+1.234")
        XCTAssertEqual(PartnerVergleich.differenzText(-567), "\u{2212}567")
        XCTAssertEqual(PartnerVergleich.differenzText(0), "\u{00B1}0")
        let tage = [PartnerVergleich.SchrittTag(tag: "2026-10-26", kuerzel: "Mo", mein: 1, sein: 2, zukunft: false)]
        XCTAssertEqual(PartnerVergleich.tag(zu: "Mo", in: tage)?.tag, "2026-10-26")
        XCTAssertNil(PartnerVergleich.tag(zu: nil, in: tage))
        XCTAssertNil(PartnerVergleich.tag(zu: "Di", in: tage))
    }

    // MARK: Schlaf "Ihr beide"

    func testSchlafWocheNurMitFreigabeSchlaf() throws {
        let partner = datei([.schlaf]) { $0.schlafWoche = ["2026-10-27": 420] }
        let woche = try XCTUnwrap(PartnerVergleich.schlafWoche(heute: heute, mein: ["2026-10-27": 400, "2026-10-29": 480], datei: partner))
        XCTAssertEqual(woche.count, 7)
        XCTAssertEqual(woche[1].sein, 420)
        XCTAssertEqual(woche[1].mein, 400)
        XCTAssertEqual(woche[3].sein, 450, "die letzte Nacht aus dem Wert von heute")
        XCTAssertTrue(woche[3].istHeute)
        XCTAssertEqual(PartnerVergleich.schlafHoechster(woche), 480)
        XCTAssertNil(PartnerVergleich.schlafWoche(heute: heute, mein: [:], datei: datei([.schritte])))
    }

    func testSchlafAnteil() {
        XCTAssertEqual(PartnerVergleich.schlafAnteil(240, hoechster: 480), 0.5)
        XCTAssertEqual(PartnerVergleich.schlafAnteil(600, hoechster: 480), 1)
        XCTAssertNil(PartnerVergleich.schlafAnteil(nil, hoechster: 480))
        XCTAssertEqual(PartnerVergleich.schlafHoechster([]), 480)
    }

    // MARK: Zusatzwerte aus den Stores

    func testTageswerteSammelnWocheGymUndEnergie() async throws {
        let daten = try VerbindenTest.daten(self)
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: "2026-10-27", schritte: 6_000), TagesWerte(tag: heute, schritte: 8_200)])
        let gesundheit = GesundheitsStand(leser: leser, uhr: { VerbindenTest.jetzt })
        await gesundheit.aktualisiere()
        for op in TestDaten.gymOps(start: jetzt.addingTimeInterval(-7200), session: "s1") { daten.raum.einreihen(op) }
        let w = PartnerTageswerte.sammle(daten: daten, gesundheit: gesundheit, jetzt: jetzt)
        XCTAssertEqual(w.schritteWoche, ["2026-10-27": 6_000, heute: 8_200])
        XCTAssertEqual(w.gymTage, [heute])
        XCTAssertTrue(w.habitsFertig.contains("gym"))
        XCTAssertNotNil(w.energie)
    }
}
