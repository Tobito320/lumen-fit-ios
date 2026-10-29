import XCTest
@testable import LumenFit

final class TagesHinweisTests: XCTestCase {
    /// Mittwoch, 23.09.2026.
    private let heute = "2026-09-23"

    private func eingabe(_ aendern: (inout TagesHinweisLogik.Eingabe) -> Void = { _ in }) -> TagesHinweisLogik.Eingabe {
        var e = TagesHinweisLogik.Eingabe(heute: heute)
        aendern(&e)
        return e
    }

    private func ids(_ e: TagesHinweisLogik.Eingabe) -> [String] { TagesHinweisLogik.regeln(e).map(\.id) }

    func testRuhigerTagGibtKeineKarte() {
        XCTAssertEqual(ids(eingabe()), [])
    }

    func testZweimalUnterSechsStunden() {
        let karten = TagesHinweisLogik.regeln(eingabe { $0.schlafMinuten = ["2026-09-23": 330, "2026-09-22": 350] })
        XCTAssertEqual(karten.map(\.id), ["schlaf-kurz-2026-09-23"])
        XCTAssertEqual(karten.first?.titel, "Zweimal unter 6 Stunden")
        XCTAssertEqual(karten.first?.text, "5:50 h und 5:30 h. Heute locker, früh ins Bett.")
    }

    func testEineKurzeNachtAlleinGenuegtNicht() {
        XCTAssertEqual(ids(eingabe { $0.schlafMinuten = ["2026-09-23": 330, "2026-09-22": 450] }), [])
        XCTAssertEqual(ids(eingabe { $0.schlafMinuten = ["2026-09-23": 330] }), [])
        XCTAssertEqual(ids(eingabe { $0.schlafMinuten = ["2026-09-23": 360, "2026-09-22": 300] }), [], "genau 6 Stunden ist nicht darunter")
    }

    func testDreiGymTageAmStueck() {
        XCTAssertEqual(ids(eingabe { $0.gymInFolge = 3 }), ["gym-folge-2026-09-23"])
        XCTAssertEqual(ids(eingabe { $0.gymInFolge = 2 }), [])
    }

    func testWochenzielErstAbFreitag() {
        // Donnerstag noch nicht, Freitag mit einem von drei Tagen.
        XCTAssertEqual(ids(eingabe { $0.heute = "2026-09-24"; $0.gymTage = ["2026-09-21"] }), [])
        let freitag = TagesHinweisLogik.regeln(eingabe { $0.heute = "2026-09-25"; $0.gymTage = ["2026-09-21"] })
        XCTAssertEqual(freitag.map(\.id), ["gym-woche-2026-09-21"])
        XCTAssertEqual(freitag.first?.titel, "Noch 2 Gym-Tage bis zum Wochenziel")
        XCTAssertEqual(freitag.first?.text, "1 von 3 Tagen, noch 3 Tage in der Woche.")
        XCTAssertEqual(ids(eingabe { $0.heute = "2026-09-25"; $0.gymTage = ["2026-09-21", "2026-09-22", "2026-09-24"] }), [], "Ziel erreicht")
    }

    func testWasserErstAbDerSechzehntenStunde() {
        XCTAssertEqual(ids(eingabe { $0.stunde = 15; $0.wasserHeute = 1 }), [])
        XCTAssertEqual(ids(eingabe { $0.stunde = 16; $0.wasserHeute = 1 }), ["wasser-2026-09-23"])
        XCTAssertEqual(ids(eingabe { $0.stunde = 20; $0.wasserHeute = 4 }), [], "die Hälfte reicht")
    }

    func testLaengerNichtGewogen() {
        XCTAssertEqual(ids(eingabe { $0.gewichtTage = ["2026-09-16"] }), ["gewicht-2026-09-23"])
        XCTAssertEqual(ids(eingabe { $0.gewichtTage = ["2026-09-17"] }), [])
        XCTAssertEqual(ids(eingabe { $0.gewichtTage = [] }), [], "wer nie gewogen hat, bekommt keine Mahnung")
    }

    func testSchrittSerie() {
        let tage = ["2026-09-23": 10_500, "2026-09-22": 11_000, "2026-09-21": 10_000]
        XCTAssertEqual(ids(eingabe { $0.schritte = tage }), ["schritte-serie-2026-09-23"])
        var luecke = tage
        luecke["2026-09-22"] = 9_999
        XCTAssertEqual(ids(eingabe { $0.schritte = luecke }), [])
    }

    func testHoechstensDreiUndWeggewischteFehlen() {
        let viele = (1...5).map { TagesHinweis(id: "x\($0)", symbol: "star", titel: "T\($0)", text: "t") }
        XCTAssertEqual(TagesHinweisLogik.zeige(viele, weggewischt: []).map(\.id), ["x1", "x2", "x3"])
        XCTAssertEqual(TagesHinweisLogik.zeige(viele, weggewischt: ["x1", "x3"]).map(\.id), ["x2", "x4", "x5"], "die nächsten rücken nach, aber nie mehr als drei")
        XCTAssertEqual(TagesHinweisLogik.zeige(viele, weggewischt: Set(viele.map(\.id))), [])
        XCTAssertEqual(TagesHinweisLogik.hoechstens, 3)
    }

