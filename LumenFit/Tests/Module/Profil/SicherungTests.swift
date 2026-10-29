import XCTest
@testable import LumenFit

@MainActor
final class SicherungTests: XCTestCase {
    private func fixture() throws -> ProfilSicherung {
        try ProfilSicherung.lies(FixtureOrt.daten("Profil", "sicherung-beispiel.json"))
    }

    func testRoundtripBleibtGleich() throws {
        let (_, quelle) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        quelle.einstellungen.aendere { $0.thema = .stahl }
        quelle.ziele.setze({ var z = Ziele(); z.schritte = 8_500; return z }())
        let sicherung = ProfilSicherungLogik.erzeuge(aus: quelle, jetzt: TestUhr().lesen)
        XCTAssertEqual(sicherung.version, ProfilSicherung.aktuelleVersion)
        XCTAssertEqual(sicherung.ops.count, 5 + 1 + 2, "eine Einheit (5), ein Frühstück, Wasser und Gym-Haken")

        let gelesen = try ProfilSicherung.lies(sicherung.daten())
        XCTAssertEqual(gelesen.ops.map(\.id), sicherung.ops.map(\.id))
        XCTAssertEqual(gelesen.ops.map(\.art), sicherung.ops.map(\.art))
        XCTAssertEqual(gelesen.einstellungen.thema, .stahl)
        XCTAssertEqual(gelesen.ziele.schritte, 8_500)
        XCTAssertEqual(gelesen.erstellt.timeIntervalSince1970, sicherung.erstellt.timeIntervalSince1970, accuracy: 1)
    }

    func testRoundtripInEinNeuesProfil() throws {
        let (_, quelle) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        let sicherung = try ProfilSicherung.lies(ProfilSicherungLogik.erzeuge(aus: quelle, jetzt: TestUhr().lesen).daten())

        let neu = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try neu.profil.anlegen(name: "Ziel", passwort: "efgh")
        let ziel = try XCTUnwrap(neu.daten)
        let ergebnis = ProfilSicherungLogik.spieleEin(sicherung, in: ziel)
        XCTAssertEqual(ergebnis, ProfilSicherungErgebnis(neu: sicherung.ops.count, uebersprungen: 0))
        XCTAssertEqual(ziel.training.sessions.count, 1)
        XCTAssertEqual(ziel.essen.eintraege("2026-09-23").count, 1)
    }

    func testDieSicherungHatKeinePasswortSpurUndKeinenNamen() throws {
        let (_, quelle) = try ProfilTestWelt.gefuellt(ordner: tempOrdner(), name: "Geheimname")
        let text = String(decoding: try ProfilSicherungLogik.erzeuge(aus: quelle, jetzt: TestUhr().lesen).daten(), as: UTF8.self)
        for spur in ["salz", "hash", "runden", "passwort", "Passwort", "Geheimname"] {
            XCTAssertFalse(text.contains(spur), "in der Sicherung steht \(spur)")
        }
    }

