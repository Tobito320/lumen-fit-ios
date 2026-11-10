import XCTest
@testable import LumenFit

/// Training-Tab im neuen Design: Kurzversion, Lumi-Zeile, Plan-Woche, Katalog-Chips, Split-Tage-Chips.
final class GymTabLogikTests: XCTestCase {
    private func uebung(_ id: String, saetze: Int = 3) -> PlanUebung {
        PlanUebung(id: id, uebung: "EIeI8Vf", name: id, saetze: Array(repeating: PlanSatz(wdh: 10, kg: nil, failure: false), count: saetze), minuten: nil)
    }

    private func tag(_ n: Int, id: String = "t") -> TrainingsTag {
        TrainingsTag(id: id, name: "Ganzkörper B", wochentage: [4], uebungen: (0..<n).map { uebung("u\($0)") })
    }

    /// Fake-Schätzung nach der neuen Regel (10 min + 3,5 min je Satz): unabhängig von der Formel in `ZeitSchaetzung`.
    private let neueRegel: (TrainingsTag) -> Int = { t in Int(10 + 3.5 * Double(t.uebungen.reduce(0) { $0 + $1.saetze.count })) }

    func testKurzversionNimmtDieErstenUebungenBisDreissigMinuten() {
        // 2 Übungen × 3 Sets = 31 min, gerundet 30: passt. 3 Übungen = 41,5 -> 40: zu lang.
        let kurz = GymTabLogik.kurzversion(tag(5), minuten: neueRegel)
        XCTAssertEqual(kurz.uebungen.map(\.id), ["u0", "u1"])
        XCTAssertEqual(GymTabLogik.kurzWeg(tag(5), minuten: neueRegel), ["u2", "u3", "u4"])
        XCTAssertTrue(GymTabLogik.kurzLohnt(tag(5), minuten: neueRegel))
    }

    func testKurzversionHatImmerMindestensEineUebung() {
        let lang = TrainingsTag(id: "t", name: "", wochentage: [], uebungen: [uebung("a", saetze: 10), uebung("b")])
        XCTAssertEqual(GymTabLogik.kurzversion(lang, minuten: neueRegel).uebungen.map(\.id), ["a"])
    }

    func testKurzLohntNichtWennDerTagSchonPasst() {
        XCTAssertFalse(GymTabLogik.kurzLohnt(tag(1), minuten: neueRegel))
        XCTAssertTrue(GymTabLogik.kurzWeg(tag(1), minuten: neueRegel).isEmpty)
        XCTAssertFalse(GymTabLogik.kurzLohnt(tag(0), minuten: neueRegel))
    }

    func testRundAufFuenfMinuten() {
        XCTAssertEqual(GymTabLogik.rund(31), 30)
        XCTAssertEqual(GymTabLogik.rund(33), 35)
        XCTAssertEqual(GymTabLogik.rund(0), 5)
    }

    func testLumiZeileNachZustand() {
        XCTAssertEqual(GymTabLogik.lumi(laeuft: true, heuteGemacht: true, tagName: "Push").stimmung, .anfeuern)
        XCTAssertEqual(GymTabLogik.lumi(laeuft: false, heuteGemacht: true, tagName: "Push").stimmung, .ziel)
        let bereit = GymTabLogik.lumi(laeuft: false, heuteGemacht: false, tagName: "Ganzkörper B")
        XCTAssertEqual(bereit.stimmung, .bereit)
        XCTAssertTrue(bereit.satz.contains("Ganzkörper B"))
        XCTAssertEqual(GymTabLogik.lumi(laeuft: false, heuteGemacht: false, tagName: nil).stimmung, .ruhetag)
    }

