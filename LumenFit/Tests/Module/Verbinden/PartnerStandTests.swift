import XCTest
@testable import LumenFit

/// Der Partner-Stand über der Brücke (Idee 81, 82): nicht verbunden heißt nichts sichtbar und keine Fehlermeldung, je Fall. Den Leser selbst
/// (`LoveaBruecke`) testet das Grundgerüst; hier die Regeln darüber: Schalter, `VerbindungStore`, Quelle A mit den Fixtures dieses Moduls.
@MainActor
final class PartnerStandTests: XCTestCase {
    private let jetzt = VerbindenTest.jetzt

    private func store(_ gruppe: URL?, schalter: Bool) -> VerbindungStore {
        let einstellungen = EinstellungenStore()
        einstellungen.aendere { $0.loveaVerbunden = schalter }
        return VerbindungStore(ordner: nil, bruecke: LoveaBruecke(ordner: gruppe), einstellungen: einstellungen)
    }

    // MARK: Nicht verbunden: je Fall nichts sichtbar

    func testKeineDateiIstNichtVerbunden() throws {
        let s = store(try VerbindenTest.gruppe(self), schalter: true)
        s.aktualisiere(jetzt: jetzt)
        XCTAssertEqual(s.partner, .nichtVerbunden)
        XCTAssertFalse(s.verbunden)
    }

    func testOhneGruppeNilOhneSignierungIstNichtVerbunden() {
        let s = store(nil, schalter: true)
        s.aktualisiere(jetzt: jetzt)
        XCTAssertEqual(s.partner, .nichtVerbunden)
    }

    func testSchalterAusIstNichtVerbundenAuchMitFrischerDatei() throws {
        let s = store(try VerbindenTest.gruppe(self, partner: "partner-beispiel.json"), schalter: false)
        s.aktualisiere(jetzt: jetzt)
        XCTAssertEqual(s.partner, .nichtVerbunden)
        XCTAssertFalse(s.verbunden)
    }

    func testVeralteteDateiIstNichtVerbundenUndKeinePartnerAnzeige() throws {
        let s = store(try VerbindenTest.gruppe(self, partner: "partner-veraltet.json"), schalter: true)
        s.aktualisiere(jetzt: jetzt)
        guard case .veraltet = s.partner else { return XCTFail("veraltet erwartet") }
        XCTAssertFalse(s.verbunden)
        XCTAssertNil(PartnerAnzeige.zusammenfassung(s.partner), "veraltet zeigt nichts")
    }

    func testFalscheVersionIstNichtVerbundenUndZeigtNichts() throws {
        let s = store(try VerbindenTest.gruppe(self, partner: "partner-version-2.json"), schalter: true)
        s.aktualisiere(jetzt: jetzt)
        XCTAssertEqual(s.partner, .unbekannteVersion)
        XCTAssertFalse(s.verbunden)
        XCTAssertNil(PartnerAnzeige.zusammenfassung(s.partner))
    }

    func testKaputteDateiIstNichtVerbunden() throws {
        let gruppe = try VerbindenTest.gruppe(self)
        try Data("{kein json".utf8).write(to: gruppe.appendingPathComponent(LoveaVertrag.ordnerName).appendingPathComponent(LoveaVertrag.partnerDatei))
        let s = store(gruppe, schalter: true)
        s.aktualisiere(jetzt: jetzt)
        XCTAssertEqual(s.partner, .nichtVerbunden)
    }

    // MARK: Verbunden

    func testVertragBFrischIstVerbunden() throws {
        let s = store(try VerbindenTest.gruppe(self, partner: "partner-beispiel.json"), schalter: true)
        s.aktualisiere(jetzt: jetzt)
        XCTAssertTrue(s.verbunden)
        XCTAssertEqual(PartnerAnzeige.zusammenfassung(s.partner)?.profilName, "Beispiel Partner")
    }

