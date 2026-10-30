// Quelle: Lovea Health/Tests/KiFotoTests.swift (angepasst auf die Lumen-Typen)
import XCTest
@testable import LumenFit

/// Reine Logik hinter "Essen fotografieren". Fasst nie einen Store oder ein echtes Tagebuch an.
final class EssenKiFotoLogikTests: XCTestCase {
    private func reis(_ gramm: Double = 200) -> EssenKiKomponente {
        EssenKiKomponente(name: "Reis", gramm: gramm, kcalPro100: 130, proteinPro100: 2.7, kohlenhydratePro100: 28, fettPro100: 0.3, sicherheit: "mittel")
    }

    private func huhn(_ gramm: Double = 150) -> EssenKiKomponente {
        EssenKiKomponente(name: "Hähnchen", gramm: gramm, kcalPro100: 165, proteinPro100: 31, kohlenhydratePro100: 0, fettPro100: 3.6, sicherheit: "hoch")
    }

    private func liste(_ k: [EssenKiKomponente], versteckt: [EssenKiVersteckt] = [], zaehlen: Bool = true) -> [EssenEintrag] {
        EssenKiFotoLogik.eintraege(komponenten: k, versteckt: versteckt, versteckteZaehlen: zaehlen, mahlzeit: .mittag, datum: "2026-10-10")
    }

    private let oel = EssenKiVersteckt(name: "Bratöl", gramm: 10, kcal: 88)

    func testKnopfZahlIstGenauDieSummeImTagebuch() {
        let e = liste([reis(), huhn()], versteckt: [oel])
        XCTAssertEqual(e.count, 3)
        XCTAssertEqual(EssenKiFotoLogik.kcal(e), 596)
        XCTAssertEqual(EssenKiFotoLogik.kcal(e), Int(ErnaehrungLogik.summe(e).kcal.rounded()))
        XCTAssertEqual(EssenKiFotoLogik.kcal(liste([reis(), huhn()], versteckt: [oel], zaehlen: false)), 508)
    }

    func testEintragSchreibtGrammMahlzeitUndTag() throws {
        let e = try XCTUnwrap(liste([reis()]).first)
        XCTAssertEqual(e.menge, 200)
        XCTAssertEqual(e.einheit, .g)
        XCTAssertEqual(e.mahlzeit, .mittag)
        XCTAssertEqual(e.datum, "2026-10-10")
        XCTAssertTrue(e.lebensmittel.id.hasPrefix("ki-"))
        XCTAssertTrue(e.lebensmittel.istEinmalig)
        XCTAssertNil(e.geloescht)
        XCTAssertEqual(Set(liste([reis(), reis()]).map(\.id)).count, 2, "jeder Eintrag eine eigene Id")
    }

    func testNullGrammZaehltNichtUndZuVielWirdGekappt() throws {
        XCTAssertTrue(liste([reis(0)]).isEmpty)
        let riesig = try XCTUnwrap(liste([reis(9000)]).first)
        XCTAssertEqual(riesig.menge, EssenKiFotoLogik.maxGramm)
    }

    func testVersteckteAlsFettUndOhneGrammMit100() throws {
        let e = try XCTUnwrap(liste([], versteckt: [oel]).first)
        XCTAssertEqual(e.lebensmittel.name, "Bratöl (nicht sichtbar)")
        XCTAssertEqual(e.naehrwerte.kcal, 88, accuracy: 0.01)
        XCTAssertEqual(e.naehrwerte.fett, 88.0 / 9, accuracy: 0.01)
        let ohneGramm = try XCTUnwrap(liste([], versteckt: [EssenKiVersteckt(name: "Soße", gramm: 0, kcal: 88)]).first)
        XCTAssertEqual(ohneGramm.menge, 100)
        XCTAssertEqual(ohneGramm.naehrwerte.kcal, 88, accuracy: 0.01)
        XCTAssertTrue(liste([], versteckt: [EssenKiVersteckt(name: "Nichts", gramm: 5, kcal: 0)]).isEmpty)
    }

    func testFotoEintraegeSindEinmaligAberOffAndEigeneNicht() {
        func l(_ id: String) -> Lebensmittel { Lebensmittel(id: id, name: "x", pro100: Naehrwerte()) }
        XCTAssertTrue(l("ki-1").istEinmalig)
        XCTAssertTrue(l("schnell-1").istEinmalig)
        XCTAssertFalse(l("off-123").istEinmalig)
        XCTAssertFalse(l("eigen-1").istEinmalig)
        XCTAssertFalse(l("rezept-1").istEinmalig)
    }

    func testJederFehlerHatTitelTextUndWeg() {
        let alle: [EssenKiFehler] = [.nichtEingerichtet, .tageslimit, .guthaben, .zuVieleAnfragen, .bildZuGross, .netz, .ungueltig, .unbekannt]
        for f in alle {
            let a = EssenKiFotoLogik.anzeige(f)
            XCTAssertFalse(a.titel.isEmpty, "\(f)")
            XCTAssertFalse(a.text.isEmpty, "\(f)")
            XCTAssertFalse(a.symbol.isEmpty, "\(f)")
        }
    }

