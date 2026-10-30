import XCTest
@testable import LumenFit

/// Gespeicherte Typen, neue Felder (Ansichten des Partners): eine alte Datei ohne die Felder lädt weiter, eine Datei mit einer Freigabe, die diese Version
/// nicht kennt, auch, und die gespeicherten Freigaben (`freigaben.json`) bleiben über die Erweiterung lesbar.
@MainActor
final class AlteDateienLadenPartnerAnsichtenTests: XCTestCase {
    private func lies(_ json: String) throws -> ZusammenfassungDatei {
        try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: Data(json.utf8))
    }

    func testZusammenfassungOhneNeueFelderLaedt() throws {
        let alt = try lies(#"{"version":1,"geschrieben":"2026-10-29T08:00:00Z","profilName":"Alt","freigaben":["schritte","gym"],"heute":{"tag":"2026-10-29","schritte":5000},"ereignisse":[]}"#)
        XCTAssertEqual(alt.freigaben, [.schritte, .gym])
        XCTAssertEqual(alt.heute.schritte, 5_000)
        XCTAssertNil(alt.heute.plan)
        XCTAssertNil(alt.heute.verlauf)
        XCTAssertNil(alt.heute.tagebuch)
        XCTAssertNil(alt.heute.tagebuchZiele)
        XCTAssertNil(alt.heute.koerper)
    }

    func testFixtureDerAltenFormLaedtUndZeigtKeineAnsicht() throws {
        let alt = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: FixtureOrt.daten("Verbinden", "partner-beispiel.json"))
        XCTAssertEqual(alt.freigaben, [.schritte, .gym, .schlaf, .essen])
        for art in PartnerAnsichtLogik.ansichtsArten { XCTAssertEqual(PartnerAnsichtLogik.lage(.verbunden(alt), art: art), .nichtFreigegeben("Beispiel Partner")) }
    }

    func testEineUnbekannteFreigabeKippeDieDateiNicht() throws {
        let neuer = try lies(#"{"version":1,"geschrieben":"2026-10-29T08:00:00Z","profilName":"Neuer","freigaben":["plan","zukunft","koerper"],"heute":{"tag":"2026-10-29"},"ereignisse":[]}"#)
        XCTAssertEqual(neuer.freigaben, [.plan, .koerper], "was diese Version nicht kennt, fällt weg")
    }

    func testFehlendesPflichtfeldBleibtEinFehler() {
        XCTAssertThrowsError(try lies(#"{"version":1,"geschrieben":"2026-10-29T08:00:00Z","freigaben":[],"heute":{"tag":"2026-10-29"},"ereignisse":[]}"#), "ohne profilName ist die Datei kaputt")
    }

    func testNeueFeldeUeberlebenDenKreislauf() throws {
        let datei = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: FixtureOrt.daten("Verbinden", "partner-ansichten.json"))
        XCTAssertEqual(datei.freigaben.count, 8)
        XCTAssertEqual(datei.heute.plan?.tage.count, 2)
        XCTAssertEqual(datei.heute.verlauf?.trainings.count, 3)
        XCTAssertNotNil(datei.heute.verlauf?.imGymSeit)
        XCTAssertEqual(datei.heute.tagebuch?.count, 2)
        XCTAssertEqual(datei.heute.koerper?["gewicht"]?.count, 3)
        let zurueck = try LoveaVertrag.decoder().decode(ZusammenfassungDatei.self, from: LoveaVertrag.encoder().encode(datei))
        XCTAssertEqual(zurueck, datei)
    }

    func testGespeicherteFreigabenMitDenAltenArtenLadenWeiter() throws {
        let ordner = try tempOrdner()
        try Data(#"["schritte","gym"]"#.utf8).write(to: ordner.appendingPathComponent("freigaben.json"))
        let store = VerbindungStore(ordner: ordner)
        XCTAssertEqual(store.freigaben, [.schritte, .gym])
    }

    func testNeueFreigabenWerdenGespeichertUndGelesen() throws {
        let ordner = try tempOrdner()
        let store = VerbindungStore(ordner: ordner)
        store.freigaben = [.plan, .tagebuch, .schlaf]
        XCTAssertEqual(VerbindungStore(ordner: ordner).freigaben, [.schlaf, .plan, .tagebuch], "Neustart: dieselben Freigaben")
        XCTAssertTrue(VerbindungStore(ordner: try tempOrdner()).freigaben.isEmpty, "ohne Datei: nichts geteilt")
    }
}
