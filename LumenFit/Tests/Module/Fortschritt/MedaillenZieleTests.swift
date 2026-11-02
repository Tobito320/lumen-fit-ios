import XCTest
@testable import LumenFit

/// Ziel-Medaillen (Runde "Mehrheit"): Wochenziel, Schritte, Protein, Kalorien; dazu Lumis Stufe, die Ansicht nach Bereich und der stille Start.
final class MedaillenZieleTests: XCTestCase {
    /// Mittwoch 14.10.2026.
    private let heute = "2026-10-14"

    private func faellig(_ d: MeilensteinDaten, schon: Set<String> = []) -> [String] { MeilensteinPruefung.faellig(d, schon: schon) }

    private func tage(_ von: String, _ anzahl: Int, wert: Int) -> [String: Int] {
        var m: [String: Int] = [:]
        for i in 0..<anzahl { m[Datum.addTage(von, i)] = wert }
        return m
    }

    // MARK: Wochenziel Gym

    func testWochenzielZaehltWochenInFolgeMitErreichtemZiel() {
        // Ziel 3 Tage, vier Wochen ab Montag 14.09. mit je Mo, Di, Mi.
        var gym: [String: Int] = [:]
        for w in 0..<4 { for t in 0..<3 { gym[Datum.addTage("2026-09-14", w * 7 + t)] = 1 } }
        let d = MeilensteinDaten(gymTage: gym, gymTageProWoche: 3, heute: heute)
        XCTAssertTrue(faellig(d).contains("wochenziel-4"))
        XCTAssertFalse(faellig(d).contains("wochenziel-12"))
        XCTAssertFalse(faellig(MeilensteinDaten(gymTage: gym, gymTageProWoche: 4, heute: heute)).contains("wochenziel-4"), "Ziel 4 Tage: keine Woche erreicht")
    }

    func testEineLueckeBrichtDieFolgeAberDieLaengsteBleibt() {
        var gym: [String: Int] = [:]
        for w in [0, 1, 3, 4, 5] { for t in 0..<3 { gym[Datum.addTage("2026-09-07", w * 7 + t)] = 1 } }
        let z = MeilensteinPruefung.zahlen(MeilensteinDaten(gymTage: gym, gymTageProWoche: 3, heute: heute))
        XCTAssertEqual(z.wochenzielSerie, 3, "die Folge 3 bis 5 zählt; die kürzere vorher nicht")
    }

    // MARK: Schritte

    func testSchrittZielSiebenTageInFolgeUndDreissigTageInsgesamt() {
        let sieben = MeilensteinDaten(heute: heute, schritte: tage("2026-10-06", 7, wert: 10_000), schrittZiel: 10_000)
        XCTAssertTrue(faellig(sieben).contains("schritte-7"))
        XCTAssertFalse(faellig(sieben).contains("schritte-30"))
        XCTAssertFalse(faellig(MeilensteinDaten(heute: heute, schritte: tage("2026-10-06", 7, wert: 9_999), schrittZiel: 10_000)).contains("schritte-7"))
        var verstreut: [String: Int] = [:]
        for i in 0..<45 where i % 3 != 2 { verstreut[Datum.addTage("2026-08-01", i)] = 12_000 }
        let d = MeilensteinDaten(heute: heute, schritte: verstreut, schrittZiel: 10_000)
        XCTAssertTrue(faellig(d).contains("schritte-30"))
        XCTAssertFalse(faellig(d).contains("schritte-7"))
        XCTAssertTrue(faellig(MeilensteinDaten(heute: heute, schritte: ["2026-10-13": 5], schrittZiel: 0)).isEmpty, "ohne Ziel kein Abzeichen")
    }

    // MARK: Protein und Kalorien

    private func essen(_ von: String, _ anzahl: Int, kcal: Double, protein: Double, ziel: (Int, Int) = (2_000, 120)) -> [String: EssenTagWerte] {
        var m: [String: EssenTagWerte] = [:]
        for i in 0..<anzahl { m[Datum.addTage(von, i)] = EssenTagWerte(kcal: kcal, protein: protein, zielKcal: ziel.0, zielProtein: ziel.1) }
        return m
    }

