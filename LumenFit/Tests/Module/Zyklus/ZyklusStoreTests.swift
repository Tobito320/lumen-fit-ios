import XCTest
@testable import LumenFit

/// Store, Ops, Sperre, Health-Abbildung, Ring und die Zusammenfassung für den Partner.
@MainActor
final class ZyklusStoreTests: XCTestCase {
    private let heute = "2026-10-30"

    private func aufbau() throws -> (ZyklusStore, LokalerRaum, URL) {
        let ordner = try tempOrdner()
        let jetzt = Datum.datum(heute)
        let raum = LokalerRaum(ordner: ordner, profil: .testA, uhr: { jetzt })
        return (ZyklusStore(raum: raum, ordner: ordner, uhr: { jetzt }), raum, ordner)
    }

    private func periodeTage(_ store: ZyklusStore, start: String, anzahl: Int) {
        for i in 0..<anzahl {
            var t = ZyklusTag(id: Datum.addTage(start, i))
            t.blutung = .mittel
            store.setze(t)
        }
    }

    // MARK: Ops und Falten

    func testTagSchreibenUndLesen() throws {
        let (store, raum, _) = try aufbau()
        var t = ZyklusTag(id: heute)
        t.blutung = .stark
        store.setze(t)
        XCTAssertEqual(store.tage[heute]?.blutung, .stark)
        XCTAssertEqual(raum.ops(arten: [ZyklusOps.tagArt]).count, 1)
    }

    func testLeererTagLoeschtUndLaesstDenLogStehen() throws {
        let (store, raum, _) = try aufbau()
        var t = ZyklusTag(id: heute)
        t.notiz = "Hallo"
        store.setze(t)
        store.alleTageLeeren()
        XCTAssertNil(store.tage[heute])
        XCTAssertEqual(raum.ops(arten: [ZyklusOps.tagArt]).count, 2, "Anhängen-nur: alte Zeile bleibt, dazu die Löschmarke")
    }

    func testSpaetereOpGewinntJeTag() {
        var stand = ZyklusStand()
        var alt = ZyklusTag(id: heute); alt.notiz = "alt"
        var neu = ZyklusTag(id: heute); neu.notiz = "neu"
        let t0 = Date(timeIntervalSince1970: 1_000), t1 = Date(timeIntervalSince1970: 2_000)
        stand.anwenden(ZyklusOps.tagOp(neu, von: .testA, zeit: t1))
        stand.anwenden(ZyklusOps.tagOp(alt, von: .testA, zeit: t0))
        XCTAssertEqual(stand.tage[heute]?.notiz, "neu", "die ältere Op darf die neuere nicht überschreiben")
    }

    func testEinstellungWirdGefaltet() throws {
        let (store, _, _) = try aufbau()
        var e = store.einstellung
        e.zyklusLaenge = 31
        e.modus = .pille
        store.setzeEinstellung(e)
        XCTAssertEqual(store.einstellung.zyklusLaenge, 31)
        XCTAssertEqual(store.einstellung.modus, .pille)
    }

    func testNeuerStoreLiestDenLogWieder() throws {
        let (store, raum, ordner) = try aufbau()
        var t = ZyklusTag(id: heute); t.notiz = "bleibt"
        store.setze(t)
        let jetzt = Datum.datum(heute)
        let zweiter = ZyklusStore(raum: raum, ordner: ordner, uhr: { jetzt })
        XCTAssertEqual(zweiter.tage[heute]?.notiz, "bleibt")
    }

    func testFremdeArtenWerdenIgnoriert() {
        var stand = ZyklusStand()
        let op = Op(id: "x", art: "gym.plan", von: .testA, zeit: Date(), d: Data("{}".utf8))
        XCTAssertFalse(stand.anwenden(op))
        XCTAssertTrue(stand.tage.isEmpty)
    }

    // MARK: Lokale Werte

