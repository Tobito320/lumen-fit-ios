// Quelle: Lovea Health/Tests/CoachTageTests.swift
import XCTest
@testable import LumenFit

/// Health-Coach: ein Chat je Kalendertag (`CoachTage.swift`). Reine Logik, mit dem Berliner Kalender der App.
final class CoachTageTests: XCTestCase {

    private var berlin: Calendar { Datum.kalender }

    private var utc: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "UTC")!
        return k
    }

    /// Ein Zeitpunkt in UTC im Oktober 2026.
    private func zeit(_ tag: Int, _ stunde: Int, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde, minute: minute))!
    }

    private func nachricht(_ id: String, _ rolle: CoachRolle, _ zeit: Date, _ text: String = "Text") -> CoachNachricht {
        CoachTestBau.nachricht(id, rolle, text, zeit)
    }

    private func ids(_ liste: [CoachNachricht]) -> [String] { liste.map(\.id) }

    // MARK: - Tag zu einer Nachricht (Suche)

    func testTagZuEinerNachrichtNurFuerVergangeneTage() {
        let beginn = CoachTage.beginn(jetzt: zeit(11, 9), kalender: berlin)
        let liste = [nachricht("alt", .nutzer, zeit(9, 8)), nachricht("gestern", .coach, zeit(10, 8)), nachricht("heute", .nutzer, zeit(11, 8))]
        let tage = CoachTage.vergangene(liste, beginn: beginn, kalender: berlin)
        XCTAssertEqual(CoachTage.tag(mit: "alt", in: tage)?.nachrichten.map(\.id), ["alt"])
        XCTAssertEqual(CoachTage.tag(mit: "gestern", in: tage)?.nachrichten.map(\.id), ["gestern"])
        XCTAssertNil(CoachTage.tag(mit: "heute", in: tage), "heute springt der Chat selbst")
        XCTAssertNil(CoachTage.tag(mit: "gibt-es-nicht", in: tage))
    }

    // MARK: - Heute

    func testMitternachtsgrenzeInBerlinerZeit() {
        let beginn = CoachTage.beginn(jetzt: zeit(11, 9), kalender: berlin) // So 11.10., 11:00 Berlin
        XCTAssertEqual(beginn, zeit(10, 22), "00:00 Berlin = 22:00 UTC am Vortag (Sommerzeit)")
        let vorher = nachricht("a", .nutzer, beginn.addingTimeInterval(-1)) // 23:59:59 am 10.10.
        let genau = nachricht("b", .coach, beginn) // 00:00:00 am 11.10.
        XCTAssertEqual(ids(CoachTage.heute([vorher, genau], beginn: beginn)), ["b"])
        let davor = CoachTage.vergangene([vorher, genau], beginn: beginn, kalender: berlin)
        XCTAssertEqual(davor.map(\.anzahl), [1])
        XCTAssertEqual(ids(davor[0].nachrichten), ["a"])
    }

    func testZeitzoneEntscheidetUeberDenTag() {
        let spaetAbend = nachricht("a", .nutzer, zeit(10, 22, 30)) // 22:30 UTC = 00:30 Berlin am 11.10.
        let jetzt = zeit(11, 9)
        let beginnBerlin = CoachTage.beginn(jetzt: jetzt, kalender: berlin)
        XCTAssertEqual(ids(CoachTage.heute([spaetAbend], beginn: beginnBerlin)), ["a"], "in Berlin schon der neue Tag")
        let beginnUTC = CoachTage.beginn(jetzt: jetzt, kalender: utc)
        XCTAssertEqual(ids(CoachTage.heute([spaetAbend], beginn: beginnUTC)), [], "in UTC noch der alte Tag")
    }

    func testHeuteBleibtNachObenOffen() {
        let beginn = CoachTage.beginn(jetzt: zeit(11, 9), kalender: berlin)
        let vorgehend = nachricht("a", .coach, zeit(11, 9).addingTimeInterval(3600))
        XCTAssertEqual(ids(CoachTage.heute([vorgehend], beginn: beginn)), ["a"])
        XCTAssertTrue(CoachTage.vergangene([vorgehend], beginn: beginn, kalender: berlin).isEmpty)
    }

    func testLeerLiefertNichts() {
        let beginn = CoachTage.beginn(jetzt: zeit(11, 9), kalender: berlin)
        XCTAssertTrue(CoachTage.heute([], beginn: beginn).isEmpty)
        XCTAssertTrue(CoachTage.vergangene([], beginn: beginn, kalender: berlin).isEmpty)
        XCTAssertTrue(CoachTage.nachrichten(am: beginn, in: [], kalender: berlin).isEmpty)
    }

    func testNurHeuteGibtKeinenVerlauf() {
        let beginn = CoachTage.beginn(jetzt: zeit(11, 9), kalender: berlin)
        let liste = [nachricht("a", .nutzer, zeit(11, 6)), nachricht("b", .coach, zeit(11, 7))]
        XCTAssertEqual(ids(CoachTage.heute(liste, beginn: beginn)), ["a", "b"])
        XCTAssertTrue(CoachTage.vergangene(liste, beginn: beginn, kalender: berlin).isEmpty)
    }

    // MARK: - Vergangene Tage

    func testNeuesteTageZuerstUndReihenfolgeImTagBleibt() {
        let beginn = CoachTage.beginn(jetzt: zeit(11, 9), kalender: berlin)
        let liste = [
            nachricht("a", .nutzer, zeit(7, 8)),
            nachricht("b", .nutzer, zeit(8, 8)),
            nachricht("c", .coach, zeit(8, 9)),
            nachricht("d", .nutzer, zeit(9, 8)),
            nachricht("e", .coach, zeit(8, 10)),
        ]
        let tage = CoachTage.vergangene(liste, beginn: beginn, kalender: berlin)
        XCTAssertEqual(tage.map(\.anzahl), [1, 3, 1])
        XCTAssertEqual(tage.map { ids($0.nachrichten) }, [["d"], ["b", "c", "e"], ["a"]], "Eingabereihenfolge je Tag")
        XCTAssertEqual(tage.map(\.beginn), [zeit(8, 22), zeit(7, 22), zeit(6, 22)])
    }

    func testTageOhneNachrichtenTauchenNichtAuf() {
        let beginn = CoachTage.beginn(jetzt: zeit(11, 9), kalender: berlin)
        let liste = [nachricht("a", .nutzer, zeit(5, 12)), nachricht("b", .nutzer, zeit(8, 12))]
        XCTAssertEqual(CoachTage.vergangene(liste, beginn: beginn, kalender: berlin).count, 2)
    }

    func testTagDerZeitumstellungHat25Stunden() {
        // Mo 26.10., 10:00 Berlin. Am So 25.10. endet die Sommerzeit: der Tag geht von 22:00 UTC (24.10.) bis 23:00 UTC (25.10.).
        let beginn = CoachTage.beginn(jetzt: zeit(26, 9), kalender: berlin)
        let liste = [
            nachricht("a", .nutzer, zeit(24, 21, 30)), // 23:30 Berlin am Sa 24.10.
            nachricht("b", .nutzer, zeit(24, 22, 30)), // 00:30 Berlin am So 25.10.
            nachricht("c", .coach, zeit(25, 22, 30)), // 23:30 Berlin am So 25.10. (schon Winterzeit)
        ]
        let tage = CoachTage.vergangene(liste, beginn: beginn, kalender: berlin)
        XCTAssertEqual(tage.map { ids($0.nachrichten) }, [["b", "c"], ["a"]])
    }

    func testNachrichtenAmTag() {
        let tag = CoachTage.beginn(jetzt: zeit(8, 12), kalender: berlin)
        let liste = [nachricht("a", .nutzer, zeit(7, 12)), nachricht("b", .nutzer, zeit(8, 6)), nachricht("c", .coach, zeit(8, 21)), nachricht("d", .nutzer, zeit(8, 22))]
        // 08.10. in Berlin = 07.10. 22:00 UTC bis 08.10. 22:00 UTC (ohne): a liegt davor, d (00:00 Berlin am 9.10.) danach.
        XCTAssertEqual(ids(CoachTage.nachrichten(am: tag, in: liste, kalender: berlin)), ["b", "c"])
    }

    // MARK: - Vorschau

    func testVorschauNimmtDieErsteFrageDerPerson() {
        let tag = CoachTage.Tag(beginn: zeit(8, 22), nachrichten: [
            nachricht("a", .coach, zeit(8, 6), "Guten Morgen, dein **Tagesbericht**."),
            nachricht("b", .nutzer, zeit(8, 7), "Wie war mein Schlaf?"),
        ])
        XCTAssertEqual(tag.vorschau, "Wie war mein Schlaf?")
    }

    func testVorschauOhneFrageNimmtDieErsteNachrichtOhneMarkdown() {
        let tag = CoachTage.Tag(beginn: zeit(8, 22), nachrichten: [nachricht("a", .coach, zeit(8, 6), "Guten Morgen, dein **Tagesbericht**.")])
        XCTAssertEqual(tag.vorschau, "Guten Morgen, dein Tagesbericht.")
    }

    func testVorschauWirdGekuerzt() {
        let lang = String(repeating: "a", count: 200)
        let tag = CoachTage.Tag(beginn: zeit(8, 22), nachrichten: [nachricht("a", .nutzer, zeit(8, 7), lang)])
        XCTAssertEqual(tag.vorschau.count, 81)
        XCTAssertTrue(tag.vorschau.hasSuffix("…"))
        XCTAssertEqual(CoachTage.Tag(beginn: zeit(8, 22), nachrichten: []).vorschau, "")
    }
}
