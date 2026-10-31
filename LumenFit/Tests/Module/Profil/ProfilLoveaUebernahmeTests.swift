import XCTest
@testable import LumenFit

/// Was aus Loveas Abgabe (`abgabe.*`) und den Arten ohne Leser wird. Alles erfunden: "Studio Test", "Gerät", keine echten Werte.
@MainActor
final class ProfilLoveaUebernahmeTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func json(_ s: String) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self, from: Data(s.utf8)) }

    private func einstellung(_ schluessel: String, _ wert: JSONValue, id: String, nach s: TimeInterval = 0) -> Op {
        TestDaten.op("einstellung.setzen", ["schluessel": JSONValue.string(schluessel), "wert": wert], zeit: t0 + s, id: id)
    }

    private func profil() throws -> (AppUmgebung, DatenSatz) {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "efgh")
        return (u, try XCTUnwrap(u.daten))
    }

    private func defaults() -> UserDefaults {
        let name = "lumenfit.test.uebernahme.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        addTeardownBlock { d.removePersistentDomain(forName: name) }
        return d
    }

    // MARK: Tabelle

    func testAbgabeSchluesselWerdenUebernommenWeckerBleibtRoh() {
        func b(_ schluessel: String) -> ProfilLoveaBehandlung {
            ProfilLoveaArten.behandlung(art: "einstellung.setzen", d: Data(#"{"schluessel":"\#(schluessel)","wert":1}"#.utf8))
        }
        XCTAssertEqual(b("abgabe.lovea.gym.studioprofil"), .uebernehmen, "sonst zählt der Import die Abgabe still als ausgeschlossen")
        XCTAssertEqual(b("abgabe.einstellungen"), .uebernehmen)
        XCTAssertEqual(ProfilLoveaArten.behandlung(art: "wecker.setzen", d: Data("{}".utf8)), .rohBehalten)
        guard case .ausschliessen = b("chat.backdrop") else { return XCTFail("Chat bleibt draußen") }
    }

    func testEinordnenNachGruppe() {
        func gruppe(_ op: Op) -> String? { ProfilLoveaUebernahme.einordnen(op)?.gruppe }
        XCTAssertEqual(gruppe(einstellung("abgabe.tagesform.gefuehl.2026-10-01", .null, id: "a")), "abgabe.tagesform.gefuehl")
        XCTAssertEqual(gruppe(einstellung("abgabe.lovea.wecker.v1", .null, id: "b")), "abgabe.lovea.wecker.v1")
        XCTAssertEqual(gruppe(einstellung("abgabe." + String(repeating: "x", count: 70), .null, id: "c")), "abgabe.andere")
        XCTAssertEqual(gruppe(einstellung("coach.ton", .string("knapp"), id: "d")), "einstellung.coach")
        XCTAssertNil(gruppe(einstellung("ziel.schritte", .number(9000), id: "e")), "Ziele haben ihren Leser")
        XCTAssertEqual(gruppe(TestDaten.op("wecker.setzen", ["min": 400], zeit: t0, id: "f")), "wecker.setzen")
        XCTAssertNil(gruppe(TestDaten.op("habit.setzen", ["x": 1], zeit: t0, id: "g")))
    }

    func testNeuesteJeEinheitZaehltAelterePassend() throws {
        let alt = einstellung("abgabe.lovea.gym.studioprofil", .object([:]), id: "alt", nach: 0)
        let neu = einstellung("abgabe.lovea.gym.studioprofil", .object(["x": .number(1)]), id: "neu", nach: 60)
        let andere = einstellung("abgabe.lovea.wecker.v1", .object([:]), id: "w", nach: 5)
        let (neueste, beleg) = ProfilLoveaUebernahme.neuesteJeEinheit([neu, alt, andere])
        XCTAssertEqual(neueste.map { $0.1.id }.sorted(), ["neu", "w"])
        XCTAssertEqual(beleg["abgabe.lovea.gym.studioprofil"]?.geholt, 2)
        XCTAssertEqual(beleg["abgabe.lovea.gym.studioprofil"]?.aelter, 1)
        XCTAssertEqual(beleg["abgabe.lovea.wecker.v1"]?.aelter, 0)
    }

    // MARK: Studio

    private let studios = #""studios":{"kennungA":"Studio Test"}"#

    func testStudioWirdGeschriebenAberNieUeberEinGewaehltesGelegt() throws {
        let ordner = try tempOrdner()
        let wert = try json(#"{"eintraege":{"person":{"studio":"kennungA","slotStart":300,"dauer":45}},\#(studios)}"#)
        let r = ProfilLoveaUebernahme.studio(wert, ordner: ordner)
        XCTAssertEqual(r.geschrieben, 1)
        XCTAssertFalse(r.kaputt)
        let datei = JSONDatei<StudioProfil>(ordner.appendingPathComponent("studio.json"))
        XCTAssertEqual(datei.lade()?.name, "Studio Test")
        XCTAssertEqual(datei.lade()?.slotStart, 300)
        // Lokal schon ein anderes Studio: bleibt.
        datei.speichere(StudioProfil(name: "Eigenes", slotStart: 420, dauer: 60))
        let zweit = ProfilLoveaUebernahme.studio(wert, ordner: ordner)
        XCTAssertEqual(zweit.geschrieben, 0)
        XCTAssertEqual(datei.lade()?.name, "Eigenes")
    }

    func testStudioOhneBekannteKennungIstUnlesbarNichtStillVerloren() throws {
        let wert = try json(#"{"eintraege":{"person":{"studio":"unbekannt","dauer":45}},\#(studios)}"#)
        XCTAssertTrue(ProfilLoveaUebernahme.studio(wert, ordner: try tempOrdner()).kaputt)
        XCTAssertTrue(ProfilLoveaUebernahme.studio(.string("kaputt"), ordner: try tempOrdner()).kaputt)
    }

    // MARK: Geräte und Defekt

    func testGeraeteEinstellungenKommenMitUebersetztemSchluessel() throws {
        let ordner = try tempOrdner()
        let wert = try json(#"{"eintraege":{"person|kennungA|bank":{"bankstufe":3,"sitzhoehe":5,"notiz":"  hoch  "},"person|kennungA|leer":{"notiz":""}},\#(studios)}"#)
        let r = ProfilLoveaUebernahme.geraete(wert, ordner: ordner)
        XCTAssertEqual(r.eintraege, 2)
        XCTAssertEqual(r.geschrieben, 1, "eine leere Einstellung ist nichts")
        let stand = GeraeteEinstellungDatei.lesen(ordner)
        let w = try XCTUnwrap(stand.eintraege[DefektLogik.schluessel(studio: "Studio Test", uebung: "bank")])
        XCTAssertEqual(w.stufe, "3")
        XCTAssertEqual(w.sitz, "5")
        XCTAssertEqual(w.notiz, "hoch")
        XCTAssertEqual(ProfilLoveaUebernahme.geraete(wert, ordner: ordner).geschrieben, 0, "zweiter Lauf legt nichts doppelt")
    }

    func testDefektNotizenMitStudioVorsatz() throws {
        let ordner = try tempOrdner()
        let wert = try json(#"{"eintraege":{"person|studio.kennungA|presse":{"text":"wackelt","gemeldetAm":"2026-10-01"}},\#(studios)}"#)
        XCTAssertEqual(ProfilLoveaUebernahme.defekt(wert, ordner: ordner).geschrieben, 1)
        let stand = JSONDatei<[String: DefektNotiz]>(ordner.appendingPathComponent("defekte.json")).lade()
        XCTAssertEqual(stand?[DefektLogik.schluessel(studio: "Studio Test", uebung: "presse")]?.text, "wackelt")
        XCTAssertEqual(ProfilLoveaUebernahme.defekt(wert, ordner: ordner).geschrieben, 0)
    }

    // MARK: Band-Regeln

    func testBandRegelnNurWoLokalNichtsGewaehltIst() throws {
        let d = defaults()
        d.set(25, forKey: "fit.band.akku.schwelle")   // schon gewählt: bleibt
        let wert = try json(#"{"lovea.tracker.band.akku.schwelle":10,"lovea.tracker.band.ruhe.nacht":false,"lovea.tracker.band.sitzen.von":540,"schlaf.bettErinnerung":true}"#)
        let r = ProfilLoveaUebernahme.band(wert, defaults: d)
        XCTAssertEqual(r.eintraege, 4)
        XCTAssertEqual(r.geschrieben, 2)
        XCTAssertTrue(r.hatLeser)
        XCTAssertEqual(d.integer(forKey: "fit.band.akku.schwelle"), 25)
        XCTAssertEqual(d.object(forKey: "fit.band.ruhe.nacht") as? Bool, false)
        XCTAssertEqual(d.integer(forKey: "fit.band.sitzen.von"), 540)
        XCTAssertNil(d.object(forKey: "schlaf.bettErinnerung"), "Health-Wecker-Schalter gehören zu Lumen Alarm")
    }

    func testEinstellungenOhneBandRegelnBleibenRoh() throws {
        let r = ProfilLoveaUebernahme.band(try json(#"{"schlaf.bettErinnerung":true}"#), defaults: defaults())
        XCTAssertFalse(r.hatLeser)
        XCTAssertEqual(r.geschrieben, 0)
    }

    // MARK: Ganzer Ablauf

    func testUebernehmeZaehltJedeGruppeUndBeleganglichStimmt() throws {
        let (_, daten) = try profil()
        let ordner = daten.ordner
        let ops: [Op] = [
            einstellung("abgabe.lovea.gym.studioprofil", try json(#"{"eintraege":{"p":{"studio":"kennungA","dauer":45}},\#(studios)}"#), id: "s1", nach: 0),
            einstellung("abgabe.lovea.gym.studioprofil", try json(#"{"eintraege":{"p":{"studio":"kennungA","dauer":30}},\#(studios)}"#), id: "s2", nach: 10),
            einstellung("abgabe.lovea.wecker.v1", try json(#"{"an":true}"#), id: "w1"),
            einstellung("abgabe.lovea.erinnerungen.v1", try json(#"[{"text":"a"},{"text":"b"}]"#), id: "e1"),
            einstellung("coach.ton", .string("knapp"), id: "c1"),
            TestDaten.op("wecker.setzen", ["min": JSONValue.number(400), "an": JSONValue.bool(true)], von: daten.profil, zeit: t0, id: "ws1"),
            TestDaten.op("wecker.setzen", ["min": JSONValue.number(410), "an": JSONValue.bool(true)], von: daten.profil, zeit: t0 + 5, id: "ws2"),
            TestDaten.op("coach.nachricht", ["rolle": "coach", "text": "Guten Morgen", "tag": "2026-10-01"], von: daten.profil, zeit: t0, id: "cn1"),
            TestDaten.op("einkauf.liste", ["x": 1], von: daten.profil, zeit: t0, id: "ek1"),
        ]
        let beleg = ProfilLoveaUebernahme.uebernehme(ops, in: daten, defaults: defaults())
        let s = try XCTUnwrap(beleg["abgabe.lovea.gym.studioprofil"])
        XCTAssertEqual([s.geholt, s.aelter, s.uebernommen], [2, 1, 1])
        XCTAssertEqual(JSONDatei<StudioProfil>(ordner.appendingPathComponent("studio.json")).lade()?.dauer, 30, "die neuere Op gewinnt")
        XCTAssertEqual(beleg["abgabe.lovea.wecker.v1"]?.roh, 1)
        XCTAssertEqual(beleg["abgabe.lovea.erinnerungen.v1"]?.eintraege, 2)
        XCTAssertEqual(beleg["einstellung.coach"]?.roh, 1)
        XCTAssertEqual(beleg["wecker.setzen"]?.geholt, 2, "jede Op ist eine Einheit")
        XCTAssertEqual(beleg["wecker.setzen"]?.roh, 2)
        XCTAssertEqual(beleg["einkauf.liste"]?.roh, 1)
        XCTAssertTrue(beleg.values.allSatisfy(\.stimmt), "\(beleg)")
        // Coach-Nachricht ist als Lumen-Op sichtbar, mit fester Kennung.
        let verlauf = daten.coach.verlauf
        XCTAssertEqual(verlauf.map(\.text), ["Guten Morgen"])
        XCTAssertEqual(verlauf.first?.rolle, .coach)
        XCTAssertEqual(beleg["coach.nachricht"]?.uebernommen, 1)
        // Zweiter Lauf: nichts doppelt, die Nachricht zählt als schon da.
        let nochmal = ProfilLoveaUebernahme.uebernehme(ops, in: daten, defaults: defaults())
        XCTAssertEqual(daten.coach.verlauf.count, 1)
        XCTAssertEqual(nochmal["coach.nachricht"]?.vorhanden, 1)
        XCTAssertEqual(nochmal["abgabe.lovea.gym.studioprofil"]?.vorhanden, 1)
    }

    func testGefuehlTageKommenDazuVorhandeneBleiben() throws {
        let (_, daten) = try profil()
        let datei = daten.ordner.appendingPathComponent(TagesformGefuehl.dateiname)
        func eintrag(_ tag: String, _ gefuehl: Int) -> TagesformEintrag {
            TagesformEintrag(tag: tag, gefuehl: gefuehl, akku: 60, formel: TagesformRechnung.version, eingabe: TagesformEingabe(), gespeichert: Date(timeIntervalSince1970: 1_700_000_000))
        }
        func op(_ e: TagesformEintrag, id: String) throws -> Op {
            let wert = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(e))
            return einstellung(ProfilLoveaUebernahme.gefuehlPraefix + e.tag, wert, id: id)
        }
        TagesformGefuehl.speichern([eintrag("2026-10-02", 5)], in: datei)
        let beleg = ProfilLoveaUebernahme.uebernehme([try op(eintrag("2026-10-01", 3), id: "g1"), try op(eintrag("2026-10-02", 1), id: "g2")], in: daten, defaults: defaults())
        let g = try XCTUnwrap(beleg["abgabe.tagesform.gefuehl"])
        XCTAssertEqual([g.geholt, g.uebernommen, g.vorhanden, g.unlesbar, g.geschrieben], [2, 1, 1, 0, 1])
        XCTAssertTrue(g.stimmt)
        let liste = TagesformGefuehl.laden(datei)
        XCTAssertEqual(liste.map(\.tag), ["2026-10-01", "2026-10-02"])
        XCTAssertEqual(liste.last?.gefuehl, 5, "der lokale Tag wird nicht überschrieben")
    }

    // MARK: Beleg

    func testBelegTraegtUebernahmeUndMeldetUnlesbaresAlsLuecke() {
        var e = ProfilLoveaErgebnis(neu: 0, schonDa: 0, uebersprungen: 0, trainings: 0, essenstage: 0, abdeckung: ProfilLoveaAbdeckung())
        e.uebernahme = ["abgabe.lovea.gym.studioprofil": ProfilLoveaUebernahmeBeleg(geholt: 1, uebernommen: 1, eintraege: 1, geschrieben: 1)]
        XCTAssertTrue(ProfilLoveaBeleg.baue(e, zeit: t0).vollstaendig)
        e.uebernahme["abgabe.lovea.gym.defekt"] = ProfilLoveaUebernahmeBeleg(geholt: 1, unlesbar: 1, eintraege: 1)
        let b = ProfilLoveaBeleg.baue(e, zeit: t0)
        XCTAssertFalse(b.vollstaendig, "eine Abgabe, die nicht ankam, hält den Import offen")
        XCTAssertEqual(b.uebernahme.count, 2)
        e.uebernahme = ["Freitext mit Leerzeichen": ProfilLoveaUebernahmeBeleg(geholt: 1, roh: 1)]
        XCTAssertTrue(ProfilLoveaBeleg.baue(e, zeit: t0).uebernahme.isEmpty, "Namen, die der Server nicht annähme, fallen heraus")
    }
}
