import XCTest
@testable import LumenFit

/// Chat-Menü und Anzeige: neue Felder des lokalen Stands, Wunschzeilen für das Modell, Diagrammlogik, Kachel, Anzeige-Hilfen und der Fluss
/// Pause, Verlauf ausblenden, Vorschlag bestätigen.
@MainActor
final class CoachMenueTests: XCTestCase {
    // MARK: - Einstellungen

    func testNeueFelderHabenStandardwerteUndBleibenInAltenDateienLesbar() throws {
        let ordner = try tempOrdner()
        try Data(#"{"name":"Lumi"}"#.utf8).write(to: ordner.appendingPathComponent("coach.json"))
        let e = CoachEinstellungen(ordner: ordner)
        XCTAssertFalse(e.stand.pause)
        XCTAssertEqual(e.stand.ton, "")
        XCTAssertEqual(e.stand.ziel, "")
        XCTAssertTrue(e.stand.morgenAn)
        XCTAssertFalse(e.stand.disziplin)
        XCTAssertNil(e.stand.ausgeblendetBis)
        XCTAssertEqual(e.stand.haken, [])
    }

    func testMenuewerteBleibenNachNeuemLaden() throws {
        let ordner = try tempOrdner()
        let e = CoachEinstellungen(ordner: ordner)
        e.setzePause(true)
        e.setzeTon("knapp")
        e.setzeZiel("Dreimal pro Woche trainieren")
        e.setzeMorgen(false)
        e.setzeDisziplin(true)
        e.haken("a/b", an: true)
        let neu = CoachEinstellungen(ordner: ordner)
        XCTAssertTrue(neu.stand.pause)
        XCTAssertEqual(neu.stand.ton, "knapp")
        XCTAssertEqual(neu.stand.ziel, "Dreimal pro Woche trainieren")
        XCTAssertFalse(neu.stand.morgenAn)
        XCTAssertTrue(neu.stand.disziplin)
        XCTAssertTrue(neu.istAbgehakt("a/b"))
    }

    func testUnbekannterTonWirdStandardUndZielWirdEinzeiligUndKurz() {
        let e = CoachEinstellungen()
        e.setzeTon("laut")
        XCTAssertEqual(e.stand.ton, "")
        XCTAssertEqual(CoachEinstellungen.zielBereinigen("  Ein Ziel\nin zwei Zeilen "), "Ein Ziel in zwei Zeilen")
        XCTAssertEqual(CoachEinstellungen.zielBereinigen(String(repeating: "x", count: 500)).count, CoachEinstellungen.maxZiel)
        XCTAssertEqual(CoachEinstellungen.zielBereinigen("   "), "")
    }

    // MARK: - Gedächtnis

    func testFindeSuchtErstNachSchluesselDannNachText() {
        let liste = ["Linkes Knie schonen", "Mag kein Fleisch"]
        XCTAssertEqual(CoachGedaechtnisRegeln.finde(CoachLokal.schluessel("Mag kein Fleisch"), in: liste), "Mag kein Fleisch")
        XCTAssertEqual(CoachGedaechtnisRegeln.finde("linkes knie schonen", in: liste), "Linkes Knie schonen")
        XCTAssertNil(CoachGedaechtnisRegeln.finde("gibt es nicht", in: liste))
        XCTAssertNil(CoachGedaechtnisRegeln.finde("  ", in: liste))
    }

    // MARK: - Wünsche im Prompt

    func testWunschZeilen() {
        var anfrage = CoachTestBau.anfrage("Hallo")
        XCTAssertTrue(CoachModellPrompt.wunschZeilen(anfrage).isEmpty)
        anfrage.ton = "knapp"
        anfrage.ziel = "Dreimal pro Woche trainieren"
        anfrage.disziplin = true
        let zeilen = CoachModellPrompt.wunschZeilen(anfrage)
        XCTAssertEqual(zeilen.count, 3)
        XCTAssertTrue(zeilen[0].contains("knapp"))
        XCTAssertTrue(zeilen[1].contains("Dreimal pro Woche trainieren"))
        anfrage.ton = "unbekannt"
        XCTAssertEqual(CoachModellPrompt.wunschZeilen(anfrage).count, 2)
    }

    // MARK: - Diagramm

    func testGleicheBeschriftungenBekommenGetrennteSpalten() {
        let spalten = CoachDiagrammLogik.spalten([.init(label: "Mo", wert: 1), .init(label: "Mo", wert: 2), .init(label: "Di", wert: 3)])
        XCTAssertEqual(Set(spalten).count, 3)
        XCTAssertEqual(spalten[2], "Di")
    }

    func testBalkenFangenBeiNullAnUndLinieZoomt() {
        let punkte: [CoachMarker.Punkt] = [.init(label: "a", wert: 78), .init(label: "b", wert: 80)]
        XCTAssertEqual(CoachDiagrammLogik.wertebereich(punkte, linie: false).lowerBound, 0)
        let linie = CoachDiagrammLogik.wertebereich(punkte, linie: true)
        XCTAssertGreaterThan(linie.lowerBound, 50)
        XCTAssertLessThan(linie.lowerBound, 78)
        XCTAssertGreaterThan(linie.upperBound, 80)
    }

    // MARK: - Anzeige

    func testZahlUndKopierText() {
        XCTAssertEqual(CoachAnzeige.zahl(8200), "8.200")
        XCTAssertEqual(CoachAnzeige.zahl(82.4), "82,4")
        XCTAssertEqual(CoachAnzeige.kopierText("Das ist **wichtig**. [[weiter: Mehr?]]"), "Das ist wichtig.")
        XCTAssertEqual(CoachAnzeige.klartext("Das ist **wichtig**"), "Das ist wichtig")
    }

    func testRingFuehrtZurSeiteZumLabel() {
        XCTAssertEqual(CoachMarker.Ziel.fuer(label: "Schritte heute"), .schritte)
        XCTAssertEqual(CoachMarker.Ziel.fuer(label: "Schlaf"), .schlaf)
        XCTAssertEqual(CoachMarker.Ziel.fuer(label: "Protein"), .essen)
        XCTAssertNil(CoachMarker.Ziel.fuer(label: "Laune"))
    }

    func testKachelText() {
        XCTAssertEqual(CoachKachelText.inhalt(pausiert: true, erstesThema: "Schritte").titel, "Pausiert")
        XCTAssertEqual(CoachKachelText.inhalt(pausiert: false, erstesThema: "Schritte").untertitel, "Schritte")
        XCTAssertEqual(CoachKachelText.inhalt(pausiert: false, erstesThema: "  ").titel, "Frag mich")
        XCTAssertFalse(CoachKachelText.inhalt(pausiert: false, erstesThema: nil).untertitel.isEmpty)
    }

    // MARK: - Modell

    func testPauseSperrtDasSendenUndDasWeckenGibtEsFrei() throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: FakeCoachMotor(texte: ["Hallo"]))
        let modell = CoachModell(umgebung: u)
        modell.setzePause(true)
        XCTAssertTrue(modell.pausiert)
        modell.senden("Wie war mein Schlaf?")
        XCTAssertFalse(modell.denkt)
        XCTAssertTrue(modell.verlauf.isEmpty)
        modell.setzePause(false)
        XCTAssertFalse(modell.pausiert)
        modell.senden("Wie war mein Schlaf?")
        XCTAssertTrue(modell.denkt)
    }

    func testVerlaufAusblendenLeertDenChatAberNichtDenSpeicher() throws {
        let (u, daten, uhr) = try CoachTestBau.umgebung()
        daten.coach.haenge(CoachTestBau.nachricht("n1", .nutzer, "Hallo", uhr.uhr().addingTimeInterval(-60)))
        let modell = CoachModell(umgebung: u)
        XCTAssertEqual(modell.heute.count, 1)
        modell.verlaufAusblenden()
        XCTAssertTrue(modell.heute.isEmpty)
        XCTAssertTrue(modell.sichtbarerVerlauf.isEmpty)
        XCTAssertEqual(modell.verlauf.count, 1, "gespeichert bleibt es")
        XCTAssertGreaterThan(modell.warnungSignal, 0)
    }

    func testAufgabeAbhakenUndWiederAufmachen() throws {
        let (u, _, uhr) = try CoachTestBau.umgebung()
        let modell = CoachModell(umgebung: u)
        let n = CoachTestBau.nachricht("n1", .coach, "- [ ] Dehnen", uhr.uhr())
        XCTAssertFalse(modell.istAbgehakt(n, "Dehnen"))
        modell.schalteHaken(n, "Dehnen")
        XCTAssertTrue(modell.istAbgehakt(n, "Dehnen"))
        modell.schalteHaken(n, "Dehnen")
        XCTAssertFalse(modell.istAbgehakt(n, "Dehnen"))
    }

    func testVorschlagVerwerfenLeertDieKarte() async throws {
        let (u, _, _) = try CoachTestBau.umgebung(motor: FakeCoachMotor(texte: ["Trink was. [[wasser: 250]]"]))
        let modell = CoachModell(umgebung: u)
        modell.senden("Ich habe Durst")
        let ende = Date().addingTimeInterval(10)
        while modell.denkt, Date() < ende { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(modell.vorschlag, [.wasser(glaeser: 1)])
        modell.vorschlagVerwerfen()
        XCTAssertTrue(modell.vorschlag.isEmpty)
    }
}
