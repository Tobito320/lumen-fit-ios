// Quelle: Lovea Health/Tests/CoachLokalTests.swift
import XCTest
@testable import LumenFit

/// Health-Coach (portiert aus Lovea): Schlüssel, Merklisten, Schnellfragen, Suche, Export (`CoachLokal.swift`). Reine Logik.
final class CoachLokalTests: XCTestCase {

    private var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.timeZone = TimeZone(identifier: "UTC")!
        return k
    }

    private func zeit(_ tag: Int, _ stunde: Int = 12) -> Date {
        kalender.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde))!
    }

    private func nachricht(_ id: String, _ rolle: CoachRolle, _ text: String, _ zeit: Date) -> CoachNachricht {
        CoachTestBau.nachricht(id, rolle, text, zeit)
    }

    // MARK: - Schlüssel

    func testStabilerHashBekannteWerte() {
        XCTAssertEqual(CoachLokal.stabilerHash(""), "cbf29ce484222325")
        XCTAssertEqual(CoachLokal.stabilerHash("a"), "af63dc4c8601ec8c")
        XCTAssertEqual(CoachLokal.stabilerHash("foobar"), "85944171f73967e8")
    }

    func testSchluesselIgnoriertDenRand() {
        XCTAssertEqual(CoachLokal.schluessel("  Hallo \n"), CoachLokal.schluessel("Hallo"))
        XCTAssertNotEqual(CoachLokal.schluessel("Hallo"), CoachLokal.schluessel("hallo"))
    }

    // MARK: - Merklisten

    func testSetzenFuegtAnsEndeUndEntferntDoppelte() {
        XCTAssertEqual(CoachLokal.setzen([], "a", an: true, maximal: 3), ["a"])
        XCTAssertEqual(CoachLokal.setzen(["a", "b"], "a", an: true, maximal: 3), ["b", "a"])
    }

    func testSetzenKuerztAmAnfang() {
        XCTAssertEqual(CoachLokal.setzen(["a", "b", "c"], "d", an: true, maximal: 3), ["b", "c", "d"])
        XCTAssertEqual(CoachLokal.setzen(["a"], "b", an: true, maximal: 0), [])
    }

    func testSetzenAusEntferntNurDenEintrag() {
        XCTAssertEqual(CoachLokal.setzen(["a", "b"], "a", an: false, maximal: 3), ["b"])
        XCTAssertEqual(CoachLokal.setzen(["a"], "x", an: false, maximal: 3), ["a"])
    }

    // MARK: - Fortschritt

    func testAnteil() {
        XCTAssertEqual(CoachLokal.anteil(aktuell: 6200, ziel: 10000), 0.62, accuracy: 0.0001)
        XCTAssertEqual(CoachLokal.anteil(aktuell: 20000, ziel: 10000), 1)
        XCTAssertEqual(CoachLokal.anteil(aktuell: -3, ziel: 10), 0)
        XCTAssertEqual(CoachLokal.anteil(aktuell: 5, ziel: 0), 0)
        XCTAssertEqual(CoachLokal.anteil(aktuell: .infinity, ziel: 10), 0)
    }

    // MARK: - Schnellfragen

    func testHeuteGefragtNimmtNurEigeneFragenVonHeute() {
        let liste = [
            nachricht("1", .nutzer, "Alt", zeit(7)),
            nachricht("2", .nutzer, "Tagesbericht ", zeit(8, 8)),
            nachricht("3", .coach, "Antwort", zeit(8, 9)),
        ]
        XCTAssertEqual(CoachLokal.heuteGefragt(liste, jetzt: zeit(8, 20), kalender: kalender), ["Tagesbericht"])
    }

    func testSchnellfragenMorgens() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 8, wochentag: 4, schonGefragt: []),
                       ["Wie fühle ich mich?", "Was soll ich heute essen?", "Wie läuft mein Training?", "Tagesbericht"])
    }

    func testSchnellfragenAbendsMitLuecken() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 20, wochentag: 4, schonGefragt: []),
                       ["Was esse ich noch?", "Tagesbericht", CoachLokal.luecken, "Wie läuft mein Training?"])
    }

    func testSchnellfragenNachtsSindDieFesten() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 2, wochentag: 4, schonGefragt: []), CoachRegeln.schnellfragen)
    }

    func testSchnellfragenMontagsMitWochenrueckblickZuerst() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 2, schonGefragt: []),
                       [CoachLokal.wochenrueckblick, "Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"])
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 1, schonGefragt: []).first, CoachLokal.wochenrueckblick)
    }

    func testSchnellfragenLassenGefragtesWeg() {
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 4, schonGefragt: ["Tagesbericht"]),
                       ["Was soll ich heute essen?", "Wie läuft mein Training?"])
    }

    func testSchnellfragenZeigenAllesWennAllesGefragtWurde() {
        let alle: Set<String> = ["Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"]
        XCTAssertEqual(CoachLokal.schnellfragen(stunde: 14, wochentag: 4, schonGefragt: alle),
                       ["Tagesbericht", "Was soll ich heute essen?", "Wie läuft mein Training?"])
    }

    // MARK: - Suche und Sprung

    func testSucheOhneGrossKleinUndAkzent() {
        let liste = [
            nachricht("1", .nutzer, "Wie war mein Café-Besuch?", zeit(5)),
            nachricht("2", .coach, "Gut. Trink mehr Wasser.\n[[weiter: Wie war mein Schlaf?]]", zeit(5, 13)),
        ]
        XCTAssertEqual(CoachLokal.suche(liste, begriff: "cafe").map(\.id), ["1"])
        XCTAssertEqual(CoachLokal.suche(liste, begriff: "WASSER").map(\.id), ["2"])
    }

    func testSucheSiehtDieMarkerNicht() {
        let liste = [nachricht("2", .coach, "Gut.\n[[weiter: Wie war mein Schlaf?]]", zeit(5))]
        XCTAssertTrue(CoachLokal.suche(liste, begriff: "schlaf").isEmpty)
    }

    func testSucheMitLeeremBegriffFindetNichts() {
        let liste = [nachricht("1", .nutzer, "Hallo", zeit(5))]
        XCTAssertTrue(CoachLokal.suche(liste, begriff: "  ").isEmpty)
    }

    func testTageErsteNachrichtJedesTagesNeuesteZuerst() {
        let liste = [
            nachricht("1", .nutzer, "a", zeit(5, 9)),
            nachricht("2", .coach, "b", zeit(5, 18)),
            nachricht("3", .nutzer, "c", zeit(6, 8)),
            nachricht("4", .nutzer, "d", zeit(8, 7)),
        ]
        XCTAssertEqual(CoachLokal.tage(liste, kalender: kalender).map(\.id), ["4", "3", "1"])
        XCTAssertEqual(CoachLokal.tage(liste, kalender: kalender, maximal: 2).map(\.id), ["4", "3"])
        XCTAssertTrue(CoachLokal.tage([], kalender: kalender).isEmpty)
    }

    // MARK: - Export

    func testExportMitNamenUndOhneMarker() {
        let liste = [
            nachricht("1", .nutzer, " Hallo ", zeit(5)),
            nachricht("2", .coach, "Hi.\n[[weiter: A?]]", zeit(5, 13)),
        ]
        XCTAssertEqual(CoachLokal.export(liste, ich: "Ich") { _ in "12:00" },
                       "[12:00] Ich: Hallo\n\n[12:00] Coach: Hi.")
        XCTAssertEqual(CoachLokal.export([], ich: "Ich") { _ in "x" }, "")
    }

    // MARK: - Schnellfragen nur bis zur ersten eigenen Nachricht des Tages

    func testSchnellfragenSichtbarImLeerenChatUndMitNurCoachAntworten() {
        let jetzt = zeit(11, 9)
        XCTAssertTrue(CoachLokal.schnellfragenSichtbar([], jetzt: jetzt, kalender: kalender))
        // Der Morgengruß des Coachs heute zählt nicht als "heute geschrieben".
        let morgen = [nachricht("1", .coach, "Guten Morgen.", zeit(11, 8))]
        XCTAssertTrue(CoachLokal.schnellfragenSichtbar(morgen, jetzt: jetzt, kalender: kalender))
    }

    func testSchnellfragenWegNachDerErstenEigenenNachrichtHeute() {
        let jetzt = zeit(11, 9)
        let liste = [nachricht("1", .coach, "Guten Morgen.", zeit(11, 8)), nachricht("2", .nutzer, "Hallo", zeit(11, 9))]
        XCTAssertFalse(CoachLokal.schnellfragenSichtbar(liste, jetzt: jetzt, kalender: kalender))
    }

    func testSchnellfragenKommenAmNaechstenTagZurueck() {
        let gestern = [nachricht("1", .nutzer, "Hallo", zeit(10, 20)), nachricht("2", .coach, "Hi", zeit(10, 20))]
        XCTAssertTrue(CoachLokal.schnellfragenSichtbar(gestern, jetzt: zeit(11, 7), kalender: kalender))
        XCTAssertFalse(CoachLokal.schnellfragenSichtbar(gestern, jetzt: zeit(10, 23), kalender: kalender))
    }

    func testSchnellfragenTagesgrenzeInBerlinerZeit() {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        // 22:30 UTC am 10.10. ist 00:30 Berliner Zeit am 11.10.: ein neuer Tag, die Chips sind wieder da.
        let vorMitternachtUTC = kalender.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 21, minute: 30))!
        let nachMitternachtBerlin = kalender.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 22, minute: 30))!
        let liste = [nachricht("1", .nutzer, "Hallo", vorMitternachtUTC)]
        XCTAssertFalse(CoachLokal.schnellfragenSichtbar(liste, jetzt: vorMitternachtUTC, kalender: berlin))
        XCTAssertTrue(CoachLokal.schnellfragenSichtbar(liste, jetzt: nachMitternachtBerlin, kalender: berlin))
    }

    // MARK: - Name des Coachs

    func testNameLeerOderNurLeerraumIstStandard() {
        XCTAssertEqual(CoachLokal.anzeigeName(""), "Coach")
        XCTAssertEqual(CoachLokal.anzeigeName("  \n "), "Coach")
        XCTAssertEqual(CoachLokal.nameBereinigen("   "), "")
    }

    func testNameWirdBereinigt() {
        XCTAssertEqual(CoachLokal.anzeigeName("  Rex  "), "Rex")
        XCTAssertEqual(CoachLokal.anzeigeName("Max\nMuster"), "Max Muster")
        XCTAssertEqual(CoachLokal.anzeigeName("\"Rex\""), "Rex")
        // Marker-Klammern dürfen nie durchkommen, auch nicht verschachtelt.
        XCTAssertEqual(CoachLokal.nameBereinigen("[[ziel: x]]"), "ziel: x")
        XCTAssertFalse(CoachLokal.nameBereinigen("[[[[a]]]]").contains("["))
        XCTAssertEqual(CoachLokal.anzeigeName("[[ ]]"), "Coach")
    }

    func testNameHoechstensVierundzwanzigZeichen() {
        let lang = String(repeating: "a", count: 40)
        XCTAssertEqual(CoachLokal.nameBereinigen(lang).count, CoachLokal.maxNameZeichen)
        XCTAssertEqual(CoachLokal.maxNameZeichen, 24)
        // Ein Leerzeichen an der Schnittstelle bleibt nicht am Ende hängen.
        let mitLeerzeichen = String(repeating: "a", count: 23) + " b"
        XCTAssertEqual(CoachLokal.nameBereinigen(mitLeerzeichen), String(repeating: "a", count: 23))
    }

    func testExportNenntDenEigenenNamen() {
        let liste = [nachricht("1", .nutzer, "Hallo", zeit(5)), nachricht("2", .coach, "Hi.", zeit(5, 13))]
        XCTAssertEqual(CoachLokal.export(liste, ich: "Ich", coach: "Rex") { _ in "12:00" },
                       "[12:00] Ich: Hallo\n\n[12:00] Rex: Hi.")
    }

    // MARK: - Warten

    func testDenkHinweisErstNachEinigenSekunden() {
        XCTAssertNil(CoachLokal.denkHinweis(sekunden: -1))
        XCTAssertNil(CoachLokal.denkHinweis(sekunden: 0))
        XCTAssertNil(CoachLokal.denkHinweis(sekunden: 7.9))
        XCTAssertNotNil(CoachLokal.denkHinweis(sekunden: 8))
        XCTAssertNotNil(CoachLokal.denkHinweis(sekunden: 14.9))
        XCTAssertNotNil(CoachLokal.denkHinweis(sekunden: 15))
        XCTAssertNotEqual(CoachLokal.denkHinweis(sekunden: 10), CoachLokal.denkHinweis(sekunden: 25))
        XCTAssertEqual(CoachLokal.denkGrenze, 15, "die Tippanzeige steht höchstens 15 Sekunden")
    }
}
