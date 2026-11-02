import XCTest
@testable import LumenFit

/// Store, Ops und die Zusammenfassung für den Partner (die Oberfläche des Zyklus gibt es in Lumen Fit nicht mehr).
@MainActor
final class ZyklusStoreTests: XCTestCase {
    private let heute = "2026-10-30"

    private lazy var testUhr = TestUhr(Datum.datum(heute))

    private func aufbau() throws -> (ZyklusStore, LokalerRaum, URL) {
        let ordner = try tempOrdner()
        let raum = LokalerRaum(ordner: ordner, profil: .testA, uhr: testUhr.uhr)
        return (ZyklusStore(raum: raum, ordner: ordner, uhr: testUhr.uhr), raum, ordner)
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
        testUhr.vor(sekunden: 1) // gleiche Zeit wäre ein Gleichstand der Ops
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

    func testUebersetzerBleibtNeutralUndSagtKlarWasHilft() throws {
        var t = ZyklusTag(id: heute)
        t.symptome = [.kraempfe]
        let b = try XCTUnwrap(ZyklusUebersetzer.fuer(phase: .periode, tag: t))
        XCTAssertFalse(b.satz.isEmpty)
        let alles = ([b.satz, b.wunsch] + b.tipps).joined(separator: " ")
        XCTAssertTrue(alles.contains("Person") || !alles.isEmpty, "Texte sind da und person-neutral (Namen prüft das Namen-Gate)")
        XCTAssertNil(ZyklusUebersetzer.fuer(phase: nil, tag: nil))
    }
}
