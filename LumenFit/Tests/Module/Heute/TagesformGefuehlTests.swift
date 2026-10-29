import XCTest
@testable import LumenFit

/// W-028: das eigene Gefühl zum Tag, Vergleich mit der Rechnung und Nachstellen.
final class TagesformGefuehlTests: XCTestCase {
    private typealias B = TagesformBeispiele

    /// Jeder Test hat seine eigene Datei (XCTest legt je Test eine neue Instanz an) und räumt sie weg.
    private let datei = FileManager.default.temporaryDirectory.appendingPathComponent("tagesform-gefuehl-\(UUID().uuidString).json")

    override func tearDown() {
        try? FileManager.default.removeItem(at: datei)
        super.tearDown()
    }

    private func eingabe() -> TagesformEingabe {
        var e = TagesformEingabe()
        e.schlaf = [420, 450, 460, 450]
        e.bett = [600, 610, 590, 620]
        e.saetze = [0, 10, 12, 0, 8]
        e.kalorien = TagesformMass(ist: 2300, ziel: 2600, bezug: .vortag)
        e.muskeln = [TagesformMuskel(gruppe: "Brust", prozent: 55)]
        e.schlafHinweis = "Quelle: Apple Watch"
        return e
    }

    private func eintrag(_ tag: String, gefuehl: Int, akku: Int?) -> TagesformEintrag {
        TagesformEintrag(tag: tag, gefuehl: gefuehl, akku: akku, formel: TagesformRechnung.version, eingabe: eingabe(),
                         gespeichert: Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: Gefühl und Zahl

    func testZielwerteWachsenMitDemGefuehlUndPassenZuDenUrteilen() {
        XCTAssertEqual(TagesformGefuehl.zielwerte.count, 5)
        XCTAssertEqual(TagesformGefuehl.namen.count, 5)
        for (a, b) in zip(TagesformGefuehl.zielwerte, TagesformGefuehl.zielwerte.dropFirst()) { XCTAssertLessThan(a, b) }
        XCTAssertEqual(TagesformLogik.urteil(TagesformGefuehl.zielwert(1)), "Sparmodus")
        XCTAssertEqual(TagesformLogik.urteil(TagesformGefuehl.zielwert(2)), "Sparmodus")
        XCTAssertEqual(TagesformLogik.urteil(TagesformGefuehl.zielwert(3)), "Halb leer")
        XCTAssertEqual(TagesformLogik.urteil(TagesformGefuehl.zielwert(4)), "Gut geladen")
        XCTAssertEqual(TagesformLogik.urteil(TagesformGefuehl.zielwert(5)), "Voll geladen")
    }

    func testGefuehlAusserhalbEinsBisFuenfWirdKlemmt() {
        XCTAssertEqual(TagesformGefuehl.zielwert(0), TagesformGefuehl.zielwert(1))
        XCTAssertEqual(TagesformGefuehl.zielwert(9), TagesformGefuehl.zielwert(5))
        XCTAssertEqual(TagesformGefuehl.name(-3), "Leer")
        XCTAssertEqual(TagesformGefuehl.name(5), "Voll")
    }

    func testAbweichungIstRechnungMinusGefuehl() {
        XCTAssertEqual(TagesformGefuehl.abweichung(eintrag("2026-10-12", gefuehl: 4, akku: 72)), 72 - 78)
        XCTAssertEqual(TagesformGefuehl.abweichung(eintrag("2026-10-12", gefuehl: 2, akku: 55)), 15)
        XCTAssertNil(TagesformGefuehl.abweichung(eintrag("2026-10-12", gefuehl: 3, akku: nil)), "ohne Zahl keine Abweichung")
    }

    // MARK: Liste

    func testEinEintragJeTagDerNeueErsetztDenAlten() {
        let alt = eintrag("2026-10-12", gefuehl: 2, akku: 40)
        let neu = eintrag("2026-10-12", gefuehl: 4, akku: 70)
        let liste = TagesformGefuehl.einsetzen([alt], neu)
        XCTAssertEqual(liste.count, 1)
        XCTAssertEqual(liste.first?.gefuehl, 4)
    }

    func testListeIstNachTagSortiertUndBegrenzt() {
        var liste: [TagesformEintrag] = []
        for i in 0..<(TagesformGefuehl.behalten + 5) {
            let tag = Datum.addTage("2026-01-01", i)
            liste = TagesformGefuehl.einsetzen(liste, eintrag(tag, gefuehl: 3, akku: 60))
        }
        XCTAssertEqual(liste.count, TagesformGefuehl.behalten)
        XCTAssertEqual(liste.map { $0.tag }, liste.map { $0.tag }.sorted())
        XCTAssertEqual(liste.last?.tag, Datum.addTage("2026-01-01", TagesformGefuehl.behalten + 4), "die neuesten bleiben")
        XCTAssertNotEqual(liste.first?.tag, "2026-01-01", "die ältesten gehen")
        // Rückwärts eingefügt ergibt dieselbe Ordnung.
        var rueckwaerts: [TagesformEintrag] = []
        for tag in ["2026-03-03", "2026-03-01", "2026-03-02"] {
            rueckwaerts = TagesformGefuehl.einsetzen(rueckwaerts, eintrag(tag, gefuehl: 3, akku: 60))
        }
        XCTAssertEqual(rueckwaerts.map { $0.tag }, ["2026-03-01", "2026-03-02", "2026-03-03"])
    }

    // MARK: Vergleich

    func testVergleichBrauchtDreiEintraege() {
        let zwei = [eintrag("2026-10-10", gefuehl: 3, akku: 70), eintrag("2026-10-11", gefuehl: 3, akku: 70)]
        XCTAssertNil(TagesformGefuehl.vergleich(zwei, bis: "2026-10-12"))
        let drei = zwei + [eintrag("2026-10-12", gefuehl: 3, akku: 70)]
        XCTAssertNotNil(TagesformGefuehl.vergleich(drei, bis: "2026-10-12"))
    }

    func testVergleichMitteltDieAbweichungenMitVorzeichen() {
        // Gefühl 3 = 60, Gefühl 4 = 78, Gefühl 5 = 92: Abweichungen +10, +2, -12.
        let liste = [
            eintrag("2026-10-10", gefuehl: 3, akku: 70),
            eintrag("2026-10-11", gefuehl: 4, akku: 80),
            eintrag("2026-10-12", gefuehl: 5, akku: 80),
        ]
        let v = TagesformGefuehl.vergleich(liste, bis: "2026-10-12")
        XCTAssertEqual(v?.anzahl, 3)
        XCTAssertEqual(v?.schnitt ?? 0, 0, accuracy: 1e-9)
        let hoch = [
            eintrag("2026-10-10", gefuehl: 3, akku: 80),
            eintrag("2026-10-11", gefuehl: 3, akku: 70),
            eintrag("2026-10-12", gefuehl: 3, akku: 90),
        ]
        XCTAssertEqual(TagesformGefuehl.vergleich(hoch, bis: "2026-10-12")?.schnitt ?? 0, 20, accuracy: 1e-9, "Rechnung über dem Gefühl: positiv")
    }

    func testVergleichZaehltNurDieLetztenSiebenBisZumTagOhneLeere() {
        var liste: [TagesformEintrag] = []
        // Zehn Tage, die ersten drei mit Abweichung +40, die letzten sieben mit 0.
        for i in 0..<10 {
            let akku = i < 3 ? 100 : 60
            liste.append(eintrag(Datum.addTage("2026-10-01", i), gefuehl: 3, akku: akku))
        }
        let v = TagesformGefuehl.vergleich(liste, bis: "2026-10-10")
        XCTAssertEqual(v?.anzahl, TagesformGefuehl.letzteFuerVergleich)
        XCTAssertEqual(v?.schnitt ?? 99, 0, accuracy: 1e-9, "nur die letzten sieben")
        // Spätere Einträge zählen nicht, Einträge ohne Zahl auch nicht.
        let bis = TagesformGefuehl.vergleich(liste, bis: "2026-10-04")
        XCTAssertEqual(bis?.anzahl, 4)
        liste[8] = eintrag("2026-10-09", gefuehl: 3, akku: nil)
        XCTAssertEqual(TagesformGefuehl.vergleich(liste, bis: "2026-10-10")?.anzahl, TagesformGefuehl.letzteFuerVergleich, "sieben mit Zahl, der leere wird übersprungen")
    }

    // MARK: Nachstellen und Speicher

    func testNachstellenGibtDieselbeZahlWieDamals() throws {
        let e = eingabe()
        let damals = TagesformRechnung.rechnen(e)
        let gespeichert = TagesformEintrag(tag: "2026-10-12", gefuehl: 4, akku: damals.akku, formel: TagesformRechnung.version,
                                           eingabe: e, gespeichert: Date(timeIntervalSince1970: 1_700_000_000))
        let daten = try JSONEncoder().encode(gespeichert)
        let gelesen = try JSONDecoder().decode(TagesformEintrag.self, from: daten)
        XCTAssertEqual(gelesen, gespeichert)
        XCTAssertEqual(TagesformGefuehl.nachgestellt(gelesen), damals)
        XCTAssertEqual(TagesformGefuehl.nachgestellt(gelesen).akku, gelesen.akku)
    }

    func testSpeichernUndLaden() {
        let liste = [eintrag("2026-10-11", gefuehl: 2, akku: 41), eintrag("2026-10-12", gefuehl: 5, akku: 88)]
        XCTAssertTrue(TagesformGefuehl.laden(datei).isEmpty, "ohne Datei gibt es nichts")
        TagesformGefuehl.speichern(liste, in: datei)
        XCTAssertEqual(TagesformGefuehl.laden(datei), liste)
        TagesformGefuehl.speichern([liste[1]], in: datei)
        XCTAssertEqual(TagesformGefuehl.laden(datei), [liste[1]], "Speichern ersetzt die Datei")
    }

    func testSpeichernLegtDenOrdnerAn() {
        // Auf einem frischen iPhone gibt es Application Support vielleicht noch nicht.
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("tagesform-ordner-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: ordner) }
        let tief = ordner.appendingPathComponent("unten", isDirectory: true).appendingPathComponent("gefuehl.json")
        let liste = [eintrag("2026-10-12", gefuehl: 4, akku: 70)]
        TagesformGefuehl.speichern(liste, in: tief)
        XCTAssertEqual(TagesformGefuehl.laden(tief), liste)
    }

    func testDieListeMitAllenRohwertenBleibtKlein() throws {
        // Mit allen Rohwerten (29 Tage HRV und Ruhepuls, Muskeln, Sätze) sind das bis zu 2,6 KB je Eintrag; deshalb eine Datei
        // und nicht die Einstellungen, in die jede Änderung die ganze Liste neu schreibt.
        var e = eingabe()
        e.hrv = B.reihe(58, B.hrvBasis)
        e.ruhepuls = B.reihe(56, B.pulsBasis)
        e.muskeln = MuskelTeil.allCases.map { TagesformMuskel(gruppe: $0.gruppe.name, prozent: 40) }
        var liste: [TagesformEintrag] = []
        for i in 0..<TagesformGefuehl.behalten {
            liste = TagesformGefuehl.einsetzen(liste, TagesformEintrag(tag: Datum.addTage("2026-01-01", i), gefuehl: 3, akku: 60,
                                                                       formel: TagesformRechnung.version, eingabe: e,
                                                                       gespeichert: Date(timeIntervalSince1970: 1_700_000_000)))
        }
        TagesformGefuehl.speichern(liste, in: datei)
        let groesse = try FileManager.default.attributesOfItem(atPath: datei.path)[.size] as? Int ?? Int.max
        XCTAssertLessThan(groesse, 400_000)
        XCTAssertEqual(TagesformGefuehl.laden(datei).count, TagesformGefuehl.behalten)
    }

    func testEinKaputterEintragKostetNichtAlleAnderen() throws {
        let gut = eintrag("2026-10-12", gefuehl: 4, akku: 70)
        let gutJson = try JSONSerialization.jsonObject(with: JSONEncoder().encode(gut))
        let gemischt: [Any] = [gutJson, ["tag": 5], "Müll", gutJson]
        let daten = try JSONSerialization.data(withJSONObject: gemischt)
        try daten.write(to: datei)
        XCTAssertEqual(TagesformGefuehl.laden(datei), [gut, gut])
        try Data("kein json".utf8).write(to: datei)
        XCTAssertTrue(TagesformGefuehl.laden(datei).isEmpty)
    }
}

/// Der Speicher hinter der Karte: hält die Einträge im Speicher und sichert jede Änderung in die Datei.
@MainActor
final class TagesformSpeicherTests: XCTestCase {
    private func eintrag(_ tag: String, gefuehl: Int) -> TagesformEintrag {
        var e = TagesformEingabe()
        e.schlaf = [420, 450]
        return TagesformEintrag(tag: tag, gefuehl: gefuehl, akku: 70, formel: TagesformRechnung.version, eingabe: e,
                                gespeichert: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testSetzenHaeltSichertUndLiestBeimNeuenStartWieder() {
        let datei = FileManager.default.temporaryDirectory.appendingPathComponent("tagesform-speicher-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: datei) }
        let speicher = TagesformSpeicher(datei: datei)
        XCTAssertTrue(speicher.eintraege.isEmpty)
        XCTAssertNil(speicher.eintrag("2026-10-12"))
        speicher.setzen(eintrag("2026-10-12", gefuehl: 4))
        speicher.setzen(eintrag("2026-10-11", gefuehl: 2))
        XCTAssertEqual(speicher.eintrag("2026-10-12")?.gefuehl, 4)
        XCTAssertEqual(speicher.eintraege.map { $0.tag }, ["2026-10-11", "2026-10-12"], "nach Tag sortiert")
        // Erneutes Antippen am selben Tag ersetzt den Eintrag.
        speicher.setzen(eintrag("2026-10-12", gefuehl: 5))
        XCTAssertEqual(speicher.eintraege.count, 2)
        XCTAssertEqual(speicher.eintrag("2026-10-12")?.gefuehl, 5)
        // Nach einem Neustart liest ein frischer Speicher dieselbe Datei.
        XCTAssertEqual(TagesformSpeicher(datei: datei).eintraege, speicher.eintraege)
    }
}