    func testProteinBrauchtEingerichteteEssensziele() {
        let werte = essen("2026-10-06", 7, kcal: 2_000, protein: 130)
        XCTAssertTrue(faellig(MeilensteinDaten(heute: heute, essenWerte: werte, essenZielDa: true)).contains("protein-7"))
        XCTAssertEqual(faellig(MeilensteinDaten(heute: heute, essenWerte: werte, essenZielDa: false)), [], "ohne Ziel nichts")
        XCTAssertFalse(faellig(MeilensteinDaten(heute: heute, essenWerte: essen("2026-10-06", 7, kcal: 2_000, protein: 119), essenZielDa: true)).contains("protein-7"))
        XCTAssertEqual(MeilensteinPruefung.ohneZiel(essenZielDa: false), ["protein-7", "protein-30", "kalorien-7"])
        XCTAssertTrue(MeilensteinPruefung.ohneZiel(essenZielDa: true).isEmpty)
    }

    func testKalorienImRahmenInBeideRichtungenUndHeuteZaehltNicht() {
        let im = MeilensteinDaten(heute: heute, essenWerte: essen("2026-10-06", 7, kcal: 1_800, protein: 0), essenZielDa: true)
        XCTAssertTrue(faellig(im).contains("kalorien-7"), "90 Prozent liegen im Rahmen")
        XCTAssertFalse(faellig(MeilensteinDaten(heute: heute, essenWerte: essen("2026-10-06", 7, kcal: 1_600, protein: 0), essenZielDa: true)).contains("kalorien-7"), "80 Prozent sind zu wenig")
        XCTAssertFalse(faellig(MeilensteinDaten(heute: heute, essenWerte: essen("2026-10-06", 7, kcal: 2_500, protein: 0), essenZielDa: true)).contains("kalorien-7"), "125 Prozent sind zu viel")
        // Sechs volle Tage plus der heutige halbe: noch nicht.
        let mitHeute = essen("2026-10-08", 7, kcal: 2_000, protein: 0)
        XCTAssertEqual(MeilensteinPruefung.zahlen(MeilensteinDaten(heute: heute, essenWerte: mitHeute, essenZielDa: true)).kalorienTage, 6, "der 14. ist heute und zählt nicht")
    }

    // MARK: Stiller Start

    func testStummIstWasSchonGesternGalt() {
        let alt = MeilensteinDaten(heute: heute, schritte: tage("2026-10-01", 7, wert: 11_000), schrittZiel: 10_000)
        XCTAssertEqual(MeilensteinPruefung.stumm(faellig(alt), alt), ["schritte-7"], "Altdaten nach dem Update: vergeben, aber ohne Toast")
        let heuteErst = MeilensteinDaten(heute: heute, schritte: tage("2026-10-08", 7, wert: 11_000), schrittZiel: 10_000)
        XCTAssertEqual(faellig(heuteErst), ["schritte-7"])
        XCTAssertTrue(MeilensteinPruefung.stumm(faellig(heuteErst), heuteErst).isEmpty, "der siebte Tag ist heute: das ist ein Fest")
    }

    func testAlteMedaillenBleibenLaut() {
        let d = MeilensteinDaten(sessions: [], gymTage: ["2026-10-01": 1], heute: heute)
        XCTAssertTrue(MeilensteinPruefung.stumm(["erster-satz", "gym-10"], d).isEmpty, "nur Ziel-Medaillen werden still vergeben")
    }

    // MARK: Lumis Stufe

    func testZielMedaillenHebenLumisStufeNie() {
        let alte = MeilensteinKatalog.alle.map(\.id).filter { !MeilensteinKatalog.neueIds.contains($0) }
        XCTAssertEqual(alte.count, 25)
        XCTAssertEqual(MeilensteinKatalog.stufenZahl(alte), 25)
        XCTAssertEqual(MeilensteinKatalog.stufenZahl(alte + Array(MeilensteinKatalog.neueIds)), 25)
        XCTAssertEqual(LumiStufe.stufe(erreicht: MeilensteinKatalog.stufenZahl(Array(alte.prefix(10)) + ["schritte-7", "protein-30"])), LumiStufe.stufe(erreicht: 10))
        XCTAssertEqual(MeilensteinKatalog.stufenZahl(["gibt-es-nicht", "erster-satz"]), 2, "unbekannte Kennungen zählen wie bisher")
        XCTAssertEqual(MeilensteinKatalog.stufenZahl(Array(MeilensteinKatalog.neueIds)), 0)
    }

