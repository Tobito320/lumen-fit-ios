import XCTest
@testable import LumenFit

@MainActor
final class GesundheitsStandTests: XCTestCase {
    private let uhr = TestUhr()
    private var heute: String { Datum.text(uhr.lesen) }

    private func tage(_ anzahl: Int, schritte: Int = 5000) -> [TagesWerte] {
        (0..<anzahl).map { TagesWerte(tag: Datum.addTage(heute, -$0), schritte: schritte) }
    }

    func testDerErsteAbrufHolt60TageSpaeterePurDieLetztenDrei() async {
        let leser = FakeHealthLeser(tage: tage(80))
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        XCTAssertEqual(stand.zugriff, .unbekannt)
        XCTAssertNil(stand.letzteAktualisierung)

        await stand.aktualisiere()
        XCTAssertEqual(leser.tagesAbfragen.count, 1)
        XCTAssertEqual(leser.tagesAbfragen[0].von, Datum.addTage(heute, -59))
        XCTAssertEqual(leser.tagesAbfragen[0].bis, heute)
        XCTAssertEqual(stand.tage.count, 60)
        XCTAssertEqual(stand.zugriff, .angefragt)
        XCTAssertEqual(stand.letzteAktualisierung, uhr.lesen)

        uhr.vor(sekunden: 3600)
        await stand.aktualisiere()
        XCTAssertEqual(leser.tagesAbfragen.count, 2)
        XCTAssertEqual(leser.tagesAbfragen[1].von, Datum.addTage(heute, -(GesundheitsStand.nachladeTage - 1)))
        XCTAssertEqual(stand.tage.count, 60, "alte Tage bleiben stehen")
    }

    func testNeueWerteDerLetztenTageErsetzenDieAlten() async {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 1000)])
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        await stand.aktualisiere()
        XCTAssertEqual(stand.tage[heute]?.schritte, 1000)
        leser.setze(tage: [TagesWerte(tag: heute, schritte: 4000)])
        await stand.aktualisiere()
        XCTAssertEqual(stand.tage[heute]?.schritte, 4000)
    }

    func testOhneHealthGibtEsEinenStatusStattEinesAbsturzes() async {
        let leser = FakeHealthLeser(zugriff: .nichtVerfuegbar, tage: tage(5))
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        await stand.aktualisiere()
        XCTAssertEqual(stand.zugriff, .nichtVerfuegbar)
        XCTAssertTrue(stand.tage.isEmpty)
        XCTAssertTrue(leser.tagesAbfragen.isEmpty, "ohne Health wird nichts abgefragt")
        XCTAssertNil(stand.letzteAktualisierung)
    }

    func testBandUndHealthZaehlenDasMaximumNieDieSumme() async {
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: heute, schritte: 10_000, distanzMeter: 7000), TagesWerte(tag: Datum.addTage(heute, -1), schritte: 3000)])
        let gestern = Datum.addTage(heute, -1)
        let band = [BandTagOp(tag: heute, schritte: 15_000, meter: 11_000), BandTagOp(tag: gestern, schritte: 2000, meter: 1500), BandTagOp(tag: Datum.addTage(heute, -2), schritte: 4000, meter: 3000)]
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr, band: { band })
        await stand.aktualisiere()
        XCTAssertEqual(stand.tage[heute]?.schritte, 15_000, "Band größer: Band gilt")
        XCTAssertEqual(stand.tage[heute]?.distanzMeter, 11_000)
        XCTAssertEqual(stand.tage[gestern]?.schritte, 3000, "Health größer: Health gilt")
        XCTAssertEqual(stand.tage[Datum.addTage(heute, -2)]?.schritte, 4000, "Tag nur vom Band")
    }

    func testGewichtUndVitalwerteKommenMitUndWerdenZusammengefuehrt() async {
        let gestern = Datum.addTage(heute, -1)
        let leser = FakeHealthLeser(gewichte: [GewichtsMesswert(tag: gestern, kg: 80.4), GewichtsMesswert(tag: heute, kg: 80.1)])
        let stand = GesundheitsStand(leser: leser, uhr: uhr.uhr)
        await stand.aktualisiere()
        XCTAssertEqual(stand.gewichte.map(\.kg), [80.4, 80.1])
        XCTAssertEqual(stand.vitale[.ruhepuls]?.count, 0)
    }
}
