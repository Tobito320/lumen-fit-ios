import XCTest
@testable import LumenFit

/// Die Pause zwischen zwei Uploads der Zusammenfassung: 2 Minuten, im Gym 20 Sekunden (Mitlauf der Crew).
@MainActor
final class KontoPartnerPauseTests: XCTestCase {
    private let zugang = KontoZugang(server: URL(string: "https://lumen.example.invalid/")!, appKey: "app-test-schluessel")

    private func antwort(_ status: Int, _ json: String = "{}") -> SkriptLader.Antwort { .init(status: status, daten: Data(json.utf8), fehler: nil) }

    private func puts(_ l: SkriptLader) -> Int { l.anfragen.filter { $0.httpMethod == "PUT" && $0.url?.path == "/partner" }.count }

    private func warteAuf(_ anzahl: Int, _ l: SkriptLader) async throws {
        for _ in 0..<50 where puts(l) < anzahl { try await Task.sleep(for: .milliseconds(20)) }
    }

    /// Ein angemeldetes Konto (Antworten wie in `EinmalLoveaTests`) und der Lader, der die Uploads mitzählt.
    private func angemeldet(_ uhr: TestUhr) async throws -> (KontoDienst, SkriptLader) {
        let lader = SkriptLader([antwort(201), antwort(200, #"{"config":{}}"#), antwort(200, #"{"erlaubt":true,"person":"person-a","importErledigt":false}"#),
                                 antwort(404), antwort(200, #"{"partner":null}"#), antwort(200)])
        let d = KontoDienst(zugang: zugang, schluesselbund: SpeicherSchluesselbund(), http: lader, ordner: try tempOrdner(), uhr: uhr.uhr, version: "0.0.1")
        await d.aktualisiere(profilName: "Beispiel", erzwingen: true)
        return (d, lader)
    }

    func testImGymGehtDerNaechsteUploadNachFuenfundzwanzigSekunden() async throws {
        let uhr = TestUhr()
        let (d, lader) = try await angemeldet(uhr)
        d.partnerHochladen(try daten(imGym: true))
        try await warteAuf(1, lader)
        uhr.vor(sekunden: 25)
        d.partnerHochladen(try daten(imGym: true))
        try await warteAuf(2, lader)
        XCTAssertEqual(puts(lader), 2)
    }

    func testSonstWirdNachFuenfundzwanzigSekundenGewartetBisZweiMinuten() async throws {
        let uhr = TestUhr()
        let (d, lader) = try await angemeldet(uhr)
        d.partnerHochladen(try daten(imGym: false))
        try await warteAuf(1, lader)
        uhr.vor(sekunden: 25)
        d.partnerHochladen(try daten(imGym: false))
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(puts(lader), 1, "zu früh")
        uhr.vor(sekunden: 100)
        d.partnerHochladen(try daten(imGym: false))
        try await warteAuf(2, lader)
        XCTAssertEqual(puts(lader), 2)
    }

    private func daten(imGym: Bool?) throws -> Data {
        var v = PartnerVerlauf(trainings: [])
        v.imGym = imGym
        return try LoveaVertrag.encoder().encode(CrewTestDaten.datei(verlauf: v))
    }

    func testImGymNurZwanzigSekunden() throws {
        XCTAssertEqual(KontoDienst.pauseFuer(try daten(imGym: true)), 20)
    }

    func testSonstZweiMinuten() throws {
        XCTAssertEqual(KontoDienst.pauseFuer(try daten(imGym: false)), 120)
        XCTAssertEqual(KontoDienst.pauseFuer(try daten(imGym: nil)), 120)
        let ohneVerlauf = try LoveaVertrag.encoder().encode(CrewTestDaten.datei(freigaben: [.schritte]))
        XCTAssertEqual(KontoDienst.pauseFuer(ohneVerlauf), 120, "ohne Freigabe verlauf kein Verlauf in der Datei")
    }

    func testUnlesbareDatenBleibenBeiZweiMinuten() {
        XCTAssertEqual(KontoDienst.pauseFuer(Data("{}".utf8)), 120)
        XCTAssertEqual(KontoDienst.pauseFuer(Data()), 120)
    }
}