    @MainActor
    func testStoreStufeZaehltNurDieAltenMedaillen() throws {
        let s = DatenSatz(profil: .testA, ordner: try tempOrdner(), ereignisse: EreignisKanal(), uhr: TestUhr().uhr)
        s.meilensteine.markiere("erster-satz")
        XCTAssertEqual(s.meilensteine.stufe, 2)
        for id in MeilensteinKatalog.neueIds { s.meilensteine.markiere(id) }
        XCTAssertEqual(s.meilensteine.stufe, 2, "acht neue Medaillen ändern die Stufe nicht")
        XCTAssertEqual(s.meilensteine.erreicht.count, 9)
    }

    // MARK: Ansicht nach Bereich

    private func alleIds(_ a: [MedaillenAbschnitt]) -> [String] {
        a.flatMap { $0.eintraege.flatMap { e -> [String] in
            switch e {
            case .einzel(let m): [m.id]
            case .reihe(_, let ms): ms.map(\.id)
            }
        } }
    }

    func testAlleBereicheZeigenJedeMedailleGenauEinmalInFuenfAbschnitten() {
        let a = MedaillenAnsicht.abschnitte(zeigt: { _ in true }, erreicht: [])
        XCTAssertEqual(a.map(\.gruppe), [.gym, .schritte, .schlaf, .essen, .koerper])
        XCTAssertEqual(alleIds(a).sorted(), MeilensteinKatalog.alle.map(\.id).sorted())
        XCTAssertTrue(MedaillenAnsicht.reihen.allSatisfy { r in r.stufen.allSatisfy { MeilensteinKatalog.nachId[$0] != nil } }, "jede Reihe nennt echte Kennungen")
    }

    func testAusgeschalteteBereicheVerschwindenSchritteUndKoerperBleiben() {
        let ohneSchlaf = MedaillenAnsicht.abschnitte(zeigt: { $0 != .schlaf }, erreicht: ["schlaf-7"])
        XCTAssertFalse(ohneSchlaf.map(\.gruppe).contains(.schlaf))
        XCTAssertFalse(alleIds(ohneSchlaf).contains("schlaf-7"), "auch eine erreichte Schlaf-Medaille ist weg, die Daten bleiben")
        let nurGym = MedaillenAnsicht.abschnitte(zeigt: { $0 == .gym }, erreicht: [])
        XCTAssertEqual(nurGym.map(\.gruppe), [.gym, .schritte, .koerper])
        XCTAssertFalse(alleIds(nurGym).contains("tagebuch-7"))
    }

    func testMedailleOhneZielFehltAberErreichteBleibt() {
        let ohne = MeilensteinPruefung.ohneZiel(essenZielDa: false)
        XCTAssertFalse(alleIds(MedaillenAnsicht.abschnitte(zeigt: { _ in true }, erreicht: [], ohneZiel: ohne)).contains("protein-7"))
        XCTAssertTrue(alleIds(MedaillenAnsicht.abschnitte(zeigt: { _ in true }, erreicht: ["protein-7"], ohneZiel: ohne)).contains("protein-7"))
        let a = MedaillenAnsicht.abschnitte(zeigt: { _ in true }, erreicht: [], ohneZiel: ohne)
        let essen = a.first { $0.gruppe == .essen }?.eintraege
        XCTAssertFalse(essen?.contains { if case .reihe(let r, _) = $0 { r.id == "protein" } else { false } } ?? true, "die Protein-Reihe fehlt ganz")
    }

    func testReihenSindEineKarteMitStufennamen() {
        let a = MedaillenAnsicht.abschnitte(zeigt: { _ in true }, erreicht: [])
        let gym = a.first { $0.gruppe == .gym }?.eintraege ?? []
        let reihen = gym.compactMap { e -> MedaillenReihe? in if case .reihe(let r, _) = e { r } else { nil } }
        XCTAssertEqual(reihen.map(\.id), ["gym", "volumen", "serie", "rekorde", "wochenziel"])
        XCTAssertEqual((0..<3).map { MedaillenAnsicht.stufenName($0, von: 3) }, ["Bronze", "Silber", "Gold"])
        XCTAssertEqual((0..<2).map { MedaillenAnsicht.stufenName($0, von: 2) }, ["Bronze", "Gold"])
        XCTAssertEqual(MedaillenAnsicht.stufenName(3, von: 4), "Platin")
    }

