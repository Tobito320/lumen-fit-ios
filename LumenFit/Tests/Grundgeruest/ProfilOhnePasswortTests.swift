import XCTest
@testable import LumenFit

/// Das Passwort ist freiwillig: ein Profil ohne Passwort wechselt und löscht nach einer Bestätigung, ein Passwort lässt sich später festlegen.
@MainActor
final class ProfilOhnePasswortTests: XCTestCase {
    private func neuerStore(_ bund: SpeicherSchluesselbund = SpeicherSchluesselbund()) -> ProfilStore {
        ProfilStore(schluesselbund: bund, ereignisse: EreignisKanal(), runden: 1_000)
    }

    func testLeeresPasswortLegtEinProfilOhnePasswortAn() throws {
        let store = neuerStore()
        let p = try store.anlegen(name: "Mira", passwort: "")
        XCTAssertTrue(p.ohnePasswort)
        XCTAssertEqual(store.aktiv?.id, p.id)
        XCTAssertTrue(store.pruefe(passwort: "", fuer: p.id), "ohne Passwort genügt die Bestätigung der Oberfläche")
    }

    func testEinZuKurzesPasswortIstWeiterEinFehlerNurLeerIstFrei() {
        let store = neuerStore()
        XCTAssertThrowsError(try store.anlegen(name: "Mira", passwort: "abc")) { XCTAssertEqual($0 as? ProfilFehler, .passwortZuKurz) }
        XCTAssertFalse(store.hatProfil)
    }

    func testProfilOhnePasswortUeberstehtDenNeustart() throws {
        let bund = SpeicherSchluesselbund()
        let id = try neuerStore(bund).anlegen(name: "Mira", passwort: "").id
        let neu = neuerStore(bund)
        XCTAssertEqual(neu.aktiv?.id, id)
        XCTAssertEqual(neu.aktiv?.ohnePasswort, true)
    }

    func testWechselnUndLoeschenOhnePasswort() async throws {
        let store = neuerStore()
        let a = try store.anlegen(name: "Eins", passwort: "")
        let b = try store.anlegen(name: "Zwei", passwort: "abcd")
        XCTAssertTrue(store.wechsle(zu: a.id, passwort: ""))
        XCTAssertEqual(store.aktiv?.id, a.id)
        XCTAssertFalse(store.wechsle(zu: b.id, passwort: ""), "ein Profil mit Passwort verlangt es weiter")
        let ok = await store.wechsleImHintergrund(zu: a.id, passwort: "")
        XCTAssertTrue(ok)
        let geloescht = await store.loescheImHintergrund(a.id, passwort: "")
        XCTAssertTrue(geloescht)
        XCTAssertEqual(store.profile.map(\.id), [b.id])
    }

    func testPasswortFestlegenUndDanachWiederPflicht() async throws {
        let store = neuerStore()
        let p = try store.anlegen(name: "Mira", passwort: "")
        let kurz = await store.aenderePasswortImHintergrund(alt: "", neu: "abc")
        XCTAssertFalse(kurz, "auch das erste Passwort braucht vier Zeichen")
        XCTAssertTrue(store.aktiv?.ohnePasswort ?? false)
        let ok = await store.aenderePasswortImHintergrund(alt: "", neu: "abcd")
        XCTAssertTrue(ok)
        XCTAssertEqual(store.aktiv?.ohnePasswort, false)
        XCTAssertTrue(store.pruefe(passwort: "abcd", fuer: p.id))
        XCTAssertFalse(store.pruefe(passwort: "", fuer: p.id))
        let falsch = await store.aenderePasswortImHintergrund(alt: "", neu: "efgh")
        XCTAssertFalse(falsch, "jetzt zählt das alte Passwort")
    }

    func testProfilMitPasswortBehaeltEsBeimAendern() throws {
        let store = neuerStore()
        let p = try store.anlegen(name: "Mira", passwort: "abcd")
        XCTAssertFalse(p.ohnePasswort)
        XCTAssertFalse(store.aenderePasswort(alt: "", neu: "efgh"))
        XCTAssertTrue(store.aenderePasswort(alt: "abcd", neu: "efgh"))
        XCTAssertTrue(store.pruefe(passwort: "efgh", fuer: p.id))
    }
}
