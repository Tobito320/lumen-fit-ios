import XCTest
@testable import LumenFit

/// Vorschlag fürs nächste Training (Idee 34): frischeste Muskeln plus verfügbare Zeit, der heutige Plantag gewinnt, solange er erholt genug ist.
final class NaechstesTrainingTests: XCTestCase {
    private let bank = Uebung(id: "bank", name: "Bankdrücken", en: "bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: [])
    private let kniebeuge = Uebung(id: "knie", name: "Kniebeuge", en: "squat", muskel: "Quadrizeps", koerper: "Beine", geraet: "Langhantel", neben: [])
    private let latzug = Uebung(id: "lat", name: "Latzug", en: "lat pulldown", muskel: "Latissimus", koerper: "Rücken", geraet: "Kabelzug", neben: [])

    private func katalog(_ id: String) -> Uebung? { [bank.id: bank, kniebeuge.id: kniebeuge, latzug.id: latzug][id] }

    private func tag(_ name: String, _ ids: [String]) -> TrainingsTag {
        TrainingsTag(id: name, name: name, wochentage: [3], uebungen: ids.enumerated().map {
            PlanUebung(id: "u\($0.offset)", uebung: $0.element, name: nil, saetze: [], minuten: nil)
        })
    }

    func testOhnePlanGewinntDieFrischesteArt() throws {
        let erholung: [MuskelTeil: Int] = [.bUnten: 40, .rLat: 30, .baGerade: 50, .biLang: 20]
        let v = try XCTUnwrap(NaechstesTraining.vorschlag(erholung: erholung, plantag: nil, minuten: 45, katalog: katalog))
        XCTAssertEqual(v.art, .beine)
        XCTAssertEqual(v.titel, "Heute Beine, 45 Minuten")
        XCTAssertEqual(v.begruendung, "Beine sind zu 100 Prozent erholt, am meisten von allen.")
        XCTAssertEqual(v.saetze, 10) // 45 min = 10 min Aufwärmen + 10 × 3,5 min
    }

    func testErholterPlantagGewinntMitBegruendung() throws {
        let plan = tag("Push", ["bank"])
        let erholung: [MuskelTeil: Int] = [.bUnten: 70, .rLat: 40]
        let v = try XCTUnwrap(NaechstesTraining.vorschlag(erholung: erholung, plantag: plan, minuten: 60, katalog: katalog))
        XCTAssertEqual(v.art, .druecken)
        XCTAssertEqual(v.titel, "Heute Brust und Schulter, 60 Minuten")
        XCTAssertEqual(v.begruendung, "Das steht heute im Plan, und Brust und Schulter sind zu 90 Prozent erholt. Rücken und Bizeps sind erst zu 80 Prozent erholt.")
    }

    func testMuederPlantagWirdDurchFrischesteArtErsetztUndGesagt() throws {
        let plan = tag("Push", ["bank"])
        let erholung: [MuskelTeil: Int] = [.bUnten: 10, .sVorne: 10, .triSeitlich: 10]
        let v = try XCTUnwrap(NaechstesTraining.vorschlag(erholung: erholung, plantag: plan, minuten: 45, katalog: katalog))
        XCTAssertEqual(v.art, .beine)
        XCTAssertEqual(v.begruendung, "Beine sind zu 100 Prozent erholt, am meisten von allen. Dein Plan sieht Brust und Schulter vor, aber Brust und Schulter sind erst zu 10 Prozent erholt.")
    }

    func testOhneTrainingMitPlantagFolgtDemPlan() throws {
        let v = try XCTUnwrap(NaechstesTraining.vorschlag(erholung: [:], plantag: tag("Beine", ["knie"]), minuten: 45, katalog: katalog))
        XCTAssertEqual(v.art, .beine)
    }

    func testOhneTrainingUndOhnePlanKeinVorschlag() {
        XCTAssertNil(NaechstesTraining.vorschlag(erholung: [:], plantag: nil, minuten: 45, katalog: katalog))
        XCTAssertNil(NaechstesTraining.vorschlag(erholung: [:], plantag: tag("Leer", []), minuten: 45, katalog: katalog))
    }

    func testMinutenBleibenImBereich() throws {
        let erholung: [MuskelTeil: Int] = [.bUnten: 40]
        XCTAssertEqual(NaechstesTraining.vorschlag(erholung: erholung, plantag: nil, minuten: 5, katalog: katalog)?.minuten, 15)
        XCTAssertEqual(NaechstesTraining.vorschlag(erholung: erholung, plantag: nil, minuten: 500, katalog: katalog)?.minuten, 120)
    }

    func testErholungDerArtIstDerMittelwertDerGruppen() {
        XCTAssertEqual(NaechstesTraining.erholung(.druecken, [.bUnten: 40]), (40 + 100 + 100) / 3)
        XCTAssertEqual(NaechstesTraining.erholung(.beine, [.beQuads: 55, .beWaden: 100]), 55, "die Gruppe ist so erholt wie ihr schlechtester Teil")
        XCTAssertEqual(NaechstesTraining.erholung(.rumpf, [:]), 100)
    }

    func testArtDesPlantagsIstDieHaeufigsteDerHauptmuskeln() {
        XCTAssertEqual(NaechstesTraining.art(tag("Beine", ["knie", "knie", "bank"]), katalog: katalog), .beine)
        XCTAssertEqual(NaechstesTraining.art(tag("Zug", ["lat"]), katalog: katalog), .ziehen)
        XCTAssertNil(NaechstesTraining.art(tag("Leer", []), katalog: katalog))
        XCTAssertNil(NaechstesTraining.art(tag("Fremd", ["unbekannt"]), katalog: katalog))
    }

    func testJedeGruppeGehoertZuGenauEinerArt() {
        for g in MuskelGruppe.allCases {
            XCTAssertEqual(NaechstesTraining.Art.allCases.filter { $0.gruppen.contains(g) }.count, g == .unterarme ? 0 : 1, g.name)
        }
        XCTAssertEqual(NaechstesTraining.Art.fuer(.unterarme), .ziehen, "Unterarme laufen beim Ziehen mit")
        XCTAssertEqual(NaechstesTraining.Art.fuer(.trizeps), .druecken)
    }
}