    func testVersionWirdGeprueft() throws {
        XCTAssertThrowsError(try ProfilSicherung.lies(Data(#"{"version": 2, "erstellt": 0}"#.utf8))) {
            XCTAssertEqual($0 as? ProfilSicherungFehler, .zuNeu(2))
        }
        XCTAssertThrowsError(try ProfilSicherung.lies(Data(#"{"version": 0, "erstellt": 0}"#.utf8))) {
            XCTAssertEqual($0 as? ProfilSicherungFehler, .keineSicherung)
        }
        XCTAssertThrowsError(try ProfilSicherung.lies(Data("hallo".utf8))) { XCTAssertEqual($0 as? ProfilSicherungFehler, .keineSicherung) }
        XCTAssertThrowsError(try ProfilSicherung.lies(Data(#"{"version": 1}"#.utf8))) { XCTAssertEqual($0 as? ProfilSicherungFehler, .keineSicherung) }
        let leer = try ProfilSicherung.lies(Data(#"{"version": 1, "erstellt": 0}"#.utf8))
        XCTAssertTrue(leer.ops.isEmpty, "alle anderen Felder sind optional")
        XCTAssertFalse(ProfilSicherungFehler.zuNeu(2).text.isEmpty)
    }

    func testEinspielenIstIdempotent() throws {
        let sicherung = try fixture()
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)

        let erstes = ProfilSicherungLogik.spieleEin(sicherung, in: daten)
        XCTAssertEqual(erstes.neu, 6)
        let zweites = ProfilSicherungLogik.spieleEin(sicherung, in: daten)
        XCTAssertEqual(zweites, ProfilSicherungErgebnis(neu: 0, uebersprungen: 6))
        XCTAssertEqual(ProfilSicherungLogik.alleOps(daten).count, 6, "nichts doppelt im Log")
        XCTAssertEqual(daten.training.sessions.count, 1)
    }

    func testFremdeProfilId() throws {
        let sicherung = try fixture()
        XCTAssertTrue(sicherung.ops.allSatisfy { $0.von.rawValue == "fixture-geraet-a" })

        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let profil = try u.profil.anlegen(name: "Anderes Gerät", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)
        XCTAssertNotEqual(profil.id.rawValue, "fixture-geraet-a")
        ProfilSicherungLogik.spieleEin(sicherung, in: daten)

        let ops = ProfilSicherungLogik.alleOps(daten)
        XCTAssertTrue(ops.allSatisfy { $0.von == profil.id }, "von ist auf das Zielprofil umgeschrieben")
        XCTAssertEqual(daten.training.sessions.count, 1, "die Einheit ist für das neue Profil sichtbar")
        XCTAssertEqual(daten.essen.eintraege("2026-09-20").map(\.id), ["fx-essen-hafer"])
        XCTAssertEqual(daten.habits.wert("wasser", "2026-09-20"), 6)

        // Der Log überlebt einen Neustart: ein frischer Datensatz im selben Ordner sieht dieselben Einträge.
        let neuGeladen = DatenSatz(profil: profil.id, ordner: daten.ordner, ereignisse: u.ereignisse, uhr: u.uhr)
        XCTAssertEqual(neuGeladen.training.sessions.count, 1)
    }

    func testDoppelteIdsInDerDateiWerdenUebersprungen() throws {
        var sicherung = try fixture()
        sicherung.ops.append(sicherung.ops[0])
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)
        let ergebnis = ProfilSicherungLogik.spieleEin(sicherung, in: daten)
        XCTAssertEqual(ergebnis, ProfilSicherungErgebnis(neu: 6, uebersprungen: 1))
    }

    func testKleineDateienKommenMitGeraeteSchalterBleibenAus() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)
        ProfilSicherungLogik.spieleEin(try fixture(), in: daten)

        let e = daten.einstellungen.werte
        XCTAssertEqual(e.thema, .wald)
        XCTAssertEqual(e.erscheinung, .dunkel)
        XCTAssertFalse(e.bandAktiv, "das Band hängt am Gerät")
        XCTAssertFalse(e.loveaVerbunden)
        XCTAssertFalse(e.healthSchreiben)
        XCTAssertFalse(e.healthGefragt, "auf dem neuen Gerät muss Health neu gefragt werden")
        XCTAssertEqual(daten.ziele.ziele.schritte, 9_000)
        XCTAssertEqual(daten.ziele.ziele.art, .aufbauen)
        XCTAssertEqual(daten.ziele.koerper.groesseCm, 178)
        XCTAssertTrue(daten.essen.ernaehrungsZiele.eingerichtet)
        XCTAssertEqual(daten.essen.ernaehrungsZiele.kcal, 2_300)
        XCTAssertEqual(daten.verbindung.freigaben, [.schritte, .gym])
    }

    func testEigeneEinstellungenWerdenNichtUeberschrieben() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        try u.profil.anlegen(name: "Ziel", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)
        daten.einstellungen.aendere { $0.thema = .glut }
        ProfilSicherungLogik.spieleEin(try fixture(), in: daten)
        XCTAssertEqual(daten.einstellungen.werte.thema, .glut)
    }

    func testNeuereWahlImProfilBleibtSieger() throws {
        let u = ProfilTestWelt.umgebung(ordner: try tempOrdner())
        let profil = try u.profil.anlegen(name: "Ziel", passwort: "abcd")
        let daten = try XCTUnwrap(u.daten)
        let jetzt = TestUhr().lesen
        let wahl = ProfilEinstellungD(schluessel: "ziel.prio.beine", wert: .number(1))
        daten.raum.einreihen(TestDaten.op("einstellung.setzen", wahl, von: profil.id, zeit: jetzt, id: "neu-im-profil"))

        let aelter = TestDaten.op("einstellung.setzen", ProfilEinstellungD(schluessel: "ziel.prio.beine", wert: .number(3)),
                                  von: ProfilID(rawValue: "fremd"), zeit: jetzt.addingTimeInterval(-3_600), id: "alt-aus-sicherung")
        let juenger = TestDaten.op("einstellung.setzen", ProfilEinstellungD(schluessel: "ziel.prio.bauch", wert: .number(2)),
                                   von: ProfilID(rawValue: "fremd"), zeit: jetzt.addingTimeInterval(3_600), id: "neuer-aus-sicherung")
        let sicherung = ProfilSicherung(erstellt: jetzt, ops: [aelter, juenger], einstellungen: Einstellungen(), ziele: Ziele())
        let ergebnis = ProfilSicherungLogik.spieleEin(sicherung, in: daten)
        XCTAssertEqual(ergebnis, ProfilSicherungErgebnis(neu: 1, uebersprungen: 1))
        XCTAssertEqual(ProfilSicherungLogik.alleOps(daten).map(\.id).sorted(), ["neu-im-profil", "neuer-aus-sicherung"])
    }

    func testDateiUndStandZeile() throws {
        XCTAssertEqual(ProfilSicherung.dateiname(jetzt: TestUhr().lesen), "lumenfit-sicherung-2026-09-23.json")
        let jetzt = TestUhr().lesen
        XCTAssertEqual(ProfilSicherungStand.zeile(zuletzt: nil, jetzt: jetzt), "Noch keine Sicherung")
        XCTAssertEqual(ProfilSicherungStand.zeile(zuletzt: jetzt, jetzt: jetzt), "Letzte Sicherung: heute")
        XCTAssertEqual(ProfilSicherungStand.zeile(zuletzt: jetzt.addingTimeInterval(-86_400), jetzt: jetzt), "Letzte Sicherung: gestern")
        XCTAssertEqual(ProfilSicherungStand.zeile(zuletzt: jetzt.addingTimeInterval(-12 * 86_400), jetzt: jetzt), "Letzte Sicherung: vor 12 Tagen")
    }

    func testDateiSchreibenMerktDenZeitpunkt() throws {
        let (_, quelle) = try ProfilTestWelt.gefuellt(ordner: tempOrdner())
        XCTAssertNil(ProfilSicherungStand.lade(quelle.ordner))
        let jetzt = TestUhr().lesen
        let url = try ProfilSicherungLogik.schreibeDatei(aus: quelle, jetzt: jetzt)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.lastPathComponent, "lumenfit-sicherung-2026-09-23.json")
        XCTAssertEqual(try ProfilSicherung.lies(Data(contentsOf: url)).ops.count, 8)
        XCTAssertEqual(try XCTUnwrap(ProfilSicherungStand.lade(quelle.ordner)).timeIntervalSince1970, jetzt.timeIntervalSince1970, accuracy: 1)
    }
}