    func testQuelleAMitFixtureZeigtSchritteGymSchlafAberNichtsAnderes() throws {
        let s = store(try VerbindenTest.gruppe(self, widgetStand: true), schalter: true)
        s.aktualisiere(jetzt: jetzt)
        guard case .verbunden(let datei) = s.partner else { return XCTFail("verbunden erwartet") }
        XCTAssertEqual(datei.heute.schritte, 10_450)
        XCTAssertEqual(datei.heute.gymTageWoche, 2)
        XCTAssertEqual(datei.heute.schlafMinuten, 440)
        XCTAssertNil(datei.heute.kcal)
        XCTAssertEqual(datei.profilName, "Kennung-b", "die andere Kennung, nie der eigenePerson-Wert")
        let text = String(decoding: try JSONEncoder().encode(datei), as: UTF8.self).lowercased()
        for fremd in ["ort,", "wetter", "akku", "status", "herzen", "punkte"] { XCTAssertFalse(text.contains(fremd), fremd) }
    }

    func testAlteQuelleANachDerFristIstNichtVerbunden() throws {
        let alt = jetzt.addingTimeInterval(-LoveaVertrag.frist - 3600)
        let s = store(try VerbindenTest.gruppe(self, widgetStand: true, geaendert: alt), schalter: true)
        s.aktualisiere(jetzt: jetzt)
        XCTAssertFalse(s.verbunden)
    }

    func testSchalterAnUndAusWechseltDenStand() throws {
        let einstellungen = EinstellungenStore()
        let s = VerbindungStore(ordner: nil, bruecke: LoveaBruecke(ordner: try VerbindenTest.gruppe(self, partner: "partner-beispiel.json")), einstellungen: einstellungen)
        einstellungen.aendere { $0.loveaVerbunden = true }
        s.aktualisiere(jetzt: jetzt)
        XCTAssertTrue(s.verbunden)
        einstellungen.aendere { $0.loveaVerbunden = false }
        s.aktualisiere(jetzt: jetzt)
        XCTAssertFalse(s.verbunden)
    }

    // MARK: Anzeige

    func testAnzeigeZeigtNurFreigegebeneFelderDesPartners() throws {
        let s = store(try VerbindenTest.gruppe(self, partner: "partner-beispiel.json"), schalter: true)
        s.aktualisiere(jetzt: jetzt)
        let heute = try XCTUnwrap(PartnerAnzeige.zusammenfassung(s.partner))
        XCTAssertEqual(PartnerAnzeige.zeilen(heute, bereich: .heute).map(\.titel), ["Schritte", "Gym diese Woche", "Essen"])
        XCTAssertEqual(PartnerAnzeige.zeilen(heute, bereich: .schlaf).map(\.titel), ["Schlaf"])
        var nurSchritte = heute
        nurSchritte.freigaben = [.schritte]
        nurSchritte.heute = TagesZusammenfassung(tag: heute.heute.tag, schritte: 100, gymTageWoche: 5, schlafMinuten: 400)
        XCTAssertEqual(PartnerAnzeige.zeilen(nurSchritte, bereich: .heute).map(\.titel), ["Schritte"], "Gym ist nicht freigegeben, auch wenn der Wert in der Datei steht")
        XCTAssertTrue(PartnerAnzeige.zeilen(nurSchritte, bereich: .schlaf).isEmpty)
    }

    func testAnzeigeOhneFreigabeIstLeer() {
        let datei = ZusammenfassungDatei(version: 1, geschrieben: jetzt, profilName: "Beispiel Partner", freigaben: [],
                                         heute: TagesZusammenfassung(tag: "2026-10-29", schritte: 5), ereignisse: [])
        XCTAssertTrue(PartnerAnzeige.zeilen(datei, bereich: .heute).isEmpty)
    }

    func testAnzeigeTexte() {
        XCTAssertEqual(PartnerAnzeige.schlafText(455), "7 h 35 min")
        XCTAssertEqual(PartnerAnzeige.schlafText(480), "8 h")
        XCTAssertEqual(PartnerAnzeige.schlafText(45), "45 min")
    }
}
