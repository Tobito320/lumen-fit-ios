// Quelle: Lovea Tests/GymTageLogikTests.swift
import XCTest
@testable import LumenFit

/// Gym-Tage ohne Einheit (`GymTageLogik`): reine Logik, ohne Oberfläche.
final class GymTageLogikTests: XCTestCase {
    private func einheit(_ id: String, am tag: String, uhr: Double = 18, ende: Date? = nil, laeufe: [UebungsLauf] = []) -> GymSession {
        GymSession(id: id, tag: nil, start: Datum.datum(tag).addingTimeInterval(uhr * 3600), ende: ende, laeufe: laeufe)
    }

    private func lauf(fertig: Bool = false, stand: [PlanSatz]? = nil) -> UebungsLauf {
        UebungsLauf(plan: "p", uebung: "x", start: nil, ende: nil, fertig: fertig, saetze: nil, stand: stand)
    }

    private func satz(ok: Bool?) -> PlanSatz {
        var s = PlanSatz(wdh: 8, kg: 40, failure: false)
        s.ok = ok
        return s
    }

    // MARK: - Tage nur mit Häkchen

    func testTageMitHaekchenOhneEinheitSindNurAbgehakt() {
        let sessions = [einheit("a", am: "2026-10-06")]
        let gym = ["2026-10-06": 1, "2026-10-07": 1, "2026-10-08": 0]
        XCTAssertEqual(GymTageLogik.nurAbgehakt(sessions: sessions, gym: gym), ["2026-10-07"])
    }

    func testOhneHaekchenGibtEsKeineNurAbgehaktenTage() {
        XCTAssertTrue(GymTageLogik.nurAbgehakt(sessions: [einheit("a", am: "2026-10-06")], gym: [:]).isEmpty)
    }

    // MARK: - Hat die Einheit Daten

    func testEinheitOhneUebungenHatKeineDaten() {
        XCTAssertFalse(GymTageLogik.hatDaten(einheit("a", am: "2026-10-06")))
    }

    func testEinheitMitOffenenSaetzenHatKeineDaten() {
        let s = einheit("a", am: "2026-10-06", laeufe: [lauf(stand: [satz(ok: nil), satz(ok: false)])])
        XCTAssertFalse(GymTageLogik.hatDaten(s))
    }

    func testEinheitMitAbgehaktemSatzHatDaten() {
        let s = einheit("a", am: "2026-10-06", laeufe: [lauf(stand: [satz(ok: true), satz(ok: nil)])])
        XCTAssertTrue(GymTageLogik.hatDaten(s))
    }

    func testFertigeUebungOhneSatzstandHatDaten() {
        XCTAssertTrue(GymTageLogik.hatDaten(einheit("a", am: "2026-10-06", laeufe: [lauf(fertig: true)])))
    }

    func testFertigeUebungOhneAbgehaktenSatzHatKeineDaten() {
        let s = einheit("a", am: "2026-10-06", laeufe: [lauf(fertig: true, stand: [satz(ok: nil), satz(ok: false)])])
        XCTAssertFalse(GymTageLogik.hatDaten(s))
    }

    // MARK: - Welche Einheit ein Tipp auf den Tag öffnet

    func testTagMitZweiEinheitenOeffnetDieMitDaten() {
        let leer = einheit("leer", am: "2026-10-06", uhr: 20)
        let voll = einheit("voll", am: "2026-10-06", uhr: 9, laeufe: [lauf(fertig: true)])
        XCTAssertEqual(GymTageLogik.einheit(am: "2026-10-06", in: [leer, voll])?.id, "voll")
    }

    func testTagOhneDatenOeffnetDieNeuesteEinheit() {
        let neu = einheit("neu", am: "2026-10-06", uhr: 20)
        let alt = einheit("alt", am: "2026-10-06", uhr: 9)
        XCTAssertEqual(GymTageLogik.einheit(am: "2026-10-06", in: [neu, alt])?.id, "neu")
    }

    func testTagOhneEinheitOeffnetNichts() {
        XCTAssertNil(GymTageLogik.einheit(am: "2026-10-07", in: [einheit("a", am: "2026-10-06")]))
    }

    // MARK: - Vorschlag zum Nachtragen

    func testVorschlagFuerVergangenenTagLiegtAmTagUndInDerVergangenheit() {
        let jetzt = Datum.datum("2026-10-11").addingTimeInterval(12 * 3600)
        let v = GymTageLogik.nachtragVorschlag(datum: "2026-10-06", jetzt: jetzt)
        XCTAssertEqual(Datum.text(v.start), "2026-10-06")
        XCTAssertEqual(v.ende.timeIntervalSince(v.start), 90 * 60)
        XCTAssertLessThanOrEqual(v.ende, jetzt)
    }

    func testVorschlagFuerHeuteEndetNichtInDerZukunft() {
        let jetzt = Datum.datum("2026-10-11").addingTimeInterval(15 * 3600)
        let v = GymTageLogik.nachtragVorschlag(datum: "2026-10-11", jetzt: jetzt)
        XCTAssertEqual(v.ende, jetzt)
        XCTAssertEqual(v.start, jetzt.addingTimeInterval(-90 * 60))
    }

    func testVorschlagNachMitternachtBleibtAmHeutigenTag() {
        let jetzt = Datum.datum("2026-10-11").addingTimeInterval(20 * 60)
        let v = GymTageLogik.nachtragVorschlag(datum: "2026-10-11", jetzt: jetzt)
        XCTAssertEqual(Datum.text(v.start), "2026-10-11")
        XCTAssertGreaterThan(v.ende, v.start)
        XCTAssertLessThanOrEqual(v.ende, jetzt)
    }

    // MARK: - Hinweis im Rückblick

    private let jetzt = Datum.datum("2026-10-11").addingTimeInterval(12 * 3600)

    func testRueckblickMitDatenHatKeinenLeerHinweis() {
        let s = einheit("a", am: "2026-10-06", ende: jetzt, laeufe: [lauf(fertig: true)])
        XCTAssertNil(GymTageLogik.leerHinweis(s, eigene: true, jetzt: jetzt))
    }

    func testLaufendeEinheitOhneSaetzeHatKeinenLeerHinweis() {
        let s = GymSession(id: "a", tag: nil, start: jetzt.addingTimeInterval(-600), ende: nil, laeufe: [])
        XCTAssertNil(GymTageLogik.leerHinweis(s, eigene: true, jetzt: jetzt))
    }

    func testBeendeteEigeneEinheitOhneSaetzeNenntNachtragen() throws {
        let s = einheit("a", am: "2026-10-06", ende: Datum.datum("2026-10-06").addingTimeInterval(19 * 3600))
        let text = try XCTUnwrap(GymTageLogik.leerHinweis(s, eigene: true, jetzt: jetzt))
        XCTAssertTrue(text.hasPrefix("Keine Sätze gespeichert."))
        XCTAssertTrue(text.contains("Übung hinzufügen"))
    }

    func testNichtAusgecheckteEigeneEinheitNenntZeiten() throws {
        let text = try XCTUnwrap(GymTageLogik.leerHinweis(einheit("a", am: "2026-10-06"), eigene: true, jetzt: jetzt))
        XCTAssertTrue(text.contains("Zeiten"))
    }

    func testEinheitDesPartnersOhneSaetzeSagtNurDasFehlen() {
        let s = einheit("a", am: "2026-10-06", ende: Datum.datum("2026-10-06").addingTimeInterval(19 * 3600))
        XCTAssertEqual(GymTageLogik.leerHinweis(s, eigene: false, jetzt: jetzt), "Keine Sätze gespeichert.")
    }
}
