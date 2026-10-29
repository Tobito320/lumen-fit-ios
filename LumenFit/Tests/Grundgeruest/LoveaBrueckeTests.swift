import XCTest
@testable import LumenFit

/// Der Dateivertrag mit Lovea (SPEC 5.5) gegen Fixtures mit erfundenen Kennungen: Quelle A (`widget-stand.json`), Vertrag B (`partner.json`),
/// Band-Wünsche, Zusammenfassung schreiben, Fristen und kaputte Dateien.
final class LoveaBrueckeTests: XCTestCase {
    /// Donnerstag 29.10.2026, 10:00 Berlin.
    private let jetzt = Datum.datum("2026-10-29").addingTimeInterval(10 * 3600)

    /// Ein Lovea-Gruppenordner mit den gewünschten Fixture-Dateien: `widget-stand.json` liegt im Gruppenordner, die anderen im Unterordner `LumenFit`.
    private func gruppe(widgetStand: Bool = false, partner: String? = nil, wuensche: Bool = false) throws -> URL {
        let wurzel = try tempOrdner()
        let unter = wurzel.appendingPathComponent(LoveaVertrag.ordnerName, isDirectory: true)
        try FileManager.default.createDirectory(at: unter, withIntermediateDirectories: true)
        if widgetStand { try FixtureOrt.daten("Grundgeruest", "grundgeruest-lovea-widget-stand.json").write(to: wurzel.appendingPathComponent(LoveaVertrag.widgetStandDatei)) }
        if let partner { try FixtureOrt.daten("Grundgeruest", partner).write(to: unter.appendingPathComponent(LoveaVertrag.partnerDatei)) }
        if wuensche { try FixtureOrt.daten("Grundgeruest", "grundgeruest-band-wuensche.json").write(to: unter.appendingPathComponent(LoveaVertrag.wuenscheDatei)) }
        return wurzel
    }

    // MARK: - Ohne Verbindung

