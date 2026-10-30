import XCTest
@testable import LumenFit

/// Der Band-Wecker von Lumen Alarm: künftige Wünsche bleiben liegen, Weck-Wünsche ignorieren Ruhezeit und Mindestpause, `lang` läuft einzeln,
/// die Merkliste reicht für 300 Wünsche je Weckzeit, die Brücke im Ordner `LumenAlarm` löscht nur die eigenen Dateien, der Schalter greift.
@MainActor
final class BandWeckerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var befehle = 0
    private var schalter = true
    private var alarmSchalter = true

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "BandWeckerTests")
        defaults.removePersistentDomain(forName: "BandWeckerTests")
        befehle = 0
        schalter = true
        alarmSchalter = true
    }

    private func wunsch(_ id: String, _ muster: BandMuster = .lang, in sekunden: TimeInterval, von: String = "wecker") -> BandWunsch {
        BandWunsch(id: id, muster: muster, zeit: VerbindenTest.jetzt.addingTimeInterval(sekunden), von: von)
    }

    private func schlange(_ bruecke: FakePartnerAustausch, zusammen: Bool = false, maximal: Int = BandWunschSchlange.alarmMerkMaximal,
                          ausgefuehrt: Sammler = Sammler()) -> BandWunschSchlange {
        BandWunschSchlange(bruecke: bruecke, defaults: defaults, uhr: { VerbindenTest.jetzt }, schluessel: BandWunschSchlange.alarmSchluessel,
                           merkMaximal: maximal, zusammenfassen: zusammen) { w in
            ausgefuehrt.ids.append(w.id)
            return .ausgefuehrt
        }
    }

    final class Sammler { var ids: [String] = [] }

    // MARK: Warteschlange

    func testKuenftigerWunschBleibtLiegenUndWirdNichtGemeldet() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("jetzt", in: 0), wunsch("spaeter", in: 90)])
        let gelaufen = Sammler()
        let s = schlange(bruecke, ausgefuehrt: gelaufen)
        XCTAssertEqual(s.verarbeite(), ["jetzt"])
        XCTAssertEqual(gelaufen.ids, ["jetzt"])
        XCTAssertEqual(bruecke.erledigt, [["jetzt"]])
        XCTAssertEqual(s.offene().map(\.id), ["spaeter"])
        XCTAssertEqual(s.naechsteZeit(), VerbindenTest.jetzt.addingTimeInterval(90))
    }

    func testNaechsteZeitIstNilOhneKuenftigeWuensche() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("jetzt", in: -1)])
        XCTAssertNil(schlange(bruecke).naechsteZeit())
        XCTAssertNil(schlange(FakePartnerAustausch()).naechsteZeit())
    }

    func testMehrereFaelligeLaufenAlsEinerWennZusammengefasst() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("a", in: -30), wunsch("b", in: -20), wunsch("c", in: -2), wunsch("d", in: 10)])
        let gelaufen = Sammler()
        XCTAssertEqual(schlange(bruecke, zusammen: true, ausgefuehrt: gelaufen).verarbeite(), ["a", "b", "c"])
        XCTAssertEqual(gelaufen.ids, ["c"], "nach einer Pause summt das Band nicht im Stau")
    }

    func testOhneZusammenfassenLaufenAlleFaelligen() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("a", in: -30), wunsch("b", in: -2)])
        let gelaufen = Sammler()
        _ = schlange(bruecke, ausgefuehrt: gelaufen).verarbeite()
        XCTAssertEqual(gelaufen.ids, ["a", "b"])
    }

    func testDreihundertWuenscheSindNachDemErstenLaufNichtNochEinmalOffen() {
        let alle = (0..<600).map { wunsch("wecker-1-\($0)", in: -Double($0) * 0.5 - 1) }
        let bruecke = FakePartnerAustausch(wuensche: alle)
        let gelaufen = Sammler()
        let s = schlange(bruecke, ausgefuehrt: gelaufen)
        XCTAssertEqual(s.verarbeite().count, 600)
        XCTAssertGreaterThan((defaults.stringArray(forKey: BandWunschSchlange.alarmSchluessel) ?? []).count, LoveaVertrag.erledigteMaximal,
                             "die Merkliste von Lovea (200) würde hier die ältesten vergessen")
        XCTAssertTrue(s.offene().isEmpty)
        let nochmal = Sammler()
        XCTAssertEqual(schlange(bruecke, ausgefuehrt: nochmal).verarbeite(), [])
        XCTAssertTrue(nochmal.ids.isEmpty, "kein Wunsch läuft ein zweites Mal")
    }

    func testDieMerklisteDerAlarmWuenscheIstGetrenntVonLovea() {
        let bruecke = FakePartnerAustausch(wuensche: [wunsch("x", in: -1)])
        _ = schlange(bruecke).verarbeite()
        XCTAssertNil(defaults.stringArray(forKey: BandWunschSchlange.schluessel))
        XCTAssertEqual(defaults.stringArray(forKey: BandWunschSchlange.alarmSchluessel), ["x"])
    }

    // MARK: Pulse

    private func geber(verbunden: Bool = true, ruhe: Bool = false) -> BandPuls {
        let fenster = ruhe ? [BandRegeln.Zeitfenster(von: 0, bis: 24 * 60 - 1)] : []
        let umfeld = BandRegeln.Umfeld(bandAmArm: true, akku: 3, akkuSchwelle: 15, ruhe: fenster, ruheAusnahme: false)
        return BandPuls(finden: { [weak self] in self?.befehle += 1 }, verbunden: { verbunden }, umfeld: { _ in umfeld }, defaults: defaults, warte: { _ in })
    }

    func testWeckerIgnoriertRuhezeitAkkuWaechterUndSchalterDerQuelle() {
        let g = geber(ruhe: true)
        defaults.set(false, forKey: BandQuelle.wunsch.anSchluessel)
        XCTAssertTrue(g.wecker(.lang, jetzt: VerbindenTest.jetzt))
        XCTAssertEqual(befehle, 1)
    }

    func testLangLaeuftEinzelnAuchImZweiSekundenTakt() {
        let g = geber()
        for _ in 0..<5 { XCTAssertTrue(g.wecker(.lang, jetzt: VerbindenTest.jetzt)) }
        XCTAssertEqual(befehle, 5, "kein Wunsch wird von der Mindestpause oder einer laufenden Folge verschluckt")
        XCTAssertNil(BandQuelle.wunsch.letzte(defaults), "die Pause der Quelle wird nicht gestempelt")
    }

    func testRufGibtDreiPulseOhneStempel() async {
        let g = geber()
        XCTAssertTrue(g.wecker(.ruf, jetzt: VerbindenTest.jetzt))
        await warte { befehle == 3 }
        XCTAssertEqual(befehle, 3)
        XCTAssertNil(BandQuelle.wunsch.letzte(defaults))
    }

    func testOhneVerbindungMeldetSpaeter() {
        XCTAssertFalse(geber(verbunden: false).wecker(.lang, jetzt: VerbindenTest.jetzt))
        XCTAssertEqual(befehle, 0)
    }

    // MARK: Dienst

    private func dienst(alarm: FakePartnerAustausch = FakePartnerAustausch()) -> (dienst: BandDienstImpl, fabrik: FakeFunkFabrik, bruecke: FakePartnerAustausch) {
        let fabrik = FakeFunkFabrik()
        let bruecke = FakePartnerAustausch()
        let sammler = BandOpsSammler()
        let d = defaults!
        let senke = BandSenke(bisher: { sammler.bisher }, tag: { sammler.tage.append($0); sammler.bisher[$0.tag] = $0 }, schlaf: { sammler.schlaf.append($0) })
        let impl = BandDienstImpl(aktiv: { [unowned self] in self.schalter }, bruecke: bruecke, defaults: d, uhr: { VerbindenTest.jetzt }, sende: { _ in },
                                  alarmBruecke: alarm, alarmAn: { [unowned self] in self.alarmSchalter },
                                  modell: { TrackerModell(funk: { fabrik.baue($0) }, senke: senke, defaults: d, uhr: { VerbindenTest.jetzt }) })
        return (impl, fabrik, bruecke)
    }

    private func warte(_ bedingung: @MainActor () -> Bool) async {
        for _ in 0..<100 {
            if bedingung() { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func testWeckWunschLaeuftTrotzAusgeschalteterWunschRegel() async {
        let a = dienst()
        await a.dienst.verbinde()
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        await warte { a.dienst.modell?.zustand == .verbunden }
        defaults.set(false, forKey: BandQuelle.wunsch.anSchluessel)
        let lovea = BandWunsch(id: "l", muster: .kurz, zeit: VerbindenTest.jetzt, von: "kennung-b")
        XCTAssertEqual(a.dienst.wunschAusfuehren(lovea), .verworfen, "Wünsche von Lovea folgen den Regeln")
        XCTAssertEqual(a.dienst.wunschAusfuehren(wunsch("w", in: 0)), .ausgefuehrt, "Weck-Wünsche nicht")
    }

    func testWeckWunschOhneBandBleibtLiegen() async {
        let a = dienst()
        await a.dienst.verbinde()
        XCTAssertEqual(a.dienst.wunschAusfuehren(wunsch("w", in: 0)), .spaeter)
    }

    func testStatusGehtAuchAnLumenAlarmSolangeDerSchalterAnIst() async {
        let alarm = FakePartnerAustausch()
        let a = dienst(alarm: alarm)
        await a.dienst.verbinde()
        a.fabrik.melde(.verbunden(name: "H59 Test"))
        await warte { a.dienst.modell?.zustand == .verbunden }
        a.dienst.statusSchreiben()
        XCTAssertEqual(alarm.status.last?.verbunden, true)
        XCTAssertEqual(alarm.status.last?.name, a.bruecke.status.last?.name)
        let anzahl = alarm.status.count
        a.dienst.statusSchreiben()
        XCTAssertEqual(alarm.status.count, anzahl, "ohne Änderung nicht noch einmal")
        alarmSchalter = false
        a.dienst.statusSchreiben(erzwingen: true)
        XCTAssertEqual(alarm.status.count, anzahl, "Schalter aus: nichts mehr an Lumen Alarm")
        alarmSchalter = true
        a.dienst.statusSchreiben()
        XCTAssertEqual(alarm.status.count, anzahl + 1, "Schalter wieder an: die Datei fehlt dort, also schreiben")
    }

    // MARK: Brücke im Ordner LumenAlarm

    private func alarmGruppe() throws -> URL {
        let wurzel = try tempOrdner()
        let ordner = wurzel.appendingPathComponent("LumenAlarm", isDirectory: true)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let datei = BandWuenscheDatei(version: LoveaVertrag.version, wuensche: [wunsch("wecker-1-0", in: 0)])
        try LoveaVertrag.encoder().encode(datei).write(to: ordner.appendingPathComponent(LoveaVertrag.wuenscheDatei))
        return wurzel
    }

    func testBrueckeLiestDieWuenscheAusDemOrdnerLumenAlarmUndSchreibtDortErledigtUndStatus() throws {
        let gruppe = try alarmGruppe()
        let bruecke = LoveaBruecke(ordner: gruppe, ordnerName: "LumenAlarm")
        XCTAssertEqual(bruecke.wuensche().map(\.id), ["wecker-1-0"])
        bruecke.melde(erledigt: ["wecker-1-0"])
        bruecke.schreibe(status: BandStatusDatei(version: LoveaVertrag.version, geschrieben: VerbindenTest.jetzt, verbunden: true, akkuProzent: 80, name: "Band"))
        XCTAssertEqual(VerbindenTest.dateien(gruppe), ["LumenAlarm/band-erledigt.json", "LumenAlarm/band-status.json", "LumenAlarm/band-wuensche.json"])
    }

    func testLoeschenLaesstDieWuenscheVonLumenAlarmStehen() throws {
        let gruppe = try alarmGruppe()
        let bruecke = LoveaBruecke(ordner: gruppe, ordnerName: "LumenAlarm")
        bruecke.melde(erledigt: ["wecker-1-0"])
        bruecke.schreibe(status: BandStatusDatei(version: LoveaVertrag.version, geschrieben: VerbindenTest.jetzt, verbunden: false, akkuProzent: nil, name: nil))
        bruecke.loescheEigeneDateien()
        XCTAssertEqual(VerbindenTest.dateien(gruppe), ["LumenAlarm/band-wuensche.json"])
    }

    func testDieLoveaBrueckeLoeschtWeiterDenGanzenOrdner() throws {
        let gruppe = try VerbindenTest.gruppe(self, wuensche: true)
        let bruecke = LoveaBruecke(ordner: gruppe)
        bruecke.loescheEigeneDateien()
        XCTAssertEqual(VerbindenTest.dateien(gruppe), [])
    }

    // MARK: Schalter und Wartetakt

    func testDerSchalterIstStandardAnUndAlteDateienBleibenLesbar() throws {
        XCTAssertTrue(Einstellungen().alarmWeckt)
        let alt = try JSONDecoder().decode(Einstellungen.self, from: Data(#"{"thema":"wald","bandAktiv":true}"#.utf8))
        XCTAssertTrue(alt.alarmWeckt)
        var aus = Einstellungen()
        aus.alarmWeckt = false
        let neu = try JSONDecoder().decode(Einstellungen.self, from: JSONEncoder().encode(aus))
        XCTAssertFalse(neu.alarmWeckt, "der Schalter wird gespeichert")
    }

    private func umgebung(alarm: FakePartnerAustausch) throws -> AppUmgebung {
        let u = AppUmgebung(ordner: try tempOrdner(), schluesselbund: SpeicherSchluesselbund(), http: FixtureLader(ordner: nil), mitteiler: FakeMitteiler(),
                            leser: LeererHealthLeser(), healthSchreiber: KeinHealthSchreiber(), bruecke: FakePartnerAustausch(), uhr: { VerbindenTest.jetzt },
                            passwortRunden: 1_000, alarmBruecke: alarm)
        _ = try u.profil.anlegen(name: "Beispiel", passwort: "abcd")
        return u
    }

    func testOhneBandSchalterRuehrtDieAlarmBrueckeNichtAn() async throws {
        let alarm = FakePartnerAustausch(wuensche: [wunsch("w", in: -1)])
        let dienste = VerbindenDienste(try umgebung(alarm: alarm), startAbruf: false, schlafe: { _ in })
        dienste.alarmWuenscheAusfuehren()
        XCTAssertTrue(alarm.erledigt.isEmpty)
        XCTAssertNil(dienste.band.modell)
    }

    func testOhneAlarmSchalterRuehrtDieAlarmBrueckeNichtAn() async throws {
        let wartend = Wartezeiten()
        let alarm = FakePartnerAustausch(wuensche: [wunsch("w", in: -1), wunsch("z", in: 60)])
        let u = try umgebung(alarm: alarm)
        u.daten?.einstellungen.aendere { $0.bandAktiv = true; $0.alarmWeckt = false }
        let dienste = VerbindenDienste(u, startAbruf: false, schlafe: { wartend.merke($0) })
        dienste.alarmWuenscheAusfuehren()
        XCTAssertTrue(alarm.erledigt.isEmpty)
        XCTAssertTrue(wartend.werte.isEmpty, "kein Wartetakt ohne Schalter")
    }

    func testDieAlarmBrueckeBrauchtNichtDenLoveaSchalterUndPlantDenNaechstenWunsch() async throws {
        let wartend = Wartezeiten()
        let alarm = FakePartnerAustausch(wuensche: [wunsch("w", in: -1), wunsch("z", in: 90)])
        let u = try umgebung(alarm: alarm)
        u.daten?.einstellungen.aendere { $0.bandAktiv = true }
        XCTAssertFalse(u.daten?.einstellungen.werte.loveaVerbunden ?? true)
        // Der Wartetakt schläft nach dem Eintrag eine Stunde: die feste Uhr des Tests ließe ihn sonst ohne Ende neu planen.
        let dienste = VerbindenDienste(u, startAbruf: false, schlafe: { wartend.merke($0); _ = try? await Task.sleep(for: .seconds(3600)) })
        dienste.alarmWuenscheAusfuehren()
        XCTAssertTrue(alarm.erledigt.isEmpty, "Band nicht verbunden: der Wunsch bleibt liegen")
        XCTAssertEqual(alarm.wuensche().count, 2)
        for _ in 0..<100 where wartend.werte.isEmpty { try? await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(wartend.werte, [90], "der Wartetakt schläft bis zur Zeit des nächsten Wunsches")
        u.daten?.einstellungen.aendere { $0.alarmWeckt = false }
        dienste.alarmWuenscheAusfuehren()
    }
}

private final class Wartezeiten: @unchecked Sendable {
    // @unchecked Sendable: jeder Zugriff auf das Feld läuft über `schloss`.
    private let schloss = NSLock()
    private var _werte: [TimeInterval] = []
    var werte: [TimeInterval] { schloss.withLock { _werte } }
    func merke(_ wert: TimeInterval) { schloss.withLock { _werte.append(wert) } }
}
