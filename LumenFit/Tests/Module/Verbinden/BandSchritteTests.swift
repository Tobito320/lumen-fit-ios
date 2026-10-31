import XCTest
@testable import LumenFit

/// Die Erweiterung der Band-Brücke zu Lumen Alarm (Vertrag, Abschnitt 3): neue Felder in `band-status.json`, `wecker` in `band-wuensche.json`,
/// der Schrittzähler im Weckfenster (`AufstehWaechter`) und `band-schritte.json`. Alles ohne Band und ohne echte Wartezeit.
@MainActor
final class BandSchritteTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt
    /// 2026-10-29T09:00:00Z, unabhängig von der Zeitzone des Rechners.
    private let utc = Date(timeIntervalSince1970: 1_793_264_400)

    // MARK: Verlauf

    func testDieErsteProbeIstNurDerAusgangspunktUndDanachZaehltDerUnterschied() {
        var v = BandSchrittVerlauf(fenster: 3600)
        XCTAssertEqual(v.aufnehmen(summe: 1000, zeit: jetzt), 0)
        XCTAssertEqual(v.aufnehmen(summe: 1012, zeit: jetzt.addingTimeInterval(30)), 12)
        XCTAssertEqual(v.aufnehmen(summe: 1040, zeit: jetzt.addingTimeInterval(60)), 40)
    }

    func testEinZaehlerRuecksetzerMachtNieSchritteDerVerlaufFaengtNeuAn() {
        var v = BandSchrittVerlauf(fenster: 3600)
        _ = v.aufnehmen(summe: 5000, zeit: jetzt)
        XCTAssertEqual(v.aufnehmen(summe: 5020, zeit: jetzt.addingTimeInterval(30)), 20)
        XCTAssertEqual(v.aufnehmen(summe: 10, zeit: jetzt.addingTimeInterval(60)), 0, "neuer Tag oder neues Band")
        XCTAssertEqual(v.aufnehmen(summe: 25, zeit: jetzt.addingTimeInterval(90)), 15)
    }

    func testProbenAelterAlsDasFensterFallenWeg() {
        var v = BandSchrittVerlauf(fenster: 100)
        _ = v.aufnehmen(summe: 10, zeit: jetzt)
        XCTAssertEqual(v.aufnehmen(summe: 30, zeit: jetzt.addingTimeInterval(50)), 20)
        XCTAssertEqual(v.aufnehmen(summe: 50, zeit: jetzt.addingTimeInterval(150)), 20, "die erste Probe ist raus, die zweite ist der Ausgangspunkt")
        XCTAssertEqual(v.proben.count, 2)
    }

    // MARK: Fenster

    private func fenster(vor sekunden: TimeInterval, noetig: Int = 20, bis: Bool = false) -> WeckFenster {
        WeckFenster(weckzeit: jetzt.addingTimeInterval(-sekunden), schritteNoetig: noetig, bisAufgewacht: bis)
    }

    func testAktivIstNurDasFensterNachDerWeckzeitMitOffenenWuenschen() {
        let offen: @MainActor (String) -> Bool = { _ in true }
        XCTAssertEqual(AufstehWaechter.aktives([fenster(vor: 60)], jetzt: jetzt, offen: offen), fenster(vor: 60))
        XCTAssertNil(AufstehWaechter.aktives([fenster(vor: -60)], jetzt: jetzt, offen: offen), "vor der Weckzeit")
        XCTAssertNil(AufstehWaechter.aktives([fenster(vor: 60, noetig: 0)], jetzt: jetzt, offen: offen), "ohne Schritte-Pflicht")
        XCTAssertNil(AufstehWaechter.aktives([fenster(vor: 91 * 60)], jetzt: jetzt, offen: offen), "länger als 90 Minuten her")
        XCTAssertNil(AufstehWaechter.aktives([fenster(vor: 60)], jetzt: jetzt, offen: { _ in false }), "keine offenen Wünsche")
    }

    func testBisAufgewachtZaehltAuchOhneOffeneWuenscheUndDieFruehesteWeckzeitGewinnt() {
        let ohne: @MainActor (String) -> Bool = { _ in false }
        XCTAssertNotNil(AufstehWaechter.aktives([fenster(vor: 60, bis: true)], jetzt: jetzt, offen: ohne))
        let spaet = fenster(vor: 30), frueh = fenster(vor: 300)
        XCTAssertEqual(AufstehWaechter.aktives([spaet, frueh], jetzt: jetzt, offen: { _ in true }), frueh)
        XCTAssertEqual(AufstehWaechter.aktives([spaet, frueh], jetzt: jetzt, offen: { $0 == spaet.idPraefix }), spaet, "die frühere hat keine offenen Wünsche mehr")
    }

    func testDiePraefixeStehenWieInDenIds() {
        let f = WeckFenster(weckzeit: Date(timeIntervalSince1970: 1_800_000_000.9), schritteNoetig: 10)
        XCTAssertEqual(f.sekunden, 1_800_000_000)
        XCTAssertEqual(f.idPraefix, "wecker-1800000000-")
    }

    // MARK: Wächter

    private final class Ablauf: @unchecked Sendable {
        // @unchecked Sendable: Zeit und Zähler laufen über `schloss`, weil der Wächter sie aus Sendable-Closures liest.
        private let schloss = NSLock()
        private var _zeit: Date
        private var _summe: Int
        private var _lesen = 0
        private var _geschrieben: [BandSchritteDatei] = []
        private var _aufgestanden: [WeckFenster] = []
        let schrittJeFrage: Int
        var bandAntwortet = true

        init(zeit: Date, summe: Int, schrittJeFrage: Int) {
            _zeit = zeit
            _summe = summe
            self.schrittJeFrage = schrittJeFrage
        }

        var zeit: Date { schloss.withLock { _zeit } }
        var summe: Int { schloss.withLock { _summe } }
        var lesen: Int { schloss.withLock { _lesen } }
        var geschrieben: [BandSchritteDatei] { schloss.withLock { _geschrieben } }
        var aufgestanden: [WeckFenster] { schloss.withLock { _aufgestanden } }
        func vor(_ sekunden: TimeInterval) { schloss.withLock { _zeit = _zeit.addingTimeInterval(sekunden) } }
        func frage() -> Bool { schloss.withLock { _lesen += 1; _summe += schrittJeFrage; return true } }
        func schreibe(_ d: BandSchritteDatei) { schloss.withLock { _geschrieben.append(d) } }
        func fertig(_ f: WeckFenster) { schloss.withLock { _aufgestanden.append(f) } }
    }

    private func waechter(_ a: Ablauf, _ fenster: [WeckFenster], offen: @escaping @MainActor (String) -> Bool = { _ in true },
                          bisher: @escaping @MainActor () -> BandSchritteDatei? = { nil }) -> AufstehWaechter {
        AufstehWaechter(uhr: { a.zeit }, fenster: { fenster }, offen: offen,
                        lesen: { a.frage() }, stand: { guard a.bandAntwortet else { return nil }; return (a.summe, a.zeit) },
                        bisher: bisher, schreibe: { a.schreibe($0) }, aufgestanden: { a.fertig($0) },
                        warte: { sekunden in a.vor(sekunden) })
    }

    private func abwarten(_ bedingung: () -> Bool) async {
        for _ in 0..<200 {
            if bedingung() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testZaehltAbDerErstenProbeUndMeldetAufgestandenBeiGenugSchritten() async {
        let f = fenster(vor: 60, noetig: 20)
        let a = Ablauf(zeit: jetzt, summe: 1000, schrittJeFrage: 8)
        let w = waechter(a, [f])
        w.anstossen()
        await abwarten { !a.aufgestanden.isEmpty }
        withExtendedLifetime(w) {}
        XCTAssertEqual(a.aufgestanden, [f])
        XCTAssertEqual(a.geschrieben.map(\.schritte), [0, 8, 16, 24])
        XCTAssertEqual(a.geschrieben.map(\.aufgestanden), [false, false, false, true])
        XCTAssertEqual(a.geschrieben.last?.weckzeit, f.weckzeit)
        XCTAssertEqual(a.geschrieben.last?.version, 1)
        XCTAssertEqual(a.lesen, 4)
    }

    func testNachDemAufstehenStartetDasZaehlenNichtNeu() async {
        let f = fenster(vor: 60)
        let a = Ablauf(zeit: jetzt, summe: 0, schrittJeFrage: 5)
        let schon = BandSchritteDatei(version: 1, geschrieben: jetzt, weckzeit: f.weckzeit, schritte: 30, aufgestanden: true)
        let w = waechter(a, [f], bisher: { schon })
        w.anstossen()
        try? await Task.sleep(for: .milliseconds(50))
        withExtendedLifetime(w) {}
        XCTAssertEqual(a.lesen, 0)
        XCTAssertTrue(a.geschrieben.isEmpty)
    }

    func testEineAndereWeckzeitInDerDateiHindertNicht() async {
        let f = fenster(vor: 60, noetig: 5)
        let a = Ablauf(zeit: jetzt, summe: 0, schrittJeFrage: 5)
        let alt = BandSchritteDatei(version: 1, geschrieben: jetzt, weckzeit: f.weckzeit.addingTimeInterval(-86_400), schritte: 99, aufgestanden: true)
        let w = waechter(a, [f], bisher: { alt })
        w.anstossen()
        await abwarten { !a.aufgestanden.isEmpty }
        withExtendedLifetime(w) {}
        XCTAssertEqual(a.aufgestanden, [f])
    }

    func testOhneAntwortVomBandWirdNichtsGeschriebenUndNichtsGemeldet() async {
        // 89 Minuten nach der Weckzeit: das Fenster endet nach zwei Proben.
        let f = fenster(vor: 89 * 60, noetig: 5)
        let a = Ablauf(zeit: jetzt, summe: 0, schrittJeFrage: 5)
        a.bandAntwortet = false
        let w = waechter(a, [f])
        w.anstossen()
        await abwarten { a.lesen >= 2 }
        withExtendedLifetime(w) {}
        XCTAssertTrue(a.geschrieben.isEmpty)
        XCTAssertTrue(a.aufgestanden.isEmpty)
    }

    func testAusserhalbDesFenstersFragtNichts() async {
        let a = Ablauf(zeit: jetzt, summe: 0, schrittJeFrage: 5)
        for f in [fenster(vor: -600), fenster(vor: 60, noetig: 0), fenster(vor: 100 * 60)] {
            waechter(a, [f]).anstossen()
        }
        waechter(a, [fenster(vor: 60)], offen: { _ in false }).anstossen()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(a.lesen, 0, "kein Timer, keine Bluetooth-Frage")
    }

    func testStoppeBeendetDenZaehler() async {
        let a = Ablauf(zeit: jetzt, summe: 0, schrittJeFrage: 0)
        let f = fenster(vor: 60, noetig: 1000)
        // Die Zeit steht still, jede Wartezeit ist echt kurz: das Fenster endet nie von selbst.
        let w = AufstehWaechter(uhr: { a.zeit }, fenster: { return [f] }, offen: { _ in true }, lesen: { a.frage() }, stand: { (a.summe, a.zeit) },
                                bisher: { nil }, schreibe: { a.schreibe($0) }, aufgestanden: { a.fertig($0) },
                                warte: { _ in _ = try? await Task.sleep(for: .milliseconds(5)) })
        w.anstossen()
        await abwarten { a.lesen >= 2 }
        XCTAssertGreaterThanOrEqual(a.lesen, 2)
        w.stoppe()
        try? await Task.sleep(for: .milliseconds(50))
        let nachStopp = a.lesen
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(a.lesen, nachStopp)
    }

    // MARK: Dateien

    func testDasStatusFeldIstTolerantGelesen() throws {
        let alt = #"{"version":1,"geschrieben":"2026-10-29T10:00:00Z","verbunden":true,"akkuProzent":80,"name":"Band"}"#
        let a = try LoveaVertrag.decoder().decode(BandStatusDatei.self, from: Data(alt.utf8))
        XCTAssertEqual(a.akkuProzent, 80)
        XCTAssertNil(a.bluetoothAn)
        XCTAssertNil(a.schritteHeute)
        let neu = #"{"version":1,"geschrieben":"2026-10-29T10:00:00Z","verbunden":false,"bluetoothAn":false,"laedt":true,"zuletztGesehen":"2026-10-29T08:00:00Z","staerke":2,"schritteHeute":4321,"fremd":1}"#
        let b = try LoveaVertrag.decoder().decode(BandStatusDatei.self, from: Data(neu.utf8))
        XCTAssertEqual([b.bluetoothAn, b.laedt], [false, true])
        XCTAssertEqual(b.staerke, 2)
        XCTAssertEqual(b.schritteHeute, 4321)
        XCTAssertEqual(b.zuletztGesehen, utc.addingTimeInterval(-3600))
        let falsch = #"{"version":1,"geschrieben":"2026-10-29T10:00:00Z","verbunden":true,"bluetoothAn":"ja","schritteHeute":"viel","zuletztGesehen":5}"#
        let c = try LoveaVertrag.decoder().decode(BandStatusDatei.self, from: Data(falsch.utf8))
        XCTAssertTrue(c.verbunden, "ein falsch getyptes Zusatzfeld macht die Datei nicht unlesbar")
        XCTAssertNil(c.bluetoothAn)
        XCTAssertNil(c.schritteHeute)
        XCTAssertNil(c.zuletztGesehen)
    }

    func testDieStatusDateiRundetMitDenNeuenFeldernUndLaesstLeereWeg() throws {
        let datei = BandStatusDatei(version: 1, geschrieben: jetzt, verbunden: true, akkuProzent: 50, name: nil, bluetoothAn: true, laedt: false,
                                    zuletztGesehen: jetzt, staerke: nil, schritteHeute: 12)
        let daten = try LoveaVertrag.encoder().encode(datei)
        XCTAssertEqual(try LoveaVertrag.decoder().decode(BandStatusDatei.self, from: daten), datei)
        let roh = try XCTUnwrap(JSONSerialization.jsonObject(with: daten) as? [String: Any])
        XCTAssertNil(roh["staerke"], "was Fit nicht kennt, steht nicht in der Datei")
        XCTAssertEqual(roh["schritteHeute"] as? Int, 12)
    }

    func testWuenscheDateiMitUndOhneWeckerFeld() throws {
        let ohne = #"{"version":1,"wuensche":[]}"#
        XCTAssertNil(try LoveaVertrag.decoder().decode(BandWuenscheDatei.self, from: Data(ohne.utf8)).wecker)
        let mit = #"{"version":1,"wuensche":[],"wecker":[{"weckzeit":"2026-10-29T09:00:00Z","schritteNoetig":30,"bisAufgewacht":true},{"weckzeit":"2026-10-30T09:00:00Z","schritteNoetig":10}]}"#
        let d = try LoveaVertrag.decoder().decode(BandWuenscheDatei.self, from: Data(mit.utf8))
        XCTAssertEqual(d.wecker, [WeckFenster(weckzeit: utc, schritteNoetig: 30, bisAufgewacht: true),
                                  WeckFenster(weckzeit: utc.addingTimeInterval(86_400), schritteNoetig: 10, bisAufgewacht: false)])
        let kaputt = #"{"version":1,"wuensche":[],"wecker":"nein"}"#
        let k = try LoveaVertrag.decoder().decode(BandWuenscheDatei.self, from: Data(kaputt.utf8))
        XCTAssertNil(k.wecker, "ein kaputtes Feld macht die Wünsche nicht unlesbar")
    }

    private func alarmOrdner() throws -> (gruppe: URL, bruecke: LoveaBruecke, datei: URL) {
        let gruppe = try tempOrdner()
        let ordner = gruppe.appendingPathComponent("LumenAlarm", isDirectory: true)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return (gruppe, LoveaBruecke(ordner: gruppe, ordnerName: "LumenAlarm"), ordner.appendingPathComponent(LoveaVertrag.wuenscheDatei))
    }

    func testDieBrueckeSchreibtUndLiestBandSchritteUndLoeschtSieMitDenEigenenDateien() throws {
        let (gruppe, bruecke, _) = try alarmOrdner()
        XCTAssertNil(bruecke.schritte())
        let datei = BandSchritteDatei(version: 1, geschrieben: jetzt, weckzeit: jetzt, schritte: 12, aufgestanden: false)
        bruecke.schreibe(schritte: datei)
        XCTAssertEqual(bruecke.schritte(), datei)
        XCTAssertEqual(VerbindenTest.dateien(gruppe), ["LumenAlarm/band-schritte.json"])
        bruecke.loescheEigeneDateien()
        XCTAssertEqual(VerbindenTest.dateien(gruppe), [])
    }

    func testDieBrueckeLiestDasWeckerFeldUndMerktDieDateiBisSieSichAendert() throws {
        let (_, bruecke, url) = try alarmOrdner()
        func schreibe(_ text: String) throws { try Data(text.utf8).write(to: url, options: .atomic) }
        try schreibe(#"{"version":1,"wuensche":[{"id":"wecker-1-0","muster":"lang","zeit":"2026-10-29T10:00:00Z","von":"wecker"}],"wecker":[{"weckzeit":"2026-10-29T10:00:00Z","schritteNoetig":30}]}"#)
        XCTAssertEqual(bruecke.wuensche().map(\.id), ["wecker-1-0"])
        XCTAssertEqual(bruecke.weckFenster().map(\.schritteNoetig), [30])
        // Gleiche Datei, zweiter Aufruf: dieselbe Antwort (aus dem Zwischenspeicher).
        XCTAssertEqual(bruecke.wuensche().map(\.id), ["wecker-1-0"])
        // Eine andere Größe und Änderungszeit: neu gelesen.
        try schreibe(#"{"version":1,"wuensche":[],"wecker":[]}"#)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: url.path)
        XCTAssertTrue(bruecke.wuensche().isEmpty)
        XCTAssertTrue(bruecke.weckFenster().isEmpty)
        try FileManager.default.removeItem(at: url)
        XCTAssertTrue(bruecke.wuensche().isEmpty)
    }

    func testZweitausendWuenscheLassenSichSchnellLesen() throws {
        let (_, bruecke, url) = try alarmOrdner()
        let zeilen = (0..<2000).map { #"{"id":"wecker-\#($0 < 1000 ? 100 : 200)-\#($0)","muster":"lang","zeit":"2026-10-29T10:00:00Z","von":"wecker"}"# }
        try Data(#"{"version":1,"wuensche":[\#(zeilen.joined(separator: ","))]}"#.utf8).write(to: url)
        let start = Date()
        for _ in 0..<50 { XCTAssertEqual(bruecke.wuensche().count, 2000) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 5, "50 Lesevorgänge im Takt des Weckers (0,7 s) kosten nur einen Dekodiervorgang")
    }
}
