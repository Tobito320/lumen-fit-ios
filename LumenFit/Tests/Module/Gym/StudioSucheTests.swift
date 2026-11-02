import XCTest
@testable import LumenFit

/// Erfundene Studios ("Studio A" ...), keine echten Namen, keine Koordinaten.
@MainActor
final class StudioSucheTests: XCTestCase {
    private func treffer(_ name: String, _ m: Double?) -> StudioTreffer { StudioTreffer(name: name, entfernungM: m) }

    func testNaechstesStudioStehtZuerst() {
        let liste = StudioSucheLogik.ordne([treffer("Studio C", 3_200), treffer("Studio A", 250), treffer("Studio B", 900)])
        XCTAssertEqual(liste.map(\.name), ["Studio A", "Studio B", "Studio C"])
    }

    func testOhneAbstandKommtNachHinten() {
        let liste = StudioSucheLogik.ordne([treffer("Studio D", nil), treffer("Studio A", 5_000), treffer("Studio E", nil)])
        XCTAssertEqual(liste.map(\.name), ["Studio A", "Studio D", "Studio E"])
    }

    func testOhneAbstandBleibtDieReihenfolgeDerQuelle() {
        let liste = StudioSucheLogik.ordne([treffer("Studio E", nil), treffer("Studio D", nil)])
        XCTAssertEqual(liste.map(\.name), ["Studio E", "Studio D"])
    }

    func testGleicherNameEinmalUndNaeherGewinnt() {
        let liste = StudioSucheLogik.ordne([treffer("Studio A", 4_000), treffer("studio a", 800), treffer(" Studio A ", 9_000)])
        XCTAssertEqual(liste, [treffer("studio a", 800)])
    }

    func testLeereNamenUndZuWeitWegFliegenRaus() {
        let liste = StudioSucheLogik.ordne([treffer("  ", 100), treffer("Studio F", StudioSucheLogik.maxEntfernungM + 1), treffer("Studio G", StudioSucheLogik.maxEntfernungM)])
        XCTAssertEqual(liste.map(\.name), ["Studio G"])
    }

    func testHoechstensAchtTreffer() {
        let roh = (0..<20).map { treffer("Studio \($0)", Double($0) * 100) }
        let liste = StudioSucheLogik.ordne(roh)
        XCTAssertEqual(liste.count, StudioSucheLogik.maxTreffer)
        XCTAssertEqual(liste.first?.name, "Studio 0")
    }

    func testEntfernungText() {
        XCTAssertEqual(StudioSucheLogik.entfernungText(0), "0 m")
        XCTAssertEqual(StudioSucheLogik.entfernungText(347), "350 m")
        XCTAssertEqual(StudioSucheLogik.entfernungText(1_240), "1,2 km")
        XCTAssertEqual(StudioSucheLogik.entfernungText(9_960), "10,0 km")
        XCTAssertEqual(StudioSucheLogik.entfernungText(12_400), "12 km")
    }

    // MARK: Modell mit Fake

    func testModellZeigtGeordneteTrefferDesPorts() async {
        let modell = StudioSucheModell(port: FakeStudioSuche(antwort: [treffer("Studio B", 700), treffer("Studio A", 100)]))
        await modell.aktualisiere(text: "stu")
        XCTAssertEqual(modell.treffer.map(\.name), ["Studio A", "Studio B"])
    }

    func testOhneErlaubnisKommenTrefferOhneAbstandUndEineLeereListeIstKeinFehler() async {
        let ohneAbstand = StudioSucheModell(port: FakeStudioSuche(antwort: [treffer("Studio A", nil)]))
        await ohneAbstand.aktualisiere(text: "stu")
        XCTAssertEqual(ohneAbstand.treffer, [treffer("Studio A", nil)])
        let leer = StudioSucheModell(port: FakeStudioSuche(antwort: []))
        await leer.aktualisiere(text: "stu")
        XCTAssertTrue(leer.treffer.isEmpty)
    }

    func testUebernehmenLiefertDenNamenUndLoeschtDieListe() async {
        let fake = FakeStudioSuche(antwort: [treffer("Studio A", 100)])
        let modell = StudioSucheModell(port: fake)
        await modell.aktualisiere(text: "stu")
        let name = modell.uebernehme(modell.treffer[0])
        XCTAssertEqual(name, "Studio A")
        XCTAssertTrue(modell.treffer.isEmpty)
        // Der übernommene Name löst keine neue Suche aus.
        await modell.aktualisiere(text: "Studio A")
        XCTAssertTrue(modell.treffer.isEmpty)
        XCTAssertEqual(fake.anfragen, ["stu"])
    }

    func testLeererTextFragtDenPortTrotzdemNachDemNaechsten() async {
        let fake = FakeStudioSuche(antwort: [treffer("Studio A", 100)])
        let modell = StudioSucheModell(port: fake)
        await modell.aktualisiere(text: "  ")
        XCTAssertEqual(fake.anfragen, [""])
        XCTAssertEqual(modell.treffer.count, 1)
    }
}

@MainActor
private final class FakeStudioSuche: StudioSuchPort {
    let antwort: [StudioTreffer]
    private(set) var anfragen: [String] = []

    init(antwort: [StudioTreffer]) { self.antwort = antwort }

    func suche(text: String) async -> [StudioTreffer] {
        anfragen.append(text)
        return antwort
    }
}
