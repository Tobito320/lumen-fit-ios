import XCTest
@testable import LumenFit

/// Der Dienst, der `zusammenfassung.json` schreibt (Idee 81, 84): nur mit Schalter, nur freigegebene Arten aus den Stores, Darwin-Anstoß, nichts außerhalb des Vertrags.
@MainActor
final class LoveaBrueckeDienstTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt   // Donnerstag 29.10.2026, 10:00

    private struct Aufbau {
        var daten: DatenSatz
        var fake: FakePartnerAustausch
        var dienst: LoveaBrueckeDienst
        var angestossen: DarwinZaehler
    }

    private func aufbau(schalter: Bool = true, freigaben: Set<FreigabeArt> = [], bruecke: FakePartnerAustausch = FakePartnerAustausch(),
                        uhr: @escaping Uhr = { VerbindenTest.jetzt }) async throws -> Aufbau {
        let daten = try VerbindenTest.daten(self, uhr: uhr)
        daten.einstellungen.aendere { $0.loveaVerbunden = schalter }
        daten.verbindung.freigaben = freigaben
        // 8.200 Schritte und 450 Minuten Schlaf aus Health, ein Training heute und eine Mahlzeit
        let leser = FakeHealthLeser(tage: [TagesWerte(tag: "2026-10-29", schritte: 8_200)], naechte: [Self.nacht("2026-10-29", minuten: 450)])
        let gesundheit = GesundheitsStand(leser: leser, uhr: uhr)
        await gesundheit.aktualisiere()
        for op in TestDaten.gymOps(start: jetzt.addingTimeInterval(-7200), session: "s1") { daten.raum.einreihen(op) }
        for op in TestDaten.essenOps(datum: "2026-10-29", zeit: jetzt.addingTimeInterval(-3600)) { daten.raum.einreihen(op) }
        let zaehler = DarwinZaehler()
        let dienst = LoveaBrueckeDienst(bruecke: bruecke,
                                        quellen: .init(daten: { daten }, gesundheit: gesundheit, profilName: { "Beispiel Profil" }), uhr: uhr,
                                        sende: { zaehler.namen.append($0) })
        return Aufbau(daten: daten, fake: bruecke, dienst: dienst, angestossen: zaehler)
    }

    private static func nacht(_ tag: String, minuten: Int) -> SchlafNacht {
        let bis = Datum.datum(tag).addingTimeInterval(7 * 3600)
        let von = bis.addingTimeInterval(-Double(minuten) * 60)
        return SchlafNacht(tag: tag, von: von, bis: bis, abschnitte: [SchlafAbschnitt(phase: .kern, von: von, bis: bis)], schlafMinuten: minuten)
    }

    // MARK: Schalter

    func testOhneSchalterWirdNichtsGeschrieben() async throws {
        let a = try await aufbau(schalter: false, freigaben: Set(FreigabeArt.allCases))
        XCTAssertFalse(a.dienst.schreibe())
        XCTAssertTrue(a.fake.zusammenfassungen.isEmpty)
        XCTAssertTrue(a.angestossen.namen.isEmpty)
    }

    func testOhneProfilWirdNichtsGeschrieben() async throws {
        let dienst = LoveaBrueckeDienst(bruecke: FakePartnerAustausch(), quellen: .init(daten: { nil }, gesundheit: GesundheitsStand(leser: FakeHealthLeser(), uhr: { VerbindenTest.jetzt }),
                                                                                       profilName: { nil }), sende: { _ in })
        XCTAssertFalse(dienst.schreibe())
    }

    // MARK: Inhalt

    func testStandardKeineFreigabeSchreibtNurNameUndTag() async throws {
        let a = try await aufbau()
        XCTAssertTrue(a.dienst.schreibe())
        let datei = try XCTUnwrap(a.fake.zusammenfassungen.last)
        XCTAssertEqual(datei.profilName, "Beispiel Profil")
        XCTAssertTrue(datei.freigaben.isEmpty)
        XCTAssertEqual(datei.heute, TagesZusammenfassung(tag: "2026-10-29"), "ohne Freigabe fehlen alle Felder")
        XCTAssertTrue(datei.ereignisse.isEmpty)
        XCTAssertEqual(a.angestossen.namen, [DarwinKanal.zusammenfassung])
    }

    func testNurFreigegebeneArtenKommenAusDenStores() async throws {
        let a = try await aufbau(freigaben: [.schritte, .gym, .essen])
        a.dienst.schreibe()
        let datei = try XCTUnwrap(a.fake.zusammenfassungen.last)
        XCTAssertEqual(datei.freigaben, [.schritte, .gym, .essen])
        XCTAssertEqual(datei.heute.schritte, 8_200)
        XCTAssertEqual(datei.heute.gymTageWoche, 1, "eine Einheit mit abgehakten Sätzen heute")
        XCTAssertEqual(datei.heute.kcal, 222, "60 g Haferflocken zu 370 kcal je 100 g")
        XCTAssertNil(datei.heute.schlafMinuten, "Schlaf ist nicht freigegeben")
    }

    func testSchlafKommtMitFreigabe() async throws {
        let a = try await aufbau(freigaben: [.schlaf])
        a.dienst.schreibe()
        XCTAssertEqual(a.fake.zusammenfassungen.last?.heute.schlafMinuten, 450)
        XCTAssertNil(a.fake.zusammenfassungen.last?.heute.schritte)
    }

    // MARK: Ereignisse

    func testTrainingsEreignisseKommenInDieDateiWennDasGymFreigegebenIst() async throws {
        let a = try await aufbau(freigaben: [.gym])
        a.dienst.ereignis(.trainingGestartet(session: "s1"))
        a.dienst.ereignis(.satzFertig(session: "s1", rekord: false))
        a.dienst.ereignis(.satzFertig(session: "s1", rekord: true))
        a.dienst.ereignis(.trainingBeendet(session: "s1"))
        a.dienst.schreibe()
        let arten = a.fake.zusammenfassungen.last?.ereignisse.map(\.art)
        XCTAssertEqual(Set(arten ?? []), [.gymStart, .rekord, .gymEnde])
        XCTAssertEqual(arten?.count, 3, "ein Satz ohne Rekord ist kein Ereignis")
        XCTAssertTrue(a.fake.zusammenfassungen.last?.ereignisse.contains { $0.text == "Beispiel Profil ist im Gym" } ?? false)
    }

    func testOhneGymFreigabeKeineGymEreignisse() async throws {
        let a = try await aufbau(freigaben: [.schritte])
        a.dienst.ereignis(.trainingGestartet(session: "s1"))
        a.dienst.schreibe()
        XCTAssertTrue(a.fake.zusammenfassungen.last?.ereignisse.isEmpty ?? false)
    }

    func testZielErreichtWirdEinEreignisEinmalJeTag() async throws {
        let a = try await aufbau(freigaben: [.schritte, .schlaf])
        a.daten.ziele.setze({ var z = Ziele(); z.schritte = 8_000; z.schlafMinuten = 420; return z }())
        a.dienst.schreibe()
        a.dienst.schreibe()
        let ids = a.fake.zusammenfassungen.last?.ereignisse.map(\.id) ?? []
        XCTAssertEqual(Set(ids), ["ziel-2026-10-29", "schlafGut-2026-10-29"])
        XCTAssertEqual(ids.count, 2)
    }

    func testEigeneEreignisseUeberlebenEinenNeustart() async throws {
        let a = try await aufbau(freigaben: [.gym])
        a.dienst.ereignis(.trainingGestartet(session: "s1"))
        let neu = LoveaBrueckeDienst(bruecke: a.fake, quellen: .init(daten: { a.daten }, gesundheit: GesundheitsStand(leser: FakeHealthLeser(), uhr: { VerbindenTest.jetzt }),
                                                                    profilName: { "Beispiel Profil" }), uhr: { VerbindenTest.jetzt }, sende: { _ in })
        neu.schreibe()
        XCTAssertEqual(a.fake.zusammenfassungen.last?.ereignisse.map(\.id), ["gymStart-s1"])
    }

    // MARK: Drosselung

    func testUnveraenderteDateiWirdNichtNeuGeschriebenAberRegelmaessigAufgefrischt() async throws {
        let uhrwerk = TestUhr(jetzt)
        let a = try await aufbau(freigaben: [.schritte], uhr: uhrwerk.uhr)
        XCTAssertTrue(a.dienst.schreibe())
        uhrwerk.vor(sekunden: 600)
        XCTAssertFalse(a.dienst.schreibe(), "nichts geändert")
        XCTAssertEqual(a.fake.zusammenfassungen.count, 1)
        uhrwerk.vor(sekunden: LoveaBrueckeDienst.auffrischen)
        XCTAssertTrue(a.dienst.schreibe(), "Lovea soll die Datei nie als veraltet sehen")
        XCTAssertEqual(a.fake.zusammenfassungen.count, 2)
    }

    func testGeaenderteFreigabeSchreibtSofortNeu() async throws {
        let a = try await aufbau(freigaben: [.schritte])
        a.dienst.schreibe()
        a.daten.verbindung.freigaben = [.schritte, .gym]
        XCTAssertTrue(a.dienst.schreibe())
        XCTAssertEqual(a.fake.zusammenfassungen.last?.freigaben, [.schritte, .gym])
    }

    // MARK: Nichts außerhalb des Vertrags

    func testEchteBrueckeLegtNurDieDateiDesVertragsAnUndLaesstWidgetStandUnberuehrt() async throws {
        let gruppe = try VerbindenTest.gruppe(self, widgetStand: true)
        let vorher = try Data(contentsOf: gruppe.appendingPathComponent(LoveaVertrag.widgetStandDatei))
        let a = try await aufbau(freigaben: [.schritte], bruecke: FakePartnerAustausch())
        let dienst = LoveaBrueckeDienst(bruecke: LoveaBruecke(ordner: gruppe),
                                        quellen: .init(daten: { a.daten }, gesundheit: GesundheitsStand(leser: FakeHealthLeser(), uhr: { VerbindenTest.jetzt }), profilName: { "Beispiel Profil" }),
                                        uhr: { VerbindenTest.jetzt }, sende: { _ in })
        XCTAssertTrue(dienst.schreibe())
        XCTAssertEqual(VerbindenTest.dateien(gruppe), ["LumenFit/zusammenfassung.json", "widget-stand.json"])
        XCTAssertEqual(try Data(contentsOf: gruppe.appendingPathComponent(LoveaVertrag.widgetStandDatei)), vorher, "Loveas widget-stand.json wird nur gelesen")
    }

    func testOhneLoveaGruppeKostetDasSchreibenNichts() async throws {
        let a = try await aufbau(freigaben: [.schritte], bruecke: FakePartnerAustausch())
        let dienst = LoveaBrueckeDienst(bruecke: LoveaBruecke(ordner: nil),
                                        quellen: .init(daten: { a.daten }, gesundheit: GesundheitsStand(leser: FakeHealthLeser(), uhr: { VerbindenTest.jetzt }), profilName: { "x" }),
                                        uhr: { VerbindenTest.jetzt }, sende: { _ in })
        XCTAssertTrue(dienst.schreibe(), "kein Absturz, auch wenn die Datei nirgends landet")
    }

    func testGymTageDerWocheZaehltNurEinheitenMitDatenInDieserWoche() {
        let start = Datum.datum("2026-10-26").addingTimeInterval(9 * 3600)   // Montag
        func session(_ id: String, _ s: Date, ok: Bool) -> GymSession {
            GymSession(id: id, tag: nil, start: s, ende: s.addingTimeInterval(3600),
                       laeufe: [UebungsLauf(plan: "p", uebung: "u", start: s, ende: nil, fertig: ok, stand: ok ? [PlanSatz(wdh: 5, kg: 50, failure: false, ok: true)] : [])])
        }
        let liste = [session("a", start, ok: true), session("b", start.addingTimeInterval(3600), ok: true), session("c", start.addingTimeInterval(86_400), ok: false),
                     session("d", start.addingTimeInterval(-86_400 * 3), ok: true)]
        XCTAssertEqual(LoveaBrueckeDienst.gymTageDerWoche(liste, heute: "2026-10-29"), 1, "zwei Einheiten am Montag zählen einen Tag, ohne Daten und vor der Woche zählt nichts")
    }

    // MARK: Vorschau

    func testVorschauZeigtGenauDieFreigegebenenZeilenUndSchreibtNichts() async throws {
        let a = try await aufbau(freigaben: [.schritte, .essen])
        let datei = try XCTUnwrap(a.dienst.vorschau())
        XCTAssertEqual(FreigabenVorschau.zeilen(datei).map(\.titel), ["Schritte", "Essen"])
        XCTAssertTrue(a.fake.zusammenfassungen.isEmpty, "die Vorschau schreibt nichts")
        XCTAssertTrue(a.angestossen.namen.isEmpty)
    }

    func testVorschauOhneFreigabeIstLeer() async throws {
        let a = try await aufbau()
        XCTAssertEqual(FreigabenVorschau.zeilen(try XCTUnwrap(a.dienst.vorschau())), [])
    }

    // MARK: Server-Upload für Verbindungen

    func testOhneVerbindungGehtNichtsAnDenServer() async throws {
        let a = try await aufbau(schalter: false, freigaben: Set(FreigabeArt.allCases))
        a.dienst.schreibe()
        XCTAssertTrue(a.fake.serverStaende.isEmpty)
    }

    func testServerStandEnthaeltNurDieBereicheDerVerbindungenAuchOhneLoveaSchalter() async throws {
        let a = try await aufbau(schalter: false, freigaben: Set(FreigabeArt.allCases))
        a.dienst.hochladen = { [.schritte, .gym] }
        XCTAssertFalse(a.dienst.schreibe(), "ohne Lovea-Schalter keine Datei für Lovea")
        XCTAssertTrue(a.fake.zusammenfassungen.isEmpty)
        let stand = try XCTUnwrap(a.fake.serverStaende.last)
        XCTAssertEqual(Set(stand.freigaben), [.schritte, .gym])
        XCTAssertEqual(stand.heute.schritte, 8_200)
        XCTAssertNil(stand.heute.kcal, "Essen zeigt keine Verbindung")
        XCTAssertNil(stand.heute.schlafMinuten)
        XCTAssertNil(stand.heute.zyklus)
    }

    func testZyklusGehtNieHinausAuchWennErInDerAppErlaubtIst() async throws {
        // Zyklus gehört nur in Lovea: selbst mit alten Zyklus-Daten und alter Erlaubnis schickt Lumen Fit ihn weder an den Server noch an Lovea.
        let a = try await aufbau(freigaben: Set(FreigabeArt.allCases))
        for i in 0..<2 {
            var t = ZyklusTag(id: Datum.addTage("2026-10-29", -i))
            t.blutung = .mittel
            a.daten.zyklus.setze(t)
        }
        a.daten.zyklus.aendere { $0.aktiv = true; $0.partnerZeigen = true }
        XCTAssertNotNil(a.daten.zyklus.partnerZusammenfassung(), "Vorbedingung: der Zyklus wäre früher teilbar gewesen")
        a.dienst.hochladen = { Set(FreigabeArt.allCases) }
        XCTAssertTrue(a.dienst.schreibe())
        XCTAssertNotNil(a.fake.serverStaende.last)
        XCTAssertNil(a.fake.serverStaende.last?.heute.zyklus, "nie an den Server")
        XCTAssertNil(a.fake.zusammenfassungen.last?.heute.zyklus, "nie in die Datei für Lovea")
        XCTAssertNil(a.dienst.vorschau()?.heute.zyklus, "nie in der Vorschau")
    }

    func testDateiFuerLoveaBleibtBeiDenFreigabenDesProfils() async throws {
        let a = try await aufbau(freigaben: [.schlaf])
        a.dienst.hochladen = { [.schritte] }
        XCTAssertTrue(a.dienst.schreibe())
        XCTAssertEqual(a.fake.zusammenfassungen.last?.freigaben, [.schlaf])
        XCTAssertEqual(a.fake.serverStaende.last?.freigaben, [.schritte])
    }

    func testStimmungUndGewohnheitenGehenNurMitIhrerFreigabeHinaus() async throws {
        let a = try await aufbau(schalter: false)
        a.daten.raum.einreihen(TestDaten.op("fit.lumi.stimmung", StimmungsEintrag(tag: "2026-10-29", wert: 4, stimmung: .bereit), zeit: jetzt))
        a.daten.habits.setze(Habit.wasser.id, datum: "2026-10-29", wert: 8)
        a.dienst.hochladen = { [.schritte] }
        a.dienst.schreibe()
        XCTAssertNil(a.fake.serverStaende.last?.heute.stimmung)
        XCTAssertNil(a.fake.serverStaende.last?.heute.gewohnheiten)
        a.dienst.hochladen = { [.schritte, .stimmung, .gewohnheiten] }
        a.dienst.schreibe()
        let heute = try XCTUnwrap(a.fake.serverStaende.last?.heute)
        XCTAssertEqual(heute.stimmung, 4)
        XCTAssertEqual(heute.stimmungWoche, ["2026-10-29": 4])
        let wasser = try XCTUnwrap(heute.gewohnheiten?.first { $0.id == Habit.wasser.id })
        XCTAssertTrue(wasser.heute)
        XCTAssertEqual(wasser.serie, 1)
        XCTAssertTrue((0...100).contains(wasser.quote))
        XCTAssertEqual(heute.gewohnheiten?.first { $0.id == Habit.gym.id }?.heute, true, "das Training von heute zählt für Gym")
    }
}

/// Zählt die gesendeten Darwin-Namen (ein Verweistyp statt einer erfassten Variable).
final class DarwinZaehler { var namen: [String] = [] }
