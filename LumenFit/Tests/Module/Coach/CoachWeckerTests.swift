import XCTest
@testable import LumenFit

/// Wecker und Erinnerungen per Coach-Marker: Form der Marker, Prüfung gegen den Stand von Lumen Alarm, die Auftragsdatei und die ehrliche Karte
/// ("gestellt" erst, wenn `wecker-ergebnis.json` ok meldet). Alles in Temp-Ordnern, ohne Namen von Personen.
@MainActor
final class CoachWeckerTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt   // 2026-10-29, 10:00 Uhr
    private let heute = "2026-10-29"
    private let jetztMinute = 10 * 60

    private let stand = WeckerStandDatei(
        version: 1,
        haupt: .init(aktiv: true, minute: 6 * 60 + 30, name: nil),
        wecker: [.init(id: "Wecker-A", minute: 7 * 60, name: "Früh", tage: [1, 2, 3, 4, 5], aktiv: true, einmalAm: nil)],
        erinnerungen: [.init(id: "Erinnerung-A", minute: 18 * 60, text: "Trinken", tage: [], datum: nil, aktiv: true)])

    private func marker(_ roh: String) -> [WeckerBefehl] {
        CoachMarker.zerlegen(roh).marker.compactMap { if case .weckerSteuern(let b) = $0 { return b } else { return nil } }
    }

    // MARK: Form

    func testWeckerNeuMitUndOhneName() {
        XCTAssertEqual(marker("[[wecker: neu | 6:30 | werktags | Früh]]"), [.weckerNeu(minute: 390, tage: [1, 2, 3, 4, 5], name: "Früh")])
        XCTAssertEqual(marker("[[wecker: neu | 06:30 | einmalig]]"), [.weckerNeu(minute: 390, tage: [], name: "")])
        XCTAssertEqual(marker("[[wecker: neu | 07:00 | taeglich]]"), [.weckerNeu(minute: 420, tage: Array(1...7), name: "")])
        XCTAssertEqual(marker("[[wecker: neu | 07:00 | mo,mi,fr | A]]"), [.weckerNeu(minute: 420, tage: [1, 3, 5], name: "A")])
    }

    func testAendernSchalterUndLoeschen() {
        XCTAssertEqual(marker("[[wecker: aendern | Wecker-A | 06:45 | wochenende | Neu]]"), [.weckerAendern(id: "Wecker-A", minute: 405, tage: [6, 7], name: "Neu")])
        XCTAssertEqual(marker("[[wecker: aendern | Wecker-A | 06:45 | werktags]]"), [.weckerAendern(id: "Wecker-A", minute: 405, tage: [1, 2, 3, 4, 5], name: nil)])
        XCTAssertEqual(marker("[[wecker: an | haupt]]"), [.weckerSchalter(id: "haupt", an: true)])
        XCTAssertEqual(marker("[[wecker: aus | Wecker-A]]"), [.weckerSchalter(id: "Wecker-A", an: false)])
        XCTAssertEqual(marker("[[wecker: loeschen | Wecker-A]]"), [.weckerLoeschen(id: "Wecker-A")])
    }

    func testErinnerungenMitTextUndDatum() {
        XCTAssertEqual(marker("[[erinnern: neu | 18:00 | einmalig | Wasser trinken]]"), [.erinnerungNeu(minute: 1080, tage: [], datum: nil, text: "Wasser trinken")])
        XCTAssertEqual(marker("[[erinnern: neu | 18:00 | 2026-11-02 | Kreatin]]"), [.erinnerungNeu(minute: 1080, tage: [], datum: "2026-11-02", text: "Kreatin")])
        XCTAssertEqual(marker("[[erinnern: aendern | Erinnerung-A | 19:00 | taeglich]]"),
                       [.erinnerungAendern(id: "Erinnerung-A", minute: 1140, tage: Array(1...7), datum: nil, text: nil)])
        XCTAssertEqual(marker("[[erinnern: aus | Erinnerung-A]]"), [.erinnerungSchalter(id: "Erinnerung-A", an: false)])
    }

    func testKaputteFormenFallenWeg() {
        for roh in ["[[wecker: neu | 25:00 | werktags]]", "[[wecker: neu | 6:5 | werktags]]", "[[wecker: neu | 06:30 | irgendwann]]", "[[wecker: neu | 06:30]]",
                    "[[wecker: neu | 06:30 | 2026-11-02 | x]]", "[[wecker: an]]", "[[wecker: an | a | b]]", "[[wecker: boom | a]]",
                    "[[erinnern: neu | 18:00 | einmalig]]", "[[erinnern: neu | 18:00 | einmalig |  ]]", "[[wecker: aendern | a | 06:30]]"] {
            XCTAssertTrue(marker(roh).isEmpty, roh)
        }
    }

    func testNameWirdAufDreissigUndTextAufSechzigZeichenGekuerzt() {
        let lang = String(repeating: "x", count: 100)
        guard case .weckerNeu(_, _, let name)? = marker("[[wecker: neu | 06:30 | taeglich | \(lang)]]").first else { return XCTFail("kein Wecker") }
        XCTAssertEqual(name.count, 30)
        guard case .erinnerungNeu(_, _, _, let text)? = marker("[[erinnern: neu | 06:30 | taeglich | \(lang)]]").first else { return XCTFail("keine Erinnerung") }
        XCTAssertEqual(text.count, 60)
    }

    func testDerMarkerStehtNieImText() {
        XCTAssertEqual(CoachMarker.zerlegen("Ich schlage 06:30 vor.\n[[wecker: neu | 06:30 | werktags]]").text, "Ich schlage 06:30 vor.")
    }

    // MARK: Prüfen gegen den Stand

    func testUnbekannteIdsGeltenNicht() {
        for b: WeckerBefehl in [.weckerAendern(id: "fremd", minute: 1, tage: [], name: nil), .weckerSchalter(id: "fremd", an: true), .weckerLoeschen(id: "fremd"),
                                .erinnerungAendern(id: "fremd", minute: 1, tage: [], datum: nil, text: nil), .erinnerungSchalter(id: "fremd", an: true),
                                .erinnerungLoeschen(id: "fremd")] {
            XCTAssertNil(b.geprueft(gegen: stand, heute: heute, jetztMinute: jetztMinute), "\(b)")
        }
    }

    func testIdsWerdenSoGeschriebenWieDerStandSieKennt() {
        let b = WeckerBefehl.weckerLoeschen(id: "wecker-a").geprueft(gegen: stand, heute: heute, jetztMinute: jetztMinute)
        XCTAssertEqual(b, .weckerLoeschen(id: "Wecker-A"))
    }

    func testHauptNurFuerAnUndAus() {
        XCTAssertNotNil(WeckerBefehl.weckerSchalter(id: "haupt", an: false).geprueft(gegen: stand, heute: heute, jetztMinute: jetztMinute))
        XCTAssertNil(WeckerBefehl.weckerLoeschen(id: "haupt").geprueft(gegen: stand, heute: heute, jetztMinute: jetztMinute))
        XCTAssertNil(WeckerBefehl.weckerAendern(id: "haupt", minute: 1, tage: [], name: nil).geprueft(gegen: stand, heute: heute, jetztMinute: jetztMinute))
        let ohne = WeckerStandDatei(version: 1)
        XCTAssertNil(WeckerBefehl.weckerSchalter(id: "haupt", an: true).geprueft(gegen: ohne, heute: heute, jetztMinute: jetztMinute))
    }

    func testEinWeckerNeuBrauchtKeineId() {
        let b = WeckerBefehl.weckerNeu(minute: 390, tage: [], name: "")
        XCTAssertEqual(b.geprueft(gegen: WeckerStandDatei(version: 1), heute: heute, jetztMinute: jetztMinute), b)
    }

    func testEinDatumInDerVergangenheitGiltNichtHeuteNurMitKuenftigerUhrzeit() {
        func neu(_ datum: String, _ minute: Int) -> WeckerBefehl? {
            WeckerBefehl.erinnerungNeu(minute: minute, tage: [], datum: datum, text: "x").geprueft(gegen: stand, heute: heute, jetztMinute: jetztMinute)
        }
        XCTAssertNil(neu("2026-10-28", 12 * 60))
        XCTAssertNil(neu(heute, 9 * 60))
        XCTAssertNil(neu(heute, jetztMinute), "genau jetzt ist schon vorbei")
        XCTAssertNotNil(neu(heute, 11 * 60))
        XCTAssertNotNil(neu("2026-10-30", 1))
    }

    func testEintraegeNehmenWeckerBefehleNurMitStand() {
        let art = CoachMarker.zerlegen("[[wecker: aus | wecker-a]][[wecker: aus | fremd]][[wasser: 2]]").marker
        XCTAssertEqual(CoachTracking.eintraege(art, stunde: 10).count, 1, "ohne Stand von Lumen Alarm nur das Wasser")
        let mit = CoachTracking.eintraege(art, stunde: 10, wecker: stand, heute: heute, jetztMinute: jetztMinute)
        XCTAssertEqual(mit.count, 2)
        XCTAssertTrue(mit.contains(.wecker(.weckerSchalter(id: "Wecker-A", an: false))))
    }

    // MARK: Auftragsdatei und Karte

    private final class Gesendet: @unchecked Sendable {
        // @unchecked Sendable: der Test läuft auf dem Main-Actor und liest erst nach dem Schreiben.
        var namen: [String] = []
    }

    private func dienst(_ ordner: URL, gesendet: Gesendet = Gesendet(), start: Int = 0) -> AlarmWeckerDienst {
        let zaehler = ZaehlerBox(start)
        return AlarmWeckerDienst(ordner: ordner, sende: { gesendet.namen.append($0) }, neueId: { zaehler.naechste() })
    }

    private final class ZaehlerBox: @unchecked Sendable {
        var n: Int
        init(_ n: Int) { self.n = n }
        func naechste() -> String { n += 1; return "auftrag-\(n)" }
    }

    private func schreibe(_ json: String, _ name: String, in ordner: URL) throws {
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: ordner.appendingPathComponent(name))
    }

    func testLegeSchreibtDenAuftragMitIdUndSendetDenDarwinNamen() throws {
        let ordner = try tempOrdner().appendingPathComponent("LumenAlarm")
        let gesendet = Gesendet()
        let d = dienst(ordner, gesendet: gesendet)
        let id = d.lege(.weckerNeu(minute: 390, tage: [1, 2], name: "Früh"), jetzt: jetzt)
        XCTAssertEqual(id, "auftrag-1")
        XCTAssertEqual(gesendet.namen, ["com.onlyus.lumen-fit.wecker-auftrag"])
        let datei = try LoveaVertrag.decoder().decode(WeckerAuftraegeDatei.self, from: Data(contentsOf: ordner.appendingPathComponent("wecker-auftraege.json")))
        XCTAssertEqual(datei.version, 1)
        XCTAssertEqual(datei.auftraege.count, 1)
        XCTAssertEqual(datei.auftraege.first?.art, .weckerNeu)
        XCTAssertEqual(datei.auftraege.first?.minute, 390)
        XCTAssertEqual(datei.auftraege.first?.tage, [1, 2])
        XCTAssertEqual(datei.auftraege.first?.name, "Früh")
        XCTAssertEqual(datei.auftraege.first?.angelegt, jetzt)
    }

    func testJederAuftragBekommtEineEigeneIdUndDieAeltestenFallenNachHundertWeg() throws {
        let ordner = try tempOrdner().appendingPathComponent("LumenAlarm")
        let d = dienst(ordner)
        for i in 0..<105 { d.lege(.weckerSchalter(id: "haupt", an: i % 2 == 0), jetzt: jetzt) }
        let datei = try LoveaVertrag.decoder().decode(WeckerAuftraegeDatei.self, from: Data(contentsOf: ordner.appendingPathComponent("wecker-auftraege.json")))
        XCTAssertEqual(datei.auftraege.count, 100)
        XCTAssertEqual(Set(datei.auftraege.map(\.id)).count, 100)
        XCTAssertEqual(datei.auftraege.first?.id, "auftrag-6")
        XCTAssertEqual(datei.auftraege.last?.id, "auftrag-105")
    }

    func testOhneOrdnerSchreibtNichtsUndLiefertNil() {
        let d = AlarmWeckerDienst(ordner: nil, sende: { _ in XCTFail("nichts zu senden") })
        XCTAssertNil(d.lege(.weckerLoeschen(id: "a"), jetzt: jetzt))
        XCTAssertFalse(d.verbunden)
    }

    func testDieKarteWartetBisLumenAlarmOkMeldet() throws {
        let ordner = try tempOrdner().appendingPathComponent("LumenAlarm")
        let d = dienst(ordner)
        let a = try XCTUnwrap(d.lege(.weckerNeu(minute: 390, tage: [], name: ""), jetzt: jetzt))
        let b = try XCTUnwrap(d.lege(.weckerLoeschen(id: "x"), jetzt: jetzt))
        let c = try XCTUnwrap(d.lege(.weckerSchalter(id: "haupt", an: true), jetzt: jetzt))
        XCTAssertEqual(d.karten(fuer: [a, b, c]).map(\.zustand), [.wartet, .wartet, .wartet], "ohne Ergebnis ist nichts gestellt")
        try schreibe(#"{"version":1,"ergebnisse":[{"id":"\#(a)","ok":true},{"id":"\#(b)","ok":false,"grund":"Wecker nicht gefunden"},{"id":"fremd","ok":true}]}"#,
                     "wecker-ergebnis.json", in: ordner)
        d.aktualisieren()
        XCTAssertEqual(d.karten(fuer: [a, b, c]).map(\.zustand), [.ok, .fehler("Wecker nicht gefunden"), .wartet])
    }

    func testEinFehlerOhneGrundHatEinenText() throws {
        let ordner = try tempOrdner().appendingPathComponent("LumenAlarm")
        let d = dienst(ordner)
        let a = try XCTUnwrap(d.lege(.weckerLoeschen(id: "x"), jetzt: jetzt))
        try schreibe(#"{"version":1,"ergebnisse":[{"id":"\#(a)","ok":false}]}"#, "wecker-ergebnis.json", in: ordner)
        d.aktualisieren()
        XCTAssertEqual(d.karten(fuer: [a]).first?.zustand, .fehler("unbekannt"))
    }

    func testEineFremdeVersionOderKaputteDateiZaehltAlsKeinErgebnis() throws {
        let ordner = try tempOrdner().appendingPathComponent("LumenAlarm")
        let d = dienst(ordner)
        let a = try XCTUnwrap(d.lege(.weckerLoeschen(id: "x"), jetzt: jetzt))
        try schreibe(#"{"version":2,"ergebnisse":[{"id":"\#(a)","ok":true}]}"#, "wecker-ergebnis.json", in: ordner)
        d.aktualisieren()
        XCTAssertEqual(d.karten(fuer: [a]).first?.zustand, .wartet)
        try schreibe("kein json", "wecker-ergebnis.json", in: ordner)
        d.aktualisieren()
        XCTAssertEqual(d.karten(fuer: [a]).first?.zustand, .wartet)
    }

    func testDerStandIstTolerantGelesenUndNurMitVersionEins() throws {
        let ordner = try tempOrdner().appendingPathComponent("LumenAlarm")
        let d = dienst(ordner)
        d.aktualisieren()
        XCTAssertFalse(d.verbunden)
        try schreibe(#"{"version":1,"fremd":1,"haupt":{"minute":390},"wecker":[{"id":"a","minute":420,"name":null},{"minute":1},{"id":"b","minute":480,"aktiv":false,"tage":[1]}],"erinnerungen":[{"id":"e","minute":60}]}"#,
                     "wecker-stand.json", in: ordner)
        d.aktualisieren()
        XCTAssertTrue(d.verbunden)
        XCTAssertEqual(d.stand?.haupt?.minute, 390)
        XCTAssertEqual(d.stand?.haupt?.aktiv, true)
        XCTAssertEqual(d.stand?.wecker.map(\.id), ["a", "b"], "der kaputte Eintrag fällt weg, die Datei bleibt lesbar")
        XCTAssertEqual(d.stand?.wecker.last?.aktiv, false)
        XCTAssertEqual(d.stand?.erinnerungen.first?.text, "")
        try schreibe(#"{"version":2,"wecker":[]}"#, "wecker-stand.json", in: ordner)
        d.aktualisieren()
        XCTAssertFalse(d.verbunden)
    }

    // MARK: Coach-Kontext

    func testDerPromptKenntDieListenNurMitStand() {
        XCTAssertTrue(AlarmWeckerDienst.promptZeilen(stand: nil).isEmpty)
        let text = AlarmWeckerDienst.promptZeilen(stand: stand).joined(separator: "\n")
        XCTAssertTrue(text.contains("Wecker-A | 07:00 | werktags | Früh | an"))
        XCTAssertTrue(text.contains("haupt | 06:30 | taeglich | Hauptwecker | an"))
        XCTAssertTrue(text.contains("Erinnerung-A | 18:00 | einmalig | Trinken | an"))
        XCTAssertTrue(text.contains("[[wecker: neu"))
        XCTAssertTrue(text.contains("Sag nie, dass etwas gestellt ist"))
    }

    func testDerPromptNimmtHoechstensZehnEintraegeJeListe() {
        let viele = (0..<30).map { WeckerStandDatei.Wecker(id: "w\($0)", minute: $0, name: nil, tage: [], aktiv: true, einmalAm: nil) }
        let text = AlarmWeckerDienst.promptZeilen(stand: WeckerStandDatei(version: 1, wecker: viele))
        XCTAssertEqual(text.filter { $0.hasPrefix("w") }.count, 10)
    }

    func testDieCoachAnfrageTraegtDieZeilenInDenPrompt() {
        var anfrage = CoachTestBau.anfrage("Stell einen Wecker")
        anfrage.weckerZeilen = ["Lumen Alarm ist verbunden."]
        XCTAssertTrue(CoachModellPrompt.bauen(anfrage).contains("Lumen Alarm ist verbunden."))
    }

    func testDieUebersetzungNimmtDieWeckerBefehleAusDemText() throws {
        let antwort = try CoachModellUebersetzer.antwort(text: "Alles klar.\n[[wecker: aus | haupt]]", chips: [])
        XCTAssertEqual(antwort.text, "Alles klar.")
        XCTAssertEqual(antwort.weckerBefehle, [.weckerSchalter(id: "haupt", an: false)])
    }
}
