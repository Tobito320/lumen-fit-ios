// Quelle: Lovea Health/Tests/CoachGedaechtnisTests.swift
import XCTest
@testable import LumenFit

/// Health-Coach, Gedächtnis (`CoachGedaechtnis.swift`): Regeln aus Lovea (Text, Grenzen, Doppelte) und der Merkzettel über dem echten `CoachStore`.
/// Nicht übernommen: Ids, Plan der Marker und Faltung der Ops mit `seq` (Lumen Fit hat keinen Server; der Text ist der Schlüssel).
@MainActor
final class CoachGedaechtnisTests: XCTestCase {
    private typealias Regeln = CoachGedaechtnisRegeln
    private let uhr = TestUhr()

    private func satz(_ ordner: URL) -> DatenSatz {
        DatenSatz(profil: .testA, ordner: ordner, ereignisse: EreignisKanal(), uhr: uhr.uhr)
    }

    private func stand(_ anzahl: Int) -> [String] { (0..<anzahl).map { "Eintrag \($0)" } }

    // MARK: - Regeln

    func testSauberTrimmtUndPrueftLaengeKlammernUndZeilenumbruch() {
        XCTAssertEqual(Regeln.sauber("  Mag Hähnchen \n"), "Mag Hähnchen")
        XCTAssertNil(Regeln.sauber("ab"))
        XCTAssertEqual(Regeln.sauber("abc"), "abc")
        XCTAssertEqual(Regeln.sauber(String(repeating: "x", count: 200))?.count, 200)
        XCTAssertNil(Regeln.sauber(String(repeating: "x", count: 201)))
        XCTAssertNil(Regeln.sauber("a [[b"))
        XCTAssertNil(Regeln.sauber("a ]] b"))
        XCTAssertNil(Regeln.sauber("zwei\nZeilen"))
    }

    func testEinzeiligMachtAusZeilenumbruechenLeerzeichen() {
        XCTAssertEqual(Regeln.einzeilig("zwei\nZeilen"), "zwei Zeilen")
        XCTAssertEqual(Regeln.einzeilig("zwei\n\nZeilen"), "zwei Zeilen")
        XCTAssertEqual(Regeln.einzeilig("a\r\nbcd"), "a bcd")
        XCTAssertNil(Regeln.einzeilig(" \n "))
        XCTAssertNil(Regeln.einzeilig("a [[b\nc"))
    }

    func testHinzufuegenLehntDubletteUngueltigesUndVollesAb() {
        XCTAssertEqual(Regeln.hinzufuegen("  Mag Hähnchen ", bestehend: []), "Mag Hähnchen")
        XCTAssertEqual(Regeln.hinzufuegen("zwei\nZeilen", bestehend: []), "zwei Zeilen")
        XCTAssertNil(Regeln.hinzufuegen("mag HÄHNCHEN", bestehend: ["Mag Hähnchen"]), "Groß und klein zählen gleich")
        XCTAssertNil(Regeln.hinzufuegen("ab", bestehend: []))
        let voll = stand(40)
        XCTAssertNil(Regeln.hinzufuegen("Nummer 41", bestehend: voll), "bei 40 fällt der neue weg, nie der älteste")
        XCTAssertEqual(Regeln.hinzufuegen("Nummer 40", bestehend: Array(voll.prefix(39))), "Nummer 40")
    }

    func testAendernLehntDoppeltenTextEinesAnderenAb() {
        XCTAssertEqual(Regeln.aendern("Mag Fisch", andere: ["Mag Hähnchen"]), "Mag Fisch")
        XCTAssertNil(Regeln.aendern("mag hähnchen", andere: ["Mag Hähnchen"]))
        XCTAssertNil(Regeln.aendern("x", andere: []))
    }

    // MARK: - Merkwunsch aus einer Frage (Idee 64)

