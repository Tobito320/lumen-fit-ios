import XCTest
@testable import LumenFit

/// Die Varianten, die das Passwort abseits des Hauptthreads rechnen (SPEC 5.4), müssen dieselben Regeln haben wie die synchronen.
@MainActor
final class ProfilStoreHintergrundTests: XCTestCase {
    private func neuerStore() -> ProfilStore {
        ProfilStore(schluesselbund: SpeicherSchluesselbund(), ereignisse: EreignisKanal(), runden: 1_000)
    }

    func testAnlegenImHintergrundMachtDasProfilAktivMitRichtigerSpur() async throws {
        let store = neuerStore()
        let profil = try await store.anlegenImHintergrund(name: " Beispiel ", passwort: "geheim-1234")
        XCTAssertEqual(profil.name, "Beispiel")
        XCTAssertEqual(store.aktiv?.id, profil.id)
        XCTAssertTrue(store.pruefe(passwort: "geheim-1234", fuer: profil.id))
        XCTAssertFalse(store.pruefe(passwort: "falsch", fuer: profil.id))
    }

    func testAnlegenImHintergrundPruefenDieEingabenVorDerRechnung() async {
        let store = neuerStore()
        do { _ = try await store.anlegenImHintergrund(name: " ", passwort: "abcd"); XCTFail("Name leer") } catch { XCTAssertEqual(error as? ProfilFehler, .nameLeer) }
        do { _ = try await store.anlegenImHintergrund(name: "Beispiel", passwort: "abc"); XCTFail("zu kurz") } catch { XCTAssertEqual(error as? ProfilFehler, .passwortZuKurz) }
        XCTAssertFalse(store.hatProfil)
    }

    func testWechselnImHintergrundBrauchtDasPasswortDesZiels() async throws {
        let store = neuerStore()
        let erstes = try store.anlegen(name: "Eins", passwort: "abcd")
        let zweites = try store.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertEqual(store.aktiv?.id, zweites.id)
        let falsch = await store.wechsleImHintergrund(zu: erstes.id, passwort: "efgh")
        XCTAssertFalse(falsch)
        XCTAssertEqual(store.aktiv?.id, zweites.id)
        let richtig = await store.wechsleImHintergrund(zu: erstes.id, passwort: "abcd")
        XCTAssertTrue(richtig)
        XCTAssertEqual(store.aktiv?.id, erstes.id)
    }

    func testPasswortAendernImHintergrund() async throws {
        let store = neuerStore()
        let profil = try store.anlegen(name: "Eins", passwort: "abcd")
        let falsch = await store.aenderePasswortImHintergrund(alt: "xxxx", neu: "neues-pw")
        XCTAssertFalse(falsch)
        let zuKurz = await store.aenderePasswortImHintergrund(alt: "abcd", neu: "abc")
        XCTAssertFalse(zuKurz)
        let ok = await store.aenderePasswortImHintergrund(alt: "abcd", neu: "neues-pw")
        XCTAssertTrue(ok)
        XCTAssertTrue(store.pruefe(passwort: "neues-pw", fuer: profil.id))
        XCTAssertFalse(store.pruefe(passwort: "abcd", fuer: profil.id))
    }

    func testLoeschenImHintergrundBrauchtDasPasswort() async throws {
        let store = neuerStore()
        let profil = try store.anlegen(name: "Eins", passwort: "abcd")
        let falsch = await store.loescheImHintergrund(profil.id, passwort: "falsch")
        XCTAssertFalse(falsch)
        XCTAssertTrue(store.hatProfil)
        let ok = await store.loescheImHintergrund(profil.id, passwort: "abcd")
        XCTAssertTrue(ok)
        XCTAssertFalse(store.hatProfil)
    }

    func testPasswortRechnenImHintergrundGleichDerSynchronenSpur() async {
        let spur = await Passwort.spurImHintergrund(fuer: "abcd", runden: 1_000)
        XCTAssertTrue(Passwort.stimmt("abcd", mit: spur))
        let stimmt = await Passwort.stimmtImHintergrund("abcd", mit: spur)
        let falsch = await Passwort.stimmtImHintergrund("abce", mit: spur)
        XCTAssertTrue(stimmt)
        XCTAssertFalse(falsch)
    }
}
