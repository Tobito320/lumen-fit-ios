import XCTest
@testable import LumenFit

/// Der Geber der Pulse: prüft die Regeln, schickt je Puls einen Finden-Befehl, nie zwei Folgen gleichzeitig.
@MainActor
final class BandPulsTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_793_187_240) // 12:34 Berliner Zeit
    private var defaults: UserDefaults!
    private var befehle = 0
    private var wartezeiten: [TimeInterval] = []

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "BandPulsTests")
        defaults.removePersistentDomain(forName: "BandPulsTests")
        befehle = 0
        wartezeiten = []
    }

    private func geber(verbunden: Bool = true, umfeld: BandRegeln.Umfeld? = nil) -> BandPuls {
        let frei = BandRegeln.Umfeld(bandAmArm: true, akku: 80, akkuSchwelle: 15, ruhe: [], ruheAusnahme: true)
        return BandPuls(finden: { [weak self] in self?.befehle += 1 }, verbunden: { verbunden }, umfeld: { _ in umfeld ?? frei },
                        defaults: defaults, warte: { _ in })
    }

    func testPauseEndeVibriertEinmalUndMerktDenZeitpunkt() async {
        let g = geber()
        XCTAssertNil(g.muster(.pauseEnde, jetzt: jetzt))
        await Task.yield()
        XCTAssertEqual(BandQuelle.gymPause.letzte(defaults), jetzt)
        XCTAssertEqual(g.muster(.pauseEnde, jetzt: jetzt.addingTimeInterval(5)), .pause, "innerhalb der Untergrenze nicht noch einmal")
    }

    func testNichtVerbundenVibriertNicht() {
        let g = geber(verbunden: false)
        XCTAssertNotNil(g.muster(.kurz, jetzt: jetzt))
        XCTAssertEqual(befehle, 0)
    }

    func testRufGibtDreiPulse() async {
        let g = geber()
        let folge = g.ausgeben(.wunsch, .stark, jetzt)
        await folge?.value
        XCTAssertEqual(befehle, 3)
        XCTAssertFalse(g.laeuft)
    }

    func testEineLaufendeFolgeGehtVor() async {
        let g = geber()
        let erste = g.ausgeben(.wunsch, .normal, jetzt)
        XCTAssertNil(g.ausgeben(.wunsch, .normal, jetzt), "zweite Folge mitten in der ersten")
        await erste?.value
        XCTAssertEqual(befehle, 2)
    }

    func testAusgeschalteteQuelleVibriertNicht() {
        let g = geber()
        defaults.set(false, forKey: BandQuelle.gymPause.anSchluessel)
        XCTAssertEqual(g.muster(.pauseEnde, jetzt: jetzt), .aus)
        XCTAssertEqual(befehle, 0)
    }

    func testRuhezeitSperrtPauseEndeAberNichtDenWunsch() {
        let nacht = BandRegeln.Umfeld(bandAmArm: true, akku: 80, akkuSchwelle: 15, ruhe: [BandRegeln.Zeitfenster(von: 0, bis: 23 * 60 + 59)],
                                      ruheAusnahme: true)
        let g = geber(umfeld: nacht)
        XCTAssertEqual(g.muster(.pauseEnde, jetzt: jetzt), .ruhezeit)
        XCTAssertNil(g.muster(.kurz, jetzt: jetzt), "Wünsche des Partners dürfen durch die Ruhezeit")
    }

    func testZielPulsNurImTrainingUndBeiFrischemWert() async {
        defaults.set(true, forKey: BandQuelle.gymPuls.anSchluessel)
        let g = geber()
        g.rundeEnde(training: false, puls: 170, zeit: jetzt, jetzt: jetzt)
        XCTAssertEqual(befehle, 0)
        g.rundeEnde(training: true, puls: 170, zeit: jetzt.addingTimeInterval(-60), jetzt: jetzt)
        await Task.yield()
        XCTAssertEqual(befehle, 1)
    }

    func testUmfeldNimmtDenAkkuNurWennFrisch() {
        let frisch = BandPuls.umfeld(jetzt, defaults: defaults, bandAmArm: true, akku: 10, akkuGelesen: jetzt.addingTimeInterval(-3600))
        XCTAssertEqual(frisch.akku, 10)
        let alt = BandPuls.umfeld(jetzt, defaults: defaults, bandAmArm: true, akku: 10, akkuGelesen: jetzt.addingTimeInterval(-13 * 3600))
        XCTAssertNil(alt.akku)
        XCTAssertEqual(frisch.akkuSchwelle, BandEinstellung.standardAkkuSchwelle)
        XCTAssertTrue(frisch.ruhe.contains(BandRegeln.standardNacht))
    }

    func testNachtLaesstSichAusschalten() {
        defaults.set(false, forKey: BandEinstellung.nachtAn)
        let u = BandPuls.umfeld(jetzt, defaults: defaults, bandAmArm: nil, akku: nil, akkuGelesen: nil)
        XCTAssertTrue(u.ruhe.isEmpty)
    }
}
