// Quelle: Lovea Tests/TrackerSchlafTests.swift
import XCTest
@testable import LumenFit

/// Schlaf vom Armband (W-033, Phase 1): Rahmen, Zusammensetzen, Auswertung der Nacht, wann gefragt wird, Log-Meldungen.
/// Die Beispielpakete sind mit einer eigenen CRC-Rechnung außerhalb der App gebaut (Python), nicht mit `TrackerSchlaf.crc16`:
/// so prüft der Test die Rechnung und kreist nicht um sich selbst. Sie folgen der Gadgetbridge-Beschreibung (Beleggrad B), nicht
/// einer echten Antwort des H59MAX.
final class TrackerSchlafTests: XCTestCase {
    private let heute = "2026-10-14"
    /// 14.10.2026, 09:00 in Berlin: alle Nächte unten sind schon zu Ende.
    private var jetzt: Date { Datum.kalender.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 9, minute: 0))! }

    private func bytes(_ hex: String) -> [UInt8] {
        var ergebnis: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let ende = hex.index(index, offsetBy: 2)
            ergebnis.append(UInt8(hex[index..<ende], radix: 16)!)
            index = ende
        }
        return ergebnis
    }

    private func zeit(_ tag: Int, _ stunde: Int, _ minute: Int) -> Date {
        Datum.kalender.date(from: DateComponents(year: 2026, month: 10, day: tag, hour: stunde, minute: minute))!
    }

    /// Nutzdaten eines Rahmens (ohne die sechs Kopf-Byte).
    private func nutzdaten(_ rahmenHex: String) -> [UInt8] { Array(bytes(rahmenHex).dropFirst(6)) }

    // Rahmen (Typ 0x27) mit Nutzdaten, außerhalb der App gebaut.
    /// 3 Tage: heute 23:10 bis 06:40 (430 min Schlaf, 20 min wach), gestern 00:30 bis 07:00 (360 min), vorgestern 13:00 bis 13:40 (Nickerchen).
    private let drei = "bc272b00a4d60300106e0590010264033c0432027805140264010e1e00a4010296035a043c051e023c02060c0334030228"
    private let einTag = "bc271300ff200100106e0590010264033c0432027805140264"
    private let minutenNull = "bc2715006e9a0100126e0590010264033c02000432027805140264"
    private let nachMitternacht = "bc270f0075f201000c14007c0102c80364050a0432"
    private let summeZuLang = "bc270b0066d30100086e05900102ff03f5"
    private let phaseNeun = "bc270b0091b90100086e05900102c809fa"
    /// Wie `einTag`, aber mit einem Eintrag der Art 0 (30 min) mitten in der Nacht; die Phasen summieren sich genau auf die 450 min.
    private let phaseNull = "bc271500d7d20100126e0590010264033c0432001e025a05140264"
    private let keinTag = "bc270100bf4000"
    private let ohnePhasen = "bc2707005b290100046e059001"
    private let kaputteCrc = "bc27130000200100106e0590010264033c0432027805140264"
    private let tagZuKurz = "bc27090036650100086e0590010264"
    private let zweiterTagZuKurz = "bc271800a5be0200106e0590010264033c0432027805140264010e1e00a4"

    // MARK: Rahmen und CRC

    func testCrcMitBekanntenWerten() {
        XCTAssertEqual(TrackerSchlaf.crc16([0xFF]), 0x00FF, "so steht es in der Anfrage BC 27 01 00 FF 00 FF")
        XCTAssertEqual(TrackerSchlaf.crc16(Array("123456789".utf8)), 0x4B37, "Prüfwert aus dem CRC-Katalog für CRC-16/MODBUS")
        XCTAssertEqual(TrackerSchlaf.crc16([]), 0xFFFF)
    }

    func testAnfrageIstDieFesteLeseanfrage() {
        XCTAssertEqual([UInt8](TrackerSchlaf.anfrage), [0xBC, 0x27, 0x01, 0x00, 0xFF, 0x00, 0xFF])
    }

    func testRahmenBautDieselbenByteWieDasHandgebauteBeispiel() {
        let tag = Array(nutzdaten(einTag))
        XCTAssertEqual([UInt8](TrackerSchlaf.rahmen(typ: 0x27, nutzdaten: tag)), bytes(einTag))
    }

    // MARK: Zusammensetzen

    func testEinPaketIstFertig() {
        var sammler = TrackerSchlaf.Sammler()
        XCTAssertEqual(sammler.aufnehmen(Data(bytes(einTag))), .fertig(nutzdaten: nutzdaten(einTag)))
    }

    func testAntwortAufDreiPaketeVerteiltMitSchnittImKopf() {
        let alles = bytes(drei)
        var sammler = TrackerSchlaf.Sammler()
        XCTAssertEqual(sammler.aufnehmen(Data(alles[0..<3])), .wartet, "Länge noch nicht komplett")
        XCTAssertEqual(sammler.aufnehmen(Data(alles[3..<20])), .wartet)
        XCTAssertEqual(sammler.aufnehmen(Data(alles[20...])), .fertig(nutzdaten: nutzdaten(drei)))
        XCTAssertEqual(sammler.hex, drei)
    }

    func testKaputteCrcWirdAbgelehntUndNenntBeideWerte() {
        var sammler = TrackerSchlaf.Sammler()
        guard case .ungueltig(let grund) = sammler.aufnehmen(Data(bytes(kaputteCrc))) else { return XCTFail("CRC hätte auffallen müssen") }
        XCTAssertEqual(grund, "CRC im Rahmen 0x2000, berechnet 0x20FF")
        XCTAssertEqual(sammler.hex, kaputteCrc, "das Roh-Hex für das Log bleibt auch bei Fehlern")
    }

    func testFalscherKopfUndFalscherTypWerdenAbgelehnt() {
        var a = TrackerSchlaf.Sammler()
        XCTAssertEqual(a.aufnehmen(Data([0x03, 0x1B])), .ungueltig("Rahmen beginnt nicht mit BC"))
        var b = TrackerSchlaf.Sammler()
        XCTAssertEqual(b.aufnehmen(Data([0xBC, 0x2A, 0x01, 0x00])), .ungueltig("Typ 0x2A statt 0x27"))
    }

    func testUnsinnigeLaengeFuelltKeinenPuffer() {
        var sammler = TrackerSchlaf.Sammler()
        guard case .ungueltig = sammler.aufnehmen(Data([0xBC, 0x27, 0xFF, 0xFF, 0x00, 0x00])) else { return XCTFail("Länge 65535 ist unsinnig") }
    }

    func testBytesHinterDemRahmenWerdenVerworfen() {
        var sammler = TrackerSchlaf.Sammler()
        XCTAssertEqual(sammler.aufnehmen(Data(bytes(einTag) + [0xDE, 0xAD])), .fertig(nutzdaten: nutzdaten(einTag)))
    }

    func testLeeresPaketWartetNur() {
        var sammler = TrackerSchlaf.Sammler()
        XCTAssertEqual(sammler.aufnehmen(Data()), .wartet)
    }

    // MARK: Nächte

    func testMehrereTageGebenZweiNaechteUndVerwerfenDasNickerchen() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(drei), heute: heute, jetzt: jetzt)
        XCTAssertEqual(ergebnis.naechte.count, 2)
        // Einschlafen vor Mitternacht: größer als Aufwachen, also am Vortag.
        let heuteNacht = ergebnis.naechte.first { $0.tag == "2026-10-14" }
        XCTAssertEqual(heuteNacht?.von, zeit(13, 23, 10))
        XCTAssertEqual(heuteNacht?.bis, zeit(14, 6, 40))
        XCTAssertEqual(heuteNacht?.minuten, 430, "450 min mit 20 min wach")
        XCTAssertEqual(heuteNacht?.phasen.count, 6)
        let gestern = ergebnis.naechte.first { $0.tag == "2026-10-13" }
        XCTAssertEqual(gestern?.von, zeit(13, 0, 30))
        XCTAssertEqual(gestern?.bis, zeit(13, 7, 0))
        XCTAssertEqual(gestern?.minuten, 360)
        XCTAssertEqual(ergebnis.verworfen.count, 1)
        XCTAssertTrue(ergebnis.verworfen[0].contains("2026-10-12"), ergebnis.verworfen[0])
    }

    func testMinutenNullWerdenIgnoriert() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(minutenNull), heute: heute, jetzt: jetzt)
        XCTAssertEqual(ergebnis.naechte.first?.phasen.count, 6)
        XCTAssertEqual(ergebnis.naechte.first?.minuten, 430)
        XCTAssertTrue(ergebnis.verworfen.isEmpty)
    }

    func testEinschlafenNachMitternachtBleibtAmAufwachtag() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(nachMitternacht), heute: heute, jetzt: jetzt)
        XCTAssertEqual(ergebnis.naechte.first?.von, zeit(14, 0, 20))
        XCTAssertEqual(ergebnis.naechte.first?.bis, zeit(14, 6, 20))
        XCTAssertEqual(ergebnis.naechte.first?.minuten, 350, "360 min mit 10 min wach")
    }

    func testTageZurueckRechnenVomHeutigenTag() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(einTag), heute: "2026-10-20", jetzt: zeit(20, 9, 0))
        XCTAssertEqual(ergebnis.naechte.first?.tag, "2026-10-20")
        let spaeter = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(drei), heute: "2026-10-20", jetzt: zeit(20, 9, 0))
        XCTAssertEqual(Set(spaeter.naechte.map(\.tag)), ["2026-10-20", "2026-10-19"])
    }

    func testPhasenSummeDieNichtZurZeitPasstWirdVerworfen() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(summeZuLang), heute: heute, jetzt: jetzt)
        XCTAssertTrue(ergebnis.naechte.isEmpty)
        XCTAssertEqual(ergebnis.verworfen.count, 1)
        XCTAssertTrue(ergebnis.verworfen[0].contains("500"), ergebnis.verworfen[0])
    }

    func testUnbekanntePhaseWirdVerworfen() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(phaseNeun), heute: heute, jetzt: jetzt)
        XCTAssertTrue(ergebnis.naechte.isEmpty)
        XCTAssertTrue(ergebnis.verworfen[0].contains("unbekannte Phase 9"), ergebnis.verworfen[0])
    }

    /// Das echte Band meldet Einträge der Art 0 mitten in sonst stimmigen Nächten (Summe der Phasen gleich der Zeit): die Nacht bleibt,
    /// die Art 0 zählt nicht als Schlaf (Annahme "keine Daten", am Gerät ungeprüft).
    func testPhaseNullVerwirftDieNachtNichtUndZaehltNichtAlsSchlaf() throws {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(phaseNull), heute: heute, jetzt: jetzt)
        XCTAssertTrue(ergebnis.verworfen.isEmpty, ergebnis.verworfen.joined())
        let nacht = try XCTUnwrap(ergebnis.naechte.first)
        XCTAssertEqual(nacht.minuten, 100 + 60 + 50 + 90 + 100, "ohne die 30 min Art 0 und die 20 min wach")
        XCTAssertEqual(nacht.phasen.count, 7)
    }

    func testPhaseNullLaesstDasDiagrammZeitlichStimmen() throws {
        let nacht = try XCTUnwrap(TrackerSchlaf.auswerten(nutzdaten: nutzdaten(phaseNull), heute: heute, jetzt: jetzt).naechte.first)
        let leiste = try XCTUnwrap(TrackerSchlaf.diagramm(nacht))
        // 100 + 60 + 50 min Schlaf, dann 30 min Art 0 als Lücke (wach), dann 90 min leicht: das Ende der Lücke liegt 240 min nach dem Einschlafen.
        let luecke = try XCTUnwrap(leiste.abschnitte.first { $0.phase == .wach })
        XCTAssertEqual(luecke.von, nacht.von.addingTimeInterval(210 * 60))
        XCTAssertEqual(luecke.bis, nacht.von.addingTimeInterval(240 * 60))
        XCTAssertEqual(leiste.bis, nacht.bis)
        XCTAssertEqual(leiste.schlafMinuten, nacht.minuten)
    }

    func testOhnePhasenWirdVerworfen() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(ohnePhasen), heute: heute, jetzt: jetzt)
        XCTAssertTrue(ergebnis.naechte.isEmpty)
        XCTAssertTrue(ergebnis.verworfen[0].contains("keine Phasen"), ergebnis.verworfen[0])
    }

    func testLeereAntwortIstKeinFehler() {
        XCTAssertEqual(TrackerSchlaf.auswerten(nutzdaten: nutzdaten(keinTag), heute: heute, jetzt: jetzt), TrackerSchlaf.Auswertung())
        XCTAssertEqual(TrackerSchlaf.auswerten(nutzdaten: [], heute: heute, jetzt: jetzt), TrackerSchlaf.Auswertung())
    }

    func testAbgeschnittenerTagWirdVerworfenOhneAbsturz() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(tagZuKurz), heute: heute, jetzt: jetzt)
        XCTAssertTrue(ergebnis.naechte.isEmpty)
        XCTAssertEqual(ergebnis.verworfen.count, 1)
    }

    func testAbgeschnittenerZweiterTagLaesstDenErstenStehen() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(zweiterTagZuKurz), heute: heute, jetzt: jetzt)
        XCTAssertEqual(ergebnis.naechte.map(\.tag), ["2026-10-14"])
        XCTAssertEqual(ergebnis.verworfen.count, 1)
    }

    func testAbgeschnittenerTageskopfUndGemeldeteLaengeOhneDaten() {
        // 1 Tag angekündigt, danach nur ein Byte (Tageskopf unvollständig); und 200 Tage angekündigt ohne Inhalt.
        XCTAssertEqual(TrackerSchlaf.auswerten(nutzdaten: [1, 0], heute: heute, jetzt: jetzt).verworfen.count, 1)
        XCTAssertEqual(TrackerSchlaf.auswerten(nutzdaten: [200], heute: heute, jetzt: jetzt).verworfen.count, 1)
    }

    func testAufwachenInDerZukunftIstEineUnfertigeNacht() {
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(einTag), heute: heute, jetzt: zeit(14, 5, 0))
        XCTAssertTrue(ergebnis.naechte.isEmpty)
        XCTAssertTrue(ergebnis.verworfen[0].contains("Zukunft"), ergebnis.verworfen[0])
    }

    func testNachtUnterDreiStundenZaehltNicht() {
        // 13:00 bis 13:40 am Tag vor 2 Tagen (zweiter Rahmen oben) ist verworfen: Mindestnacht ist TrackerSchlaf.mindestNacht.
        XCTAssertEqual(TrackerSchlaf.mindestNacht, 180)
        let ergebnis = TrackerSchlaf.auswerten(nutzdaten: nutzdaten(drei), heute: heute, jetzt: jetzt)
        XCTAssertFalse(ergebnis.naechte.contains { $0.tag == "2026-10-12" })
    }

    // MARK: Zwei Teile einer Nacht

    private func teil(_ von: Date, _ bis: Date, _ phasen: [TrackerSchlaf.Phasenzeit]) -> TrackerSchlaf.Nacht {
        TrackerSchlaf.Nacht(tag: "2026-11-03", von: von, bis: bis, minuten: phasen.filter { $0.art != TrackerSchlaf.Phase.wach }.reduce(0) { $0 + $1.minuten }, phasen: phasen)
    }

    /// Rückmeldung 03.11.: 21:52 bis 01:25 geschlafen, Toilette, weiter bis 06:45. Vorher zeigte die App nur den ersten Teil (3:33 h).
    func testZweiTeileMitKurzerLueckeWerdenEineNachtMitWachPhase() {
        let a = teil(zeit(2, 21, 52), zeit(3, 1, 25), [.init(art: 2, minuten: 120), .init(art: 3, minuten: 93)])
        let b = teil(zeit(3, 1, 40), zeit(3, 6, 45), [.init(art: 2, minuten: 200), .init(art: 4, minuten: 105)])
        for n in [TrackerSchlaf.zusammen(a, b), TrackerSchlaf.zusammen(b, a)] {
            XCTAssertEqual(n.von, zeit(2, 21, 52))
            XCTAssertEqual(n.bis, zeit(3, 6, 45))
            XCTAssertEqual(n.minuten, 518)
            XCTAssertEqual(n.phasen.map(\.art), [2, 3, 5, 2, 4])
            XCTAssertEqual(n.phasen[2].minuten, 15)
        }
    }

    func testTeileMitLangerLueckeBleibenGetrenntUndDerLaengereGewinnt() {
        let a = teil(zeit(2, 14, 0), zeit(2, 14, 50), [.init(art: 2, minuten: 50)])
        let b = teil(zeit(2, 23, 0), zeit(3, 6, 0), [.init(art: 2, minuten: 420)])
        XCTAssertEqual(TrackerSchlaf.zusammen(a, b), b)
    }

    // MARK: Wann gefragt wird

    private func nachtHeute(bis: Date) -> [String: TrackerSchlaf.Nacht] {
        ["2026-10-14": TrackerSchlaf.Nacht(tag: "2026-10-14", von: bis.addingTimeInterval(-8 * 3600), bis: bis, minuten: 450, phasen: [])]
    }

    func testHoechstensAlleDreissigMinutenFragen() {
        XCTAssertTrue(TrackerSchlaf.faellig(letzte: nil, naechte: [:], heute: heute, jetzt: jetzt))
        XCTAssertFalse(TrackerSchlaf.faellig(letzte: jetzt.addingTimeInterval(-10 * 60), naechte: [:], heute: heute, jetzt: jetzt))
        XCTAssertFalse(TrackerSchlaf.faellig(letzte: jetzt.addingTimeInterval(-29 * 60), naechte: [:], heute: heute, jetzt: jetzt))
        XCTAssertTrue(TrackerSchlaf.faellig(letzte: jetzt.addingTimeInterval(-31 * 60), naechte: [:], heute: heute, jetzt: jetzt))
    }

    /// Das echte Band antwortet auf die Schlaf-Anfrage oft gar nicht (Lovea-Log: etwa jede dritte bis zweite Anfrage "0 Byte nach 15 s"). Eine
    /// Anfrage ohne Antwort darf nicht 30 Minuten sperren; nach `wiederholung` geht die nächste raus.
    func testAnfrageOhneAntwortWirdFrueherWiederholt() {
        XCTAssertEqual(TrackerSchlaf.wiederholung, 5 * 60)
        XCTAssertFalse(TrackerSchlaf.faellig(letzte: jetzt.addingTimeInterval(-4 * 60), naechte: [:], heute: heute, jetzt: jetzt, ohneAntwort: true))
        XCTAssertTrue(TrackerSchlaf.faellig(letzte: jetzt.addingTimeInterval(-6 * 60), naechte: [:], heute: heute, jetzt: jetzt, ohneAntwort: true))
        XCTAssertFalse(TrackerSchlaf.faellig(letzte: jetzt.addingTimeInterval(-6 * 60), naechte: [:], heute: heute, jetzt: jetzt, ohneAntwort: false),
                       "nach einer Antwort bleibt es bei 30 Minuten")
    }

    func testEineAnfrageOhneAntwortBeweistNichtDassDieNachtFertigIst() {
        let bis = zeit(14, 6, 40)
        let gelesen = nachtHeute(bis: bis)
        let spaet = zeit(14, 12, 30)
        XCTAssertFalse(TrackerSchlaf.faellig(letzte: spaet, naechte: gelesen, heute: heute, jetzt: spaet.addingTimeInterval(40 * 60)))
        XCTAssertTrue(TrackerSchlaf.faellig(letzte: spaet, naechte: gelesen, heute: heute, jetzt: spaet.addingTimeInterval(40 * 60), ohneAntwort: true))
    }

    func testSpringendeUhrSperrtNichtFuerImmer() {
        XCTAssertTrue(TrackerSchlaf.faellig(letzte: jetzt.addingTimeInterval(3600), naechte: [:], heute: heute, jetzt: jetzt))
    }

    func testNachGelesenerNachtVonHeuteWirdNichtMehrGefragt() {
        let bis = zeit(14, 6, 40)
        let nachMittag = zeit(14, 12, 30)
        XCTAssertFalse(TrackerSchlaf.faellig(letzte: nachMittag, naechte: nachtHeute(bis: bis), heute: heute, jetzt: nachMittag.addingTimeInterval(3600)))
        // Am Morgen gelesen: es kann noch ein zweiter Teil kommen, also weiter fragen.
        let gelesenNachAufwachen = jetzt.addingTimeInterval(-2 * 3600)
        XCTAssertTrue(TrackerSchlaf.faellig(letzte: gelesenNachAufwachen, naechte: nachtHeute(bis: bis), heute: heute, jetzt: jetzt))
        // Gelesen, bevor die Nacht zu Ende war: noch einmal fragen.
        let gelesenVorher = bis.addingTimeInterval(-3600)
        XCTAssertTrue(TrackerSchlaf.faellig(letzte: gelesenVorher, naechte: nachtHeute(bis: bis), heute: heute, jetzt: jetzt))
    }

    // MARK: Speicher

    func testBandSchlafMeldetNurAenderungenUndKuerzt() {
        let nacht = TrackerSchlaf.Nacht(tag: "2026-10-14", von: zeit(13, 23, 10), bis: zeit(14, 6, 40), minuten: 430, phasen: [.init(art: 2, minuten: 100)])
        var speicher = BandSchlaf()
        XCTAssertTrue(speicher.aufnehmen([nacht]))
        XCTAssertFalse(speicher.aufnehmen([nacht]), "dieselbe Nacht noch einmal ist nichts Neues")
        var laenger = nacht
        laenger.minuten = 440
        XCTAssertTrue(speicher.aufnehmen([laenger]))
        XCTAssertEqual(speicher.naechte["2026-10-14"]?.minuten, 440)
        var alt = nacht
        alt.tag = "2026-09-01"
        speicher.aufnehmen([alt])
        speicher.kuerzen(heute: "2026-10-14")
        XCTAssertEqual(Set(speicher.naechte.keys), ["2026-10-14"])
    }

    func testBandSchlafUeberlebtKodierenUndDekodieren() throws {
        var speicher = BandSchlaf()
        speicher.aufnehmen(TrackerSchlaf.auswerten(nutzdaten: nutzdaten(drei), heute: heute, jetzt: jetzt).naechte)
        let zurueck = try JSONDecoder().decode(BandSchlaf.self, from: JSONEncoder().encode(speicher))
        XCTAssertEqual(zurueck, speicher)
    }
}
