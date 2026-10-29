import XCTest
@testable import LumenFit

final class WochenStreifenTests: XCTestCase {
    /// Mittwoch, 23.09.2026.
    private let heute = "2026-09-23"

    private func woche(heute: String? = nil, schritte: [String: Int] = [:], schlaf: [String: Int] = [:], gym: Set<String> = [],
                       schritteZiel: Int = 10_000, schlafZiel: Int = 480) -> [WochenTag] {
        WochenStreifenLogik.woche(heute: heute ?? self.heute, schritte: schritte, schlafMinuten: schlaf, gymTage: gym, schritteZiel: schritteZiel, schlafZiel: schlafZiel)
    }

    func testSiebenTageMontagBisSonntag() {
        let w = woche()
        XCTAssertEqual(w.map(\.tag), ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27"])
        XCTAssertEqual(w.map(\.kuerzel), ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
        XCTAssertEqual(w.filter(\.istHeute).map(\.tag), ["2026-09-23"])
        XCTAssertEqual(w.filter(\.zukunft).count, 4)
    }

    func testAnteileJeBereich() {
        let w = woche(schritte: ["2026-09-21": 10_000, "2026-09-22": 5_000], schlaf: ["2026-09-21": 480, "2026-09-22": 240], gym: ["2026-09-21", "2026-09-23"])
        XCTAssertEqual(w[0].schritte, 1)
        XCTAssertEqual(w[1].schritte, 0.5)
        XCTAssertEqual(w[0].schlaf, 1)
        XCTAssertEqual(w[1].schlaf, 0.5)
        XCTAssertEqual(w.map(\.gym), [1, 0, 1, 0, 0, 0, 0])
        XCTAssertEqual(w[0].anteil(.bewegen), 1)
        XCTAssertEqual(w[0].anteil(.trainieren), 1)
        XCTAssertEqual(w[1].anteil(.erholen), 0.5)
        XCTAssertEqual(w[0].gesamt, 1, accuracy: 0.0001)
    }

    func testUeberschussWirdGekapptUndFehlendesIstNull() {
        let w = woche(schritte: ["2026-09-21": 25_000], schlaf: ["2026-09-21": 900])
        XCTAssertEqual(w[0].schritte, 1)
        XCTAssertEqual(w[0].schlaf, 1)
        XCTAssertEqual(w[1].schritte, 0)
        XCTAssertEqual(w[1].schlaf, 0)
        let ohneZiel = woche(schritte: ["2026-09-21": 8_000], schritteZiel: 0)
        XCTAssertEqual(ohneZiel[0].schritte, 0, "ohne Ziel gibt es keinen Anteil statt einer Division durch null")
    }

    func testZukunftHatImmerNull() {
        let w = woche(schritte: ["2026-09-25": 9_000], schlaf: ["2026-09-25": 400], gym: ["2026-09-25"])
        XCTAssertEqual(w[4].schritte, 0)
        XCTAssertEqual(w[4].schlaf, 0)
        XCTAssertEqual(w[4].gym, 0)
    }

    func testGymTageDerWocheZaehltEinheitenUndHakenBisHeute() {
        let session = GymSession(id: "s", tag: nil, start: Datum.datum("2026-09-22").addingTimeInterval(18 * 3600), ende: nil, laeufe: [])
        let alt = GymSession(id: "a", tag: nil, start: Datum.datum("2026-09-15").addingTimeInterval(18 * 3600), ende: nil, laeufe: [])
        let tage = WochenStreifenLogik.gymTageDerWoche(heute: heute, sessions: [session, alt], haken: ["2026-09-21": 1, "2026-09-20": 1, "2026-09-24": 1, "2026-09-23": 0])
        XCTAssertEqual(tage, ["2026-09-21", "2026-09-22"], "Vorwoche, Zukunft und Haken mit Wert 0 zählen nicht")
        XCTAssertEqual(WochenStreifenLogik.gymTage(sessions: [session, alt], haken: ["2026-09-21": 1]).count, 3)
    }

    func testBeschreibungFuerVoiceOver() {
        let w = woche(schritte: ["2026-09-21": 8_000], schlaf: ["2026-09-21": 456], gym: ["2026-09-21"])
        XCTAssertEqual(WochenStreifenLogik.beschreibung(w[0]), "Montag, 21. September: Schritte 80 %, Gym ja, Schlaf 95 %")
        XCTAssertEqual(WochenStreifenLogik.beschreibung(w[1]), "Dienstag, 22. September: Schritte 0 %, Gym nein, Schlaf 0 %")
        XCTAssertEqual(WochenStreifenLogik.beschreibung(w[6]), "Sonntag, 27. September: noch nicht dran")
    }
}

/// Zeitlogik um Mitternacht und über die Zeitumstellung (Berlin): der Tag und die Woche folgen dem Kalender, nie 24-Stunden-Schritten.
final class HeuteZeitTests: XCTestCase {
    func testWocheUeberDenTagMitDreiUndzwanzigStunden() {
        // Sonntag, 29.03.2026: Sommerzeit beginnt, der Tag hat 23 Stunden.
        let w = WochenStreifenLogik.woche(heute: "2026-03-29", schritte: [:], schlafMinuten: [:], gymTage: [], schritteZiel: 10_000, schlafZiel: 480)
        XCTAssertEqual(w.first?.tag, "2026-03-23")
        XCTAssertEqual(w.last?.tag, "2026-03-29")
        XCTAssertEqual(w.last?.istHeute, true)
        XCTAssertEqual(w.filter(\.zukunft).count, 0)
    }

    func testWocheUeberDenTagMitFuenfUndzwanzigStunden() {
        // Sonntag, 25.10.2026: Sommerzeit endet, der Tag hat 25 Stunden.
        let w = WochenStreifenLogik.woche(heute: "2026-10-25", schritte: [:], schlafMinuten: [:], gymTage: [], schritteZiel: 10_000, schlafZiel: 480)
        XCTAssertEqual(w.map(\.tag), (19...25).map { "2026-10-\($0)" })
        let naechsteWoche = WochenStreifenLogik.woche(heute: "2026-10-26", schritte: [:], schlafMinuten: [:], gymTage: [], schritteZiel: 10_000, schlafZiel: 480)
        XCTAssertEqual(naechsteWoche.first?.tag, "2026-10-26", "um Mitternacht beginnt die neue Woche")
        XCTAssertEqual(Datum.datum("2026-10-26").timeIntervalSince(Datum.datum("2026-10-25")), 25 * 3600, accuracy: 1)
    }

    func testTagWechseltExaktUmMitternachtBerlin() {
        let mitternacht = Datum.datum("2026-09-24")
        XCTAssertEqual(Datum.text(mitternacht.addingTimeInterval(-1)), "2026-09-23")
        XCTAssertEqual(Datum.text(mitternacht), "2026-09-24")
        XCTAssertEqual(TagesformRechnung.stunde(tag: "2026-09-24", jetzt: mitternacht), 0)
        XCTAssertEqual(TagesformRechnung.stunde(tag: "2026-09-23", jetzt: mitternacht), 24, "der Vortag zählt ganz")
    }

    func testSchlafUeberMitternachtGehoertZumAufwachtag() {
        // Bett um 23:30 am 23.09., aufgewacht 06:30 am 24.09.: die Nacht heißt 24.09.
        XCTAssertEqual(TagesformRechnung.bettMinuten(Datum.datum("2026-09-23").addingTimeInterval(23.5 * 3600)), 690)
        XCTAssertEqual(TagesformRechnung.bettMinuten(Datum.datum("2026-09-24").addingTimeInterval(0.5 * 3600)), 750, "00:30 liegt nach 23:30")
    }

    func testSchritteVerschiebenUeberDieZeitumstellung() {
        XCTAssertEqual(SchritteLogik.verschoben("2026-10-25", .tag, um: 1, heute: "2026-10-26"), "2026-10-26")
        XCTAssertEqual(SchritteLogik.verschoben("2026-10-26", .tag, um: -1, heute: "2026-10-26"), "2026-10-25")
        XCTAssertEqual(SchritteLogik.tage(.woche, anker: "2026-10-25").first, "2026-10-19")
    }
}