    func testMerkWunschNurBeiKlaremWunschOderZiel() {
        XCTAssertEqual(Regeln.merkWunsch(in: "Merk dir, dass ich Knieprobleme habe"), "ich Knieprobleme habe")
        XCTAssertEqual(Regeln.merkWunsch(in: "merke dir: ich trainiere montags"), "ich trainiere montags")
        XCTAssertEqual(Regeln.merkWunsch(in: "Bitte merk dir mein Lieblingsgericht ist Reis"), "mein Lieblingsgericht ist Reis")
        XCTAssertEqual(Regeln.merkWunsch(in: "Mein Ziel ist es, 5 km zu laufen"), "Ziel: es, 5 km zu laufen")
        XCTAssertNil(Regeln.merkWunsch(in: "Mein Knie tut weh"), "Beschwerden merkt der Coach nie von allein")
        XCTAssertNil(Regeln.merkWunsch(in: "Wie läuft mein Training?"))
        XCTAssertNil(Regeln.merkWunsch(in: "Merk dir"), "nichts zu merken")
    }

    // MARK: - Merkzettel über dem echten Store

    func testMerkzettelUeberlebtDenNeustartUndIstNeuesteZuerst() throws {
        let ordner = try tempOrdner()
        let erster = satz(ordner)
        let g = CoachGedaechtnis(store: erster.coach)
        XCTAssertEqual(g.hinzufuegen("Linkes Knie vorsichtig belasten"), "Linkes Knie vorsichtig belasten")
        XCTAssertEqual(g.hinzufuegen("Mag Hähnchen"), "Mag Hähnchen")
        XCTAssertEqual(g.eintraege, ["Mag Hähnchen", "Linkes Knie vorsichtig belasten"])

        let zweiter = CoachGedaechtnis(store: satz(ordner).coach)
        XCTAssertEqual(zweiter.eintraege, ["Mag Hähnchen", "Linkes Knie vorsichtig belasten"])
    }

    func testDoppeltesUngueltigesUndVollesWirdAbgelehnt() throws {
        let g = CoachGedaechtnis(store: satz(try tempOrdner()).coach)
        XCTAssertNotNil(g.hinzufuegen("Mag Hähnchen"))
        XCTAssertNil(g.hinzufuegen("mag hähnchen"))
        XCTAssertNil(g.hinzufuegen("ab"))
        for i in 1..<CoachGedaechtnis.maxEintraege { XCTAssertNotNil(g.hinzufuegen("Eintrag \(i)")) }
        XCTAssertEqual(g.eintraege.count, 40)
        XCTAssertNil(g.hinzufuegen("Nummer 41"))
    }

    func testAendernLoeschenUndWiederherstellen() throws {
        let g = CoachGedaechtnis(store: satz(try tempOrdner()).coach)
        g.hinzufuegen("Mag Fisch")
        g.hinzufuegen("Mag Hähnchen")
        XCTAssertTrue(g.aendern("Mag Fisch", zu: "Isst gern Fisch"))
        XCTAssertEqual(Set(g.eintraege), ["Isst gern Fisch", "Mag Hähnchen"])
        XCTAssertFalse(g.aendern("Isst gern Fisch", zu: "mag hähnchen"), "doppelt")
        XCTAssertFalse(g.aendern("Gibt es nicht", zu: "Neuer Text"))
        g.loeschen("Mag Hähnchen")
        XCTAssertEqual(g.eintraege, ["Isst gern Fisch"])
        g.wiederherstellen("Mag Hähnchen")
        XCTAssertTrue(g.eintraege.contains("Mag Hähnchen"))
    }

    func testMerkeAusFrageSchreibtInDenStore() throws {
        let daten = satz(try tempOrdner())
        let g = CoachGedaechtnis(store: daten.coach)
        XCTAssertEqual(g.merkeAusFrage("Merk dir, dass ich abends trainiere"), "ich abends trainiere")
        XCTAssertEqual(daten.coach.merkzettel, ["ich abends trainiere"])
        XCTAssertNil(g.merkeAusFrage("Wie läuft mein Training?"))
    }

    func testDerMerkzettelGehtInDenKontextDesCoachs() throws {
        let u = AppUmgebung.vorschau(uhr: uhr.uhr)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)
        daten.coach.merke("Linkes Knie vorsichtig belasten")
        XCTAssertEqual(CoachDaten.kontext(u, daten).merkzettel, ["Linkes Knie vorsichtig belasten"])
    }
}