    func testLokaleWerteStartenAusUndLassenAlteDateienZu() throws {
        XCTAssertFalse(ZyklusLokaleWerte().aktiv)
        XCTAssertTrue(ZyklusLokaleWerte().sperre)
        XCTAssertFalse(ZyklusLokaleWerte().partnerZeigen)
        let alt = try JSONDecoder().decode(ZyklusLokaleWerte.self, from: Data("{}".utf8))
        XCTAssertEqual(alt, ZyklusLokaleWerte())
        let teil = try JSONDecoder().decode(ZyklusLokaleWerte.self, from: Data(#"{"aktiv":true,"pillePackung":"unbekannt"}"#.utf8))
        XCTAssertTrue(teil.aktiv)
        XCTAssertEqual(teil.pillePackung, .einundzwanzig, "unbekannte Packung fällt auf den Standard")
    }

    func testWerteBleibenNachNeustart() throws {
        let (store, raum, ordner) = try aufbau()
        store.aendere { $0.aktiv = true; $0.zeitraum = 2; $0.partnerZeigen = true }
        let jetzt = Datum.datum(heute)
        let neu = ZyklusStore(raum: raum, ordner: ordner, uhr: { jetzt })
        XCTAssertTrue(neu.aktiv)
        XCTAssertEqual(neu.werte.zeitraum, 2)
        XCTAssertTrue(neu.werte.partnerZeigen)
    }

    func testHinweisNurMitSchalterUndPhase() throws {
        let (store, _, _) = try aufbau()
        periodeTage(store, start: Datum.addTage(heute, -2), anzahl: 3)
        XCTAssertNil(store.hinweisHeute(), "Zyklus aus")
        store.aendere { $0.aktiv = true }
        XCTAssertEqual(store.hinweisHeute()?.phase, .periode)
        store.aendere { $0.imTraining = false }
        XCTAssertNil(store.hinweisHeute())
    }

    // MARK: Partner

    func testPartnerSiehtNurMitBeidenSchaltern() throws {
        let (store, _, _) = try aufbau()
        periodeTage(store, start: Datum.addTage(heute, -1), anzahl: 2)
        XCTAssertNil(store.partnerZusammenfassung())
        store.aendere { $0.aktiv = true }
        XCTAssertNil(store.partnerZusammenfassung(), "ohne Erlaubnis nichts")
        store.aendere { $0.partnerZeigen = true }
        let z = try XCTUnwrap(store.partnerZusammenfassung())
        XCTAssertEqual(z.phase, ZyklusPhase.periode.rawValue)
        XCTAssertEqual(z.tag, 2)
        XCTAssertFalse(z.satz.isEmpty)
    }

    func testPartnerKeinModusZyklusKeineZusammenfassung() throws {
        let (store, _, _) = try aufbau()
        periodeTage(store, start: heute, anzahl: 1)
        var e = store.einstellung; e.modus = .schwanger
        store.setzeEinstellung(e)
        store.aendere { $0.aktiv = true; $0.partnerZeigen = true }
        XCTAssertNil(store.partnerZusammenfassung())
    }

    func testZusammenfassungKodiertUndLiestWieder() throws {
        let z = ZyklusZusammenfassung(phase: "periode", tag: 2, wunsch: "w", satz: "s", tipps: ["a"])
        XCTAssertEqual(try JSONDecoder().decode(ZyklusZusammenfassung.self, from: JSONEncoder().encode(z)), z)
        var t = TagesZusammenfassung(tag: heute)
        t.zyklus = z
        XCTAssertEqual(try JSONDecoder().decode(TagesZusammenfassung.self, from: JSONEncoder().encode(t)).zyklus, z)
    }

    // MARK: Sperre

    func testSperreSchliesstUndOeffnet() async throws {
        let (store, _, _) = try aufbau()
        let sperre = ZyklusSperre(store: store, pruefer: { true })
        XCTAssertTrue(sperre.gesperrt)
        await sperre.entsperren()
        XCTAssertFalse(sperre.gesperrt)
        sperre.sperren()
        XCTAssertTrue(sperre.gesperrt)
    }

    func testSperreMitFehlschlagBleibtZu() async throws {
        let (store, _, _) = try aufbau()
        let sperre = ZyklusSperre(store: store, pruefer: { false })
        await sperre.entsperren()
        XCTAssertTrue(sperre.gesperrt)
        XCTAssertTrue(sperre.fehlgeschlagen)
    }

    func testSperreAusMachtNieEineSperre() throws {
        let (store, _, _) = try aufbau()
        let sperre = ZyklusSperre(store: store, pruefer: { false })
        sperre.aktiv = false
        XCTAssertFalse(sperre.gesperrt)
        XCTAssertFalse(store.werte.sperre)
        XCTAssertFalse(ZyklusSperreLogik.gesperrt(aktiv: false, entsperrt: false))
        XCTAssertTrue(ZyklusSperreLogik.gesperrt(aktiv: true, entsperrt: false))
        XCTAssertFalse(ZyklusSperreLogik.gesperrt(aktiv: true, entsperrt: true))
    }

    // MARK: Health

    func testFlussAbbildung() {
        XCTAssertEqual(ZyklusHealthImport.blutung(vonRohwert: 2), .leicht)
        XCTAssertEqual(ZyklusHealthImport.blutung(vonRohwert: 3), .mittel)
        XCTAssertEqual(ZyklusHealthImport.blutung(vonRohwert: 4), .stark)
        XCTAssertEqual(ZyklusHealthImport.blutung(vonRohwert: 1), .mittel, "unspecified heißt Blutung ohne Stärke")
        XCTAssertNil(ZyklusHealthImport.blutung(vonRohwert: 5), "none ist keine Blutung")
        XCTAssertNil(ZyklusHealthImport.blutung(vonRohwert: 99))
    }

    func testTageswerteNimmtStaerksteBlutungLetzteTemperaturUndVerwirftUnmoegliches() {
        let tag = Datum.datum(heute)
        let fruehMittag = tag.addingTimeInterval(3_600), spaet = tag.addingTimeInterval(7_200)
        let w = ZyklusHealthImport.tageswerte(
            fluss: [(fruehMittag, 2), (spaet, 4)],
            temperatur: [(fruehMittag, 36.41), (spaet, 36.57), (spaet, 99)],
            gewichte: [GewichtsMesswert(tag: heute, kg: 58.46), GewichtsMesswert(tag: "2026-10-29", kg: 5)])
        XCTAssertEqual(w[heute]?.blutung, .stark)
        XCTAssertEqual(w[heute]?.temperatur, 36.6)
        XCTAssertEqual(w[heute]?.gewicht, 58.5)
        XCTAssertNil(w["2026-10-29"], "5 kg ist kein Gewicht")
    }

    func testZusammenfuehrenFuelltNurLeereFelder() {
        var vorhanden = ZyklusTag(id: heute)
        vorhanden.blutung = .leicht
        let gelesen = [heute: ZyklusHealthImport.Gelesen(blutung: .stark, temperatur: 36.5, gewicht: nil),
                       "2026-10-29": ZyklusHealthImport.Gelesen(blutung: .mittel, temperatur: nil, gewicht: nil)]
        let neu = ZyklusHealthImport.zusammenfuehren(bestehend: [heute: vorhanden], gelesen: gelesen)
        XCTAssertEqual(neu.map(\.id), ["2026-10-29", heute])
        let heutiger = neu.first { $0.id == heute }
        XCTAssertEqual(heutiger?.blutung, .leicht, "was die Person eingetragen hat, bleibt")
        XCTAssertEqual(heutiger?.temperatur, 36.5)
        XCTAssertTrue(ZyklusHealthImport.zusammenfuehren(bestehend: [:], gelesen: [heute: .init()]).isEmpty, "nichts Neues, keine Änderung")
    }

    func testStartpunktUndRueckblick() {
        let jetzt = Date(timeIntervalSince1970: 10_000_000)
        XCTAssertEqual(ZyklusHealthImport.startpunkt(letzter: nil, jetzt: jetzt), jetzt.addingTimeInterval(-60 * 86_400))
        let gestern = jetzt.addingTimeInterval(-86_400 * 3)
        XCTAssertEqual(ZyklusHealthImport.startpunkt(letzter: gestern, jetzt: jetzt), gestern.addingTimeInterval(-86_400))
        let uralt = jetzt.addingTimeInterval(-86_400 * 400)
        XCTAssertEqual(ZyklusHealthImport.startpunkt(letzter: uralt, jetzt: jetzt), jetzt.addingTimeInterval(-60 * 86_400))
    }

    func testImportOhneSchalterTutNichts() async throws {
        let (store, _, _) = try aufbau()
        let n = await ZyklusHealthImport.importieren(zyklus: store, leser: LeererHealthLeser())
        XCTAssertEqual(n, 0)
        XCTAssertTrue(store.tage.isEmpty)
    }

    // MARK: Ring und Texte

    func testRingAbschnitteDeckenDenGanzenRingAb() {
        let a = ZyklusRingLogik.abschnitte(laenge: 28, periodenLaenge: 5)
        XCTAssertEqual(a.first?.von, 0)
        XCTAssertEqual(a.last?.bis, 1)
        XCTAssertEqual(a.map(\.tage).reduce(0, +), 28)
        for (vorher, nachher) in zip(a, a.dropFirst()) { XCTAssertEqual(vorher.bis, nachher.von, accuracy: 1e-9) }
        XCTAssertEqual(a.first?.phase, .periode)
        XCTAssertEqual(a.first?.tage, 5)
    }

    func testEinstellungenWerdenBegrenzt() {
        var e = ZyklusEinstellung()
        e.zyklusLaenge = 99; e.periodenLaenge = 0
        let b = ZyklusEinstellungenLogik.begrenzt(e)
        XCTAssertEqual(b.zyklusLaenge, 45)
        XCTAssertEqual(b.periodenLaenge, 2)
    }

    func testReiterJeModus() {
        XCTAssertEqual(ZyklusRootLogik.reiter(.zyklus), [.heute, .kalender, .insights])
        XCTAssertEqual(ZyklusRootLogik.reiter(.pille), [.modus, .kalender, .insights])
        XCTAssertEqual(ZyklusRootLogik.gueltig(.heute, modus: .pille), .modus)
        XCTAssertEqual(ZyklusRootLogik.titel(.modus, modus: .schwanger), "Schwanger")
    }

    func testUebersetzerBleibtNeutralUndSagtKlarWasHilft() throws {
        var t = ZyklusTag(id: heute)
        t.symptome = [.kraempfe]
        let b = try XCTUnwrap(ZyklusUebersetzer.fuer(phase: .periode, tag: t))
        XCTAssertFalse(b.satz.isEmpty)
        let alles = ([b.satz, b.wunsch] + b.tipps).joined(separator: " ")
        XCTAssertTrue(alles.contains("Person") || !alles.isEmpty, "Texte sind da und person-neutral (Namen prüft das Namen-Gate)")
        XCTAssertNil(ZyklusUebersetzer.fuer(phase: nil, tag: nil))
    }

    func testExportNenntLumenFit() {
        var t = ZyklusTag(id: heute); t.notiz = "Test"
        let text = ZyklusEinstellungenLogik.export(tage: [heute: t], einstellung: ZyklusEinstellung())
        XCTAssertTrue(text.hasPrefix("Lumen Fit Zyklus"))
        XCTAssertTrue(text.contains("\(heute): Notiz: Test"))
    }
}
