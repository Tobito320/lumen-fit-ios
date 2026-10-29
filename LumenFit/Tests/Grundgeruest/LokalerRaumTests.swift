import XCTest
@testable import LumenFit

@MainActor
final class LokalerRaumTests: XCTestCase {
    private struct Probe: Codable, Equatable { var wert: Int }

    func testSendenSchreibtDieOpMitUhrzeitUndProfil() throws {
        let uhr = TestUhr()
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: .testA, uhr: uhr.uhr)
        raum.senden("probe.eins", Probe(wert: 7))
        let op = try XCTUnwrap(raum.ops(arten: ["probe.eins"]).first)
        XCTAssertEqual(op.von, .testA)
        XCTAssertEqual(op.zeit, uhr.lesen)
        XCTAssertEqual(op.daten(Probe.self), Probe(wert: 7))
    }

    func testBeobachterBekommtErstDasVorhandeneDannLiveNurSeineArten() throws {
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: .testA, uhr: TestUhr().uhr)
        raum.senden("probe.eins", Probe(wert: 1))
        raum.senden("probe.zwei", Probe(wert: 100))
        var gesehen: [Int] = []
        raum.beobachten(["probe.eins"]) { op in if let p = op.daten(Probe.self) { gesehen.append(p.wert) } }
        raum.senden("probe.eins", Probe(wert: 2))
        raum.senden("probe.zwei", Probe(wert: 200))
        raum.senden("probe.eins", Probe(wert: 3))
        XCTAssertEqual(gesehen, [1, 2, 3])
    }

    func testNeustartLiestDieOpsWiederUndBeobachterSehenSie() throws {
        let ordner = try tempOrdner()
        let erster = LokalerRaum(ordner: ordner, profil: .testA, uhr: TestUhr().uhr)
        erster.senden("probe.eins", Probe(wert: 5))
        erster.senden("probe.eins", Probe(wert: 6))

        let zweiter = LokalerRaum(ordner: ordner, profil: .testA, uhr: TestUhr().uhr)
        var gesehen: [Int] = []
        zweiter.beobachten(["probe.eins"]) { op in if let p = op.daten(Probe.self) { gesehen.append(p.wert) } }
        XCTAssertEqual(gesehen, [5, 6])
    }

    func testEinreihenUeberspringtDoppelteIdUndMeldetNichtNochmal() throws {
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: .testA, uhr: TestUhr().uhr)
        var zahl = 0
        raum.beobachten(["probe.eins"]) { _ in zahl += 1 }
        let op = Op.neu("probe.eins", Probe(wert: 1), von: .testA, zeit: TestUhr().lesen)
        raum.einreihen(op)
        raum.einreihen(op)
        XCTAssertEqual(zahl, 1)
        XCTAssertEqual(raum.ops(arten: ["probe.eins"]).count, 1)
    }

    func testZweiProfileHabenGetrennteOrdnerUndOps() throws {
        let wurzel = try tempOrdner()
        let a = LokalerRaum(ordner: wurzel.appendingPathComponent("a"), profil: .testA, uhr: TestUhr().uhr)
        let b = LokalerRaum(ordner: wurzel.appendingPathComponent("b"), profil: .testB, uhr: TestUhr().uhr)
        a.senden("probe.eins", Probe(wert: 1))
        XCTAssertEqual(a.ops(arten: ["probe.eins"]).count, 1)
        XCTAssertTrue(b.ops(arten: ["probe.eins"]).isEmpty)
    }

    func testLeerKehrtSofortZurueck() async throws {
        let raum = LokalerRaum(ordner: try tempOrdner(), profil: .testA, uhr: TestUhr().uhr)
        raum.senden("probe.eins", Probe(wert: 1))
        await raum.leer()
        XCTAssertEqual(raum.ops(arten: ["probe.eins"]).count, 1)
    }
}
