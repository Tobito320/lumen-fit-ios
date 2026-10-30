import XCTest
@testable import LumenFit

/// Eigene Übungen: Prüfung, Falten der Ops `fit.gym.uebung`, Zusammenführung mit dem Katalog, Plan-Eintrag, Speichern und Neuladen.
@MainActor
final class GymEigeneUebungTests: XCTestCase {
    private let katalog = [
        Uebung(id: "k1", name: "Bankdrücken", en: "bench press", muskel: "Brust", koerper: "Brust", geraet: "Langhantel", neben: []),
        Uebung(id: "k2", name: "Laufband", en: "treadmill", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Maschine", neben: []),
        Uebung(id: "k3", name: "Seitheben", en: "lateral raise", muskel: "Schultern", koerper: "Schultern", geraet: "Kurzhantel", neben: []),
    ]

    private func d(_ id: String, _ name: String, geloescht: Bool? = nil) -> GymEigeneUebungD {
        GymEigeneUebungD(id: id, name: name, muskel: "Brust", koerper: "Brust", geraet: "Kurzhantel", geloescht: geloescht)
    }

    private func op(_ d: GymEigeneUebungD) -> Op { Op.neu(GymEigeneLogik.art, d, von: .testA) }

    // MARK: Prüfen

    func testPruefenOk() {
        XCTAssertNil(GymEigeneLogik.pruefe(name: "Kabel-Fly tief", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", bekannt: katalog))
    }

    func testPruefenLeerUndZuLang() {
        XCTAssertEqual(GymEigeneLogik.pruefe(name: "  \n ", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", bekannt: katalog), .nameLeer)
        let lang = String(repeating: "a", count: GymEigeneLogik.maxName + 1)
        XCTAssertEqual(GymEigeneLogik.pruefe(name: lang, koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", bekannt: katalog), .nameZuLang)
        let genau = String(repeating: "a", count: GymEigeneLogik.maxName)
        XCTAssertNil(GymEigeneLogik.pruefe(name: genau, koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", bekannt: katalog))
    }

    func testPruefenMuskelUndGeraetFehlen() {
        XCTAssertEqual(GymEigeneLogik.pruefe(name: "X", koerper: "", muskel: "Brust", geraet: "Kabelzug", bekannt: []), .muskelFehlt)
        XCTAssertEqual(GymEigeneLogik.pruefe(name: "X", koerper: "Brust", muskel: "", geraet: "Kabelzug", bekannt: []), .muskelFehlt)
        XCTAssertEqual(GymEigeneLogik.pruefe(name: "X", koerper: "Brust", muskel: "Brust", geraet: "", bekannt: []), .geraetFehlt)
    }

    func testDubletteKatalogIgnoriertGrossUmlautUndEnglisch() {
        XCTAssertEqual(GymEigeneLogik.pruefe(name: "BANKDRUECKEN", koerper: "Brust", muskel: "Brust", geraet: "Langhantel", bekannt: katalog), .dubletteKatalog)
        XCTAssertEqual(GymEigeneLogik.pruefe(name: "Bench  Press", koerper: "Brust", muskel: "Brust", geraet: "Langhantel", bekannt: katalog), .dubletteKatalog)
    }

    func testDubletteEigeneUndBearbeitenZaehltSichSelbstNicht() {
        let eigene = GymEigeneLogik.uebung(d("lv-eigen-1", "Kabel-Fly"))
        let bekannt = [eigene] + katalog
        XCTAssertEqual(GymEigeneLogik.pruefe(name: "kabel-fly", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", bekannt: bekannt), .dubletteEigene)
        XCTAssertNil(GymEigeneLogik.pruefe(name: "Kabel-Fly", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", id: "lv-eigen-1", bekannt: bekannt))
    }

    func testBereinigtFasstLeerraumZusammen() {
        XCTAssertEqual(GymEigeneLogik.bereinigt("  Kabel \n  Fly  "), "Kabel Fly")
    }

    func testFehlerTexteSindDeutschUndNichtLeer() {
        let alle: [GymEigeneFehler] = [.nameLeer, .nameZuLang, .muskelFehlt, .geraetFehlt, .dubletteKatalog, .dubletteEigene]
        XCTAssertEqual(Set(alle.map(\.text)).count, alle.count)
        XCTAssertTrue(alle.allSatisfy { !$0.text.isEmpty })
    }

    // MARK: Muskeln und Einheit

    func testMuskelnCardioHatNurHerzKreislauf() {
        XCTAssertEqual(GymEigeneLogik.muskeln(koerper: "Cardio", katalog: katalog), ["Herz-Kreislauf"])
        XCTAssertEqual(GymEigeneLogik.muskeln(koerper: "Brust", katalog: katalog), ["Brust"])
        XCTAssertEqual(GymEigeneLogik.einheitText(koerper: "Cardio"), "Minuten")
        XCTAssertEqual(GymEigeneLogik.einheitText(koerper: "Brust"), "Gewicht und Wiederholungen")
    }

    func testMuskelBleibtOderWechseltMitKoerperteil() {
        XCTAssertEqual(GymEigeneLogik.muskel(koerper: "Schultern", aktuell: "Schultern", katalog: katalog), "Schultern")
        XCTAssertEqual(GymEigeneLogik.muskel(koerper: "Schultern", aktuell: "Brust", katalog: katalog), "Schultern")
        XCTAssertEqual(GymEigeneLogik.muskel(koerper: "Cardio", aktuell: "Brust", katalog: katalog), "Herz-Kreislauf")
        XCTAssertEqual(GymEigeneLogik.muskel(koerper: "Nacken", aktuell: "Brust", katalog: katalog), "")
    }

    // MARK: Falten und Zusammenführen

    func testFaltenLetzteOpGewinntGeloeschtFehltReihenfolgeBleibt() {
        let ops = [op(d("lv-eigen-1", "Alt")), op(d("lv-eigen-2", "Zwei")), op(d("lv-eigen-1", "Neu")), op(d("lv-eigen-3", "Weg")), op(d("lv-eigen-3", "Weg", geloescht: true))]
        let stand = GymEigeneLogik.falten(ops: ops)
        XCTAssertEqual(stand.map(\.name), ["Neu", "Zwei"])
    }

    func testFaltenIgnoriertFremdeArtKaputtesUndFremdeIds() {
        let kaputt = Op(id: "x", art: GymEigeneLogik.art, von: .testA, zeit: Date(), d: Data("{".utf8))
        let fremdeArt = Op.neu("gym.uebung", d("lv-eigen-9", "Fremd"), von: .testA)
        let fremdeId = op(d("abc", "Katalogid"))
        XCTAssertEqual(GymEigeneLogik.falten(ops: [kaputt, fremdeArt, fremdeId]), [])
    }

    func testZusammenhaengtEigeneVorDenKatalogUndUeberdecktNichts() {
        let eigene = [d("lv-eigen-b", "Zebra-Curl"), d("lv-eigen-a", "Alpha-Fly"), d("k1", "Gleiche Id")]
        let alle = GymEigeneLogik.zusammen(katalog: katalog, eigene: eigene)
        XCTAssertEqual(alle.map(\.name), ["Alpha-Fly", "Zebra-Curl", "Bankdrücken", "Laufband", "Seitheben"])
    }

    func testEigeneUebungIstKeineMediaUebung() {
        let u = GymEigeneLogik.uebung(d(GymEigeneLogik.neueId(), "Kabel-Fly"))
        XCTAssertFalse(UebungsKatalog.hatVideo(u.id))
        XCTAssertTrue(GymEigeneLogik.istEigene(u.id))
        XCTAssertFalse(GymEigeneLogik.istEigene("k1"))
        XCTAssertEqual(u.en, u.name)
    }

    // MARK: Plan-Eintrag

    func testPlanEintragEigeneTraegtNamenKatalogNicht() {
        let eigene = GymEigeneLogik.uebung(d("lv-eigen-1", "Kabel-Fly"))
        let p = GymEigeneLogik.planUebung(eigene)
        XCTAssertEqual(p.name, "Kabel-Fly")
        XCTAssertEqual(p.anzeigeName, "Kabel-Fly")
        XCTAssertEqual(p.saetze.count, 3)
        XCTAssertNil(GymEigeneLogik.planUebung(katalog[0]).name)
    }

    func testPlanEintragCardioZaehltMinuten() {
        let lauf = GymEigeneUebungD(id: "lv-eigen-2", name: "Rudern draußen", muskel: "Herz-Kreislauf", koerper: "Cardio", geraet: "Maschine")
        let p = GymEigeneLogik.planUebung(GymEigeneLogik.uebung(lauf))
        XCTAssertEqual(p.minuten, 20)
        XCTAssertTrue(p.saetze.isEmpty)
        XCTAssertEqual(p.name, "Rudern draußen")
    }

    // MARK: Store und Raum

    private func aufbau() throws -> (ordner: URL, raum: LokalerRaum, uhr: TestUhr) {
        let ordner = try tempOrdner()
        let uhr = TestUhr()
        return (ordner, LokalerRaum(ordner: ordner, profil: .testA, uhr: uhr.uhr), uhr)
    }

    func testSichernSchreibtOpUndLaedtNachNeustartWieder() throws {
        let (ordner, raum, uhr) = try aufbau()
        let store = GymEigeneStore(raum: raum, uhr: uhr.uhr)
        guard case .success(let u) = store.sichern(name: "  Kabel-Fly tief ", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", notiz: " Sitz  3 ") else {
            return XCTFail("sollte speichern")
        }
        XCTAssertTrue(GymEigeneLogik.istEigene(u.id))
        XCTAssertEqual(raum.ops(arten: [GymEigeneLogik.art]).count, 1)
        XCTAssertEqual(store.liste.first?.angelegt, "2026-09-23")
        XCTAssertEqual(store.liste.first?.notiz, "Sitz 3")

        // Neustart: neuer Raum liest ops.jsonl, neuer Store faltet.
        let raum2 = LokalerRaum(ordner: ordner, profil: .testA, uhr: uhr.uhr)
        let store2 = GymEigeneStore(raum: raum2, uhr: uhr.uhr)
        XCTAssertEqual(store2.liste.map(\.name), ["Kabel-Fly tief"])
        XCTAssertEqual(store2.finde(u.id)?.muskel, "Brust")
        XCTAssertEqual(store2.alle.first?.id, u.id)
        XCTAssertEqual(store2.nachId[u.id]?.name, "Kabel-Fly tief")
    }

    func testFehlerSchreibtKeineOpUndDubletteBleibtAus() throws {
        let (_, raum, uhr) = try aufbau()
        let store = GymEigeneStore(raum: raum, uhr: uhr.uhr)
        XCTAssertEqual(store.sichern(name: "", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", notiz: ""), .failure(.nameLeer))
        XCTAssertEqual(raum.ops(arten: [GymEigeneLogik.art]).count, 0)
        _ = store.sichern(name: "Kabel-Fly", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", notiz: "")
        XCTAssertEqual(store.sichern(name: "kabel fly", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", notiz: ""), .failure(.dubletteEigene))
        XCTAssertEqual(raum.ops(arten: [GymEigeneLogik.art]).count, 1)
    }

    func testAendernBehaeltIdUndAngelegtLoeschenSetztGrabstein() throws {
        let (_, raum, uhr) = try aufbau()
        let store = GymEigeneStore(raum: raum, uhr: uhr.uhr)
        guard case .success(let u) = store.sichern(name: "Kabel-Fly", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", notiz: "") else { return XCTFail("sollte speichern") }
        uhr.vor(sekunden: 86_400 * 3)
        guard case .success(let neu) = store.sichern(id: u.id, name: "Kabel-Fly hoch", koerper: "Schultern", muskel: "Schultern", geraet: "Kabelzug", notiz: "") else { return XCTFail("sollte ändern") }
        XCTAssertEqual(neu.id, u.id)
        XCTAssertEqual(store.liste.count, 1)
        XCTAssertEqual(store.liste.first?.name, "Kabel-Fly hoch")
        XCTAssertEqual(store.liste.first?.angelegt, "2026-09-23")

        store.loeschen(u.id)
        XCTAssertTrue(store.liste.isEmpty)
        XCTAssertFalse(store.istEigene(u.id))
        XCTAssertEqual(raum.ops(arten: [GymEigeneLogik.art]).count, 3, "Grabstein ist eine eigene Op")
        // Derselbe Name ist nach dem Löschen wieder frei.
        XCTAssertNotNil(try? store.sichern(name: "Kabel-Fly hoch", koerper: "Schultern", muskel: "Schultern", geraet: "Kabelzug", notiz: "").get())
    }

    func testBestehendeTrainingsBehaltenNachLoeschenIhrenNamen() throws {
        let (_, raum, uhr) = try aufbau()
        let store = GymEigeneStore(raum: raum, uhr: uhr.uhr)
        guard case .success(let u) = store.sichern(name: "Kabel-Fly", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", notiz: "") else { return XCTFail("sollte speichern") }
        let plan = GymEigeneLogik.planUebung(u)
        store.loeschen(u.id)
        XCTAssertNil(store.finde(plan.uebung))
        XCTAssertEqual(plan.anzeigeName, "Kabel-Fly")
    }

    func testStoreOhneRaumSchreibtNichts() {
        let store = GymEigeneStore(raum: nil)
        XCTAssertTrue(store.liste.isEmpty)
        XCTAssertNotNil(try? store.sichern(name: "Kabel-Fly", koerper: "Brust", muskel: "Brust", geraet: "Kabelzug", notiz: "").get())
        XCTAssertTrue(store.liste.isEmpty)
    }
}
