// Quelle: Lovea Health/Tests/EssenAuftragTests.swift (angepasst auf die Lumen-Typen)
import UIKit
import XCTest
@testable import LumenFit

/// Statuswechsel und Speicherformat der Foto-Aufträge, dazu der Store mit Ordner im Temp-Verzeichnis, einem Sender ohne Netz
/// und einem Hintergrund ohne UIKit.
final class EssenKiAuftragTests: XCTestCase {
    private func schaetzung(frage: String? = nil) throws -> EssenKiAnalyse {
        let json = """
        {"ist_essen":true,"items":[{"name":"Reis","gramm":200,"kcal_pro_100g":130,"protein_pro_100g":2.7,"kohlenhydrate_pro_100g":28,"fett_pro_100g":0.3,"sicherheit":"hoch"}],
         "versteckt":[],"gesamt":{"kcal":260,"kcal_min":230,"kcal_max":300},"frage":\(frage.map { "\"\($0)\"" } ?? "null"),"bemerkung":"","rest":5}
        """
        return try JSONDecoder().decode(EssenKiAnalyse.self, from: Data(json.utf8))
    }

    private func neu() -> EssenKiAuftrag { EssenKiAuftragLogik.neu(mahlzeit: .mittag, datum: "2026-10-10") }

    // MARK: - Logik

    func testNeuLaeuftOhneErgebnis() {
        let a = neu()
        XCTAssertEqual(a.status, .laeuft)
        XCTAssertNil(a.analyse)
        XCTAssertNil(EssenKiAuftragLogik.anzeige(a))
    }

    func testErgebnisMachtFertigUndLoeschtFehler() throws {
        var a = EssenKiAuftragLogik.fehlgeschlagen(neu(), .netz)
        a = EssenKiAuftragLogik.neuStart(a)
        let f = EssenKiAuftragLogik.ergebnis(a, try schaetzung())
        XCTAssertEqual(f.status, .fertig)
        XCTAssertNil(f.fehler)
        XCTAssertFalse(f.autoNochmal)
        XCTAssertEqual(EssenKiAuftragLogik.anzahlFertig([f, neu()]), 1)
    }

    func testNetzfehlerMerktEineWiederholungNurEinmal() {
        let erst = EssenKiAuftragLogik.fehlgeschlagen(neu(), .netz)
        XCTAssertEqual(erst.status, .fehler)
        XCTAssertTrue(erst.autoNochmal)
        let lauf = EssenKiAuftragLogik.neuStart(erst, automatisch: true)
        XCTAssertTrue(lauf.wiederholt)
        XCTAssertFalse(EssenKiAuftragLogik.fehlgeschlagen(lauf, .netz).autoNochmal)
        XCTAssertFalse(EssenKiAuftragLogik.fehlgeschlagen(neu(), .tageslimit).autoNochmal)
    }

    func testFehlerBeiNeuSchaetzenBehaeltDieAlteSchaetzung() throws {
        let fertig = EssenKiAuftragLogik.ergebnis(neu(), try schaetzung(frage: "Welches Öl?"))
        let lauf = EssenKiAuftragLogik.neuStart(fertig, hinweis: "Olivenöl")
        XCTAssertEqual(lauf.hinweis, "Olivenöl")
        let fehl = EssenKiAuftragLogik.fehlgeschlagen(lauf, .zuVieleAnfragen)
        XCTAssertEqual(fehl.status, .fertig)
        XCTAssertNotNil(fehl.analyse)
        XCTAssertNotNil(fehl.neuFehler)
        XCTAssertEqual(EssenKiAuftragLogik.abgebrochen(lauf)?.status, .fertig)
        XCTAssertNil(EssenKiAuftragLogik.abgebrochen(neu()))
    }

