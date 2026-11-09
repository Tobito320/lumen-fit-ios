import XCTest
@testable import LumenFit

/// Essen zurück zu Lovea: nur mit Server-Schalter, die neuen Essen-Ops in Paketen plus Ziele, gemerkt wird der Stand; ein Fehler lässt alles für den nächsten Lauf.
@MainActor
final class LoveaEssenExportTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")

    private func antwort(_ status: Int, _ json: String = "{}") -> SkriptLader.Antwort { .init(status: status, daten: Data(json.utf8), fehler: nil) }

    /// Ein angemeldetes Konto mit Lovea-Freigabe; `exportAn` ist der Server-Schalter. Die letzte Antwort gilt für alle weiteren Aufrufe.
    private func angemeldet(exportAn: Bool, danach: SkriptLader.Antwort) async throws -> (KontoDienst, SkriptLader) {
        let freigabe = #"{"erlaubt":true,"person":"person-a","importErledigt":true,"essenExportErledigt":false,"essenExportAn":\#(exportAn)}"#
        let lader = SkriptLader([antwort(201), antwort(200, #"{"config":{}}"#), antwort(200, freigabe), antwort(404), antwort(200, #"{"partner":null}"#), antwort(200), danach])
        let d = KontoDienst(zugang: zugang, schluesselbund: SpeicherSchluesselbund(), http: lader, ordner: try tempOrdner(), uhr: { Date() }, version: "0.0.1")
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        return (d, lader)
    }

    private func opsAnfragen(_ lader: SkriptLader) -> [[String: Any]] {
        lader.anfragen.filter { $0.httpMethod == "POST" && $0.url?.path == "/lovea/ops" }
            .compactMap { $0.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } }
    }

    private func datenMitEssen() throws -> DatenSatz {
        let satz = DatenSatz(profil: .testA, ordner: try tempOrdner(), ereignisse: EreignisKanal(), uhr: { Date() })
        satz.raum.senden("essen.setzen", ["id": "e1", "kcal": 500])
        satz.raum.senden("gym.checkin", ["session": "s1"])   // kein Essen: geht nicht mit
        satz.raum.senden("fasten.plan", ["plan": "16:8"])
        return satz
    }

    func testOhneSchalterPassiertNichts() async throws {
        let (konto, lader) = try await angemeldet(exportAn: false, danach: antwort(200))
        XCTAssertFalse(konto.essenExportAn)
        let n = await LoveaEssenExport.starteWennOffen(konto: konto, daten: try datenMitEssen(), jetzt: Date())
        XCTAssertNil(n)
        XCTAssertTrue(opsAnfragen(lader).isEmpty)
    }

    func testNeueOpsUndZieleGehenRausUndWerdenGemerkt() async throws {
        let (konto, lader) = try await angemeldet(exportAn: true, danach: antwort(200, #"{"seq":9,"uebersprungen":0}"#))
        XCTAssertTrue(konto.essenExportAn)
        let daten = try datenMitEssen()
        var z = ErnaehrungsZiele()
        z.kcal = 2400
        daten.essen.zieleSichern(z)
        let n = await LoveaEssenExport.starteWennOffen(konto: konto, daten: daten, jetzt: Date())
        XCTAssertEqual(n, 2)
        let pakete = opsAnfragen(lader)
        XCTAssertEqual(pakete.count, 2, "ein Paket Ops, ein Paket Ziele")
        let erste = try XCTUnwrap(pakete[0]["ops"] as? [[String: Any]])
        XCTAssertEqual(erste.map { $0["art"] as? String }, ["essen.setzen", "fasten.plan"])
        let ziele = try XCTUnwrap(pakete[1]["ops"] as? [[String: Any]])
        XCTAssertTrue(ziele.allSatisfy { $0["art"] as? String == "einstellung.setzen" })
        let kcal = ziele.first { ($0["id"] as? String)?.hasPrefix("lumenfit-ziel-kcal-") == true }
        XCTAssertEqual((kcal?["d"] as? [String: Any])?["schluessel"] as? String, "ziel.ernaehrung.kcal")
        XCTAssertEqual(konto.essenExportAnzahl, 2)
        XCTAssertTrue(konto.essenExportErledigt)
        XCTAssertEqual(lader.anfragen.filter { $0.url?.path == "/lovea/export-erledigt" }.count, 1)

        // Zweiter Lauf ohne Neues: nichts geht raus. Eine neue Op: nur sie.
        XCTAssertEqual(await LoveaEssenExport.starteWennOffen(konto: konto, daten: daten, jetzt: Date()), 0)
        XCTAssertEqual(opsAnfragen(lader).count, 2)
        daten.raum.senden("essen.setzen", ["id": "e2", "kcal": 300])
        XCTAssertEqual(await LoveaEssenExport.starteWennOffen(konto: konto, daten: daten, jetzt: Date()), 1)
        let letzte = try XCTUnwrap(opsAnfragen(lader).last?["ops"] as? [[String: Any]])
        XCTAssertEqual(letzte.count, 1)
        XCTAssertEqual(konto.essenExportAnzahl, 3)
    }

    func testFehlerLaesstDenStandFuerDenNaechstenLauf() async throws {
        let (konto, lader) = try await angemeldet(exportAn: true, danach: antwort(500))
        let n = await LoveaEssenExport.starteWennOffen(konto: konto, daten: try datenMitEssen(), jetzt: Date())
        XCTAssertNil(n)
        XCTAssertEqual(opsAnfragen(lader).count, 1)
        XCTAssertEqual(konto.essenExportAnzahl, 0)
        XCTAssertFalse(konto.essenExportErledigt)
    }

    func testAlterKontoStandOhneExportFelderLaedt() throws {
        let alt = try JSONDecoder().decode(KontoStand.self, from: Data(#"{"config":{},"loveaErlaubt":true,"loveaImportErledigt":true}"#.utf8))
        XCTAssertTrue(alt.loveaErlaubt)
        XCTAssertFalse(alt.essenExportAn)
        XCTAssertEqual(alt.essenExportAnzahl, 0)
        XCTAssertNil(alt.essenExportZiele)
        XCTAssertFalse(alt.essenExportErledigt)
    }
}
