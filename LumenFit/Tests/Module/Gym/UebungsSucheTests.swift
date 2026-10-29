// Quelle: Lovea Tests/UebungsSucheTests.swift
import XCTest
@testable import LumenFit

/// Suche (Synonyme, Muskel-Zuordnung, Tippfehler), Standard-Gerätefilter und die eigenen `lv-`-Einträge.
/// Der Katalog kommt über `Bundle(for:)` (Bundle.main ist im XCTest leer, siehe `UebungsKatalogTests`).
final class UebungsSucheTests: XCTestCase {
    private let alle = UebungsKatalog.laden(Bundle(for: BundleAnker.self))

    /// Suchbegriff, erwartete id, unter den ersten `top` Treffern.
    private let faelle: [(text: String, id: String, top: Int)] = [
        ("upper chest", "3TZduzM", 3),       // Schrägbankdrücken mit Langhantel
        ("obere Brust", "ns0SIbU", 3),       // Schrägbankdrücken mit Kurzhanteln
        ("triceps", "3ZflifB", 3),           // Trizeps-Pushdown am Kabelzug
        ("Trizeps", "3ZflifB", 3),
        ("quads", "my33uHU", 1),             // Beinstrecker an der Maschine
        ("Beinstrecker", "my33uHU", 1),
        ("Oberschenkel", "my33uHU", 3),
        ("lats", "RVwzP10", 3),              // Latzug am Kabelzug
        ("rear delts", "myfUsKf", 1),        // Reverse Fliegende sitzend an der Maschine
        ("glutes", "qKBpF7I", 3),            // Gesäßbrücke mit Langhantel
        ("Po", "qKBpF7I", 3),
        ("Gesäß", "qKBpF7I", 3),
        ("hamstrings", "17lJ1kr", 2),        // Beinbeuger liegend an der Maschine
        ("pull up", "lBDjFxJ", 1),           // Klimmzug
        ("pec deck", "v3xmPAR", 1),          // Fliegende sitzend an der Maschine
        ("butterfly", "v3xmPAR", 3),
        ("Bankdrücken", "EIeI8Vf", 1),
        ("bankdruecken", "EIeI8Vf", 1),
        ("Schulterdruecken", "znQUdHY", 3),
        ("hip thrust", "lv-hip-thrust-kurzhantel", 2),
        ("face pull", "lv-face-pull", 1),
        ("bulgarische Kniebeuge", "lv-bulgarisch-kurzhantel", 2),
        ("Beinpresse", "lv-beinpresse-sitzend", 8),
        ("Hackenschmidt", "2ORFMoR", 6),     // Wadenheben an der Hackenschmidt-Maschine
        ("kh bizeps curl", "ae9UoXQ", 6),    // Curls schräg mit Kurzhanteln
    ]

    func testSearchFindsGermanAndEnglishTerms() {
        XCTAssertGreaterThanOrEqual(faelle.count, 15)
        for f in faelle {
            let treffer = UebungsKatalog.suchen(f.text, in: alle).prefix(f.top).map(\.id)
            XCTAssertTrue(treffer.contains(f.id), "\(f.text): \(f.id) nicht unter den ersten \(f.top), sondern \(Array(treffer))")
        }
    }

    func testSearchToleratesTyposAndUmlautSpellings() {
        for (tippfehler, richtig) in [("bizepz", "bizeps"), ("trizpes", "trizeps"), ("kniebeugn", "kniebeuge"), ("Gesaess", "gesäß")] {
            let treffer = UebungsKatalog.suchen(tippfehler, in: alle)
            XCTAssertFalse(treffer.isEmpty, tippfehler)
            XCTAssertEqual(Array(treffer.prefix(3)), Array(UebungsKatalog.suchen(richtig, in: alle).prefix(3)), tippfehler)
        }
        XCTAssertEqual(UebungsKatalog.suchen("Schraegbankdruecken", in: alle).first?.id,
                       UebungsKatalog.suchen("Schrägbankdrücken", in: alle).first?.id)
    }

    func testMuscleSearchOnlyReturnsThatMuscleGroup() {
        // "po" meint das Gesäß, nicht jedes Wort mit "po" drin.
        let po = UebungsKatalog.suchen("po", in: alle).prefix(10)
        XCTAssertTrue(po.allSatisfy { $0.muskel == "Po" || $0.koerper == "Beine" }, "\(po.map(\.name))")
        let obereBrust = UebungsKatalog.suchen("obere brust", in: alle)
        XCTAssertTrue(obereBrust.allSatisfy { $0.koerper == "Brust" })
    }

    func testNoHitsForNonsense() {
        XCTAssertTrue(UebungsKatalog.suchen("xqzvbn", in: alle).isEmpty)
    }

    func testStandardFilterShowsFreeWeightsAndMachines() {
        func u(_ geraet: String) -> Uebung { Uebung(id: geraet, name: geraet, en: geraet, muskel: "Brust", koerper: "Brust", geraet: geraet, neben: []) }
        for geraet in ["Kurzhantel", "Langhantel", "Kabelzug", "Maschine", "Multipresse"] {
            XCTAssertTrue(UebungsKatalog.passtGeraet(u(geraet), wahl: nil), geraet)
        }
        for geraet in ["Band", "Kettlebell", "Körpergewicht", "Widerstandsband", "Bosu-Ball"] {
            XCTAssertFalse(UebungsKatalog.passtGeraet(u(geraet), wahl: nil), geraet)
            XCTAssertTrue(UebungsKatalog.passtGeraet(u(geraet), wahl: UebungsKatalog.alleGeraete), geraet)
            XCTAssertTrue(UebungsKatalog.passtGeraet(u(geraet), wahl: geraet), geraet)
        }
        XCTAssertFalse(UebungsKatalog.passtGeraet(u("Band"), wahl: "Kurzhantel"))
        let standard = alle.filter { UebungsKatalog.passtGeraet($0, wahl: nil) }
        XCTAssertGreaterThan(standard.count, 300)
        XCTAssertLessThan(standard.count, alle.count)
    }

    func testOwnEntriesAreAdditiveAndComplete() throws {
        let eigene = alle.filter { $0.id.hasPrefix("lv-") }
        XCTAssertEqual(eigene.count, 9)
        XCTAssertEqual(Set(alle.map(\.id)).count, alle.count, "doppelte ids")
        for u in eigene {
            XCTAssertFalse(UebungsKatalog.hatVideo(u.id), u.id)
            XCTAssertFalse(u.name.isEmpty || u.en.isEmpty || u.muskel.isEmpty || u.koerper.isEmpty || u.geraet.isEmpty, u.id)
        }
        XCTAssertTrue(UebungsKatalog.hatVideo("EIeI8Vf"))
        // Bestehende ids (Pläne hängen daran) bleiben.
        for id in UebungsKatalog.beliebt { XCTAssertTrue(alle.contains { $0.id == id }, id) }
    }

    func testOwnEntriesHaveNoMedia() async {
        let datei = await UebungsMedien.datei("lv-face-pull")
        XCTAssertNil(datei)
    }
}
