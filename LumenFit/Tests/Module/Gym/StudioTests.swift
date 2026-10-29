// Quelle: Lovea Tests/StudioTests.swift (mit erfundenen Studios; Zeiten sind Daten, keine festen Studios)
import XCTest
@testable import LumenFit

@MainActor
final class StudioTests: XCTestCase {
    /// Erfundenes Studio mit festen Zeiten: Mo-Fr 08:00-22:00, Sa/So 09:00-18:00.
    private let halle = StudioOeffnung(werktage: .init(von: 8 * 60, bis: 22 * 60), wochenende: .init(von: 9 * 60, bis: 18 * 60))
    /// Erfundenes Studio, das immer offen ist.
    private let rund = StudioOeffnung(rund: true)

    // MARK: Öffnungslogik

    func testRundUmDieUhrIstImmerOffen() {
        for tag in 1...7 {
            for minute in [0, 5 * 60, 12 * 60, 23 * 60 + 59] {
                XCTAssertTrue(GymOeffnung.istOffen(rund, wochentag: tag, minute: minute))
            }
            XCTAssertNil(GymOeffnung.warnung(rund, wochentag: tag, start: 0, dauer: 45))
        }
    }

    func testWerktageAb8() {
        XCTAssertFalse(GymOeffnung.istOffen(halle, wochentag: 1, minute: 7 * 60 + 59))
        XCTAssertTrue(GymOeffnung.istOffen(halle, wochentag: 1, minute: 8 * 60))
        XCTAssertTrue(GymOeffnung.istOffen(halle, wochentag: 5, minute: 21 * 60 + 59))
        XCTAssertFalse(GymOeffnung.istOffen(halle, wochentag: 5, minute: 22 * 60))
    }

    func testWochenendeAb9() {
        for tag in [6, 7] {
            XCTAssertFalse(GymOeffnung.istOffen(halle, wochentag: tag, minute: 8 * 60 + 59))
            XCTAssertTrue(GymOeffnung.istOffen(halle, wochentag: tag, minute: 9 * 60))
            XCTAssertFalse(GymOeffnung.istOffen(halle, wochentag: tag, minute: 18 * 60))
        }
    }

    func testSlotGrenzen() {
        // bündig am Anfang ok, eine Minute davor nicht
        XCTAssertNil(GymOeffnung.warnung(halle, wochentag: 2, start: 8 * 60, dauer: 45))
        XCTAssertEqual(GymOeffnung.warnung(halle, wochentag: 2, start: 8 * 60 - 1, dauer: 45)?.grund, .vorOeffnung(von: 8 * 60))
        // bündig am Ende ok, eine Minute darüber nicht
        XCTAssertNil(GymOeffnung.warnung(halle, wochentag: 2, start: 22 * 60 - 45, dauer: 45))
        XCTAssertEqual(GymOeffnung.warnung(halle, wochentag: 2, start: 22 * 60 - 44, dauer: 45)?.grund, .nachSchluss(bis: 22 * 60))
    }

    func testFrueherSlotWarntNurBeiDemStudioMitZeiten() {
        let tage = [1, 3, 6]
        XCTAssertEqual(GymOeffnung.warnungen(halle, wochentage: tage, start: 5 * 60, dauer: 45).map(\.wochentag), [1, 3, 6])
        XCTAssertTrue(GymOeffnung.warnungen(rund, wochentage: tage, start: 5 * 60, dauer: 45).isEmpty)
        XCTAssertTrue(GymOeffnung.warnungen(.unbekannt, wochentage: tage, start: 5 * 60, dauer: 45).isEmpty)
    }

    func testOhneUhrzeitKeineWarnung() {
        XCTAssertTrue(GymOeffnung.warnungen(halle, wochentage: [1, 2], start: nil, dauer: 45).isEmpty)
    }

