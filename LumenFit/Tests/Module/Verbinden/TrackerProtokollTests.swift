// Quelle: Lovea Tests/TrackerProtokollTests.swift
import XCTest
@testable import LumenFit

/// Paket-Codec des iSo-Tech-Trackers. `echt` sind Antworten, die am 08.10.2026 um 20:28 vom Gerät
/// mitgeschnitten wurden (Firmware 1.00.13, nur Lesebefehle). Alles andere ist synthetisch, aus
/// `paket` oder Hand-Bytes gebaut. Dass die Schrittzahl stimmt, hat Nutzer am 10.10.2026 bestätigt.
final class TrackerProtokollTests: XCTestCase {
    private func daten(hex: String) -> Data {
        var ergebnis = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let ende = hex.index(index, offsetBy: 2)
            ergebnis.append(UInt8(hex[index..<ende], radix: 16)!)
            index = ende
        }
        return ergebnis
    }

    private func bytes(_ daten: Data) -> [UInt8] { [UInt8](daten) }

    // MARK: Echte Pakete vom Gerät

    func testEchteAnfragenStimmenMitDemGeraetFormatUeberein() {
        XCTAssertEqual(TrackerProtokoll.akkuAnfrage, daten(hex: "03000000000000000000000000000003"))
        XCTAssertEqual(TrackerProtokoll.pulsEinstellungAnfrage, daten(hex: "16010000000000000000000000000017"))
        XCTAssertEqual(TrackerProtokoll.schritteHeuteAnfrage, daten(hex: "43000f005f01000000000000000000b2"))
    }

    func testSchrittAnfrageFuerVortageSetztNurByteEinsUndPruefsumme() {
        let gestern = bytes(TrackerProtokoll.schritteAnfrage(tagVersatz: 1))
        XCTAssertEqual(gestern.count, 16)
        XCTAssertEqual(Array(gestern[0..<6]), [0x43, 0x01, 0x0F, 0x00, 0x5F, 0x01])
        XCTAssertEqual(gestern[15], 0xB3)
        XCTAssertTrue(TrackerProtokoll.istGueltig(Data(gestern)))
    }

    func testEchteAkkuAntwort() {
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "031b000000000000000000000000001e")),
                       .akku(.init(prozent: 27, laedt: false)))
    }

    /// Schutz zum Fehler "Akku immer 100 %" (W-030): die Prozentzahl ist Byte 1 der Antwort, nie eine feste Zahl. Die Zeile
    /// im Parser ist seit dem ersten Commit (08.10.) unverändert; das hält fest, dass sie nicht auf 100 hängt.
    func testAkkuProzentKommtAusByteEins() {
        for prozent in [0, 1, 27, 50, 99, 100] {
            XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.akku, [UInt8(prozent), 0])),
                           .akku(.init(prozent: prozent, laedt: false)), "\(prozent) %")
        }
    }

    func testAkkuLadebitIstByteZwei() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.akku, [100, 1])), .akku(.init(prozent: 100, laedt: true)))
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.akku, [100, 0])), .akku(.init(prozent: 100, laedt: false)))
    }

    func testEchtePulsEinstellung() {
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "1601010a050000000000000000000027")),
                       .pulsEinstellung(.init(an: true, intervallMinuten: 10)))
    }

    func testEchteSchrittAntwortZeilen() {
        // Kopfpaket (Byte 1 = 0xF0, vier Zeilen folgen) ist keine Zeile.
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "43f00401000000000000000000000038")), .schritteKopf)
        let erste = TrackerProtokoll.SchrittSlot(tag: "2026-10-08", slot: 0x44, index: 0, anzahl: 4, kcal: 461, schritte: 128, meter: 77)
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "43261008440004cd0180004d00000064")), .schritte(erste))
        let dritte = TrackerProtokoll.SchrittSlot(tag: "2026-10-08", slot: 0x4C, index: 2, anzahl: 4, kcal: 944, schritte: 225, meter: 159)
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "432610084c0204b003e1009f00000006")), .schritte(dritte))
        XCTAssertFalse(erste.letzte)
        XCTAssertFalse(dritte.letzte)
    }

    func testEchtesSchlussPaketIstKeineZeile() {
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "43ff0000000000000000000000000042")), .schritteEnde)
    }

    func testLetzteZeileErkenntDasEndeDerAntwort() {
        let zeile = TrackerProtokoll.SchrittSlot(tag: "2026-10-08", slot: 1, index: 3, anzahl: 4, kcal: 0, schritte: 1, meter: 1)
        XCTAssertTrue(zeile.letzte)
        var einzige = zeile
        einzige.index = 0
        einzige.anzahl = 1
        XCTAssertTrue(einzige.letzte)
    }

    func testSchrittZeileMitUngueltigemDatumOderSlotIstKeineZeile() {
        // Monat 0x1A ist keine BCD-Zahl.
        var roh: [UInt8] = [0x43, 0x26, 0x1A, 0x08, 0x44, 0, 4, 1, 0, 1, 0, 1, 0, 0, 0, 0]
        roh[15] = TrackerProtokoll.pruefsumme(Array(roh[0..<15]))
        XCTAssertEqual(TrackerProtokoll.lesen(Data(roh)), .unbekannt(0x43))
        // Zeitindex 96 gibt es nicht (0 bis 95).
        roh = [0x43, 0x26, 0x10, 0x08, 96, 0, 4, 1, 0, 1, 0, 1, 0, 0, 0, 0]
        roh[15] = TrackerProtokoll.pruefsumme(Array(roh[0..<15]))
        XCTAssertEqual(TrackerProtokoll.lesen(Data(roh)), .unbekannt(0x43))
    }

    // MARK: Synthetisch

    func testPaketHatSechzehnByteUndPruefsumme() {
        let akku = bytes(TrackerProtokoll.akkuAnfrage)
        XCTAssertEqual(akku.count, 16)
        XCTAssertEqual(akku[0], 0x03)
        XCTAssertEqual(akku[15], 0x03)
    }

    func testPruefsummeLaeuftUeberModulo256() {
        XCTAssertEqual(TrackerProtokoll.pruefsumme([0xFF, 0x02]), 0x01)
    }

    func testUngueltigeLaengeOderPruefsummeGibtNil() {
        XCTAssertNil(TrackerProtokoll.lesen(Data([0x03, 0x1B])))
        var kaputt = bytes(daten(hex: "031b000000000000000000000000001e"))
        kaputt[15] = kaputt[15] &+ 1
        XCTAssertNil(TrackerProtokoll.lesen(Data(kaputt)))
        XCTAssertFalse(TrackerProtokoll.istGueltig(Data()))
    }

    func testAkkuLaedt() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.akku, [100, 1])),
                       .akku(.init(prozent: 100, laedt: true)))
    }

    func testPulsEinstellungAus() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsEinstellung, [1, 2, 30])),
                       .pulsEinstellung(.init(an: false, intervallMinuten: 30)))
    }

    func testUnbekannterBefehlWirdNichtGedeutet() {
        var roh = [UInt8](repeating: 0, count: 16)
        roh[0] = 0x7F
        roh[15] = TrackerProtokoll.pruefsumme(Array(roh[0..<15]))
        XCTAssertEqual(TrackerProtokoll.lesen(Data(roh)), .unbekannt(0x7F))
    }

    func testKennungenDesTrackers() {
        XCTAssertEqual(TrackerProtokoll.namenspraefix, "H59")
        XCTAssertEqual(TrackerProtokoll.dienst, "6E40FFF0-B5A3-F393-E0A9-E50E24DCCA9E")
    }

    // MARK: Einstellungen (Lesen echt vom 08.10.2026, Schreiben nach Referenz, am Gerät ungeprüft)

    private func nullen(_ anzahl: Int) -> String { String(repeating: "0", count: anzahl) }

    func testEchteEinstellungsAnfragenFuerSpo2StressHrv() {
        XCTAssertEqual(TrackerProtokoll.einstellungAnfrage(.spo2), daten(hex: "2c01" + nullen(26) + "2d"))
        XCTAssertEqual(TrackerProtokoll.einstellungAnfrage(.stress), daten(hex: "3601" + nullen(26) + "37"))
        XCTAssertEqual(TrackerProtokoll.einstellungAnfrage(.hrv), daten(hex: "3801" + nullen(26) + "39"))
    }

    func testEchteAntwortenAufDieEinstellungsAnfragen() {
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "2c01010000000000000000000000002e")), .dauermessung(.spo2, an: true))
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "36010100000000000000000000000038")), .dauermessung(.stress, an: true))
        XCTAssertEqual(TrackerProtokoll.lesen(daten(hex: "3801010000000000000000000000003a")), .dauermessung(.hrv, an: true))
    }

    func testAusgeschalteteDauermessungWirdAlsAusGelesen() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.spo2Einstellung, [1, 0])), .dauermessung(.spo2, an: false))
        // Puls: 2 heißt aus.
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsEinstellung, [1, 2, 30])),
                       .pulsEinstellung(.init(an: false, intervallMinuten: 30)))
    }

    func testSchreibpaketeFuerPuls() {
        XCTAssertEqual(TrackerProtokoll.Aenderung.puls(an: true, minuten: 30).schreiben, daten(hex: "1602011e" + nullen(22) + "37"))
        XCTAssertEqual(TrackerProtokoll.Aenderung.puls(an: false, minuten: 10).schreiben, daten(hex: "1602020a" + nullen(22) + "24"))
        XCTAssertEqual(TrackerProtokoll.Aenderung.puls(an: true, minuten: 30).lesen, TrackerProtokoll.pulsEinstellungAnfrage)
    }

    func testSchreibpaketeFuerSpo2StressHrv() {
        XCTAssertEqual(TrackerProtokoll.Aenderung.messung(.spo2, an: true).schreiben, daten(hex: "2c0201" + nullen(24) + "2f"))
        XCTAssertEqual(TrackerProtokoll.Aenderung.messung(.stress, an: false).schreiben, daten(hex: "360200" + nullen(24) + "38"))
        XCTAssertEqual(TrackerProtokoll.Aenderung.messung(.hrv, an: true).schreiben, daten(hex: "380201" + nullen(24) + "3b"))
        XCTAssertEqual(TrackerProtokoll.Aenderung.messung(.hrv, an: true).lesen, TrackerProtokoll.einstellungAnfrage(.hrv))
    }

    func testAntwortAufSchreibenIstEineQuittungUndKeinLesewert() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.Aenderung.messung(.spo2, an: true).schreiben), .quittung(0x2C))
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.Aenderung.puls(an: true, minuten: 10).schreiben), .quittung(0x16))
    }

    func testFindenPaketUndKeinResetOderAusschalten() {
        XCTAssertEqual(TrackerProtokoll.findenAnfrage, daten(hex: "5055aa" + nullen(24) + "4f"))
        // Nur diese Befehle kann Lumen Fit überhaupt bauen (0x15 liest nur den Pulsverlauf): Ausschalten (0x08) und Werksreset (0xFF) sind nicht dabei.
        // 0x37 und 0x39 lesen nur den Verlauf von Stress und HRV, 0x69 startet eine Pulsmessung (alle nach Gadgetbridge, Grad B).
        // 0x01 stellt nur die Uhr (Gadgetbridge `setDateTime`, jede Verbindung).
        XCTAssertEqual(Set(TrackerProtokoll.Befehl.allCases.map(\.rawValue)),
                       [0x01, 0x03, 0x15, 0x16, 0x2C, 0x36, 0x37, 0x38, 0x39, 0x43, 0x50, 0x69])
        XCTAssertFalse(TrackerProtokoll.Befehl.allCases.contains { $0.rawValue == 0x08 || $0.rawValue == 0xFF })
    }

    // MARK: Uhr des Bands stellen (Gadgetbridge `setDateTime`, am Gerät ungeprüft)

    private func berlin(_ j: Int, _ m: Int, _ t: Int, _ h: Int, _ min: Int, _ s: Int) -> Date {
        Datum.kalender.date(from: DateComponents(year: j, month: m, day: t, hour: h, minute: min, second: s))!
    }

    func testZeitSetzenPaketIstBcdInBerlinerZeitMitPruefsumme() {
        // Winterzeit: 29.10.2026 10:00:00 Berlin. Sprach-Byte 1. Summe 1 + 0x26 + 0x10 + 0x29 + 0x10 + 1 = 0x71.
        let winter = TrackerProtokoll.zeitSetzenAnfrage(berlin(2026, 10, 29, 10, 0, 0))
        XCTAssertEqual(winter, daten(hex: "0126102910000001" + nullen(14) + "71"))
        // Sommerzeit: 12:30:45 Berlin (10:30:45 UTC), Summe 0xCB.
        let sommer = TrackerProtokoll.zeitSetzenAnfrage(berlin(2026, 7, 15, 12, 30, 45))
        XCTAssertEqual(sommer, daten(hex: "0126071512304501" + nullen(14) + "cb"))
        XCTAssertTrue(TrackerProtokoll.istGueltig(winter))
        XCTAssertTrue(TrackerProtokoll.istGueltig(sommer))
    }

    func testZeitSetzenNimmtDenGegebenenKalenderNichtDieZeitzoneDesGeraets() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        let paket = bytes(TrackerProtokoll.zeitSetzenAnfrage(berlin(2026, 7, 15, 12, 30, 45), kalender: utc))
        XCTAssertEqual(Array(paket[1...6]), [0x26, 0x07, 0x15, 0x10, 0x30, 0x45])
    }

    func testZeitSetzenUeberJahreswechsel() {
        XCTAssertEqual(TrackerProtokoll.zeitSetzenAnfrage(berlin(2026, 12, 31, 23, 59, 58)), daten(hex: "0126123123595801" + nullen(14) + "3f"))
        XCTAssertEqual(TrackerProtokoll.zeitSetzenAnfrage(berlin(2027, 1, 1, 0, 0, 1)), daten(hex: "0127010100000101" + nullen(14) + "2c"))
    }

    func testAntwortAufDieUhrIstEineZeitQuittung() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.zeitSetzen, [0, 1, 0, 5])), .zeitQuittung)
    }

    // MARK: Verlauf von Stress und HRV, Pulsmessung (Gadgetbridge, am Gerät ungeprüft)

    func testVerlaufAnfragen() {
        XCTAssertEqual(TrackerProtokoll.stressVerlaufAnfrage, daten(hex: "37" + nullen(28) + "37"))
        XCTAssertEqual(TrackerProtokoll.hrvVerlaufAnfrage(tageZurueck: 0), daten(hex: "39" + nullen(28) + "39"))
        XCTAssertEqual(TrackerProtokoll.hrvVerlaufAnfrage(tageZurueck: 2), daten(hex: "3902000000" + nullen(20) + "3b"))
    }

    func testPulsMessenAnfrage() {
        XCTAssertEqual(TrackerProtokoll.pulsMessenAnfrage, daten(hex: "6901" + nullen(26) + "6a"))
    }

    func testVerlaufKopfWerteUndEnde() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.hrvVerlauf, [0, 4])), .verlauf(.hrv, .kopf(pakete: 4)))
        // Paket 1: Byte 2 ist etwas anderes, die zwölf Werte stehen in Byte 3 bis 14.
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.stressVerlauf, [1, 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120])),
                       .verlauf(.stress, .werte(nr: 1, werte: [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120])))
        // Ab Paket 2: dreizehn Werte in Byte 2 bis 14.
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.hrvVerlauf, [2, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])),
                       .verlauf(.hrv, .werte(nr: 2, werte: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])))
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.stressVerlauf, [0xFF])), .verlauf(.stress, .ende))
    }

    func testPulsMessungAntwort() {
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsMessen, [1, 0, 72])), .pulsMessung(fehler: 0, wert: 72))
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsMessen, [1, 1, 0])), .pulsMessung(fehler: 1, wert: 0))
        // Andere Messarten (Byte 1 = 3 ist SpO2) misst Lumen Fit nicht und deutet sie nicht.
        XCTAssertEqual(TrackerProtokoll.lesen(TrackerProtokoll.paket(.pulsMessen, [3, 0, 98])), .unbekannt(0x69))
    }
}