    func testZaehlungNenntNurWasDieSeiteZeigt() {
        let a = MedaillenAnsicht.abschnitte(zeigt: { $0 == .gym }, erreicht: ["erster-satz", "schlaf-7"])
        let z = MedaillenAnsicht.zaehlung(a, erreicht: ["erster-satz", "schlaf-7"])
        XCTAssertEqual(z.erreicht, 1, "schlaf-7 ist ausgeblendet")
        XCTAssertEqual(z.gesamt, MeilensteinKatalog.alle.filter { $0.gruppe == .gym || $0.gruppe == .schritte || $0.gruppe == .koerper }.count)
    }

    func testFortschrittsZaehlerGibtEsFuerJedeReiheMitZaehlbarenStufen() {
        let z = MeilensteinZahlen()
        for id in ["wochenziel-4", "schritte-7", "schritte-30", "protein-7", "protein-30", "kalorien-7"] {
            XCTAssertNotNil(LumiPfad.zaehler(id, z), id)
        }
        XCTAssertFalse(MeilensteinKatalog.neueIds.contains(LumiPfad.naechstesZiel(z, schon: [])?.meilenstein.id ?? ""), "Ziel-Medaillen sind nie das nächste Stufen-Ziel")
    }
}

/// Der Wächter gegen einen echten Datensatz: Ziel-Medaillen aus Altdaten still, neue laut, ausgeblendete Bereiche ohne Toast.
@MainActor
final class MedaillenZieleWaechterTests: XCTestCase {
    private let uhr = TestUhr()
    private var heute: String { Datum.text(uhr.lesen) }

    private func satz() throws -> DatenSatz { DatenSatz(profil: .testA, ordner: try tempOrdner(), ereignisse: EreignisKanal(), uhr: uhr.uhr) }

    private func schritte(bisHeuteTage n: Int, endetAm ende: String) -> [String: Int] {
        var m: [String: Int] = [:]
        for i in 0..<n { m[Datum.addTage(ende, -i)] = 12_000 }
        return m
    }

    func testAltdatenNachDemUpdateVergebenOhneToast() throws {
        let s = try satz()
        let w = MeilensteinWaechter()
        let neu = w.pruefe(s, naechte: [:], schritte: schritte(bisHeuteTage: 7, endetAm: Datum.addTage(heute, -1)), heute: heute)
        XCTAssertEqual(neu, ["schritte-7"])
        XCTAssertTrue(s.meilensteine.istErreicht("schritte-7"))
        XCTAssertNil(w.toast, "kein Medaillen-Regen")
        XCTAssertEqual(w.stufenZaehler, 0)
        XCTAssertEqual(w.pruefe(s, naechte: [:], schritte: schritte(bisHeuteTage: 7, endetAm: Datum.addTage(heute, -1)), heute: heute), [], "kein zweites Mal")
    }

    func testDerSiebteTagHeuteZeigtDenToastOhneNeueStufe() throws {
        let s = try satz()
        let w = MeilensteinWaechter()
        w.pruefe(s, naechte: [:], schritte: schritte(bisHeuteTage: 6, endetAm: Datum.addTage(heute, -1)), heute: heute)
        XCTAssertNil(w.toast)
        XCTAssertEqual(w.pruefe(s, naechte: [:], schritte: schritte(bisHeuteTage: 7, endetAm: heute), heute: heute), ["schritte-7"])
        XCTAssertEqual(w.toast?.titel, "Neue Medaille: 7 Tage Schrittziel")
        XCTAssertEqual(s.meilensteine.stufe, 1)
        XCTAssertEqual(w.stufenZaehler, 0)
    }

    func testAusgeblendeterBereichVergibtStillOhneToast() throws {
        let s = try satz()
        let w = MeilensteinWaechter()
        var naechte: [String: SchlafNacht] = [:]
        for i in 0..<7 {
            let tag = Datum.addTage(heute, -i)
            let ende = Datum.datum(tag).addingTimeInterval(7 * 3600)
            naechte[tag] = SchlafNacht(tag: tag, von: ende.addingTimeInterval(-500 * 60), bis: ende, abschnitte: [], schlafMinuten: 500)
        }
        XCTAssertEqual(w.pruefe(s, naechte: naechte, heute: heute, sichtbar: { $0 != .schlaf }), ["schlaf-7"])
        XCTAssertNil(w.toast?.zeile, "die Medaille selbst wird nicht genannt, nur Lumis neue Stufe")
        XCTAssertTrue(s.meilensteine.istErreicht("schlaf-7"), "die Medaille wird trotzdem vergeben")
    }
}