    func testWarnungNurWennSlotVorOeffnung() {
        // 08:30 Mo-Fr ok, Sa/So vor 09:00 nicht
        XCTAssertEqual(GymOeffnung.warnungen(halle, wochentage: [1, 6, 7], start: 8 * 60 + 30, dauer: 45).map(\.wochentag), [6, 7])
    }

    func testZeilenFasstGleicheGruendeZusammen() {
        let w = GymOeffnung.warnungen(halle, wochentage: [1, 2, 6, 7], start: 5 * 60, dauer: 45)
        XCTAssertEqual(GymOeffnung.zeilen(w), ["Mo, Di: öffnet erst um 08:00", "Sa, So: öffnet erst um 09:00"])
    }

    func testUngueltigeWochentageIgnoriert() {
        XCTAssertTrue(GymOeffnung.warnungen(halle, wochentage: [0, 8], start: 5 * 60, dauer: 45).isEmpty)
    }

    func testNurWerktageBekanntLaesstDasWochenendeOffen() {
        let nurWerktage = StudioOeffnung(werktage: .init(von: 8 * 60, bis: 22 * 60))
        XCTAssertTrue(GymOeffnung.istOffen(nurWerktage, wochentag: 6, minute: 3 * 60))
        XCTAssertFalse(GymOeffnung.istOffen(nurWerktage, wochentag: 2, minute: 3 * 60))
    }

    // MARK: Hinweis beim Einchecken (Idee 29)

    /// Mittwoch 23.09.2026 um `stunde` Uhr Berlin.
    private func mittwoch(_ stunde: Double) -> Date { Datum.datum("2026-09-23").addingTimeInterval(stunde * 3600) }

    func testHinweisAusserhalbDerOeffnungszeiten() {
        XCTAssertEqual(GymOeffnung.hinweis(halle, jetzt: mittwoch(5)), "Das Studio öffnet erst um 08:00.")
        XCTAssertEqual(GymOeffnung.hinweis(halle, jetzt: mittwoch(23)), "Das Studio hat seit 22:00 zu.")
        XCTAssertNil(GymOeffnung.hinweis(halle, jetzt: mittwoch(12)))
        XCTAssertNil(GymOeffnung.hinweis(rund, jetzt: mittwoch(3)))
        XCTAssertNil(GymOeffnung.hinweis(.unbekannt, jetzt: mittwoch(3)))
    }

    func testKurztext() {
        XCTAssertEqual(GymOeffnung.kurztext(rund), "24/7 geöffnet")
        XCTAssertEqual(GymOeffnung.kurztext(halle), "Mo–Fr 08:00–22:00, Sa/So 09:00–18:00")
        XCTAssertEqual(GymOeffnung.kurztext(.unbekannt), "Zeiten unbekannt")
    }

    func testFensterAusText() {
        XCTAssertEqual(StudioOeffnung.fenster(text: "08:00-22:00"), .init(von: 480, bis: 1320))
        XCTAssertEqual(StudioOeffnung.fenster(text: " 9:30 - 18:00 "), .init(von: 570, bis: 1080))
        XCTAssertNil(StudioOeffnung.fenster(text: "22:00-08:00"))
        XCTAssertNil(StudioOeffnung.fenster(text: "kaputt"))
    }

    // MARK: Profil und Speicher

    func testProfilRundlaufUndAlteDateiOhneNeueFelder() throws {
        let p = StudioProfil(name: "Testhalle", slotStart: 5 * 60, dauer: 45, oeffnung: halle)
        XCTAssertEqual(try JSONDecoder().decode(StudioProfil.self, from: JSONEncoder().encode(p)), p)
        let alt = try JSONDecoder().decode(StudioProfil.self, from: Data("{}".utf8))
        XCTAssertEqual(alt, .standard)
        XCTAssertFalse(alt.hatStudio)
        XCTAssertEqual(alt.dauer, 45)
        XCTAssertTrue(StudioProfil(name: "  Testhalle ").hatStudio)
        XCTAssertEqual(StudioProfil(name: "  Testhalle ").anzeigeName, "Testhalle")
    }

