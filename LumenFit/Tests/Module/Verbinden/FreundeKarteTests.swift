import XCTest
@testable import LumenFit

/// Freundeskarte (Idee 89, 90): Roundtrip, Prüfsumme, manipulierte Nutzlast, Link, Rangliste mit Respekt. Keine Namen Dritter: alle Namen sind erfunden.
final class FreundeKarteTests: XCTestCase {
    private let absender = FreundeKarteCodec.absender(ProfilID(rawValue: "profil-eins"))

    private func karte(name: String = "Beispiel Freund", woche: String = "2026-10-26", schritte: Int = 42_000, gym: Int = 3, schlaf: Int? = 430) -> FreundKarte {
        FreundKarte(id: "x", name: name, woche: woche, schritte: schritte, gymTage: gym, schlafSchnittMinuten: schlaf,
                    erstellt: Date(timeIntervalSince1970: 1_793_250_000), respekt: true)
    }

    private func lies(_ text: String) throws -> FreundKarte { try XCTUnwrap(try? FreundeKarteCodec.lies(text).get()) }

    // MARK: Roundtrip

    func testRoundtripErzeugenUndLesen() throws {
        let text = FreundeKarteCodec.kodiere(karte(), absender: absender)
        let gelesen = try lies(text)
        XCTAssertEqual(gelesen.name, "Beispiel Freund")
        XCTAssertEqual(gelesen.woche, "2026-10-26")
        XCTAssertEqual(gelesen.schritte, 42_000)
        XCTAssertEqual(gelesen.gymTage, 3)
        XCTAssertEqual(gelesen.schlafSchnittMinuten, 430)
        XCTAssertEqual(gelesen.erstellt, Date(timeIntervalSince1970: 1_793_250_000))
        XCTAssertEqual(gelesen.id, "\(absender)-2026-10-26")
        XCTAssertFalse(gelesen.respekt, "der Respekt gehört dem Empfänger und reist nie mit")
    }

    func testRoundtripOhneSchlaf() throws {
        XCTAssertNil(try lies(FreundeKarteCodec.kodiere(karte(schlaf: nil), absender: absender)).schlafSchnittMinuten)
    }

    func testLinkTraegtDieNutzlastUndLaesstSichOeffnen() throws {
        let url = FreundeKarteCodec.link(karte(), absender: absender)
        XCTAssertEqual(url.scheme, "lumenfit")
        XCTAssertEqual(url.host, "freund")
        guard case .freund(let daten?)? = RouteURL.route(aus: url) else { return XCTFail("Route freund mit Nutzlast erwartet") }
        XCTAssertEqual(try lies(daten).schritte, 42_000)
        XCTAssertEqual(try lies(url.absoluteString).schritte, 42_000, "auch der ganze Link wird gelesen")
    }

    func testAbsenderIstHashUndNieDerProfilname() {
        XCTAssertEqual(absender.count, 16)
        XCTAssertFalse(absender.contains("profil"))
        XCTAssertEqual(absender, FreundeKarteCodec.absender(ProfilID(rawValue: "profil-eins")), "stabil")
        XCTAssertNotEqual(absender, FreundeKarteCodec.absender(ProfilID(rawValue: "profil-zwei")))
    }

    // MARK: Ablehnen

    func testManipulierteNutzlastWirdAbgelehnt() {
        let text = FreundeKarteCodec.kodiere(karte(), absender: absender)
        var zeichen = Array(text)
        zeichen[10] = zeichen[10] == "A" ? "B" : "A"
        XCTAssertEqual(FreundeKarteCodec.lies(String(zeichen)), .failure(.pruefsumme))
    }

    func testAnderePruefsummeWirdAbgelehnt() {
        let text = FreundeKarteCodec.kodiere(karte(), absender: absender)
        let teil = String(text.split(separator: ".")[0])
        XCTAssertEqual(FreundeKarteCodec.lies(teil + ".0000000000000000"), .failure(.pruefsumme))
        XCTAssertEqual(FreundeKarteCodec.lies(teil + ".zz"), .failure(.pruefsumme))
    }

    func testAbgeschnittenerOderLeererTextWirdAbgelehnt() {
        let text = FreundeKarteCodec.kodiere(karte(), absender: absender)
        XCTAssertEqual(FreundeKarteCodec.lies(String(text.dropLast(5))), .failure(.pruefsumme))
        XCTAssertEqual(FreundeKarteCodec.lies(""), .failure(.leer))
        XCTAssertEqual(FreundeKarteCodec.lies("   "), .failure(.leer))
        XCTAssertEqual(FreundeKarteCodec.lies("kein-punkt-und-keine-karte"), .failure(.format))
    }