    func testNachNeustartNichtsGehtVerloren() throws {
        let ohne = neu()
        let mit = EssenKiAuftragLogik.ergebnis(neu(), try schaetzung())
        let lauf = EssenKiAuftragLogik.neuStart(mit)
        let r = EssenKiAuftragLogik.nachNeustart([ohne, lauf, mit])
        XCTAssertEqual(r[0].status, .unterbrochen)
        XCTAssertEqual(EssenKiAuftragLogik.anzeige(r[0])?.nochmal, true)
        XCTAssertEqual(r[1].status, .fertig)
        XCTAssertNotNil(r[1].analyse)
        XCTAssertNotNil(r[1].neuFehler)
        XCTAssertEqual(r[2], mit)
    }

    func testSchrittNachZeit() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(EssenKiAuftragLogik.schritt(seit: start, jetzt: start.addingTimeInterval(1)), 0)
        XCTAssertEqual(EssenKiAuftragLogik.schritt(seit: start, jetzt: start.addingTimeInterval(3)), 1)
        XCTAssertEqual(EssenKiAuftragLogik.schritt(seit: start, jetzt: start.addingTimeInterval(9)), 2)
    }

    func testDateiformatRundeUndUnlesbar() throws {
        let liste = [EssenKiAuftragLogik.ergebnis(neu(), try schaetzung())]
        let daten = try XCTUnwrap(EssenKiAuftragLogik.kodieren(liste))
        XCTAssertEqual(EssenKiAuftragLogik.lesen(daten), liste)
        XCTAssertNil(EssenKiAuftragLogik.lesen(Data("kaputt".utf8)))
        XCTAssertEqual(EssenKiAuftragLogik.lesen(Data("[]".utf8)), [])
    }

    // MARK: - Store

    private struct Sender: EssenKiSender {
        let antwort: @Sendable () async throws -> EssenKiAnalyse
        func analysieren(bild: Data, hinweis: String, mahlzeit: Mahlzeit) async throws -> EssenKiAnalyse { try await antwort() }
    }

    @MainActor
    private final class Hintergrund: EssenKiHintergrund {
        var vorne = true
        private(set) var starts = 0
        private(set) var enden = 0
        func start() { starts += 1 }
        func ende() { enden += 1 }
    }

    private func ordner() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("essen-ki-test-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func jpeg() throws -> Data {
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { c in
            UIColor.orange.setFill()
            c.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        }
        return try XCTUnwrap(bild.jpegData(compressionQuality: 0.8))
    }

    @MainActor
    private func warte(_ bedingung: @MainActor () -> Bool) async throws {
        for _ in 0..<200 where !bedingung() { try await Task.sleep(for: .milliseconds(25)) }
    }

    @MainActor
    func testNeuesFotoWirdGeschaetztGespeichertUndHintergrundEndet() async throws {
        let a = try schaetzung()
        let hg = Hintergrund()
        let url = ordner()
        let store = EssenKiAuftragStore(ordner: url, sender: Sender { a }, hintergrund: hg)
        let id = store.neu(foto: try jpeg(), mahlzeit: .abend, datum: "2026-10-10")
        XCTAssertEqual(store.auftraege.count, 1)
        try await warte { store.auftrag(id)?.status == .fertig }
        XCTAssertEqual(store.auftrag(id)?.status, .fertig)
        XCTAssertEqual(store.auftrag(id)?.analyse, a)
        XCTAssertEqual(store.anzahlFertig, 1)
        XCTAssertNotNil(store.bildDaten(id))
        XCTAssertGreaterThan(hg.starts, 0)
        XCTAssertGreaterThan(hg.enden, 0)
        // Neu geladen: derselbe Auftrag aus der Datei.
        let neuStore = EssenKiAuftragStore(ordner: url, sender: Sender { a }, hintergrund: Hintergrund())
        XCTAssertEqual(neuStore.auftrag(id)?.analyse, a)
    }

    @MainActor
    func testFehlerUndNochmal() async throws {
        let a = try schaetzung()
        let store = EssenKiAuftragStore(ordner: ordner(), sender: Sender { throw EssenKiFehler.tageslimit }, hintergrund: Hintergrund())
        let id = store.neu(foto: try jpeg(), mahlzeit: .mittag, datum: "2026-10-10")
        try await warte { store.auftrag(id)?.status == .fehler }
        XCTAssertEqual(store.auftrag(id)?.status, .fehler)
        XCTAssertEqual(store.auftrag(id)?.fehler, EssenKiFotoLogik.anzeige(.tageslimit))
        let ok = EssenKiAuftragStore(ordner: ordner(), sender: Sender { a }, hintergrund: Hintergrund())
        let id2 = ok.neu(foto: try jpeg(), mahlzeit: .mittag, datum: "2026-10-10")
        try await warte { ok.auftrag(id2)?.status == .fertig }
        ok.nochmal(id2, hinweis: "mit Öl")
        try await warte { ok.auftrag(id2)?.status == .fertig && ok.auftrag(id2)?.hinweis == "mit Öl" }
        XCTAssertEqual(ok.auftrag(id2)?.hinweis, "mit Öl")
    }

    @MainActor
    func testVerwerfenUndRueckgaengigUndEntfernen() async throws {
        let a = try schaetzung()
        let store = EssenKiAuftragStore(ordner: ordner(), sender: Sender { a }, hintergrund: Hintergrund())
        let id = store.neu(foto: try jpeg(), mahlzeit: .snack, datum: "2026-10-10")
        try await warte { store.auftrag(id)?.status == .fertig }
        store.verwerfen(id)
        XCTAssertNil(store.auftrag(id))
        XCTAssertEqual(store.verworfen?.id, id)
        XCTAssertNotNil(store.bildDaten(id), "das Foto bleibt für Rückgängig")
        store.rueckgaengig()
        XCTAssertNotNil(store.auftrag(id))
        XCTAssertNil(store.verworfen)
        store.entfernen(id)
        XCTAssertTrue(store.auftraege.isEmpty)
        XCTAssertNil(store.bildDaten(id))
    }

    @MainActor
    func testDefekteIndexDateiWirdZurSeiteGelegtUndNieUeberschrieben() throws {
        let url = ordner()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let datei = url.appendingPathComponent(EssenKiAuftragStore.indexName)
        try Data("kaputt".utf8).write(to: datei)
        let store = EssenKiAuftragStore(ordner: url, sender: Sender { throw EssenKiFehler.netz }, hintergrund: Hintergrund())
        XCTAssertTrue(store.auftraege.isEmpty)
        let namen = try FileManager.default.contentsOfDirectory(atPath: url.path)
        XCTAssertTrue(namen.contains { $0.hasPrefix("index-defekt-") })
        XCTAssertFalse(namen.contains(EssenKiAuftragStore.indexName))
    }

    @MainActor
    func testFotoOhneAuftragWirdBeimLadenEntfernt() throws {
        let url = ordner()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let verwaist = url.appendingPathComponent("\(UUID().uuidString).jpg")
        try Data([1, 2, 3]).write(to: verwaist)
        _ = EssenKiAuftragStore(ordner: url, sender: Sender { throw EssenKiFehler.netz }, hintergrund: Hintergrund())
        XCTAssertFalse(FileManager.default.fileExists(atPath: verwaist.path))
    }

    @MainActor
    func testUnlesbaresFotoGibtFotoUnlesbar() async throws {
        let store = EssenKiAuftragStore(ordner: ordner(), sender: Sender { throw EssenKiFehler.netz }, hintergrund: Hintergrund())
        let id = store.neu(foto: Data("kein bild".utf8), mahlzeit: .mittag, datum: "2026-10-10")
        try await warte { store.auftrag(id)?.status == .fehler }
        XCTAssertEqual(store.auftrag(id)?.fehler, EssenKiFotoLogik.fotoUnlesbar)
    }
}