    func testOhneOrdnerOderOhneDateienIstNichtVerbunden() throws {
        XCTAssertEqual(LoveaBruecke(ordner: nil).partner(jetzt: jetzt), .nichtVerbunden)
        XCTAssertEqual(LoveaBruecke(ordner: try tempOrdner()).partner(jetzt: jetzt), .nichtVerbunden)
        XCTAssertTrue(LoveaBruecke(ordner: nil).wuensche().isEmpty)
        LoveaBruecke(ordner: nil).schreibe(zusammenfassung: ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "x", freigaben: [], heute: TagesZusammenfassung(tag: "2026-10-29"), ereignisse: []))
    }

    // MARK: - Vertrag B

    func testVertragBWirdGelesenMitUndOhneSekundenbruchteile() throws {
        let bruecke = LoveaBruecke(ordner: try gruppe(partner: "grundgeruest-partner.json"))
        guard case .verbunden(let datei) = bruecke.partner(jetzt: jetzt) else { return XCTFail("verbunden erwartet") }
        XCTAssertEqual(datei.profilName, "Beispielpartner")
        XCTAssertEqual(datei.freigaben, [.schritte, .gym])
        XCTAssertEqual(datei.heute.schritte, 5000)
        XCTAssertEqual(datei.heute.gymTageWoche, 2)
        XCTAssertNil(datei.heute.schlafMinuten)
        XCTAssertEqual(datei.ereignisse.first?.art, .gymEnde)
        XCTAssertEqual(datei.ereignisse.first?.zeit.timeIntervalSince1970 ?? 0, 1_793_251_800.25, accuracy: 0.001, "2026-10-29T05:30:00.250Z")
    }

    func testVertragBNachDerFristIstVeraltetAnDerGrenzeNochNicht() throws {
        let bruecke = LoveaBruecke(ordner: try gruppe(partner: "grundgeruest-partner.json"))
        let geschrieben = Date(timeIntervalSince1970: 1_793_253_600)   // 2026-10-29T06:00:00Z
        XCTAssertEqual(LoveaVertrag.frist, 48 * 3600)
        guard case .verbunden = bruecke.partner(jetzt: geschrieben.addingTimeInterval(LoveaVertrag.frist)) else { return XCTFail("genau 48 h: noch verbunden") }
        guard case .veraltet(let datei) = bruecke.partner(jetzt: geschrieben.addingTimeInterval(LoveaVertrag.frist + 1)) else { return XCTFail("veraltet erwartet") }
        XCTAssertEqual(datei.profilName, "Beispielpartner")
    }

    func testUnbekannteVersionUndKaputteDateienDuerfenNichtAbstuerzen() throws {
        XCTAssertEqual(LoveaBruecke(ordner: try gruppe(partner: "grundgeruest-partner-version-9.json")).partner(jetzt: jetzt), .unbekannteVersion)

        let kaputt = try gruppe()
        try Data("{das ist kein json".utf8).write(to: kaputt.appendingPathComponent(LoveaVertrag.ordnerName).appendingPathComponent(LoveaVertrag.partnerDatei))
        XCTAssertEqual(LoveaBruecke(ordner: kaputt).partner(jetzt: jetzt), .nichtVerbunden)

        let leer = try gruppe()
        try Data().write(to: leer.appendingPathComponent(LoveaVertrag.widgetStandDatei))
        XCTAssertEqual(LoveaBruecke(ordner: leer).partner(jetzt: jetzt), .nichtVerbunden)
    }

    // MARK: - Quelle A

    func testQuelleAliefertDenPartnerAusLoveasWidgetStand() throws {
        let bruecke = LoveaBruecke(ordner: try gruppe(widgetStand: true))
        guard case .verbunden(let datei) = bruecke.partner(jetzt: jetzt) else { return XCTFail("verbunden erwartet (Datei ist gerade erst kopiert)") }
        XCTAssertEqual(datei.profilName, "Person-zwei", "die andere Kennung als eigenePerson, erster Buchstabe groß")
        XCTAssertEqual(datei.heute.tag, "2026-10-29")
        XCTAssertEqual(datei.heute.schritte, 9100)
        XCTAssertEqual(datei.heute.gymTageWoche, 2, "zwei erledigte Tage")
        XCTAssertEqual(datei.heute.schlafMinuten, 470)
        XCTAssertEqual(Set(datei.freigaben), [.schritte, .gym, .schlaf])
        XCTAssertEqual(Set(datei.ereignisse.map(\.art)), [.gymEnde, .ziel, .schlafGut])
        XCTAssertEqual(Set(datei.ereignisse.map(\.id)), ["gymEnde-2026-10-29", "ziel-2026-10-29", "schlafGut-2026-10-29"])
    }

    func testQuelleAWirdNachDerFristVeraltetUndLiestKeineFremdenFelder() throws {
        let wurzel = try gruppe(widgetStand: true)
        let alt = jetzt.addingTimeInterval(-LoveaVertrag.frist - 3600)
        try FileManager.default.setAttributes([.modificationDate: alt], ofItemAtPath: wurzel.appendingPathComponent(LoveaVertrag.widgetStandDatei).path)
        guard case .veraltet(let datei) = LoveaBruecke(ordner: wurzel).partner(jetzt: jetzt) else { return XCTFail("veraltet erwartet") }
        XCTAssertEqual(datei.profilName, "Person-zwei")
        // Ort, Herzen und Punkte stehen in der Datei, kommen aber nirgends an.
        let text = String(decoding: try JSONEncoder().encode(datei), as: UTF8.self).lowercased()
        XCTAssertFalse(text.contains("wird nie gelesen"))
        XCTAssertFalse(text.contains("herzen"))
        XCTAssertFalse(text.contains("punkte"))
    }

    func testVertragBGewinntGegenQuelleA() throws {
        let bruecke = LoveaBruecke(ordner: try gruppe(widgetStand: true, partner: "grundgeruest-partner.json"))
        guard case .verbunden(let datei) = bruecke.partner(jetzt: jetzt) else { return XCTFail("verbunden erwartet") }
        XCTAssertEqual(datei.profilName, "Beispielpartner")
    }

    // MARK: - Schreiben und Band

    func testZusammenfassungSchreibenUndWiederLesenKostetNichts() throws {
        let wurzel = try tempOrdner()
        let zusammenfassung = ZusammenfassungDatei(version: LoveaVertrag.version, geschrieben: Date(timeIntervalSince1970: 1_793_253_600), profilName: "Beispiel",
                                                   freigaben: [.schritte, .essen], heute: TagesZusammenfassung(tag: "2026-10-29", schritte: 1234, gymTageWoche: 1, schlafMinuten: 400, kcal: 1800),
                                                   ereignisse: [PartnerEreignis(id: "e1", art: .rekord, zeit: Date(timeIntervalSince1970: 1_793_253_000), text: "Neuer Rekord")])
        LoveaBruecke(ordner: wurzel).schreibe(zusammenfassung: zusammenfassung)
        let datei = wurzel.appendingPathComponent(LoveaVertrag.ordnerName).appendingPathComponent(LoveaVertrag.zusammenfassungDatei)
        let gelesen = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: Data(contentsOf: datei))
        XCTAssertEqual(gelesen, zusammenfassung)
        let objekt = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: datei)) as? [String: Any])
        XCTAssertEqual(objekt["version"] as? Int, 1)
        XCTAssertEqual(objekt["geschrieben"] as? String, "2026-10-29T06:00:00.000Z", "ISO 8601 als Text")
    }

    func testBandWuenscheLesen() throws {
        let bruecke = LoveaBruecke(ordner: try gruppe(wuensche: true))
        let wuensche = bruecke.wuensche()
        XCTAssertEqual(wuensche.map(\.id), ["w1", "w2"])
        XCTAssertEqual(wuensche.map(\.muster), [.kurz, .doppelt])
        XCTAssertEqual(wuensche.first?.von, "person-zwei")
    }

    func testErledigteWuenscheSammelnSichOhneDoppelteUndBegrenzt() throws {
        let wurzel = try tempOrdner()
        let bruecke = LoveaBruecke(ordner: wurzel)
        bruecke.melde(erledigt: ["a", "b"])
        bruecke.melde(erledigt: ["b", "c"])
        let datei = wurzel.appendingPathComponent(LoveaVertrag.ordnerName).appendingPathComponent(LoveaVertrag.erledigtDatei)
        var gelesen = try LoveaVertrag.decoder().decode(BandErledigtDatei.self, from: Data(contentsOf: datei))
        XCTAssertEqual(gelesen.ids, ["a", "b", "c"])
        XCTAssertEqual(gelesen.version, 1)

        bruecke.melde(erledigt: (0..<250).map { "id-\($0)" })
        gelesen = try LoveaVertrag.decoder().decode(BandErledigtDatei.self, from: Data(contentsOf: datei))
        XCTAssertEqual(gelesen.ids.count, LoveaVertrag.erledigteMaximal)
        XCTAssertEqual(gelesen.ids.last, "id-249")
        XCTAssertEqual(gelesen.ids.first, "id-50")
    }

    func testBandStatusSchreiben() throws {
        let wurzel = try tempOrdner()
        LoveaBruecke(ordner: wurzel).schreibe(status: BandStatusDatei(version: 1, geschrieben: jetzt, verbunden: true, akkuProzent: 64, name: "Testband"))
        let datei = wurzel.appendingPathComponent(LoveaVertrag.ordnerName).appendingPathComponent(LoveaVertrag.statusDatei)
        let gelesen = try LoveaVertrag.decoder().decode(BandStatusDatei.self, from: Data(contentsOf: datei))
        XCTAssertEqual(gelesen.akkuProzent, 64)
        XCTAssertTrue(gelesen.verbunden)
    }

    func testUnbekannteWunschVersionLiefertNichts() throws {
        let wurzel = try tempOrdner()
        let unter = wurzel.appendingPathComponent(LoveaVertrag.ordnerName, isDirectory: true)
        try FileManager.default.createDirectory(at: unter, withIntermediateDirectories: true)
        try Data(#"{"version":7,"wuensche":[{"id":"w","muster":"kurz","zeit":"2026-10-29T08:00:00Z","von":"x"}]}"#.utf8).write(to: unter.appendingPathComponent(LoveaVertrag.wuenscheDatei))
        XCTAssertTrue(LoveaBruecke(ordner: wurzel).wuensche().isEmpty)
    }
}