    func testStoreBehaeltDieWahlNachNeustart() throws {
        let ordner = try tempOrdner()
        let a = StudioStore(ordner: ordner)
        XCTAssertEqual(a.profil, .standard)
        a.aendere { $0.name = "Teststudio"; $0.slotStart = 7 * 60; $0.oeffnung = rund }
        let b = StudioStore(ordner: ordner)
        XCTAssertEqual(b.profil.name, "Teststudio")
        XCTAssertEqual(b.profil.slotStart, 7 * 60)
        XCTAssertEqual(b.profil.oeffnung, rund)
    }

    func testStoreOhneOrdnerBleibtImSpeicher() {
        let s = StudioStore()
        s.profil = StudioProfil(name: "Nur im Speicher")
        XCTAssertEqual(s.profil.name, "Nur im Speicher")
    }

    // MARK: Vorgaben aus PrivateDaten.json

    private let privat = Data("""
    {"version": 1, "personen": [
      {"id": "p1", "name": "Beispiel Person", "orte": [
        {"name": "Testhalle", "art": "gym", "adresse": "Musterstraße 1", "breite": 1, "laenge": 2,
         "oeffnung": {"werktage": "08:00-22:00", "wochenende": "09:00-18:00"}},
        {"name": "Teststudio", "art": "gym", "oeffnung": {"rund": true}},
        {"name": "Testbüro", "art": "arbeit"}]},
      {"id": "p2", "name": "Andere Person", "orte": [{"name": "Fremdstudio", "art": "gym"}]}]}
    """.utf8)

    func testVorgabenNurFuerDenPassendenProfilnamenUndNurGyms() {
        let v = StudioVorgaben.vorschlaege(daten: privat, profilName: "beispiel person")
        XCTAssertEqual(v.map(\.name), ["Testhalle", "Teststudio"])
        XCTAssertEqual(v[0].oeffnung, halle)
        XCTAssertEqual(v[1].oeffnung, rund)
        XCTAssertEqual(StudioVorgaben.vorschlaege(daten: privat, profilName: "Andere Person").map(\.name), ["Fremdstudio"])
        XCTAssertEqual(StudioVorgaben.vorschlaege(daten: privat, profilName: "p1").count, 2, "auch über die Kennung")
    }

    func testVorgabenOhneTrefferOderMitKaputterDateiSindLeer() {
        XCTAssertTrue(StudioVorgaben.vorschlaege(daten: privat, profilName: "Jemand").isEmpty)
        XCTAssertTrue(StudioVorgaben.vorschlaege(daten: privat, profilName: "  ").isEmpty)
        XCTAssertTrue(StudioVorgaben.vorschlaege(daten: Data("kaputt".utf8), profilName: "Beispiel Person").isEmpty)
        XCTAssertTrue(StudioVorgaben.vorschlaege(daten: Data("{}".utf8), profilName: "Beispiel Person").isEmpty)
    }

    // MARK: Besuche

    func testBesucheZaehlenWocheMonatGesamtUndSerie() {
        func einheit(_ tag: String) -> GymSession {
            GymSession(id: tag, tag: nil, start: Datum.datum(tag).addingTimeInterval(18 * 3600), ende: nil, laeufe: [])
        }
        let liste = [einheit("2026-09-22"), einheit("2026-09-08"), einheit("2026-08-30")]
        let z = StudioBesuche.zaehlen(liste, heute: "2026-09-23")
        XCTAssertEqual(z.dieseWoche, 1)
        XCTAssertEqual(z.diesenMonat, 2)
        XCTAssertEqual(z.gesamt, 3)
        XCTAssertEqual(z.serieWochen, 1) // Woche ab 21.09. hat einen Besuch, die davor keinen
        XCTAssertEqual(StudioBesuche.wochenText(z), "1 Besuch diese Woche")
        XCTAssertEqual(StudioBesuche.wochenText(StudioBesuche.zaehlen([], heute: "2026-09-23")), "0 Besuche diese Woche")
    }
}
