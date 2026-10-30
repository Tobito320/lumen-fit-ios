// Quelle: Lovea Tests/KonsistenzKategorienTests.swift
import XCTest
@testable import LumenFit

// Konsistenz-Kategorien: Vorbelegung nach Plantag-Name, eigene Wahl, geteilte Zelle, Speichern.
final class KonsistenzKategorienTests: XCTestCase {
    private let e = KonsistenzEinstellung.standard

    private func session(_ tag: String, plan: String?, stunde: Double = 12) -> GymSession {
        GymSession(id: UUID().uuidString, tag: plan, start: Datum.datum(tag).addingTimeInterval(stunde * 3600), ende: nil, laeufe: [])
    }

    func testVorbelegungAusDemNamen() {
        let k = e.kategorien
        XCTAssertEqual(KonsistenzKategorienLogik.vorbelegt(name: "Unterkörper", in: k), "unterkoerper")
        XCTAssertEqual(KonsistenzKategorienLogik.vorbelegt(name: "Legs", in: k), "unterkoerper")
        XCTAssertEqual(KonsistenzKategorienLogik.vorbelegt(name: "Upper Body", in: k), "oberkoerper")
        XCTAssertEqual(KonsistenzKategorienLogik.vorbelegt(name: "Rücken & Bizeps", in: k), "ruecken")
        XCTAssertEqual(KonsistenzKategorienLogik.vorbelegt(name: "Push", in: k), "brust")
        XCTAssertEqual(KonsistenzKategorienLogik.vorbelegt(name: "Cardio", in: k), "cardio")
        XCTAssertNil(KonsistenzKategorienLogik.vorbelegt(name: "Mobility", in: k))
        XCTAssertNil(KonsistenzKategorienLogik.vorbelegt(name: nil, in: k))
    }

    func testGeloeschteKategorieWirdNichtVorbelegt() {
        var neu = e
        neu.kategorien.removeAll { $0.id == "cardio" }
        XCTAssertNil(KonsistenzKategorienLogik.vorbelegt(name: "Cardio", in: neu.kategorien))
    }

    func testEigeneWahlSchlaegtVorbelegungAuchKeine() {
        var neu = e
        neu.zuordnung["t1"] = "ruecken"
        neu.zuordnung["t2"] = ""
        XCTAssertEqual(KonsistenzKategorienLogik.kategorie(tagId: "t1", name: "Legs", einstellung: neu), "ruecken")
        XCTAssertNil(KonsistenzKategorienLogik.kategorie(tagId: "t2", name: "Legs", einstellung: neu))
        XCTAssertEqual(KonsistenzKategorienLogik.kategorie(tagId: "t3", name: "Legs", einstellung: neu), "unterkoerper")
    }

    func testFuellungen() {
        let namen = ["a": "Legs", "b": "Push", "c": "Pull", "x": "Mobility"]
        let f = KonsistenzKategorienLogik.fuellungen([
            session("2026-03-10", plan: "a"),
            session("2026-03-11", plan: "a", stunde: 8), session("2026-03-11", plan: "b", stunde: 19),
            session("2026-03-12", plan: "x"),
            session("2026-03-13", plan: nil),
            session("2026-03-14", plan: "a"), session("2026-03-14", plan: "a", stunde: 18),
            session("2026-03-15", plan: "a", stunde: 7), session("2026-03-15", plan: "b", stunde: 12), session("2026-03-15", plan: "c", stunde: 18),
        ], einstellung: e) { namen[$0 ?? ""] }
        XCTAssertEqual(f["2026-03-10"], .eine("unterkoerper"))
        XCTAssertEqual(f["2026-03-11"], .zwei("unterkoerper", "brust"))
        XCTAssertEqual(f["2026-03-12"], .neutral)
        XCTAssertEqual(f["2026-03-13"], .neutral)
        XCTAssertEqual(f["2026-03-14"], .eine("unterkoerper"))
        XCTAssertEqual(f["2026-03-15"], .zwei("unterkoerper", "brust"))
        XCTAssertNil(f["2026-03-16"])
    }

    func testNeueKategorieNimmtFreieFarbe() {
        let k = KonsistenzKategorienLogik.neu(in: e)
        XCTAssertFalse(e.kategorien.map(\.farbe).contains(k.farbe))
    }

    func testSpeichernRundreise() {
        var neu = e
        neu.kategorien.append(KonsistenzKategorie(id: "k", name: "Yoga", farbe: "112233"))
        neu.zuordnung["t1"] = "k"
        XCTAssertEqual(KonsistenzKategorienLogik.lesen(KonsistenzKategorienLogik.text(neu)), neu)
        XCTAssertEqual(KonsistenzKategorienLogik.lesen(""), .standard)
        XCTAssertEqual(KonsistenzKategorienLogik.lesen("kaputt"), .standard)
    }
}

/// Die Kategorien im Profilordner: tolerantes Lesen, Sichern, Farben, Namen bereinigen.
final class KonsistenzKategorienDateiTests: XCTestCase {
    func testOhneDateiGeltenDieStandardKategorien() throws {
        XCTAssertEqual(KonsistenzKategorienDatei.lesen(try tempOrdner()), .standard)
        XCTAssertEqual(KonsistenzKategorienDatei.lesen(nil), .standard)
    }

    func testSichernUndLesenBringtDasGleicheZurueck() throws {
        let ordner = try tempOrdner()
        var e = KonsistenzEinstellung.standard
        e.kategorien.append(KonsistenzKategorie(id: "x", name: "Mobility", farbe: "112233"))
        e.zuordnung["plan1"] = "x"
        KonsistenzKategorienDatei.sichern(e, in: ordner)
        XCTAssertEqual(KonsistenzKategorienDatei.lesen(ordner), e)
    }

    func testEineDateiOhneZuordnungUndEineLeereDateiSindLesbar() throws {
        let ordner = try tempOrdner()
        try Data(#"{"kategorien":[{"id":"a","name":"Beine","farbe":"34C3A0"}]}"#.utf8).write(to: ordner.appendingPathComponent("konsistenz.json"))
        let e = KonsistenzKategorienDatei.lesen(ordner)
        XCTAssertEqual(e.kategorien.map(\.name), ["Beine"])
        XCTAssertEqual(e.zuordnung, [:])
        try Data("{}".utf8).write(to: ordner.appendingPathComponent("konsistenz.json"))
        XCTAssertEqual(KonsistenzKategorienDatei.lesen(ordner).kategorien, KonsistenzKategorienLogik.standardKategorien)
    }

    func testBereinigtLoeschtLeereNamenUndKuerztDenRand() {
        var e = KonsistenzEinstellung.standard
        e.kategorien = [KonsistenzKategorie(id: "a", name: "  Beine ", farbe: "34C3A0"), KonsistenzKategorie(id: "b", name: "   ", farbe: "34C3A0")]
        XCTAssertEqual(KonsistenzKategorienDatei.bereinigt(e).kategorien.map(\.name), ["Beine"])
    }

    func testFarbeHexRunde() throws {
        let k = try XCTUnwrap(KonsistenzFarbe.kanaele(hex: "F0609E"))
        XCTAssertEqual(KonsistenzFarbe.hex(r: k.r, g: k.g, b: k.b), "F0609E")
        XCTAssertNil(KonsistenzFarbe.kanaele(hex: "XYZ"))
        XCTAssertEqual(KonsistenzFarbe.hex(r: 2, g: -1, b: 0.5), "FF0080")
    }
}