    func testPlanWocheZaehltAbDerErstenEinheitMitDemPlan() {
        let plan = TrainingsPlan(tage: [tag(3, id: "a")])
        let heute = "2026-11-12" // Donnerstag
        XCTAssertNil(GymTabLogik.planWoche(plan, sessions: [], heute: heute))
        let fremd = GymSession(id: "x", tag: "alt", start: Datum.datum("2026-09-01"), ende: nil, laeufe: [])
        XCTAssertNil(GymTabLogik.planWoche(plan, sessions: [fremd], heute: heute))
        let diese = GymSession(id: "s1", tag: "a", start: Datum.datum("2026-11-10"), ende: nil, laeufe: [])
        XCTAssertEqual(GymTabLogik.planWoche(plan, sessions: [diese], heute: heute), 1)
        let frueher = GymSession(id: "s0", tag: "a", start: Datum.datum("2026-10-22"), ende: nil, laeufe: [])
        XCTAssertEqual(GymTabLogik.planWoche(plan, sessions: [diese, frueher, fremd], heute: heute), 4)
    }

    func testKatalogChipsFassenTeileZusammen() {
        let wade = Uebung(id: "w", name: "Wadenheben", en: "calf raise", muskel: "Waden", koerper: "Waden", geraet: "Maschine", neben: [])
        XCTAssertTrue(GymKatalogChip.beine.passt(wade))
        XCTAssertFalse(GymKatalogChip.brust.passt(wade))
        let unterarm = Uebung(id: "u", name: "Handgelenkcurl", en: "wrist curl", muskel: "Unterarme", koerper: "Unterarme", geraet: "Kurzhantel", neben: [])
        XCTAssertTrue(GymKatalogChip.arme.passt(unterarm))
    }

    func testGanzkoerperSindGrunduebungenMitLast() {
        let kreuzheben = Uebung(id: "k", name: "Kreuzheben", en: "deadlift", muskel: "Po", koerper: "Beine", geraet: "Langhantel", neben: ["Rückenstrecker", "Beinbeuger"])
        XCTAssertTrue(GymKatalogChip.ganzkoerper.passt(kreuzheben))
        let dehnung = Uebung(id: "d", name: "Dehnung", en: "stretch", muskel: "Rückenstrecker", koerper: "Rücken", geraet: "Körpergewicht", neben: ["Po"])
        XCTAssertFalse(GymKatalogChip.ganzkoerper.passt(dehnung))
        let curl = Uebung(id: "c", name: "Curl", en: "curl", muskel: "Bizeps", koerper: "Arme", geraet: "Kurzhantel", neben: ["Unterarme"])
        XCTAssertFalse(GymKatalogChip.ganzkoerper.passt(curl))
        XCTAssertFalse(UebungsKatalog.alle.filter(GymKatalogChip.ganzkoerper.passt).isEmpty)
    }

    func testCardioChipIstMitStandardGeraetenNichtLeer() {
        let wahl = GymKatalogChip.cardio.geraetWahl(nil)
        let cardio = UebungsKatalog.alle.filter { GymKatalogChip.cardio.passt($0) && UebungsKatalog.passtGeraet($0, wahl: wahl) }
        XCTAssertFalse(cardio.isEmpty)
        XCTAssertNil(GymKatalogChip.brust.geraetWahl(nil))
        XCTAssertEqual(GymKatalogChip.cardio.geraetWahl("Kabelzug"), "Kabelzug")
    }

    func testSplitTageChips() {
        XCTAssertTrue(GymTabLogik.TageChip.zweiDrei.passt(2))
        XCTAssertTrue(GymTabLogik.TageChip.zweiDrei.passt(3))
        XCTAssertFalse(GymTabLogik.TageChip.vier.passt(3))
        XCTAssertTrue(GymTabLogik.TageChip.fuenfPlus.passt(6))
    }

    func testMuskelHilfeUebungenGehoerenZurGruppe() {
        let brust = GymMuskelHilfe.uebungen(.brust)
        XCTAssertFalse(brust.isEmpty)
        XCTAssertTrue(brust.allSatisfy { GymTabLogik.gruppe($0) == .brust })
        XCTAssertTrue(GymMuskelHilfe.vonHinten(.ruecken))
        XCTAssertFalse(GymMuskelHilfe.vonHinten(.brust))
    }
}
