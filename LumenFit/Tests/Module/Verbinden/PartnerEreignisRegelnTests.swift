import XCTest
@testable import LumenFit

/// Mitteilungen bei Partner-Ereignissen (Idee 83): genau einmal je Ereignis, je Art abschaltbar, nur im Stand `verbunden`, nur frische Ereignisse.
/// Sammelt Werte aus Rückrufen (ein Verweistyp statt einer erfassten Variable).
final class PartnerTestSammler { var ids: [String] = [] }

@MainActor
final class PartnerEreignisRegelnTests: XCTestCase {
    typealias Sammler = PartnerTestSammler

    private let jetzt = VerbindenTest.jetzt

    private func ereignis(_ id: String, _ art: PartnerEreignisArt, vor: TimeInterval = 600) -> PartnerEreignis {
        PartnerEreignis(id: id, art: art, zeit: jetzt.addingTimeInterval(-vor), text: "Text \(id)")
    }

    private func stand(_ ereignisse: [PartnerEreignis]) -> PartnerStand {
        .verbunden(ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Beispiel Partner", freigaben: [], heute: TagesZusammenfassung(tag: "2026-10-29"),
                                        ereignisse: ereignisse))
    }

    // MARK: Genau einmal

    func testEinEreignisGenauEinmalAuchBeiWiederholtemLesen() async {
        let mitteiler = FakeMitteiler()
        let regeln = PartnerEreignisRegeln(mitteiler: mitteiler, ordner: nil)
        let s = stand([ereignis("gymEnde-2026-10-29", .gymEnde)])
        let erste = await regeln.verarbeite(s, einstellungen: Einstellungen(), jetzt: jetzt)
        let zweite = await regeln.verarbeite(s, einstellungen: Einstellungen(), jetzt: jetzt.addingTimeInterval(60))
        XCTAssertEqual(erste.map(\.id), ["gymEnde-2026-10-29"])
        XCTAssertTrue(zweite.isEmpty)
        XCTAssertEqual(mitteiler.meldungen.count, 1)
        XCTAssertEqual(mitteiler.meldungen.first?.text, "Text gymEnde-2026-10-29")
        XCTAssertEqual(mitteiler.meldungen.first?.route, .heute)
    }

    func testGemerkteIdsUeberlebenEinenNeustart() async throws {
        let ordner = try tempOrdner()
        let mitteiler = FakeMitteiler()
        let s = stand([ereignis("a", .gymStart)])
        await PartnerEreignisRegeln(mitteiler: mitteiler, ordner: ordner).verarbeite(s, einstellungen: Einstellungen(), jetzt: jetzt)
        await PartnerEreignisRegeln(mitteiler: mitteiler, ordner: ordner).verarbeite(s, einstellungen: Einstellungen(), jetzt: jetzt)
        XCTAssertEqual(mitteiler.meldungen.count, 1)
    }

    func testVerschiedeneEreignisseBekommenJedesEineMitteilung() async {
        let mitteiler = FakeMitteiler()
        let regeln = PartnerEreignisRegeln(mitteiler: mitteiler, ordner: nil)
        await regeln.verarbeite(stand([ereignis("a", .gymStart, vor: 300), ereignis("b", .ziel, vor: 100)]), einstellungen: Einstellungen(), jetzt: jetzt)
        XCTAssertEqual(mitteiler.meldungen.map(\.id), ["partner.a", "partner.b"], "ältestes zuerst")
        await regeln.verarbeite(stand([ereignis("a", .gymStart), ereignis("b", .ziel), ereignis("c", .schlafGut)]), einstellungen: Einstellungen(), jetzt: jetzt)
        XCTAssertEqual(mitteiler.meldungen.count, 3)
    }

    func testDieMerkListeIstBegrenzt() async throws {
        let ordner = try tempOrdner()
        let regeln = PartnerEreignisRegeln(mitteiler: FakeMitteiler(), ordner: ordner)
        let viele = (0..<(PartnerEreignisRegeln.gemerktMaximal + 30)).map { ereignis("e\($0)", .ziel) }
        await regeln.verarbeite(stand(viele), einstellungen: Einstellungen(), jetzt: jetzt)
        let gespeichert = JSONDatei<[String]>(ordner.appendingPathComponent("partner-gemeldet.json")).lade() ?? []
        XCTAssertEqual(gespeichert.count, PartnerEreignisRegeln.gemerktMaximal)
        XCTAssertEqual(gespeichert.last, "e\(PartnerEreignisRegeln.gemerktMaximal + 29)")
    }

    // MARK: Je Art abschaltbar

    func testAbgeschalteteArtBekommtKeineMitteilungWirdAberGemerkt() async {
        let mitteiler = FakeMitteiler()
        let regeln = PartnerEreignisRegeln(mitteiler: mitteiler, ordner: nil)
        var e = Einstellungen()
        e.mitteilungen[PartnerEreignisRegeln.schluessel(.gymStart)] = false
        let s = stand([ereignis("a", .gymStart), ereignis("b", .ziel)])
        let gemeldet = await regeln.verarbeite(s, einstellungen: e, jetzt: jetzt)
        XCTAssertEqual(gemeldet.map(\.id), ["b"])
        e.mitteilungen[PartnerEreignisRegeln.schluessel(.gymStart)] = true
        let spaeter = await regeln.verarbeite(s, einstellungen: e, jetzt: jetzt)
        XCTAssertTrue(spaeter.isEmpty, "wieder eingeschaltet holt Altes nicht nach")
    }

    func testStandardIstAnFuerJedeArt() {
        for art in [PartnerEreignisArt.gymStart, .gymEnde, .ziel, .rekord, .schlafGut] {
            XCTAssertTrue(PartnerEreignisRegeln.an(art, Einstellungen()), art.rawValue)
            XCTAssertFalse(PartnerEreignisRegeln.name(art).isEmpty)
        }
        XCTAssertEqual(Set([PartnerEreignisArt.gymStart, .gymEnde, .ziel, .rekord, .schlafGut].map(PartnerEreignisRegeln.schluessel)).count, 5)
    }

    // MARK: Nur verbunden und frisch

    func testNichtVerbundenVeraltetOderFalscheVersionGibtNichts() async {
        let mitteiler = FakeMitteiler()
        let regeln = PartnerEreignisRegeln(mitteiler: mitteiler, ordner: nil)
        let datei = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "x", freigaben: [], heute: TagesZusammenfassung(tag: "2026-10-29"),
                                         ereignisse: [ereignis("a", .gymEnde)])
        for s in [PartnerStand.nichtVerbunden, .veraltet(datei), .unbekannteVersion] {
            let gemeldet = await regeln.verarbeite(s, einstellungen: Einstellungen(), jetzt: jetzt)
            XCTAssertTrue(gemeldet.isEmpty)
        }
        XCTAssertTrue(mitteiler.meldungen.isEmpty)
    }

    func testAlteEreignisseWerdenNichtGemeldet() async {
        let mitteiler = FakeMitteiler()
        let regeln = PartnerEreignisRegeln(mitteiler: mitteiler, ordner: nil)
        let alt = ereignis("alt", .gymEnde, vor: PartnerEreignisRegeln.frischBis + 60)
        await regeln.verarbeite(stand([alt]), einstellungen: Einstellungen(), jetzt: jetzt)
        XCTAssertTrue(mitteiler.meldungen.isEmpty)
    }

    func testRueckrufFuerDasBandKommtJeNeuemEreignis() async {
        let regeln = PartnerEreignisRegeln(mitteiler: FakeMitteiler(), ordner: nil)
        let gesehen = Sammler()
        regeln.beiNeuem = { gesehen.ids.append($0.id) }
        let s = stand([ereignis("a", .gymStart)])
        await regeln.verarbeite(s, einstellungen: Einstellungen(), jetzt: jetzt)
        await regeln.verarbeite(s, einstellungen: Einstellungen(), jetzt: jetzt)
        XCTAssertEqual(gesehen.ids, ["a"])
    }

    // MARK: Mit der Fixture von Quelle A

    func testPartnerWarImGymErscheintGenauEinmalJeTag() async throws {
        let mitteiler = FakeMitteiler()
        let regeln = PartnerEreignisRegeln(mitteiler: mitteiler, ordner: nil)
        let einstellungen = EinstellungenStore()
        einstellungen.aendere { $0.loveaVerbunden = true }
        let bruecke = LoveaBruecke(ordner: try VerbindenTest.gruppe(self, widgetStand: true))
        let store = VerbindungStore(ordner: nil, bruecke: bruecke, einstellungen: einstellungen)
        for minuten in [0, 15, 30] {   // der Abruf läuft mehrmals am Tag
            let t = jetzt.addingTimeInterval(TimeInterval(minuten * 60))
            store.aktualisiere(jetzt: t)
            await regeln.verarbeite(store.partner, einstellungen: einstellungen.werte, jetzt: t)
        }
        let gym = mitteiler.meldungen.filter { $0.id == "partner.gymEnde-2026-10-29" }
        XCTAssertEqual(gym.count, 1)
        XCTAssertEqual(gym.first?.text, "Kennung-b war im Gym")
        XCTAssertTrue(mitteiler.meldungen.contains { $0.id == "partner.ziel-2026-10-29" })
    }

    func testAmNaechstenTagKommtDieMitteilungWieder() async throws {
        let mitteiler = FakeMitteiler()
        let regeln = PartnerEreignisRegeln(mitteiler: mitteiler, ordner: nil)
        await regeln.verarbeite(stand([ereignis("gymEnde-2026-10-29", .gymEnde)]), einstellungen: Einstellungen(), jetzt: jetzt)
        let morgen = jetzt.addingTimeInterval(86_400)
        let neu = PartnerEreignis(id: "gymEnde-2026-10-30", art: .gymEnde, zeit: morgen, text: "Text morgen")
        await regeln.verarbeite(stand([neu]), einstellungen: Einstellungen(), jetzt: morgen)
        XCTAssertEqual(mitteiler.meldungen.count, 2)
    }
}