    func testUnplausibleWerteWerdenAbgelehnt() {
        func abgelehnt(_ k: FreundKarte, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(FreundeKarteCodec.lies(FreundeKarteCodec.kodiere(k, absender: absender)), .failure(.werte), file: file, line: line)
        }
        abgelehnt(karte(schritte: 9_000_000))
        abgelehnt(karte(schritte: -1))
        abgelehnt(karte(gym: 9))
        abgelehnt(karte(schlaf: 3_000))
        abgelehnt(karte(woche: "2026-10-27"))   // Dienstag, keine Woche
        abgelehnt(karte(woche: "kaputt"))
        abgelehnt(karte(name: "   "))
    }

    func testNameWirdBereinigtUndGekuerzt() throws {
        let lang = String(repeating: "A", count: 60)
        XCTAssertEqual(try lies(FreundeKarteCodec.kodiere(karte(name: lang), absender: absender)).name.count, 24)
        XCTAssertEqual(FreundeKarteCodec.bereinigt("  Mia\n\t"), "Mia")
    }

    func testQuelltextEnthaeltKeineNamenDritter() throws {
        // Das Namens-Gate (scripts/namen-gate.sh) prüft den ganzen Baum; hier nur: die Karte selbst trägt nur, was der Absender eingibt.
        let text = FreundeKarteCodec.kodiere(karte(name: "Beispiel Freund"), absender: absender)
        XCTAssertFalse(text.contains("Beispiel"), "der Name steht nur base64-kodiert in der Nutzlast")
    }

    // MARK: Eigene Karte und Rangliste

    func testEigeneKarteSummiertDieWoche() {
        let jetzt = Datum.datum("2026-10-29").addingTimeInterval(10 * 3600) // Donnerstag
        let k = FreundeRangliste.eigene(name: "Beispiel Profil", absender: absender, jetzt: jetzt,
                                        schritteJeTag: ["2026-10-25": 99_999, "2026-10-26": 8_000, "2026-10-27": 9_000, "2026-10-29": 4_000],
                                        gymTage: 2, schlafMinutenJeTag: ["2026-10-27": 420, "2026-10-28": 480, "2026-10-29": 0])
        XCTAssertEqual(k.woche, "2026-10-26")
        XCTAssertEqual(k.schritte, 21_000, "Sonntag davor zählt nicht")
        XCTAssertEqual(k.gymTage, 2)
        XCTAssertEqual(k.schlafSchnittMinuten, 450)
        XCTAssertEqual(k.id, "\(absender)-2026-10-26")
    }

    func testRanglisteNachSchrittenDannGymTagenMitGleichstand() {
        func k(_ n: String, _ s: Int, _ g: Int, _ w: String = "2026-10-26") -> FreundKarte {
            FreundKarte(id: n, name: n, woche: w, schritte: s, gymTage: g, schlafSchnittMinuten: nil, erstellt: VerbindenTest.jetzt, respekt: false)
        }
        let eigene = k("Ich", 30_000, 3)
        let zeilen = FreundeRangliste.rangliste([k("A", 50_000, 1), k("B", 30_000, 3), k("C", 30_000, 4), k("Alt", 99_000, 7, "2026-10-19")], eigene: eigene, woche: "2026-10-26")
        XCTAssertEqual(zeilen.map(\.karte.name), ["A", "C", "B", "Ich"], "Alt gehört zu einer anderen Woche")
        XCTAssertEqual(zeilen.map(\.platz), [1, 2, 3, 3], "Gleichstand: gleicher Platz")
        XCTAssertEqual(zeilen.filter(\.eigene).map(\.karte.name), ["Ich"])
    }

    func testWocheIstDieJuengsteMitKarte() {
        func k(_ w: String) -> FreundKarte { FreundKarte(id: w, name: "x", woche: w, schritte: 1, gymTage: 0, schlafSchnittMinuten: nil, erstellt: VerbindenTest.jetzt, respekt: false) }
        XCTAssertEqual(FreundeRangliste.woche([k("2026-10-12"), k("2026-10-19")], eigene: k("2026-10-26")), "2026-10-26")
        XCTAssertEqual(FreundeRangliste.woche([k("2026-10-12")], eigene: nil), "2026-10-12")
        XCTAssertNil(FreundeRangliste.woche([], eigene: nil))
    }

    func testAufnehmenErsetztGleicheKarteNurMitJuengererUndBehaeltRespekt() {
        var alt = karte()
        alt.id = "a-2026-10-26"
        alt.respekt = true
        var neu = alt
        neu.schritte = 50_000
        neu.erstellt = alt.erstellt.addingTimeInterval(3600)
        neu.respekt = false
        let liste = FreundeRangliste.aufnehmen(neu, in: [alt])
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste[0].schritte, 50_000)
        XCTAssertTrue(liste[0].respekt, "der gegebene Respekt bleibt")
        var aelter = alt
        aelter.schritte = 1
        aelter.erstellt = alt.erstellt.addingTimeInterval(-60)
        XCTAssertEqual(FreundeRangliste.aufnehmen(aelter, in: [alt]), [alt], "eine ältere Karte ersetzt nichts")
        var anderer = alt
        anderer.id = "b-2026-10-26"
        XCTAssertEqual(FreundeRangliste.aufnehmen(anderer, in: [alt]).count, 2)
    }
}