    func testFehlerBietetNurSinnvolleWege() {
        let netz = EssenKiFotoLogik.anzeige(.netz)
        XCTAssertTrue(netz.nochmal)
        XCTAssertFalse(netz.neuesFoto)
        let gross = EssenKiFotoLogik.anzeige(.bildZuGross)
        XCTAssertFalse(gross.nochmal, "dasselbe zu große Foto nochmal schicken hilft nicht")
        XCTAssertTrue(gross.neuesFoto)
        let kaputt = EssenKiFotoLogik.anzeige(.ungueltig)
        XCTAssertTrue(kaputt.nochmal && kaputt.neuesFoto)
        for f in [EssenKiFehler.tageslimit, .guthaben, .nichtEingerichtet] {
            let a = EssenKiFotoLogik.anzeige(f)
            XCTAssertFalse(a.nochmal || a.neuesFoto, "\(f): ein neuer Versuch ändert nichts")
        }
        XCTAssertTrue(EssenKiFotoLogik.fotoUnlesbar.neuesFoto)
        XCTAssertFalse(EssenKiFotoLogik.fotoUnlesbar.nochmal)
    }

    func testNichtEingerichtetSagtVonHandEintragenUndKeinWortServerOderSchluessel() {
        let a = EssenKiFotoLogik.anzeige(.nichtEingerichtet)
        XCTAssertEqual(a.titel, "KI gerade nicht erreichbar")
        XCTAssertEqual(a.text, "Trag die Mahlzeit solange von Hand ein.")
    }

    private func analyse(istEssen: Bool, items: String, bemerkung: String) throws -> EssenKiAnalyse {
        let json = """
        {"ist_essen":\(istEssen),"items":\(items),"versteckt":[],"gesamt":{"kcal":0,"kcal_min":0,"kcal_max":0},
         "frage":null,"bemerkung":"\(bemerkung)","rest":3}
        """
        return try JSONDecoder().decode(EssenKiAnalyse.self, from: Data(json.utf8))
    }

    func testKeinEssenAuchBeiLeererListe() throws {
        let hund = try analyse(istEssen: false, items: "[]", bemerkung: "Das ist ein Hund.")
        XCTAssertTrue(EssenKiFotoLogik.keinEssen(hund))
        XCTAssertEqual(EssenKiFotoLogik.keinEssenText(hund), "Das ist ein Hund.")
        let leer = try analyse(istEssen: true, items: "[]", bemerkung: "  ")
        XCTAssertTrue(EssenKiFotoLogik.keinEssen(leer))
        XCTAssertEqual(EssenKiFotoLogik.keinEssenText(leer), "Auf dem Foto ist kein Essen zu erkennen.")
        let item = #"[{"name":"Reis","gramm":200,"kcal_pro_100g":130,"protein_pro_100g":2.7,"kohlenhydrate_pro_100g":28,"fett_pro_100g":0.3,"sicherheit":"mittel"}]"#
        XCTAssertFalse(EssenKiFotoLogik.keinEssen(try analyse(istEssen: true, items: item, bemerkung: "")))
    }

    func testRestTextErstKurzVorSchluss() {
        XCTAssertNil(EssenKiFotoLogik.restText(nil))
        XCTAssertNil(EssenKiFotoLogik.restText(39))
        XCTAssertNil(EssenKiFotoLogik.restText(6))
        XCTAssertEqual(EssenKiFotoLogik.restText(5), "Noch 5 Fotos für heute.")
        XCTAssertEqual(EssenKiFotoLogik.restText(1), "Noch 1 Foto für heute.")
        XCTAssertEqual(EssenKiFotoLogik.restText(0), "Das war dein letztes Foto für heute.")
    }

    func testBereichNurWennSinnvollUndMitVersteckten() {
        // Server: kcal_min nur Zutaten, kcal_max schon mit den versteckten 88 kcal.
        let g = EssenKiAnalyse.Gesamt(kcal: 508, kcalMin: 406, kcalMax: 698)
        XCTAssertEqual(EssenKiFotoLogik.bereich(g, versteckteKcal: 88, gezaehlt: true), 494...698)
        XCTAssertEqual(EssenKiFotoLogik.bereich(g, versteckteKcal: 88, gezaehlt: false), 406...610)
        XCTAssertNil(EssenKiFotoLogik.bereich(.init(kcal: 500, kcalMin: 0, kcalMax: 0), versteckteKcal: 0, gezaehlt: true))
        XCTAssertNil(EssenKiFotoLogik.bereich(.init(kcal: 500, kcalMin: 500, kcalMax: 500), versteckteKcal: 0, gezaehlt: true))
    }

    func testKorrekturenNurBeiGeaenderterMengeUndNichtBeiEntfernten() {
        let r = reis(250), h = huhn(), x = huhn(100)
        let vorher: [UUID: Double] = [r.id: 200, h.id: 150, x.id: 150]
        let k = EssenKiFotoLogik.korrekturen([r, h, x], urspruenglich: vorher, entfernt: [x.id])
        XCTAssertEqual(k.map(\.name), ["Reis"])
        XCTAssertEqual(k.map(\.gramm), [250])
        XCTAssertTrue(EssenKiFotoLogik.korrekturen([reis(200.4)], urspruenglich: [:], entfernt: []).isEmpty)
    }

