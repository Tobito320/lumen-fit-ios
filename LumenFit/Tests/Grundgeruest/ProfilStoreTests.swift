import XCTest
@testable import LumenFit

@MainActor
final class ProfilStoreTests: XCTestCase {
    private func neuerStore(_ bund: SpeicherSchluesselbund = SpeicherSchluesselbund(), uhr: TestUhr = TestUhr()) -> (store: ProfilStore, kanal: EreignisKanal, bund: SpeicherSchluesselbund) {
        let kanal = EreignisKanal()
        return (ProfilStore(schluesselbund: bund, ereignisse: kanal, runden: 1_000, uhr: uhr.uhr), kanal, bund)
    }

    func testOhneProfilStartetDasOnboarding() {
        let (store, _, _) = neuerStore()
        XCTAssertFalse(store.hatProfil)
        XCTAssertNil(store.aktiv)
        XCTAssertTrue(store.profile.isEmpty)
    }

    func testAnlegenMachtDasProfilAktivUndSpeichertNurDieSpur() throws {
        let uhr = TestUhr()
        let (store, _, bund) = neuerStore(uhr: uhr)
        let profil = try store.anlegen(name: "  Beispiel  ", passwort: "geheim-1234")
        XCTAssertEqual(profil.name, "Beispiel")
        XCTAssertEqual(profil.erstellt, uhr.lesen)
        XCTAssertEqual(store.aktiv?.id, profil.id)
        XCTAssertTrue(store.pruefe(passwort: "geheim-1234", fuer: profil.id))
        XCTAssertFalse(store.pruefe(passwort: "falsch", fuer: profil.id))

        let gespeichert = try XCTUnwrap(bund.lese(ProfilStore.profileSchluessel))
        XCTAssertFalse(String(decoding: gespeichert, as: UTF8.self).contains("geheim-1234"), "das Passwort selbst wird nie gespeichert")
        XCTAssertEqual(bund.lese(ProfilStore.aktivSchluessel).map { String(decoding: $0, as: UTF8.self) }, profil.id.rawValue)
    }

    func testEingabenWerdenGeprueft() {
        let (store, _, _) = neuerStore()
        XCTAssertThrowsError(try store.anlegen(name: "   ", passwort: "abcd")) { XCTAssertEqual($0 as? ProfilFehler, .nameLeer) }
        XCTAssertThrowsError(try store.anlegen(name: "Beispiel", passwort: "abc")) { XCTAssertEqual($0 as? ProfilFehler, .passwortZuKurz) }
        XCTAssertFalse(store.hatProfil)
    }

    func testNeuerStoreMitDemselbenSchluesselbundFindetDasProfilWieder() throws {
        let (erster, _, bund) = neuerStore()
        let a = try erster.anlegen(name: "Eins", passwort: "abcd")
        let b = try erster.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertEqual(erster.aktiv?.id, b.id, "das zuletzt angelegte ist aktiv")

        let zweiter = neuerStore(bund).store
        XCTAssertEqual(zweiter.profile.map(\.name), ["Eins", "Zwei"])
        XCTAssertEqual(zweiter.aktiv?.id, b.id)
        XCTAssertTrue(zweiter.pruefe(passwort: "abcd", fuer: a.id))
    }

    func testWechselnBrauchtDasPasswortDesZielsUndMeldetEinEreignis() async throws {
        let (store, kanal, _) = neuerStore()
        let a = try store.anlegen(name: "Eins", passwort: "abcd")
        let b = try store.anlegen(name: "Zwei", passwort: "efgh")
        let strom = kanal.strom()

        XCTAssertFalse(store.wechsle(zu: a.id, passwort: "efgh"), "Passwort des anderen Profils zählt nicht")
        XCTAssertEqual(store.aktiv?.id, b.id)
        XCTAssertTrue(store.wechsle(zu: a.id, passwort: "abcd"))
        XCTAssertEqual(store.aktiv?.id, a.id)

        var gemeldet: ProfilID?
        for await ereignis in strom {
            if case .profilGewechselt(let id) = ereignis { gemeldet = id; break }
        }
        XCTAssertEqual(gemeldet, a.id)
    }

    func testUmbenennenUndPasswortAendern() throws {
        let (store, _, bund) = neuerStore()
        let profil = try store.anlegen(name: "Alt", passwort: "abcd")
        store.benenne(um: "  Neu ")
        XCTAssertEqual(store.aktiv?.name, "Neu")
        store.benenne(um: "   ")
        XCTAssertEqual(store.aktiv?.name, "Neu", "leerer Name ändert nichts")

        XCTAssertFalse(store.aenderePasswort(alt: "falsch", neu: "wxyz"))
        XCTAssertFalse(store.aenderePasswort(alt: "abcd", neu: "abc"), "neues Passwort zu kurz")
        XCTAssertTrue(store.aenderePasswort(alt: "abcd", neu: "wxyz"))
        XCTAssertFalse(store.pruefe(passwort: "abcd", fuer: profil.id))
        XCTAssertTrue(store.pruefe(passwort: "wxyz", fuer: profil.id))
        XCTAssertTrue(neuerStore(bund).store.pruefe(passwort: "wxyz", fuer: profil.id), "gespeichert")
    }

    func testLoeschenNurMitPasswortUndDasNaechsteProfilWirdAktiv() throws {
        let (store, _, bund) = neuerStore()
        let a = try store.anlegen(name: "Eins", passwort: "abcd")
        let b = try store.anlegen(name: "Zwei", passwort: "efgh")
        XCTAssertFalse(store.loesche(b.id, passwort: "abcd"))
        XCTAssertEqual(store.profile.count, 2)

        XCTAssertTrue(store.loesche(b.id, passwort: "efgh"))
        XCTAssertEqual(store.profile.map(\.id), [a.id])
        XCTAssertEqual(store.aktiv?.id, a.id, "war das aktive weg, wird das erste übrige aktiv")

        XCTAssertTrue(store.loesche(a.id, passwort: "abcd"))
        XCTAssertFalse(store.hatProfil)
        XCTAssertNil(bund.lese(ProfilStore.aktivSchluessel), "ohne aktives Profil kein Eintrag")
        XCTAssertTrue(neuerStore(bund).store.profile.isEmpty)
    }

    func testKaputterSchluesselbundEintragErgibtEinenLeerenStore() throws {
        let bund = SpeicherSchluesselbund()
        try bund.schreibe(Data("kein json".utf8), fuer: ProfilStore.profileSchluessel)
        XCTAssertFalse(neuerStore(bund).store.hatProfil)
    }
}