    func testEinsichtenAlsKartenOhneGesperrte() {
        let h = [HeuteHinweis(id: "stillstand.bank", art: .stillstand, titel: "Bank steht still", zahl: "80 kg", text: "Kein Plus.", tipp: "Eine leichte Woche.", basis: "", fortschritt: nil),
                 HeuteHinweis(id: "gesperrt.schlaf", art: .gesperrt, titel: "Schlaf gegen Leistung", zahl: "2/8", text: "Noch 6.", tipp: "", basis: "", fortschritt: 0.25)]
        let karten = TagesHinweisLogik.ausEinsichten(h, heute: heute)
        XCTAssertEqual(karten.map(\.id), ["einsicht-stillstand.bank-2026-09-21"], "je Woche eine Id: eine weggewischte Karte kommt nächste Woche wieder")
        XCTAssertEqual(karten.first?.text, "Kein Plus. Eine leichte Woche.")
    }

    // MARK: Speicher

    @MainActor
    func testWeggewischtesBleibtNachNeustart() throws {
        let ordner = try tempOrdner()
        let speicher = TagesHinweisSpeicher(ordner: ordner)
        XCTAssertTrue(speicher.ids.isEmpty)
        speicher.wische("a")
        speicher.wische("a")
        speicher.wische("b")
        XCTAssertEqual(speicher.weggewischt, ["a", "b"])
        XCTAssertEqual(TagesHinweisSpeicher(ordner: ordner).ids, ["a", "b"])
    }

    @MainActor
    func testSpeicherBehaeltNurDieLetztenNeunzig() {
        let speicher = TagesHinweisSpeicher()
        for i in 0..<100 { speicher.wische("id\(i)") }
        XCTAssertEqual(speicher.weggewischt.count, TagesHinweisSpeicher.behalten)
        XCTAssertEqual(speicher.weggewischt.last, "id99")
        XCTAssertFalse(speicher.ids.contains("id0"))
    }

    // MARK: - Sonntagskarte (Idee 39)

    func testSonntagsKommtDerWochenrueckblickMitDerZahlDerGymTage() {
        // Sonntag, 27.09.2026; die Woche beginnt am 21.09.
        let karten = TagesHinweisLogik.regeln(eingabe { $0.heute = "2026-09-27"; $0.gymTage = ["2026-09-21", "2026-09-23", "2026-09-14"] })
        let karte = karten.first { $0.id == "rueckblick-woche-2026-09-21" }
        XCTAssertEqual(karte?.titel, "Dein Wochenrückblick ist da")
        XCTAssertEqual(karte?.text, "2 Gym-Tage diese Woche. Tippe, um ihn anzusehen und zu teilen.", "nur die Tage dieser Woche zählen")
        XCTAssertEqual(karte?.ziel, .rueckblick, "ein Tipp öffnet den Rückblick")
        XCTAssertEqual(karten.first?.id, "rueckblick-woche-2026-09-21", "die Karte steht oben")
    }

    func testEinGymTagStehtInDerEinzahl() {
        let karten = TagesHinweisLogik.regeln(eingabe { $0.heute = "2026-09-27"; $0.gymTage = ["2026-09-22"] })
        XCTAssertEqual(karten.first?.text, "1 Gym-Tag diese Woche. Tippe, um ihn anzusehen und zu teilen.")
    }

    func testAnAnderenWochentagenKommtKeineRueckblickKarte() {
        for tag in ["2026-09-21", "2026-09-23", "2026-09-26"] {
            XCTAssertFalse(ids(eingabe { $0.heute = tag }).contains { $0.hasPrefix("rueckblick") }, tag)
        }
    }

    func testAmLetztenTagDesMonatsKommtDerMonatsrueckblick() {
        // Mittwoch, 30.09.2026 ist der letzte Tag; der 29. nicht.
        let karten = TagesHinweisLogik.regeln(eingabe { $0.heute = "2026-09-30" })
        XCTAssertEqual(karten.map(\.id), ["rueckblick-monat-2026-09"])
        XCTAssertEqual(karten.first?.titel, "Dein Monatsrückblick ist da")
        XCTAssertEqual(karten.first?.ziel, .rueckblick)
        XCTAssertFalse(ids(eingabe { $0.heute = "2026-09-29" }).contains { $0.hasPrefix("rueckblick") })
        // Fällt der letzte Tag auf einen Sonntag (31.05.2026), kommen beide, die Woche zuerst.
        XCTAssertEqual(TagesHinweisLogik.regeln(eingabe { $0.heute = "2026-05-31" }).map(\.id).prefix(2), ["rueckblick-woche-2026-05-25", "rueckblick-monat-2026-05"])
    }

    func testEineWeggewischteSonntagskarteKommtNichtZurueck() {
        let alle = TagesHinweisLogik.regeln(eingabe { $0.heute = "2026-09-27" })
        XCTAssertTrue(TagesHinweisLogik.zeige(alle, weggewischt: ["rueckblick-woche-2026-09-21"]).allSatisfy { $0.id != "rueckblick-woche-2026-09-21" })
    }
}
