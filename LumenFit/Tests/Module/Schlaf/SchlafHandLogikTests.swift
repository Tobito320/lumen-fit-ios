import XCTest
@testable import LumenFit

/// Das Journal (Freitext) ist weg; die Zeit-Rechnung für Nächte von Hand steht jetzt in `SchlafHandLogik`.
final class SchlafHandLogikTests: XCTestCase {
    private func uhr(_ tag: String, _ h: Int, _ m: Int) -> Date {
        Datum.kalender.date(bySettingHour: h, minute: m, second: 0, of: Datum.datum(tag)) ?? Date()
    }

    func testEintragAusZeitwaehlernLegtBettAufDenVorabend() {
        // Die Zeitwähler liefern nur Stunde und Minute, das Datum dahinter ist beliebig.
        let d = SchlafHandLogik.eintrag(tag: "2026-10-30", bett: uhr("2026-01-01", 23, 15), auf: uhr("2026-01-01", 6, 45))
        XCTAssertEqual(d?.bett, uhr("2026-10-29", 23, 15))
        XCTAssertEqual(d?.auf, uhr("2026-10-30", 6, 45))
    }

    func testEintragNachMitternachtBleibtAmSelbenTag() {
        let d = SchlafHandLogik.eintrag(tag: "2026-10-30", bett: uhr("2026-01-01", 0, 30), auf: uhr("2026-01-01", 8, 0))
        XCTAssertEqual(d?.bett, uhr("2026-10-30", 0, 30))
    }

    func testZuKurzOderZuLangIstKeinEintrag() {
        XCTAssertNil(SchlafHandLogik.eintrag(tag: "2026-10-30", bett: uhr("2026-01-01", 7, 0), auf: uhr("2026-01-01", 7, 30)))
        XCTAssertNil(SchlafHandLogik.eintrag(tag: "2026-10-30", bett: uhr("2026-01-01", 8, 0), auf: uhr("2026-01-01", 7, 0)), "Bett 8 Uhr, auf 7 Uhr wären 23 Stunden")
        XCTAssertNotNil(SchlafHandLogik.eintrag(tag: "2026-10-30", bett: uhr("2026-01-01", 8, 0), auf: uhr("2026-01-01", 9, 0)), "genau eine Stunde ist erlaubt")
    }

    func testNachtAusEintragUndLoeschung() {
        let d = SchlafHandD(tag: "2026-10-30", bett: uhr("2026-10-29", 23, 0), auf: uhr("2026-10-30", 6, 30))
        XCTAssertEqual(SchlafHandLogik.nacht(d)?.schlafMinuten, 450)
        XCTAssertEqual(SchlafHandLogik.nacht(d)?.abschnitte.first?.phase, .unbestimmt)
        var weg = d
        weg.geloescht = true
        XCTAssertNil(SchlafHandLogik.nacht(weg))
        XCTAssertNil(SchlafHandLogik.nacht(SchlafHandD(tag: "kaputt", bett: d.bett, auf: d.auf)))
        XCTAssertNil(SchlafHandLogik.nacht(SchlafHandD(tag: d.tag, bett: d.auf, auf: d.bett)))
    }

    func testLetzteOpJeTagGiltUndLoeschungNimmtSieWeg() {
        func op(_ d: SchlafHandD) -> Op { Op.neu(SchlafHandLogik.art, d, von: .testA, zeit: Date()) }
        let a = SchlafHandD(tag: "2026-10-30", bett: uhr("2026-10-29", 23, 0), auf: uhr("2026-10-30", 6, 0))
        var b = a
        b.auf = uhr("2026-10-30", 7, 0)
        XCTAssertEqual(SchlafHandLogik.naechte(ops: [op(a), op(b)])["2026-10-30"]?.schlafMinuten, 480)
        var weg = a
        weg.geloescht = true
        XCTAssertNil(SchlafHandLogik.naechte(ops: [op(a), op(weg)])["2026-10-30"])
    }

    func testAltesJSONOhneGeloeschtLaedt() throws {
        let json = Data(#"{"tag":"2026-10-30","bett":"2026-10-29T22:00:00Z","auf":"2026-10-30T05:00:00Z"}"#.utf8)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        XCTAssertNil(try dec.decode(SchlafHandD.self, from: json).geloescht)
    }

    func testEingetragenGewinntGegenUhrUndBand() {
        let uhrNacht = SchlafTestBau.nacht("2026-10-30", minuten: 420, phasen: true)
        let hand = SchlafHandLogik.nacht(SchlafHandD(tag: "2026-10-30", bett: uhr("2026-10-29", 23, 0), auf: uhr("2026-10-30", 6, 0))) ?? uhrNacht
        let liste = SchlafQuellenWahl.waehle(health: [uhrNacht.tag: uhrNacht], band: [], eingetragen: [hand.tag: hand])
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.quelle, .eingetragen)
        XCTAssertEqual(liste.first?.weitere, [.uhr])
    }
}

final class CreatinHabitTests: XCTestCase {
    func testCreatinIstEingebautUndNurHeute() {
        XCTAssertTrue(Habit.eingebaut.contains { $0.id == "creatin" })
        XCTAssertTrue(Habit.nurHeute.contains("creatin"))
        XCTAssertEqual(Habit.creatin.tagesziel, 2)
    }
}
