import XCTest
@testable import LumenFit

/// Die Brücke zu Lumen Alarm: Band-Nächte als `schlaf-band.json` (nur bei Änderung neu), Nächte von Hand und Ziel einmal als `schlaf-uebergabe.json`.
@MainActor
final class SchlafBrueckeTests: XCTestCase {
    private let jetzt = Date(timeIntervalSince1970: 1_794_200_000)

    private func nacht(_ tag: String, minuten: Double, wach: Double = 0) -> BandSchlafOp {
        let ende = Datum.datum(tag).addingTimeInterval(7 * 3600)
        let start = ende.addingTimeInterval(-(minuten + wach) * 60)
        var phasen = [SchlafAbschnitt(phase: .kern, von: start, bis: start.addingTimeInterval(minuten * 60))]
        if wach > 0 { phasen.append(SchlafAbschnitt(phase: .wach, von: start.addingTimeInterval(minuten * 60), bis: ende)) }
        return BandSchlafOp(tag: tag, start: start, ende: ende, phasen: phasen)
    }

    func testBandNaechteJeTagDieLetzteOhneWachHoechstensDreissig() {
        var ops = (1...35).map { nacht(Datum.addTage("2026-10-01", $0), minuten: 400) }
        ops.append(nacht("2026-11-05", minuten: 300, wach: 20))   // zweite Op für denselben Tag gewinnt
        let datei = SchlafBruecke.band(ops: ops, jetzt: jetzt)
        XCTAssertEqual(datei.version, 1)
        XCTAssertEqual(datei.naechte.count, 30)
        XCTAssertEqual(datei.naechte.first?.tag, "2026-10-07", "die ältesten fallen weg")
        let fuenfter = datei.naechte.first { $0.tag == "2026-11-05" }
        XCTAssertEqual(fuenfter?.minuten, 300, "Wach zählt nicht")
        XCTAssertEqual(fuenfter?.phasen.map(\.art), ["kern", "wach"])
        XCTAssertEqual(SchlafBruecke.art(.unbestimmt), "schlaf")
        XCTAssertEqual(SchlafBruecke.minuten([], start: jetzt, ende: jetzt.addingTimeInterval(7 * 3600)), 420, "ohne Phasen die ganze Spanne")
    }

    func testUebergabeTraegtHandNaechteUndZiel() throws {
        let hand = try XCTUnwrap(SchlafHandLogik.nacht(SchlafHandD(tag: "2026-11-07", bett: Datum.datum("2026-11-06").addingTimeInterval(23 * 3600), auf: Datum.datum("2026-11-07").addingTimeInterval(7 * 3600))))
        let u = SchlafBruecke.uebergabe(hand: ["2026-11-07": hand], zielMinuten: 450, extra: SchlafZielExtra(extraMinuten: 30, extraTage: 96), jetzt: jetzt)
        XCTAssertEqual(u.hand.map(\.tag), ["2026-11-07"])
        XCTAssertEqual(u.hand.first?.bett, hand.von)
        XCTAssertEqual(u.ziel, .init(minuten: 450, extraMinuten: 30, extraTage: 96))
        let text = String(decoding: try LoveaVertrag.encoder().encode(u), as: UTF8.self)
        XCTAssertTrue(text.contains("\"extraTage\":96"))
        XCTAssertTrue(text.contains("\"version\":1"))
    }

    func testBandDateiWirdNurBeiAenderungNeuGeschriebenUebergabeNurEinmal() throws {
        let ordner = try tempOrdner()
        let a = SchlafBruecke.band(ops: [nacht("2026-11-08", minuten: 410)], jetzt: jetzt)
        SchlafBruecke.schreibeBand(a, in: ordner)
        let url = ordner.appendingPathComponent(SchlafBruecke.bandDatei)
        let erst = try Data(contentsOf: url)
        SchlafBruecke.schreibeBand(SchlafBruecke.band(ops: [nacht("2026-11-08", minuten: 410)], jetzt: jetzt + 600), in: ordner)
        XCTAssertEqual(try Data(contentsOf: url), erst, "gleiche Nächte, anderes geschrieben: Datei bleibt")
        SchlafBruecke.schreibeBand(SchlafBruecke.band(ops: [nacht("2026-11-08", minuten: 410), nacht("2026-11-09", minuten: 380)], jetzt: jetzt + 600), in: ordner)
        let gelesen = try LoveaVertrag.decoder().decode(SchlafBandDatei.self, from: try Data(contentsOf: url))
        XCTAssertEqual(gelesen.naechte.map(\.tag), ["2026-11-08", "2026-11-09"])

        // Über die Umgebung: die Übergabe entsteht einmal und wird nicht überschrieben.
        let uhr = TestUhr()
        uhr.setze(jetzt)
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: StilleMitteilung(),
                            leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: KeinePartnerBruecke(), uhr: uhr.uhr, passwortRunden: 1_000)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "")
        let daten = try XCTUnwrap(u.daten)
        daten.raum.senden(SchlafZielLogik.art, SchlafZielExtra(extraMinuten: -15, extraTage: 1))
        SchlafBruecke.schreiben(u, ordner: ordner)
        let uebergabe = ordner.appendingPathComponent(SchlafBruecke.uebergabeDatei)
        let u1 = try LoveaVertrag.decoder().decode(SchlafUebergabeDatei.self, from: try Data(contentsOf: uebergabe))
        XCTAssertEqual(u1.ziel.extraMinuten, -15)
        XCTAssertEqual(u1.ziel.minuten, daten.ziele.ziele.schlafMinuten)
        daten.raum.senden(SchlafZielLogik.art, SchlafZielExtra(extraMinuten: 45, extraTage: 1))
        SchlafBruecke.schreiben(u, ordner: ordner)
        let u2 = try LoveaVertrag.decoder().decode(SchlafUebergabeDatei.self, from: try Data(contentsOf: uebergabe))
        XCTAssertEqual(u2.ziel.extraMinuten, -15, "die Übergabe bleibt, wie sie zuerst geschrieben wurde")
        XCTAssertEqual(try LoveaVertrag.decoder().decode(SchlafBandDatei.self, from: try Data(contentsOf: url)).naechte, [], "ohne Band-Ops eine leere Liste")
    }
}
