import XCTest
@testable import LumenFit

/// Band geteilt (Idee 86): Wünsche aus `band-wuensche.json` werden einmal ausgeführt und als erledigt gemeldet; alte Wünsche verfallen; ohne Band bleiben sie liegen.
@MainActor
final class BandWunschSchlangeTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "BandWunschSchlangeTests")
        defaults.removePersistentDomain(forName: "BandWunschSchlangeTests")
    }

    private func wunsch(_ id: String, _ muster: BandMuster = .kurz, vor: TimeInterval) -> BandWunsch {
        BandWunsch(id: id, muster: muster, zeit: VerbindenTest.jetzt.addingTimeInterval(-vor), von: "kennung-b")
    }

    private func schlange(_ bruecke: FakePartnerAustausch, ergebnis: BandWunschSchlange.Ergebnis = .ausgefuehrt, ausgefuehrt: Sammler = Sammler()) -> BandWunschSchlange {
        BandWunschSchlange(bruecke: bruecke, defaults: defaults, uhr: { VerbindenTest.jetzt }) { w in
            ausgefuehrt.ids.append(w.id)
            return ergebnis
        }
    }

    final class Sammler { var ids: [String] = [] }

    func testJederWunschLaeuftEinmalUndWirdAlsErledigtGemeldet() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("a", vor: 120), wunsch("b", .doppelt, vor: 60)])
        let gelaufen = Sammler()
        let s = schlange(bruecke, ausgefuehrt: gelaufen)
        XCTAssertEqual(s.verarbeite(), ["a", "b"])
        XCTAssertEqual(s.verarbeite(), [], "zweiter Lauf: nichts mehr offen")
        XCTAssertEqual(gelaufen.ids, ["a", "b"])
        XCTAssertEqual(bruecke.erledigt, [["a", "b"]])
    }

    func testErledigteBleibenAuchNachEinemNeuenObjektErledigt() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("a", vor: 60)])
        _ = schlange(bruecke).verarbeite()
        let gelaufen = Sammler()
        XCTAssertEqual(schlange(bruecke, ausgefuehrt: gelaufen).verarbeite(), [], "Lovea räumt die Datei vielleicht nicht auf: Lumen Fit merkt es selbst")
        XCTAssertTrue(gelaufen.ids.isEmpty)
    }

    func testAelteresZuerst() {
        let gelaufen = Sammler()
        _ = schlange(FakePartnerAustausch(wuensche: [wunsch("neu", vor: 30), wunsch("alt", vor: 300)]), ausgefuehrt: gelaufen).verarbeite()
        XCTAssertEqual(gelaufen.ids, ["alt", "neu"])
    }

    func testVerfalleneWuenscheLaufenNichtWerdenAberAlsErledigtGemeldet() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("alt", .ruf, vor: BandWunschSchlange.verfall + 60), wunsch("frisch", vor: 60)])
        let gelaufen = Sammler()
        XCTAssertEqual(schlange(bruecke, ausgefuehrt: gelaufen).verarbeite(), ["alt", "frisch"])
        XCTAssertEqual(gelaufen.ids, ["frisch"])
    }

    func testOhneBandBleibtDerWunschLiegen() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("a", vor: 60)])
        let s = schlange(bruecke, ergebnis: .spaeter)
        XCTAssertEqual(s.verarbeite(), [])
        XCTAssertTrue(bruecke.erledigt.isEmpty)
        XCTAssertEqual(s.offene().map(\.id), ["a"])
    }

    func testVonDenRegelnVerworfenerWunschGiltAlsErledigt() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("a", vor: 60)])
        XCTAssertEqual(schlange(bruecke, ergebnis: .verworfen).verarbeite(), ["a"])
    }

    func testKeineWuenscheMeldetNichts() {
        let bruecke = FakePartnerAustausch()
        XCTAssertEqual(schlange(bruecke).verarbeite(), [])
        XCTAssertTrue(bruecke.erledigt.isEmpty)
    }

    func testMerkListeIstBegrenzt() {
        defaults.set((0..<(LoveaVertrag.erledigteMaximal + 50)).map { "alt-\($0)" }, forKey: BandWunschSchlange.schluessel)
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("neu", vor: 30)])
        _ = schlange(bruecke).verarbeite()
        let gemerkt = defaults.stringArray(forKey: BandWunschSchlange.schluessel) ?? []
        XCTAssertEqual(gemerkt.count, LoveaVertrag.erledigteMaximal)
        XCTAssertEqual(gemerkt.last, "neu")
    }

    func testFixtureDerWuenscheWirdMitDerEchtenBrueckeGelesen() throws {
        let gruppe = try VerbindenTest.gruppe(self, wuensche: true)
        let bruecke = LoveaBruecke(ordner: gruppe)
        XCTAssertEqual(bruecke.wuensche().map(\.id), ["wunsch-1", "wunsch-2", "wunsch-alt"])
        let gelaufen = Sammler()
        let s = BandWunschSchlange(bruecke: bruecke, defaults: defaults, uhr: { VerbindenTest.jetzt }) { w in gelaufen.ids.append(w.id); return .ausgefuehrt }
        let erledigt = s.verarbeite()
        XCTAssertEqual(erledigt, ["wunsch-alt", "wunsch-1", "wunsch-2"], "der Wunsch von 07:00 verfällt, die zwei von 08:50 und 08:52 UTC laufen")
        XCTAssertEqual(gelaufen.ids, ["wunsch-1", "wunsch-2"])
        let datei = gruppe.appendingPathComponent(LoveaVertrag.ordnerName).appendingPathComponent(LoveaVertrag.erledigtDatei)
        let gelesen = try LoveaVertrag.decoder().decode(BandErledigtDatei.self, from: Data(contentsOf: datei))
        XCTAssertEqual(gelesen.ids, ["wunsch-alt", "wunsch-1", "wunsch-2"])
        XCTAssertEqual(VerbindenTest.dateien(gruppe), ["LumenFit/band-erledigt.json", "LumenFit/band-wuensche.json"], "keine Datei außerhalb des Vertrags")
    }
}