    func testHinweisBleibtImServerLimitUndBehaeltDieAntwort() {
        XCTAssertEqual(EssenKiFotoLogik.hinweis(frage: "Welches Öl?", antwort: " Olivenöl "), "Frage: Welches Öl? Antwort: Olivenöl")
        let lang = EssenKiFotoLogik.hinweis(frage: "F", antwort: String(repeating: "x", count: 400))
        XCTAssertEqual(lang.count, 300)
        XCTAssertTrue(lang.hasSuffix("xxx"))
    }

    func testTitelUndSicherheit() {
        XCTAssertEqual(EssenKiFotoLogik.titel([]), "Foto-Mahlzeit")
        XCTAssertEqual(EssenKiFotoLogik.titel([reis()]), "Reis")
        XCTAssertEqual(EssenKiFotoLogik.titel([reis(), huhn()]), "Reis, Hähnchen")
        XCTAssertEqual(EssenKiFotoLogik.titel([reis(), huhn(), reis()]), "Reis, Hähnchen …")
        XCTAssertEqual(EssenKiFotoLogik.sicherheit("hoch").text, "sicher")
        XCTAssertEqual(EssenKiFotoLogik.sicherheit("niedrig").text, "unsicher")
        XCTAssertEqual(EssenKiFotoLogik.sicherheit("mittel").text, "ungefähr")
    }

    // MARK: - Codec der Antwort (Format des Servers)

    func testAntwortDesServersWirdGelesenUndRechnetPortionen() throws {
        let json = """
        {"ok":true,"ist_essen":true,
         "items":[{"name":"Reis, gekocht","gramm":200,"kcal_pro_100g":130,"protein_pro_100g":2.7,"kohlenhydrate_pro_100g":28,"fett_pro_100g":0.3,
                   "kcal":260,"protein":5.4,"kohlenhydrate":56,"fett":0.6,"sicherheit":"hoch"}],
         "versteckt":[{"name":"Bratöl","gramm":10,"kcal":88}],
         "gesamt":{"kcal":260,"kcal_min":234,"kcal_max":374,"protein":5.4,"kohlenhydrate":56,"fett":0.6,"versteckt_kcal":88,"kcal_mit_versteckt":348},
         "frage":"Welches Öl?","bemerkung":"Reis mit Öl.","rest":39,"modell":"gpt-6-luna"}
        """
        let a = try JSONDecoder().decode(EssenKiAnalyse.self, from: Data(json.utf8))
        XCTAssertTrue(a.istEssen)
        XCTAssertEqual(a.items.map(\.name), ["Reis, gekocht"])
        XCTAssertEqual(a.items.first?.kcalPro100, 130)
        XCTAssertEqual(a.items.first?.sicherheit, "hoch")
        XCTAssertEqual(a.versteckt, [EssenKiAnalyse.Versteckt(name: "Bratöl", gramm: 10, kcal: 88)])
        XCTAssertEqual(a.gesamt, EssenKiAnalyse.Gesamt(kcal: 260, kcalMin: 234, kcalMax: 374))
        XCTAssertEqual(a.frage, "Welches Öl?")
        XCTAssertEqual(a.rest, 39)
        XCTAssertEqual(a.komponenten.first?.kcal, 260)
        XCTAssertEqual(a.versteckteListe.first?.kcal, 88)
    }

    func testAntwortMitFehlendenFeldernIstLesbar() throws {
        let a = try JSONDecoder().decode(EssenKiAnalyse.self, from: Data(#"{"ist_essen":true,"items":[{"name":"Apfel"}]}"#.utf8))
        XCTAssertEqual(a.items.first?.gramm, 0)
        XCTAssertEqual(a.items.first?.sicherheit, "mittel")
        XCTAssertTrue(a.versteckt.isEmpty)
        XCTAssertEqual(a.gesamt.kcal, 0)
        XCTAssertEqual(a.bemerkung, "")
        XCTAssertNil(a.frage)
        XCTAssertNil(a.rest)
    }

    func testAntwortKodierenUndLesenGibtDasGleiche() throws {
        let a = EssenKiAnalyse(istEssen: true, items: [.init(name: "Reis", gramm: 200, kcalPro100: 130, proteinPro100: 2.7, kohlenhydratePro100: 28, fettPro100: 0.3, sicherheit: "niedrig")],
                               versteckt: [.init(name: "Öl", gramm: 5, kcal: 44)], gesamt: .init(kcal: 260, kcalMin: 200, kcalMax: 330), frage: "Welches Öl?", bemerkung: "ok", rest: 3)
        let neu = try JSONDecoder().decode(EssenKiAnalyse.self, from: JSONEncoder().encode(a))
        XCTAssertEqual(neu, a)
    }
}
